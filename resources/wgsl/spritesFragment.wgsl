@group(0) @binding(2) var spritesheet : texture_2d<f32>;
@group(0) @binding(3) var spritesheetSampler : sampler;

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
    @location(1) v_position : vec2f
}

@fragment fn fragmentShader( v_in : v_out ) -> @location(0) vec4f {
    if (v_in.v_position.x > 1.0 || v_in.v_position.y > 1.0) {
        discard;
    }

    let uv = v_in.texCoord / vec2f(textureDimensions(spritesheet));
    return textureSample(spritesheet, spritesheetSampler, uv);
}