const SPRITES_JSON_PATH: string = `../src/json/sprites/sprites.json`;

import { parseSpritesJson } from "./parseSpriteJson";

interface IndexMapElement {
    index: number,
    splice: [number, number, number, number]
}
const { spritesIndexMap, spritesArray } = parseSpritesJson(SPRITES_JSON_PATH);

