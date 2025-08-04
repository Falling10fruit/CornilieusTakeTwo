const canvas = document.createElement("canvas");
const gl = canvas.getContext("webgl2", {antialias: false});
canvas.width = canvas.clientWidth;
canvas.height = canvas.clientHeight;
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

uniform vec2 u_cameraPosition;
uniform float u_cameraZoom;
uniform vec2 u_cameraRotation;

uniform sampler2D u_worldData;

out vec4 outColor;

void main() {
    vec2 position = v_position * vec2(` + canvas.clientWidth + `.0, ` + canvas.clientHeight + `.0);
    position = vec2(
        position.x * u_cameraRotation.y + position.y * u_cameraRotation.x,
        position.y * u_cameraRotation.y - position.x * u_cameraRotation.x);
    position *= u_cameraZoom;
    position += u_cameraPosition;
    
    outColor = vec4(v_position.y, position.x/255.0, float(texelFetch(u_worldData, ivec2(position), 0).r)/255.0, 1.0);
}`;

const vertexShader = window.createShader(gl, gl.VERTEX_SHADER, vertexShaderSource);
const fragmentShader = window.createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);
const program = window.createProgram(gl, vertexShader, fragmentShader);
gl.useProgram(program);

const cameraPositionUniformLocation = gl.getUniformLocation(program, 'u_cameraPosition');
const cameraZoomUniformLocation = gl.getUniformLocation(program, 'u_cameraZoom');
const cameraRotationUniformLocation = gl.getUniformLocation(program, 'u_cameraRotation');

const positionAttributeLocation = gl.getAttribLocation(program, 'a_position');
const positionBuffer = gl.createBuffer();

const Uint8WorldData = window.generateWorldUint8Array(window.world.width, window.world.height, window.world.seed);
uploadWorldToGPU(window.world.width, window.world.height, Uint8WorldData);

console.log("parsing");
const parseUint8WorldWorker = new Worker('parseUint8WorldWorker.js');
parseUint8WorldWorker.postMessage({ Uint8World: Uint8WorldData });

gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
    -1, -1,
    1, -1,
    -1, 1,
    1, 1,
]), gl.STATIC_DRAW);

const vao = gl.createVertexArray();
gl.bindVertexArray(vao);
gl.enableVertexAttribArray(positionAttributeLocation);
gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, false, 0, 0);

gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
render();
function render () {
    controlCamera();

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);

    gl.uniform2f(cameraPositionUniformLocation, camera.x, camera.y);
    gl.uniform1f(cameraZoomUniformLocation, camera.zoom);
    gl.uniform2f(cameraRotationUniformLocation, Math.sin(camera.rotation), Math.cos(camera.rotation));
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);

    requestAnimationFrame(render);
}

function uploadWorldToGPU (width, height, data) {
    const worldTexture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, worldTexture);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    const worldUniformLocation = gl.getUniformLocation(program, 'u_worldData');
    gl.uniform1i(worldUniformLocation, 0);
}

function controlCamera() {
    if (window.keyIsDown.w) {
        window.camera.y += 10;
    }

    if (window.keyIsDown.s) {
        window.camera.y -= 10;
    }

    if (window.keyIsDown.a) {
        window.camera.x -= 10;
    }

    if (window.keyIsDown.d) {
        window.camera.x += 10;
    }

    if (window.keyIsDown.e) {
        window.camera.zoom *= 1.01;
    }

    if (window.keyIsDown.q) {
        window.camera.zoom *= 0.99;
    }

    if (window.keyIsDown.arrowLeft) {
        window.camera.rotation += Math.PI/180;
    }

    if (window.keyIsDown.arrowRight) {
        window.camera.rotation -= Math.PI/180;
    }
}