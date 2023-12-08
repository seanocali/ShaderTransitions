#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;
uniform float progress;
uniform float diamondPixelSize; // 10

out vec4 fragColor;

vec4 transition(vec2 uv) {
    float xFraction = fract(FlutterFragCoord().x / diamondPixelSize);
    float yFraction = fract(FlutterFragCoord().y / diamondPixelSize);

    float xDistance = abs(xFraction - 0.5);
    float yDistance = abs(yFraction - 0.5);

    if (xDistance + yDistance + uv.x + uv.y > progress * 4) {
        return vec4(1.0, 1.0, 1.0, 0.0);
    }
    return vec4(1.0, 1.0, 1.0, 1.0);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / resolution.xy;
  fragColor = transition(uv);
}
