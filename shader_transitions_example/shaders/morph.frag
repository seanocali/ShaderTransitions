#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float strength; // = 0.1
uniform sampler2D uTexture0;
uniform sampler2D uTexture1;
out vec4 fragColor;

vec4 getFromColor(vec2 uv) {
 return texture(uTexture1, vec2(uv.x, 1 - uv.y));
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

vec4 transition(vec2 p) {
  vec4 ca = getFromColor(p);
  vec4 cb = getToColor(p);

  vec2 oa = (((ca.rg+ca.b)*0.5)*2.0-1.0);
  vec2 ob = (((cb.rg+cb.b)*0.5)*2.0-1.0);
  vec2 oc = mix(oa,ob,0.5)*strength;

  float w0 = progress;
  float w1 = 1.0-w0;
  return mix(getFromColor(p+oc*w0), getToColor(p-oc*w1), progress);
}


void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
