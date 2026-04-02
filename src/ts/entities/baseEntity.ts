import { shift_left, shift_right, add32Uints, print_bits } from "../../bit_utils";

const entity_indicies = fetch("./src/json/entities/entity_indicies.json").then((res) => {
    if (!res.ok) { throw new Error(`Failed to fetch entity indicies json with http code ${res.status}`) }
    return res.json()
});

// type (2^9 = 512)     chunk index 2^16         xPos(2^13)       yPos (16 * 8 pixels divided by 2^13)         rotation 2^13 
//  [ 01010101 0 ]   [ 1010101 01010101 0 ] [ 1010101 | 010101 ]           [ 01 01010101 010 ]              [ 10101 01010101 ] |
// x_vel      y_vel      rotate_vel
// 0101010101 0101010101 010101010101 
// 2^10 -> 1023          2^12 -> 4095

export class Entity {
    #entity_type : number | string;
    #global_x_position : number;
    #global_y_position : number;
    #rotation : number;
    #y_velocity : number;
    #x_velocity : number;
    #rotation_velocity : number

    constructor (parameters: {
        entity_type : number | string,
        global_x_position : number,
        global_y_position : number,
        /** In radians */
        rotation : number,
        x_velocity : number,
        y_velocity : number,
        /** In radians */
        rotation_velocity : number
    }) {
        const { entity_type, global_x_position, global_y_position, rotation, x_velocity, y_velocity, rotation_velocity} = parameters;
        if (typeof entity_type == "number") { this.#entity_type = entity_type; }
        if (typeof entity_type == "string") { this.#entity_type = entity_indicies[entity_type] as any; }

        this.#global_x_position = global_x_position;
        this.#global_y_position = global_y_position;
        this.#rotation = rotation;
        this.#x_velocity = x_velocity;
        this.#y_velocity = y_velocity;
        this.#rotation_velocity = rotation_velocity;
    }

    serialized_representation() {
        const entity_type = shift_left(this.#entity_type, 23);
        
        const formatted_x_position = Math.round(this.#global_x_position * 64);
        const formatted_y_position = Math.round(this.#global_y_position * 64);
        const chunk = Math.floor(formatted_x_position / (2**13)) + window.world.width * Math.floor(formatted_y_position / (2**13));
        const serialized_x_position = formatted_x_position % (2**13);
        const serialized_y_position = formatted_y_position % (2**13);
        
        const x_position_first_part = shift_right(serialized_x_position, 6);
        const x_position_second_part = shift_left(serialized_x_position, 26);
        const y_position = shift_left(serialized_y_position, 13);
        
        const x_velocity = shift_left(serialize_to_10_bit(this.#x_velocity), 22);
        
        // console.log("serialized x velocity");
        // print_bits(x_velocity);
        const y_velocity = shift_left(serialize_to_10_bit(this.#y_velocity), 12);

        const serialized_rotation = Math.round(this.#rotation * 2**13 / (2 * Math.PI)) % 2**13;
        const serialized_rotation_velocity = Math.round(this.#rotation_velocity * 2**13 / (2 * Math.PI)) % 2**13;
        
        // console.log("testing", parse_from_10_bit(serialize_to_10_bit(13)));
        // print_bits(serialize_to_10_bit(13));

        return new Uint32Array([
            add32Uints(entity_type, (chunk << 7), x_position_first_part),
            add32Uints(x_position_second_part, y_position, serialized_rotation),
            add32Uints(x_velocity, y_velocity, serialized_rotation_velocity),
            0,
        ]);
    }
}

// total bits doesn't include sign bit
// const total_bits = 9
// const exponent_bias = -1;
// const exponent_base = 32;
// const mantissa_base = 2;
// const exponent_bits = 2;
// const mantissa_bits = total_bits - exponent_bits;

const bitcast_buffer = new ArrayBuffer(4);
const bitcast_float = new Float32Array(bitcast_buffer);
const bitcast_uint = new Uint32Array(bitcast_buffer);

function serialize_to_10_bit(float: number) {
    bitcast_float[0] = float;

    const v_exponent = ((bitcast_uint[0] >> 23) & 255) - 127 + 8;
    if (v_exponent < 0) return 0;
    const v_mantissa = Math.round((bitcast_uint[0] & 8388607) / 2**19);

    // console.log(v_exponent);
    // console.log((bitcast_uint[0] & 8388607) / 2**19);

    return ((float < 0 ? 1 : 0) << 9) + (v_exponent << 4) + v_mantissa;
}

function parse_from_10_bit(bits: number) {
    const sign_bit = bits >> 9;
    const exponent = ((bits >> 4) & 31) - 8;
    const mantissa = (bits & 15) / 16 + 1;
    
    return (1 - sign_bit * 2) * 2**exponent * mantissa;
}