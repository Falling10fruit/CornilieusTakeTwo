const global = window.renderWorld = {};
global.setUp = () => {
    const vShader = window.device.createShaderModule({
        label: `world vertex shader`,
        code: `
            const vertexArray : array<vec2f, 4> = array(
                vec2f(2.0, -1.0),
                vec2f(-1.0, -1.0),
                vec2f(2.0, -1.0),
            )

            @vertex fn vertexShader( @builtin(vertex_index) vertexIndex : u32 ) -> @builtin(position) vec4f {

                return vertexArray[vertexIndex] * vec2f(1.0, -1.0);
            }
        `
    });

    const fShader = window.device.createShaderModule({
        label: `world fragment shader`,
        code: `
            @group(0) @binding(0) var u_worldData : texture_2d<u32>;
            @group(0) @binding(1) var u_worldSampler : sampler;

            struct Transform {
                @location(0) viewport : vec2f;
                @location(1) cameraPosition : vec2f;
                @location(2) cameraZoom : f32;
            }

            @group(0) @binding(2) var<uniform> u_transform : Transform;

            @fragment fn fragmentShader( @builtin v_position : vec2f ) -> @location(0) vec4f {
                var position : vec2f = v_position * u_transform.viewport;
                position *= u_transform.cameraZoom;
                position += u_transform.cameraPosition;

                let tileData : u32 = textureLoad(u_worldData, vec2i(position), 0);
            }
        `
    });
    
    window.renderWorld.pipeline = window.await;
    device.createRenderPipelineAsync({
        label: `render world pipeline`,
        layout: window.device.createPipelineLayout({
            label: `render world pipeline layout`,
            bindGroupLayouts: wind,
        }),
        vertex: {
            module: vShader,
            entryPoint: "vertexShader",
        },
        fragment: {
            module: fShader,
            entryPoint: "fragmentShader",
            targets: [{
                format: navigator.gpu.getPreferredCanvasFormat(),
            }],
        },
    });

}

const vertexShaderSource = `#version 300 es
in vec2 a_position;

out vec2 v_position;

void main() {
    v_position = a_position;
    gl_Position = vec4(a_position, 0.0, 1.0);
}`;

const fragmentShaderSource = `#version 300 es
precision highp float;
precision mediump usampler2D;

in vec2 v_position;

uniform vec2 u_viewport;

uniform vec2 u_cameraPosition;
uniform float u_cameraZoom;
uniform vec2 u_cameraRotation;

uniform sampler2D u_worldData;

out vec4 outColor;

void main() {
    vec2 position = v_position * u_viewport;
    // position = vec2(
    //     position.x * u_cameraRotation.y + position.y * u_cameraRotation.x,
    //     position.y * u_cameraRotation.y - position.x * u_cameraRotation.x);
    position *= u_cameraZoom;
    position += u_cameraPosition;
    
    // outColor = vec4(v_position.y, position.x/255.0, float(texelFetch(u_worldData, ivec2(position), 0).r)/255.0, 1.0);

    vec4 tileData = texelFetch(u_worldData, ivec2(position), 0)*255.0;

    outColor = vec4(247.0, 0.0, 214.0, 69.0);

    float biome = tileData.x;
    if (biome == 0.0) {
        outColor = vec4(51.0, 127.5, 102.0, 69.0); // green stone
    } else if (biome == 1.0) {
        outColor = vec4(51.0, 51.0, 51.0, 69.0); // dark stone
    } else if (biome == 2.0) {
        outColor = vec4(153.0, 127.5, 51.0, 69.0); // aquarite
    } else if (biome == 3.0) {
        outColor = vec4(255.0, 255.0, 255.0, 69.0); // ice
    }

    if (tileData.y == 0.0) { outColor /= 2.0; };
    
    outColor /= 255.0;
    outColor.a = 1.0;

    // outColor = vec4(tileData.xyz/25.5, 1.0);
}`;

const vertexShader = window.createShader(window.gl, window.gl.VERTEX_SHADER, vertexShaderSource);
const fragmentShader = window.createShader(window.gl, window.gl.FRAGMENT_SHADER, fragmentShaderSource);
const program = window.createProgram(window.gl, vertexShader, fragmentShader);

window.gl.useProgram(program);
const viewportUniformLocation = window.gl.getUniformLocation(program, 'u_viewport');
const cameraPositionUniformLocation = window.gl.getUniformLocation(program, 'u_cameraPosition');
const cameraZoomUniformLocation = window.gl.getUniformLocation(program, 'u_cameraZoom');
const cameraRotationUniformLocation = window.gl.getUniformLocation(program, 'u_cameraRotation');
const worldUniformLocation = window.gl.getUniformLocation(program, 'u_worldData');

const worldTexture = window.generateWorldTexture(window.world.width, window.world.height, window.world.seed);
window.gl.bindTexture(window.gl.TEXTURE_2D, worldTexture);
window.gl.useProgram(program);
window.gl.uniform1i(worldUniformLocation, 0);



const positionAttributeLocation = window.gl.getAttribLocation(program, 'a_position');

const renderWorldVAO = window.gl.createVertexArray();
window.gl.bindVertexArray(renderWorldVAO);

window.gl.bindBuffer(window.gl.ARRAY_BUFFER, window.gl.createBuffer());
window.gl.bufferData(window.gl.ARRAY_BUFFER, new Float32Array([
    -1, -1,
     1, -1,
    -1,  1,
     1,  1,
]), window.gl.STATIC_DRAW);
window.gl.enableVertexAttribArray(positionAttributeLocation);
window.gl.vertexAttribPointer(positionAttributeLocation, 2, window.gl.FLOAT, false, 0, 0);

window.renderWorld = function() {
    window.gl.useProgram(program);
    window.gl.uniform2f(cameraPositionUniformLocation, camera.x, camera.y);
    window.gl.uniform1f(cameraZoomUniformLocation, camera.zoom);
    window.gl.uniform2f(cameraRotationUniformLocation, Math.sin(camera.rotation), Math.cos(camera.rotation));

    // console.log("ahn~ im drawing");
    window.gl.bindVertexArray(renderWorldVAO);
    window.gl.drawArrays(window.gl.TRIANGLE_STRIP, 0, 4);
}