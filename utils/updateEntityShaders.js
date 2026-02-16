import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { writeFile, readFile } from 'node:fs/promises';

import { linkEntity } from "./linkEntity.js";
import { parseEntityJson, parseSpriteJson } from "./parseEntitiesJson.js";
import { writeFileSync } from 'node:fs';

const ENTITIES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'entities', 'entities.json');
const { entities_array, entity_indicies } = await parseEntityJson(ENTITIES_JSON);

const ENTITY_INDICIES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'entities', 'entity_indicies.json');
writeFile(ENTITY_INDICIES_JSON, JSON.stringify(entity_indicies));

const SPRITES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'sprites', 'sprites.json');
const { sprites_array, sprite_indicies } = await parseSpriteJson(SPRITES_JSON);

const SPRITE_INDICIES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'sprites', 'sprite_indicies.json');
writeFile(SPRITE_INDICIES_JSON, JSON.stringify(sprite_indicies))

{
    const sprite_vertex_path = path.join("resources", "wgsl", "spritesVertex_source.wgsl");
    const sprite_vertex_source = await readFile(sprite_vertex_path, { encoding: 'utf-8' });
    const sprite_vertex_split = sprite_vertex_source.split("// insert here")
    const sprite_vertex_out = sprite_vertex_split[0] + `
const spritesArray : array<vec4u, ${sprites_array.length}> = array(
    ${sprites_array.map(sprite_data => `vec4u(${sprite_data.splice.join(", ")})`).join(`,
    `)}
);` + sprite_vertex_split[1];

    const sprite_vertex_out_path = path.join("resources", "wgsl", "spritesVertex.wgsl")
    writeFile(sprite_vertex_out_path, sprite_vertex_out);
}

if (process.argv.length > 2) {
    for (let i = 2; i < process.argv.length; i++) {
        const entity_id = process.argv[i];
        const entity_index = entity_indicies[entity_id];
        const entity_json = entities_array[entity_index];

        linkEntity(entity_json);
    }
} else {
    // 601310 different and 619383 619320
    // 510585
    let logic_branch = `//`; // To comment out the first "else" statement
    let collision_handler_branch = "//";
    let entity_source = ``;

    for (let entity in entities_array) {
        const { entity_id } = entities_array[entity];

        logic_branch += ` else
    if (entity_type == ${entity_indicies[entity_id]}) { main_${entity_id}(); }`;
        
        collision_handler_branch += ` else
    if (entity_type == ${entity_indicies[entity_id]}) { handle_collision_${entity_id}(collider); }`;
    
        const entity_source_path = path.join("resources", "wgsl", "entities", "modules", `entities_${entity_id}.wgsl`);
        const entity_source_wgsl =  (await readFile(entity_source_path, { encoding: 'utf-8' }));
        entity_source += entity_source_wgsl;
    }

    const entity_base_path = path.join("resources", "wgsl", "entities", "core", "entities_base.wgsl");
    const entity_base_wgsl = (await readFile(entity_base_path, { encoding: 'utf-8' }));
    
    const insert_split = entity_base_wgsl.split("// insert here");
    const linked_source = insert_split[0] + logic_branch + insert_split[1] + collision_handler_branch + insert_split[2] + entity_source;

    const linked_path = path.join("resources", "wgsl", "entities", "entities_linked.wgsl");
    writeFile(linked_path, linked_source, (err) => { console.error(err); });
}