#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform vec2 sizeVal; // = (10, 10)
uniform float smoothness; // = 0.5

out vec4 fragColor;

ivec2 size = ivec2(sizeVal);

vec4 getFromColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 0.0);
}

vec4 getToColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 1.0);
}

float rand (vec2 co) {
  return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

vec4 transition(vec2 p) {
  float r = rand(floor(vec2(size) * p));
  float m = smoothstep(0.0, -smoothness, r - (progress * (1.0 + smoothness)));
  return mix(getFromColor(p), getToColor(p), m);
}
void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
