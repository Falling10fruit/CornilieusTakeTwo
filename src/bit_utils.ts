const shift_left = (value : number, shift : number) => (value << shift) >>> 0;
const shift_right = (value : number, shift : number) => (value >> shift) >>> 0;

function add32Uints(...numbers: number[]) {
    let sum = 0;
    for (let i = 0; i < numbers.length; i++) { sum = (sum + numbers[i]) >>> 0; }
    return sum >>> 0;
}

export { shift_left, shift_right, add32Uints }