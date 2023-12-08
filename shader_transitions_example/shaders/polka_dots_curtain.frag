#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float dots;// = 20.0;
uniform vec2 center;// = vec2(0, 0);
const float SQRT_2 = 1.414213562373;

out vec4 fragColor;

vec4 getFromColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 0.0);
}

vec4 getToColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 1.0);
}

vec4 transition(vec2 uv) {
  bool nextImage = distance(fract(uv * dots), vec2(0.5, 0.5)) < ( progress / distance(uv, center));
  return nextImage ? getToColor(uv) : getFromColor(uv);
}

void main() {
  vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}