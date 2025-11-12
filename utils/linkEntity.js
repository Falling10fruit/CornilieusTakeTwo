import path from 'node:path'
import fs from 'node:fs/promises'
import { readFile } from 'node:fs';

async function linkEntity(entities
//     entity_id,
//     description,
//     mass,
//     nodes,
//     joints,
//     sprites
// }
) {
    const entity_path = path.join("resources", "wgsl", "entities", "entities_" + entity_id + ".wgsl");
    const main_path = path.join("resources", "wgsl", "entities", "entities.wgsl");

    const entity_wgsl = (await fs.readFile(entity_path, { encoding: 'utf-8' }));
    update_mains_and_handlers(entities);

    const main_wgsl = (await fs.readFile(main_path, { encoding: 'utf-8' }));

    const regex =/\r\n|\n|\r/g;

    // console.log(JSON.stringify(source_wgsl).match(/\r\n|\n|\r/g));
    const string = "012345678901234567890"
    console.log(string.slice(0, 18));

    let insert_sections = main_wgsl.split("// insert here")
    console.log(insert_sections);
}

function update_mains_and_handlers(entities) {
    const current_mains = await fs.readFile("entity_mains.wgsl", { encoding: 'utf-8' });
    const current_handlers = await fs.readFile("entity_mains.wgsl", { encoding: 'utf-8' });

    const linked_entities = JSON.parse(await fs.readFile('entities_linked.json', { encoding: 'utf-8'}));
    for (const entity in entities) {
        if (linked_entities.hasOwnProperty(entity.entity_id)) {
            
        }
    }
}

export { linkEntity }