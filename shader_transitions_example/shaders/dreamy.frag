#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;

uniform sampler2D uTexture0;
uniform sampler2D uTexture1;

out vec4 fragColor;


vec4 getFromColor(vec2 uv) {
 return texture(uTexture1, vec2(uv.x, 1 - uv.y));
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

vec2 offset(float progress, float x, float theta) {
  float phase = progress*progress + progress + theta;
  float shifty = 0.03*progress*cos(10.0*(progress+x));
  return vec2(0, shifty);
}

vec4 transition(vec2 p) {
  return mix(getFromColor(p + offset(progress, p.x, 0.0)), getToColor(p + offset(1.0-progress, p.x, 3.14)), progress);
}

void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
