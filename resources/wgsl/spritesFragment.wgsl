@group(0) @binding(2) var spritesheet : texture_2d<f32>;
@group(0) @binding(3) var spritesheetSampler : sampler;

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
}

@fragment fn fragmentShader( v_in : v_out ) -> @location(0) vec4f {
    let uv = v_in.texCoord / textureDimensions(spritesheet);
    return textureSample(spritesheet, spritesheetSampler, uv);
}