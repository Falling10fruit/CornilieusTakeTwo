import { fileURLToPath } from 'node:url';
import path from 'node:path';

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
}