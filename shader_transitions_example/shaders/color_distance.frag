#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float power; // = 5.0

out vec4 fragColor;


vec4 getFromColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 0.0);
}

vec4 getToColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 1.0);
}

vec4 transition(vec2 p) {
  vec4 fTex = getFromColor(p);
  vec4 tTex = getToColor(p);
  float m = step(distance(fTex, tTex), progress);
  return mix(
    mix(fTex, tTex, m),
    tTex,
    pow(progress, power)
  );
}

void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
