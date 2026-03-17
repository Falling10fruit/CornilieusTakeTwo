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
        rotation : number,
        x_velocity : number,
        y_velocity : number,
        rotation_velocity : number
    }) {
        const { entity_type, global_x_position, global_y_position, rotation, x_velocity, y_velocity, rotation_velocity} = parameters;
        if (typeof entity_type == "number") { this.#entity_type = entity_type; }
        if (typeof entity_type == "string") { this.#entity_type = entity_indicies[entity_type] as any; }

        this.#global_x_position = global_x_position;
        this.#global_y_position = global_y_position;
        this.#rotation = rotation;
        this.#y_velocity = y_velocity;
        this.#x_velocity = x_velocity;
        this.#rotation_velocity = rotation_velocity;
    }

    serialized_representation() {
        const entity_type = shift_left(this.#entity_type, 23);
        const x_velocity = shift_left(this.#x_velocity, 22);
        const y_velocity = shift_left(this.#y_velocity, 12);


        const formatted_x_position = Math.round(this.#global_x_position * 2**(9 - 3));
        const formatted_y_position = Math.round(this.#global_y_position * 2**(9 - 3));
        const chunk = formatted_x_position / (2**13) + window.world.width * formatted_y_position / (2**13);
        const serialized_x_position = formatted_x_position % (2**13);
        const serialized_y_position = formatted_y_position % (2**13);

        // console.log("serialized x position");
        // console.log(serialized_x_position);

        const x_position_first_part = shift_right(serialized_x_position, 6);
        const x_position_second_part = shift_left(serialized_x_position, 26);
        const y_position = shift_left(serialized_y_position, 13);

        // console.log(entity_type);

        return new Uint32Array([
            add32Uints(entity_type, chunk, x_position_first_part),
            add32Uints(x_position_second_part, y_position, this.#rotation),
            add32Uints(x_velocity, y_velocity, this.#rotation_velocity),
            0, 0, 0, 0
        ]);
    }
}