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
    const main_wgsl = (await fs.readFile(main_path, { encoding: 'utf-8' }));

    let insert_sections = main_wgsl.split("// insert here")
}

export { linkEntity }