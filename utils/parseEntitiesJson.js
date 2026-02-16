import * as fs from "node:fs/promises"

// interface jointFnStruct {
//     "behavior": String,
//     "description": String
// }

// interface jointDefaultStruct {
//     "behavior": String,
//     "description": String
//     "position": Array<Number> | String,
//     "angle": Number | String,
// }

// interface spriteStruct {
//     "name": String,
//     "splice": Array<Number>
// }

// interface EntityStruct {
//     "entity_id": string,
//     "description": "test character",
//     "mass": 40,
//     "nodes": Array<Number>,
//     "joints": Array<jointFnStruct | jointDefaultStruct>,
//     "sprites": Array<spriteStruct>
// }

async function parseEntityJson(ENTITIES_JSON_PATH) {
    const entities_array = await readJsonFile(ENTITIES_JSON_PATH);

    let entity_indicies = {};
    for (let i = 0; i < entities_array.length; i++) {
        entity_indicies[entities_array[i].entity_id] = i;
    }

    return { entities_array, entity_indicies }
}

async function parseSpriteJson(SPRITE_JSON_PATH) {
    const sprites_array = await readJsonFile(SPRITE_JSON_PATH);

    let sprite_indicies = {};
    for (let i = 0; i < sprites_array.length; i++) {
        sprite_indicies[sprites_array[i].sprite_id] = i;
    }
    
    return { sprites_array, sprite_indicies }
}

async function readJsonFile(path) {
    const data = await fs.readFile(path);
    return JSON.parse(data.toString());
}

export { parseEntityJson, parseSpriteJson }