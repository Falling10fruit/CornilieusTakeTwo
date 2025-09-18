struct TransformStruct {
    @location(0) translate : vec2f,
    @location(1) scale : f32,
    @location(2) rotation : f32,
}

@group(0) @binding(0) var<uniform> uTransform : TransformStruct;
@group(0) @binding(1) var<uniform> uViewport : vec2f;

const vertexArray : array<vec2f, 3> = array<vec2f, 3>(
    vec2f(0.0, 2.0),
    vec2f(0.0, 0.0),
    vec2f(2.0, 0.0),
);

@group(0) @binding(4) var<storage, read> sSprites : array<u32>;

/*spritesArray*/const spritesArray : array<vec4u, 1> = array(
    vec4u(16, 0, 25, 16), // only one sprite so far, uh sprite key should be automaticallly be mapped to a number during compiling
);/*spritesArray*/

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
    @location(1) v_position : vec2f,
}

@vertex fn vertexShader(
    @builtin(vertex_index) vertexIndex : u32,
    @builtin(instance_index) instanceIndex : u32
) -> v_out {
    var out : v_out;

    let spriteData = sSprites[instanceIndex];
    let xPos : f32 = f32((spriteData << 24) & 127u);
    let yPos : f32 = f32((spriteData << 16) & 127u);
    let rotation = f32((spriteData << 8) & 511u);
    let spriteIndex = (spriteData << 0) & 511u;
    let sprite : vec4f = vec4f(spritesArray[spriteIndex]);

    let translateMatrix : mat3x3f = createTranslateMatrix(xPos, yPos); // The bottom left of the 
    let rotateMatrix : mat3x3f = createRotateMatrix(rotation);
    let scaleMatrix : mat3x3f = createScaleMatrix(sprite.zw - sprite.xy);
    let transform : mat3x3f = translateMatrix * scaleMatrix * rotateMatrix; // matricies are associative
    
    let position : vec3f = transform * vec3f(vertexArray[vertexIndex] * 2.0 - 1.0, 1.0);

    // I do not want to deal with integer interpolation, I can already imagine the edge cases of the math on top of the convoluted implementation the WebGPU engineers probably went over if it even exists. Anyways, the bottlneck is cpu gpu communication not interstage.
    switch (vertexIndex) {
        case 0: { out.texCoord = vec2f(0.0, sprite.y - sprite.w); }
        case 1: { out.texCoord = vec2f(0.0, 0.0); }
        case 2: { out.texCoord = vec2f(sprite.z - sprite.x, 0.0); }
        default { out.texCoord = vec2f(0.0, 0.0); }
    }
    out.texCoord *= vertexArray[vertexIndex];
    out.texCoord += sprite.xw;
    
    out.v_position = vertexArray[vertexIndex];

    return out;
}

fn createTranslateMatrix(xPos : f32, yPos : f32) -> mat3x3f {
    return mat3x3(       // ╭                ╮
        1.0,  0.0,  0.0, // | 1.0  0.0  xPos |
        0.0,  1.0,  0.0, // | 0.0  1.0  yPos |
        xPos, yPos, 1.0, // | 0.0  0.0  1.0  |
    );                   // ╰                ╯
}

fn createRotateMatrix(rotation : f32) -> mat3x3f {
    let radians : f32 = rotation / 512.0 * 2.0 * 3.1415926535;

    return mat3x3(
        cos(radians),  sin(radians), 0.0,
        -sin(radians), cos(radians), 0.0,
        0.0,           0.0,          1.0,
    );
}

fn createScaleMatrix(scale : vec2f) -> mat3x3f {
    return mat3x3f(                      // ╭       ╮
        scale.x, 0.0,     0.0, // | x 0 0 |
        0.0,     scale.y, 0.0, // | 0 y 0 |
        0.0,     0.0,     1.0, // | 0 0 1 |
    );                                   // ╰       ╯
}