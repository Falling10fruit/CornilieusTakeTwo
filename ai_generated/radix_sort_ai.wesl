enable subgroups;
// All lanes do reach the subgroup operations below, but the compiler cannot prove
// it, so silence its uniformity analysis.
diagnostic(off, subgroup_uniformity);

// ---- Constants (overridable ones are set from JavaScript at pipeline creation) ----
override WG: u32 = 256u;      // threads per workgroup
override MAXSG: u32 = 8u;     // max subgroups per workgroup (= WG / smallest subgroup size)
const ITEMS = 16u;            // elements handled per thread; tile size = WG * ITEMS
const NUM_BINS = 256u;        // 8-bit digit -> 256 bins
const DIGIT_MASK = 255u;
const SCAN_PER_THREAD = 16u;  // hist entries each thread scans in scanBlocks

// ---- Bindings -----------------------------------------------------------------
struct Params {
  shift: u32,        // 0 for the low-digit pass, 8 for the high-digit pass
  numTiles: u32,
  numElements: u32,
  pad: u32,
};
@group(0) @binding(0) var<uniform> params: Params;
@group(0) @binding(1) var<storage, read> src: array<vec4u>;
@group(0) @binding(2) var<storage, read_write> dst: array<vec4u>;
// Per-tile digit counts at [bin * numTiles + tile]. After scanning, the same slots
// hold start offsets. Scan-block totals are appended after the NUM_BINS*numTiles entries.
@group(0) @binding(3) var<storage, read_write> hist: array<u32>;
// verify results: [0] order errors, [1] stability errors, [2] payload errors
@group(0) @binding(4) var<storage, read_write> verifyErrors: array<atomic<u32>, 4>;

// ---- Small helpers --------------------------------------------------------------
fn hash(i: u32) -> u32 {
  var x = i * 0x9E3779B1u;
  x ^= x >> 15u;  x *= 0x85EBCA77u;
  x ^= x >> 13u;  x *= 0xC2B2AE3Du;
  x ^= x >> 16u;
  return x;
}

fn digitOf(key: u32) -> u32 { return (key >> params.shift) & DIGIT_MASK; }

// How many bins each thread must handle so that WG threads cover all NUM_BINS.
fn binsPerThread() -> u32 { return (NUM_BINS + WG - 1u) / WG; }

fn sum4(v: vec4u) -> u32 { return v.x + v.y + v.z + v.w; }

// ---- Finding lanes that share a digit -------------------------------------------
struct DigitMatch {
  rank: u32,     // number of lower-numbered lanes holding the same digit
  count: u32,    // number of lanes holding this digit
  leader: u32,   // lowest lane holding this digit
};

fn matchDigit(digit: u32, lane: u32) -> DigitMatch {
  // Build a 128-bit lane mask of "lanes whose digit equals mine". Start with all
  // active lanes, then for each of the 8 bits keep only lanes that agree with me.
  var same = subgroupBallot(true);
  for (var bit = 0u; bit < 8u; bit++) {
    let iHaveBit = ((digit >> bit) & 1u) == 1u;
    let ballot = subgroupBallot(iHaveBit);
    same &= select(~ballot, ballot, iHaveBit);
  }

  // Mask of lanes below mine, spread across four 32-bit words.
  var lowerLanes = vec4u(0u);
  for (var word = 0u; word < 4u; word++) {
    let firstLane = word * 32u;
    if (lane >= firstLane + 32u)  { lowerLanes[word] = 0xffffffffu; }
    else if (lane > firstLane)    { lowerLanes[word] = (1u << (lane - firstLane)) - 1u; }
  }

  // Lowest set bit across the four words is the leader lane.
  var leader = 96u + firstTrailingBit(same.w);
  if      (same.x != 0u) { leader = firstTrailingBit(same.x); }
  else if (same.y != 0u) { leader = 32u + firstTrailingBit(same.y); }
  else if (same.z != 0u) { leader = 64u + firstTrailingBit(same.z); }

  return DigitMatch(sum4(countOneBits(same & lowerLanes)), sum4(countOneBits(same)), leader);
}

// =============================================================================
// Kernel: init. Writes record i = (16-bit key, index, payload1, payload2).
// =============================================================================
@compute @workgroup_size(WG)
fn init(@builtin(workgroup_id) workgroupId: vec3u,
        @builtin(local_invocation_index) localIdx: u32) {
  for (var r = 0u; r < ITEMS; r++) {
    let i = workgroupId.x * WG * ITEMS + r * WG + localIdx;
    dst[i] = vec4u(hash(i) & 0xFFFFu, i, hash(i + 1u), ~i);
  }
}

// =============================================================================
// Kernel 1: histogram. Count digits in this workgroup's tile.
// =============================================================================
var<workgroup> tileCounts: array<atomic<u32>, NUM_BINS>;

@compute @workgroup_size(WG)
fn histogram(@builtin(workgroup_id) workgroupId: vec3u,
             @builtin(local_invocation_index) localIdx: u32,
             @builtin(subgroup_invocation_id) lane: u32) {
  let tile = workgroupId.x;

  for (var k = 0u; k < binsPerThread(); k++) {          // zero the counters
    let bin = k * WG + localIdx;
    if (bin < NUM_BINS) { atomicStore(&tileCounts[bin], 0u); }
  }
  workgroupBarrier();

  for (var r = 0u; r < ITEMS; r++) {
    let digit = digitOf(src[tile * WG * ITEMS + r * WG + localIdx].x);
    let m = matchDigit(digit, lane);
    // Only one lane per distinct digit does the atomic add, adding the whole group.
    if (m.rank == 0u) { atomicAdd(&tileCounts[digit], m.count); }
  }
  workgroupBarrier();

  for (var k = 0u; k < binsPerThread(); k++) {          // publish bin-major
    let bin = k * WG + localIdx;
    if (bin < NUM_BINS) { hist[bin * params.numTiles + tile] = atomicLoad(&tileCounts[bin]); }
  }
}

// =============================================================================
// Kernel 2: scanBlocks. Exclusive scan of hist in blocks of WG*SCAN_PER_THREAD
// entries. Each thread owns 16 consecutive entries. Block totals go to
// hist[NUM_BINS * numTiles + block].
// =============================================================================
var<workgroup> subgroupTotals: array<u32, MAXSG>;

@compute @workgroup_size(WG)
fn scanBlocks(@builtin(workgroup_id) workgroupId: vec3u,
              @builtin(local_invocation_index) localIdx: u32,
              @builtin(subgroup_invocation_id) lane: u32,
              @builtin(subgroup_size) sgSize: u32) {
  let base = (workgroupId.x * WG + localIdx) * SCAN_PER_THREAD;

  var vals: array<u32, SCAN_PER_THREAD>;
  var mySum = 0u;
  for (var i = 0u; i < SCAN_PER_THREAD; i++) { vals[i] = hist[base + i]; mySum += vals[i]; }

  // Step 1: scan across the lanes of my subgroup.
  let sumOfLowerLanes = subgroupExclusiveAdd(mySum);
  let subgroupSum = subgroupAdd(mySum);
  let sg = localIdx / sgSize;
  let numSubgroups = WG / sgSize;
  if (lane == 0u) { subgroupTotals[sg] = subgroupSum; }
  workgroupBarrier();

  // Step 2: add totals of earlier subgroups; also total the whole block.
  var running = sumOfLowerLanes;
  var blockTotal = 0u;
  for (var j = 0u; j < numSubgroups; j++) {
    let t = subgroupTotals[j];
    if (j < sg) { running += t; }
    blockTotal += t;
  }

  // Step 3: write the exclusive scan of my 16 entries.
  for (var i = 0u; i < SCAN_PER_THREAD; i++) { hist[base + i] = running; running += vals[i]; }
  if (localIdx == 0u) { hist[NUM_BINS * params.numTiles + workgroupId.x] = blockTotal; }
}

// =============================================================================
// Kernel 3: scanSums. A single workgroup does an exclusive scan of block totals.
// =============================================================================
@compute @workgroup_size(WG)
fn scanSums(@builtin(local_invocation_index) localIdx: u32,
            @builtin(subgroup_invocation_id) lane: u32,
            @builtin(subgroup_size) sgSize: u32) {
  let totalsOffset = NUM_BINS * params.numTiles;
  let numBlocks = totalsOffset / (WG * SCAN_PER_THREAD);
  let chunk = (numBlocks + WG - 1u) / WG;     // block totals per thread
  let base = localIdx * chunk;

  var mySum = 0u;
  for (var i = 0u; i < chunk; i++) { if (base + i < numBlocks) { mySum += hist[totalsOffset + base + i]; } }

  let sumOfLowerLanes = subgroupExclusiveAdd(mySum);
  let subgroupSum = subgroupAdd(mySum);
  let sg = localIdx / sgSize;
  if (lane == 0u) { subgroupTotals[sg] = subgroupSum; }
  workgroupBarrier();

  var running = sumOfLowerLanes;
  for (var j = 0u; j < sg; j++) { running += subgroupTotals[j]; }
  for (var i = 0u; i < chunk; i++) {
    if (base + i < numBlocks) {
      let v = hist[totalsOffset + base + i];
      hist[totalsOffset + base + i] = running;
      running += v;
    }
  }
}

// =============================================================================
// Kernel 4: scatter. Move each element to its sorted position.
//
// Each subgroup owns a contiguous chunk of ITEMS * subgroupSize elements, so
// iterating (round, lane) walks that chunk in input order. That keeps the sort stable.
//
// binTable[subgroup][bin] first counts how many of this subgroup's elements have
// each digit, then is rewritten as the absolute output offset of the subgroup's
// first element with that digit.
// =============================================================================
var<workgroup> binTable: array<u32, MAXSG * NUM_BINS>;

@compute @workgroup_size(WG)
fn scatter(@builtin(workgroup_id) workgroupId: vec3u,
           @builtin(local_invocation_index) localIdx: u32,
           @builtin(subgroup_invocation_id) lane: u32,
           @builtin(subgroup_size) sgSize: u32) {
  let sg = localIdx / sgSize;
  let numSubgroups = WG / sgSize;
  let tile = workgroupId.x;
  let firstElement = tile * WG * ITEMS + sg * ITEMS * sgSize + lane;   // element for round 0

  for (var k = 0u; k < MAXSG * NUM_BINS / WG; k++) { binTable[k * WG + localIdx] = 0u; }
  workgroupBarrier();

  // Phase A: for each element, find its rank among earlier elements in this
  // subgroup's chunk that share its digit.
  var localRank: array<u32, ITEMS>;
  for (var r = 0u; r < ITEMS; r++) {
    let digit = digitOf(src[firstElement + r * sgSize].x);
    let m = matchDigit(digit, lane);

    // The leader lane reads the running count for this digit and bumps it by the group size.
    var countBefore = 0u;
    if (m.rank == 0u) {
      countBefore = binTable[sg * NUM_BINS + digit];
      binTable[sg * NUM_BINS + digit] = countBefore + m.count;
    }
    countBefore = subgroupShuffle(countBefore, m.leader);   // everyone with this digit gets the leader's value
    localRank[r] = countBefore + m.rank;
    workgroupBarrier();                                     // make leader writes visible to the next round
  }

  // Phase B: turn per-subgroup counts into absolute offsets. For each bin, walk the
  // subgroups in order, starting from the bin/tile's global offset from the scan.
  let totalsOffset = NUM_BINS * params.numTiles;
  for (var k = 0u; k < binsPerThread(); k++) {
    let bin = k * WG + localIdx;
    if (bin < NUM_BINS) {
      let histIdx = bin * params.numTiles + tile;
      var offset = hist[histIdx] + hist[totalsOffset + histIdx / (WG * SCAN_PER_THREAD)];
      for (var s = 0u; s < numSubgroups; s++) {
        let count = binTable[s * NUM_BINS + bin];
        binTable[s * NUM_BINS + bin] = offset;
        offset += count;
      }
    }
  }
  workgroupBarrier();

  // Phase C: write each element to (my subgroup's offset for its digit) + (its rank).
  for (var r = 0u; r < ITEMS; r++) {
    let element = src[firstElement + r * sgSize];
    dst[binTable[sg * NUM_BINS + digitOf(element.x)] + localRank[r]] = element;
  }
}

// =============================================================================
// Kernel: verify. Checks the final array, counting three kinds of error.
// =============================================================================
@compute @workgroup_size(WG)
fn verify(@builtin(workgroup_id) workgroupId: vec3u,
          @builtin(local_invocation_index) localIdx: u32,
          @builtin(subgroup_invocation_id) lane: u32) {
  var orderErrors = 0u;      // key smaller than the previous one
  var stabilityErrors = 0u;  // equal keys but original indices out of order
  var payloadErrors = 0u;    // record is not an intact original record

  for (var r = 0u; r < ITEMS; r++) {
    let i = workgroupId.x * WG * ITEMS + r * WG + localIdx;
    let e = src[i];

    if (e.y >= params.numElements || e.x != (hash(e.y) & 0xFFFFu) ||
        e.z != hash(e.y + 1u) || e.w != ~e.y) { payloadErrors++; }

    if (i > 0u) {
      let prev = src[i - 1u];
      if (prev.x > e.x)                         { orderErrors++; }
      else if (prev.x == e.x && prev.y >= e.y)  { stabilityErrors++; }
    }
  }

  // Reduce within the subgroup, then one atomic per subgroup.
  let o = subgroupAdd(orderErrors);
  let s = subgroupAdd(stabilityErrors);
  let p = subgroupAdd(payloadErrors);
  if (lane == 0u) {
    atomicAdd(&verifyErrors[0], o);
    atomicAdd(&verifyErrors[1], s);
    atomicAdd(&verifyErrors[2], p);
  }
}