import * as fs from "node:fs/promises"

interface spriteStruct {
    "sprite_id": string,
    "splice": [number, number, number, number]
}

interface indexMapElement {
    "index": number,
    "splice": [number, number, number, number]
}

async function parseSpritesJson(SPRITES_JSON_PATH: string) {
    const spritesJson = await readSpriteJsonFile(SPRITES_JSON_PATH);
    const sprites: Record<string, spriteStruct> = spritesJson.sprites;

    let spritesIndexMap: Record<string, indexMapElement> = {};
    let spritesArray: Array<string> = [];

    Object.entries(sprites).forEach(([sprite_id, sprite], spriteIndex) => {
        spritesArray.push(sprite_id);
        spritesIndexMap[sprite_id] = {
            index: spriteIndex,
            splice: sprite.splice
        }
    });

    return { spritesIndexMap, spritesArray }
}

async function readSpriteJsonFile(SPRITES_JSON_PATH: string) {
    const data = await fs.readFile(SPRITES_JSON_PATH);
    return JSON.parse(data.toString());
}

export { parseSpritesJson }