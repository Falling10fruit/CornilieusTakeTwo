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

struct spriteDataStruct {
    atlas_splice: vec4f,
    pivot: vec2f
}

// const spritesArray : array<vec4u, 6> = array(
//      vec4(0, 0, 16, 16)
// );
// const spriteDataStruct : array<spriteDataStruct, 6> = array(
//      spriteDataStruct(vec4f(0.0, 0.0, 16.0, 16.0), vec2f(8.0, 8.0))
// );

const spritesArray : array<spriteDataStruct, 7> = array(
    spriteDataStruct(
        vec4f(16.0, 15.0, 25.0, 30.0),
        vec2f(5.0, 7.0)
    ),
    spriteDataStruct(
        vec4f(16.0, 0.0, 25.0, 15.0),
        vec2f(4.0, 7.0)
    ),
    spriteDataStruct(
        vec4f(25.0, 0.0, 29.0, 11.0),
        vec2f(2.0, 7.0)
    ),
    spriteDataStruct(
        vec4f(25.0, 11.0, 26.0, 13.0),
        vec2f(1.0, 0.5)
    ),
    spriteDataStruct(
        vec4f(26.0, 1.0, 27.0, 2.0),
        vec2f(0.5, 0.5)
    ),
    spriteDataStruct(
        vec4f(28.0, 6.0, 37.0, 20.0),
        vec2f(5.0, 8.0)
    ),
    spriteDataStruct(
        vec4f(25.0, 20.0, 33.0, 28.0),
        vec2f(4.0, 4.0)
    )
);

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

    let sprite_vector = sCurrentSprites[instanceIndex];
    let sprite_index = (sprite_vector.x >> 7);
    let sprite_atlas : vec4f = spritesArray[sprite_index].atlas_splice;

    let chunk : u32 = ((sprite_vector.x & 0x7Fu) << 9) + (sprite_vector.y >> 23);
    let xPos : f32 = f32(((sprite_vector.y >> 16) & 127u) + 128 * (chunk % world_dimensions.x) );
    let yPos : f32 = f32(((sprite_vector.y >> 9) & 127u) + 128 * (chunk / world_dimensions.x) );
    let rotation = f32((sprite_vector.y >> 0) & 511u);

    let translate_by_pivot : mat3x3f = createTranslateMatrix((-spritesArray[sprite_index].pivot) / 16.0);
    let translateMatrix : mat3x3f = createTranslateMatrix((vec2f(xPos, yPos)) / 16.0); // The bottom left
    let rotateMatrix : mat3x3f = createRotateMatrix(rotation);
    let scaleMatrix : mat3x3f = createScaleMatrix((sprite_atlas.zw - sprite_atlas.xy) / 16.0);
    let transform : mat3x3f = translateMatrix * rotateMatrix * scaleMatrix * translate_by_pivot; // * rotateMatrix; just start with something basic // matricies are associative

    let cameraTranslate : mat3x3f = createTranslateMatrix(-vec2f(uTransform.translate.x, uTransform.translate.y));
    let cameraScale : mat3x3f = createScaleMatrix(vec2f(1.0, 1.0) * uTransform.scale);
    let cameraRotate : mat3x3f = createRotateMatrix(-uTransform.rotation * 512.0 / 2.0 / 3.1415926535);
    let cameraTransform : mat3x3f = cameraRotate * cameraScale * cameraTranslate;
    
    let position : vec3f = cameraTransform * transform * vec3f(vertexArray[vertexIndex], 1.0);
    out.position = vec4f((position.xy * 2.0 / uViewport), 0.0, 1.0);

    // I do not want to deal with integer interpolation, I can already imagine the edge cases of the math on top of the convoluted implementation the WebGPU engineers probably went over if it even exists. Anyways, the bottlneck is cpu gpu communication not interstage.
    switch (vertexIndex) {
        case 0: { out.texCoord = vec2f(0.0, sprite_atlas.y - sprite_atlas.w); }
        case 1: { out.texCoord = vec2f(0.0, 0.0); }
        case 2: { out.texCoord = vec2f(sprite_atlas.z - sprite_atlas.x, 0.0); }
        default { out.texCoord = vec2f(0.0, 0.0); }
    }
    out.texCoord *= vertexArray[vertexIndex];
    out.texCoord += sprite_atlas.xw;
    
    out.v_position = vertexArray[vertexIndex];
    
    // out.position = vec4f(((vertexArray[vertexIndex] + vec2f(xPos, yPos) - uTransform.translate) * uTransform.scale * 2.0) / uViewport, 0.0, 1.0);
    // out.debug = vec4f(f32(chunk) * 255.0, 0.0, 0.0, 255.0)/255.0;
    return out;
}

fn createTranslateMatrix(translate_vector: vec2f) -> mat3x3f {
    return mat3x3(                                   // ╭                ╮
        1.0,  0.0,  0.0,                             // | 1.0  0.0  xPos |
        0.0,  1.0,  0.0,                             // | 0.0  1.0  yPos |
        translate_vector.x, translate_vector.y, 1.0, // | 0.0  0.0  1.0  |
    );                                               // ╰                ╯
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