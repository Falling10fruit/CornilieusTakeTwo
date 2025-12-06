import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';

import { linkEntity } from "./linkEntity.js";
import { parseEntityJson } from "./parseEntitiesJson.js";

const ENTITIES_JSON = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'src', 'json', 'entities', 'entities.json');
const { entities_array, entity_indicies } = await parseEntityJson(ENTITIES_JSON);

if (process.argv.length > 2) {
    for (let i = 2; i < process.argv.length; i++) {
        const entity_id = process.argv[i];
        const entity_index = entity_indicies[entity_id];
        const entity_json = entities_array[entity_index];

        linkEntity(entity_json);
    }
} else {
// Bokura no Libido
// 601310 different
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
        const entity_source_wgsl =  (await fs.readFile(entity_source_path, { encoding: 'utf-8' }));
        entity_source += entity_source_wgsl;
    }

    const entity_base_path = path.join("resources", "wgsl", "entities", "core", "entities_base.wgsl");
    const entity_base_wgsl = (await fs.readFile(entity_base_path, { encoding: 'utf-8' }));

    const main_path = path.join("resources", "wgsl", "entities", "core", "entities.wgsl");
    const main_wgsl = (await fs.readFile(main_path, { encoding: 'utf-8' }));
    
    const main_sections = main_wgsl.split("// insert here");
    const linked_source = entity_base_wgsl + entity_source + main_sections[0] + logic_branch + main_sections[1] + collision_handler_branch + main_sections[2];

    const linked_path = path.join("resources", "wgsl", "entities", "entities_linked.wgsl");
    fs.writeFile(linked_path, linked_source, (err) => { console.error(err); });
}