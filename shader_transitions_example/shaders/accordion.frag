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

vec4 transition (vec2 uv) {
  float t = progress;

  if (mod(floor(uv.y*100.*progress),2.)==0.)
    t*=2.-.5;

  return mix(
    getFromColor(uv),
    getToColor(uv),
    mix(t, progress, smoothstep(0.8, 1.0, progress))
  );
}

void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
