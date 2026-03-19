@group(1) @binding(0) var spritesheet : texture_2d<f32>;
@group(1) @binding(1) var spritesheetSampler : sampler;

struct v_out {
    @builtin(position) position : vec4f,
    @location(0) texCoord : vec2f,
    @location(1) v_position : vec2f,
    @location(2) debug: vec4f,
}

@fragment fn fragmentShader( v_in : v_out ) -> @location(0) vec4f {
    var outColor: vec4f;

    if (v_in.v_position.x > 1.0 || v_in.v_position.y > 1.0) { discard; }

    let uv = v_in.texCoord / vec2f(textureDimensions(spritesheet));
    outColor = textureSample(spritesheet, spritesheetSampler, uv);

    if (v_in.debug.w > 0.0) { outColor = v_in.debug; }
    // outColor = vec4f(vec2f(textureDimensions(spritesheet))/255.0, 0.0, 1.0);
    return outColor;
}