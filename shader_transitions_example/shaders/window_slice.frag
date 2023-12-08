#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;
uniform float progress;
uniform float count; // = 10.0
uniform float smoothness; // = 0.5
uniform float direction; // Angle in degrees

out vec4 fragColor;

vec4 getFromColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 1.0);
}

vec4 getToColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 0.0);
}

vec4 transition (vec2 p) {
    // Convert direction to radians
    float theta = radians(direction);

    // Rotate the uv coordinates for the slicing logic
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    mat2 rotMat = mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
    vec2 rotatedP = p * rotMat;

    float pr = smoothstep(-smoothness, 0.0, rotatedP.x - progress * (1.0 + smoothness));
    float s = step(pr, fract(count * rotatedP.x));
    return mix(getFromColor(p), getToColor(p), s);
}
void main() {
vec2 uv = FlutterFragCoord().xy / resolution.xy;
fragColor = transition(uv);
}