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
console.log("world texture:", worldTexture);
window.gl.bindTexture(window.gl.TEXTURE_2D, worldTexture);
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

resizeCanvas();
window.onresize = resizeCanvas;

render(); // render and gametick are not synced
function render () {
    controlCamera();

    window.gl.clearColor(0, 0, 0, 0);
    window.gl.clear(window.gl.COLOR_BUFFER_BIT);

    window.gl.useProgram(program);
    window.gl.uniform2f(cameraPositionUniformLocation, camera.x, camera.y);
    window.gl.uniform1f(cameraZoomUniformLocation, camera.zoom);
    window.gl.uniform2f(cameraRotationUniformLocation, Math.sin(camera.rotation), Math.cos(camera.rotation));

    // console.log("ahn~ im drawing");
    window.gl.bindVertexArray(renderWorldVAO);
    window.gl.drawArrays(window.gl.TRIANwindow.glE_STRIP, 0, 4);

    requestAnimationFrame(render);
}

function controlCamera() {
    if (window.keyIsDown.w) {
        window.camera.y += 30*window.camera.zoom;
    }

    if (window.keyIsDown.s) {
        window.camera.y -= 30*window.camera.zoom;
    }

    if (window.keyIsDown.a) {
        window.camera.x -= 30*window.camera.zoom;
    }

    if (window.keyIsDown.d) {
        window.camera.x += 30*window.camera.zoom;
    }

    if (window.keyIsDown.e) {
        window.camera.zoom *= 1.02;
    }

    if (window.keyIsDown.q) {
        window.camera.zoom *= 0.98;
    }

    if (window.keyIsDown.ArrowLeft) {
        window.camera.rotation += Math.PI/180;
    }

    if (window.keyIsDown.ArrowRight) {
        window.camera.rotation -= Math.PI/180;
    }
}

function resizeCanvas () {
    console.log("setting canvas to width:", canvas.clientWidth, "height:", canvas.clientHeight);
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
    window.gl.viewport(0, 0, window.gl.canvas.width, window.gl.canvas.height);
    window.gl.useProgram(program);
    window.gl.uniform2f(viewportUniformLocation, canvas.width, canvas.height);
}