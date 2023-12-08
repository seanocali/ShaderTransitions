#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float smoothness; // = 1.0
uniform sampler2D uTexture0;

out vec4 fragColor;

vec4 getFromColor(vec2 uv) {
 return vec4(1.0, 1.0, 1.0, 0.0);
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

const float PI = 3.141592653589;

vec4 transition(vec2 p) {
  vec2 rp = p*2.-1.;
  return mix(
    getToColor(p),
    getFromColor(p),
    smoothstep(0., smoothness, atan(rp.y,rp.x) - (progress-.5) * PI * 2.5)
  );
}


void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
