/*
                          y         x      rotation sprite
                     1111111111 1111111111 11111111  1111

*/

const vss = `#version 300 es
in uint a_data;

out uint v_sprite;

void main () {
    v_sprite      = (a_data >> 0) & 15;
    uint rotation = (a_data >> 3) & 255;
    uint xPos     = (a_data >> 12) & 1023;
    uint yPos     = (a_data >> 22) & 1023;
}`

const fss = `#version 300 es
precision highp float;

in uint v_sprite;

uniform sampler2D u_spritesheet;

out vec4 outColor;

int main () {
    if (v_sprite == 0) {
        outColor = vec4(1.0, 0.0, 0.0, 1.0); // red
    } else if (v_sprite == 1) {
        outColor = vec4(0.0, 1.0, 0.0, 1.0); // green
    } else if (v_sprite == 2) {
        outColor = vec4(0.0, 0.0, 1.0, 1.0); // blue
    } else {
        outColor = vec4(1.0, 1.0, 1.0, 1.0); // white
    }
}`;