import { fileURLToPath } from 'node:url';
import path from 'path';
import { writeFile, readFile } from "node:fs/promises"
import { parseSpriteJson } from "./parseEntitiesJson.js";

const SPRITES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'sprites', 'sprites.json');
const { sprites_array, sprite_indicies } = await parseSpriteJson(SPRITES_JSON);

const sprite_vertex_path = path.join("resources", "wgsl", "spritesVertex_source.wgsl");
const sprite_vertex_source = await readFile(sprite_vertex_path, { encoding: 'utf-8' });
const sprite_vertex_split = sprite_vertex_source.split("// insert here")
const sprite_vertex_out = sprite_vertex_split[0] + `
const spritesArray : array<vec4u, ${sprites_array.length}> = array(
    ${sprites_array.map(sprite_data => `vec4u(${sprite_data.coordinates.join(", ")})`).join(`,
    `)}
);` + sprite_vertex_split[1];

const sprite_vertex_out_path = path.join("resources", "wgsl", "spritesVertex.wgsl")
writeFile(sprite_vertex_out_path, sprite_vertex_out);

const entities_compute_path = path.join("resources", "wgsl", "entities", "core", "entities_base.wgsl");
const entities_compute_source = await readFile(entities_compute_path, { encoding: 'utf-8' });
const entities_compute_split = entities_compute_source.split("// sprite insert")
const entities_compute_out = entities_compute_split[0] + `// sprite insert
    ` + sprites_array.map(sprite_data => `${sprite_data.sprite_id}: u32`).join(`,
    `) + `
    // sprite insert` + entities_compute_split[2] + `// sprite insert
    ` + sprites_array.map((useless, index) => index).join(`,
    `) + `
    // sprite insert` + entities_compute_split[4];

const entities_compute_out_path = path.join("resources", "wgsl", "entities", "core", "entities_base.wgsl");
writeFile(entities_compute_out_path, entities_compute_out);