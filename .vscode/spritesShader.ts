import * as fs from "fs"
const SPRITES_JSON_PATH: string = `../src/json/sprites/sprites.json`;
const SPRITESVERTEX_WGSL_PATH: string = `../src/wgsl/spritesVertex.wgsl`

interface IndexMapElement {
    index: number,
    splice: [number, number, number, number]
}

let spritesIndexMap: Record<string, IndexMapElement> = {};
let spritesArray: Array<string> = [];

function compileSpritesShader() {
    let vec4f: Array<string> = [];
        vec4f.push(`vec4f(${ sprite.splice.join(".0, ") }.0)`);
        

    let spritesArrayWgsl: string = `const spritesArray : array<vec4u, 1> = array(${ vec4f.join(`, `) });`;

    fs.readFile(SPRITESVERTEX_WGSL_PATH, (err, data) => {
            if (err) return console.error(err);
            
            let vertexSource: string = data.toString();
        }
    )

    let spritesArrayRegex = new RegExp("/*spritesArray*/", "g");
}

export { compileSpritesShader }