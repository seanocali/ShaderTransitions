#version 460 core

#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;
uniform float progress;
uniform float smoothValue; // Set to 0.02 for default
uniform float direction; // Set to 0.0 for default
out vec4 fragColor;

void main() {
    vec2 st = FlutterFragCoord().xy / resolution.xy;

    // Convert direction to radians and compute direction vector
    float radian = direction * 3.14159265359 / 180.0;
    vec2 dir = vec2(cos(radian), sin(radian));

    // Compute dot product of direction and st to get the position based on direction
    float pos = dot(st - vec2(0.5, 0.5), dir) + 0.5;  // Adjusting so 0.5 is the center

    float alpha = smoothstep(progress - smoothValue, progress + smoothValue, pos);

    fragColor = vec4(1.0, 1.0, 1.0, alpha);
}
