struct TransformStruct {
    @location(0) translate : vec2f,
    @location(1) scale : f32,
    @location(2) rotation : f32,
}

@group(0) @binding(0) var<uniform> uTransform : TransformStruct;
@group(0) @binding(1) var<uniform> uViewport : vec2f;
@group(0) @binding(2) var<storage, read> sCurrentSprites : array<vec2u>;
@group(0) @binding(3) var<uniform> world_dimensions : vec2u;

const vertexArray : array<vec2f, 3> = array<vec2f, 3>(
    vec2f(0.0, 2.0),
    vec2f(0.0, 0.0),
    vec2f(2.0, 0.0),
);


//   33554432                         65536                   127          127          511     
//  sprite index                     chunk index             x pos        y pos       rotation
// 01010101 01010101 01010101 0 ] [ 1010101 |  01010101 0 ] [ 1010101 ] [ 0101010 ] [ 1 01010101 ]

// const spritesArray : array<vec4u, 6> = array(
//      vec4(0, 0, 16, 16)
// );
// insert here

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
    @location(1) v_position : vec2f,
    @location(2) debug : vec4f,
}

@vertex fn vertexShader(
    @builtin(vertex_index) vertexIndex : u32,
    @builtin(instance_index) instanceIndex : u32
) -> v_out {
    var out : v_out;

    let sprite_data = sCurrentSprites[instanceIndex];
    let spriteIndex = (sprite_data.x >> 7);
    let sprite : vec4f = vec4f(spritesArray[spriteIndex]);

    let chunk : u32 = ((sprite_data.x & 0x7Fu) << 9) + (sprite_data.y >> 23);
    let xPos : f32 = f32(((sprite_data.y >> 16) & 127u) + 128 * (chunk % world_dimensions.x) );
    let yPos : f32 = f32(((sprite_data.y >> 9) & 127u) + 128 * (chunk / world_dimensions.x) );
    let rotation = f32((sprite_data.y >> 0) & 511u);

    let translateMatrix : mat3x3f = createTranslateMatrix(xPos / 16.0, yPos / 16.0); // The bottom left of the sprite
    let rotateMatrix : mat3x3f = createRotateMatrix(rotation);
    let scaleMatrix : mat3x3f = createScaleMatrix((sprite.zw - sprite.xy) / 16.0);
    let transform : mat3x3f = translateMatrix * rotateMatrix * scaleMatrix; // * rotateMatrix; just start with something basic // matricies are associative

    let cameraTranslate : mat3x3f = createTranslateMatrix(-uTransform.translate.x, -uTransform.translate.y);
    let cameraScale : mat3x3f = createScaleMatrix(vec2f(1.0, 1.0) * uTransform.scale);
    let cameraRotate : mat3x3f = createRotateMatrix(-uTransform.rotation * 512.0 / 2.0 / 3.1415926535);
    let cameraTransform : mat3x3f = cameraRotate * cameraScale * cameraTranslate;
    
    let position : vec3f = cameraTransform * transform * vec3f(vertexArray[vertexIndex], 1.0);
    out.position = vec4f((position.xy * 2.0 / uViewport), 0.0, 1.0);

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
    
    // out.position = vec4f(((vertexArray[vertexIndex] + vec2f(xPos, yPos) - uTransform.translate) * uTransform.scale * 2.0) / uViewport, 0.0, 1.0);
    // out.debug = vec4f(f32(chunk) * 255.0, 0.0, 0.0, 255.0)/255.0;
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
    return mat3x3f(            // ╭       ╮
        scale.x, 0.0,     0.0, // | x 0 0 |
        0.0,     scale.y, 0.0, // | 0 y 0 |
        0.0,     0.0,     1.0, // | 0 0 1 |
    );                         // ╰       ╯
}