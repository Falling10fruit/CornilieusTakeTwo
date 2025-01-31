const canvas = document.getElementById('canvas');
const gl = canvas.getContext('webgl2');
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

in vec2 v_position;

uniform vec2 u_cameraPosition;
uniform float u_cameraZoom;
uniform vec2 u_cameraRotation;

out vec4 outColor;

void main() {
    vec2 position = v_position * vec2(` + canvas.clientWidth + `.0, ` + canvas.clientHeight + `.0);
    position = vec2(
        position.x * u_cameraRotation.y + position.y * u_cameraRotation.x,
        position.y * u_cameraRotation.y - position.x * u_cameraRotation.x);
    position *= u_cameraZoom;
    position += u_cameraPosition;
    
    outColor = vec4(v_position, position.x/255.0, 1.0);
}`;

const vertexShader = createShader(gl, gl.VERTEX_SHADER, vertexShaderSource);
const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, fragmentShaderSource);
const program = createProgram(gl, vertexShader, fragmentShader);
gl.useProgram(program);

const cameraPositionUniformLocation = gl.getUniformLocation(program, 'u_cameraPosition');
const cameraZoomUniformLocation = gl.getUniformLocation(program, 'u_cameraZoom');
const cameraRotationUniformLocation = gl.getUniformLocation(program, 'u_cameraRotation');

const positionAttributeLocation = gl.getAttribLocation(program, 'a_position');
const positionBuffer = gl.createBuffer();

const camera = {
    x: 0,
    y: 0,
    zoom: 1,
    rotation: (0)*Math.PI/180,
};

const keyIsDown = {
    w: false,
    a: false,
    s: false,
    d: false,
    e: false, 
    q: false,
    arrowLeft: false,
    arrowRight: false,
};

const world = new Float32Array(1440000);
const worker = new Worker(new URL('generateWorldWorker.js', import.meta.url));

window.addEventListener('keydown', setKeyIsDown);
window.addEventListener('keyup', setKeyIsDown);

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

function controlCamera() {
    if (keyIsDown.w) {
        camera.y += 10;
    }

    if (keyIsDown.s) {
        camera.y -= 10;
    }

    if (keyIsDown.a) {
        camera.x -= 10;
    }

    if (keyIsDown.d) {
        camera.x += 10;
    }

    if (keyIsDown.e) {
        camera.zoom *= 1.01;
    }

    if (keyIsDown.q) {
        camera.zoom *= 0.99;
    }

    if (keyIsDown.arrowLeft) {
        camera.rotation += Math.PI/180;
    }

    if (keyIsDown.arrowRight) {
        camera.rotation -= Math.PI/180;
    }
}

function setKeyIsDown (event) {
    const isDown = event.type === 'keydown' ? true : false;

    switch (event.keyCode) {
        case 87:
            keyIsDown.w = isDown;
            console.log(isDown);
            break;
        case 83:
            keyIsDown.s = isDown;
            break;
        case 65:
            keyIsDown.a = isDown;
            break;
        case 68:
            keyIsDown.d = isDown;
            break;
        case 69:
            keyIsDown.e = isDown;
            break;
        case 81:
            keyIsDown.q = isDown;
            break;
        case 37:
            keyIsDown.arrowLeft = isDown;
            break;
        case 39:
            keyIsDown.arrowRight = isDown;
            break;
    }

}

function createShader(gl, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
    if (success) {
      return shader;
    }
  
    console.error(gl.getShaderInfoLog(shader));  // eslint-disable-line
    gl.deleteShader(shader);
    return undefined;
}

function createProgram(gl, vertexShader, fragmentShader) {
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    const success = gl.getProgramParameter(program, gl.LINK_STATUS);
    if (success) {
      return program;
    }
  
    console.log(gl.getProgramInfoLog(program));  // eslint-disable-line
    gl.deleteProgram(program);
    return undefined;
}