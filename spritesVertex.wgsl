struct TransformStruct {
    @location(0) translate : vec2f,
    @location(1) scale : f32,
    @location(2) rotation : f32,
}

@group(0) @binding(0) var<uniform> uTransform : TransformStruct;
@group(0) @binding(1) var<uniform> uViewport : vec2f;

const vertexArray : array<vec2f, 3> = array(
    vec2f(0.0, 2.0),
    vec2f(0.0, 0.0),
    vec2f(2.0, 0.0),
);

@group(0) @binding(4) var<storage, read> sSprites : array<u32>;

const spritesArray : array<vec4u, 1> = array(
    vec4u(16, 0, 25, 16), // only one sprite so far, uh sprite key should be automaticallly be mapped to a number during compiling
);

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
}

@vertex fn vertexShader(
    @builtin(vertex_index) vertexIndex : u32,
    @builtin(instance_index) instanceIndex : u32
) -> v_out {
    var out : v_out;

    let spriteData = sSprites[instanceIndex];
    let xPos = (spriteData << 24) & 255u;
    let yPos = (spriteData << 16) & 255u;
    let rotation = (spriteData << 8) & 255u;
    let spriteIndex = (spriteData << 0) & 255u;

    let sprite : vec4f = vec4f(spritesArray[spriteIndex]); // I do not want to deal with integer interpolation, I can already imagine the edge cases of the math on top of the convoluted implementation the WebGPU engineers probably went over if it even exists. Anyways, the bottlneck is cpu gpu communication not interstage.
    switch vertexIndex {
        case 0: { out.texCoord = vec2f(0.0, sprite.y - sprite.w) * vertexArray[vertexIndex]; }
        case 1: { out.texCoord = vec2f(0.0, 0.0); }
        case 2: { out.texCoord = vec2f(sprite.z - sprite.x, 0.0) * vertexArray[vertexIndex];}
        default {}
    }
    out.texCoord += sprite.xw;

    return out;
}