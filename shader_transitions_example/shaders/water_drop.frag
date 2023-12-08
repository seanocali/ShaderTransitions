#include <flutter/runtime_effect.glsl>

precision mediump float;

uniform vec2 resolution;
uniform float progress;
uniform float amplitude; // = 30
uniform float speed; // = 30
uniform sampler2D uTexture0;
uniform sampler2D uTexture1;

out vec4 fragColor;


vec4 getFromColor(vec2 uv) {
 return texture(uTexture0, uv);
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture1, uv);
}

vec4 transition(vec2 p) {
  vec2 dir = p - vec2(.5);
  float dist = length(dir);

  if (dist > progress) {
    return mix(getFromColor( p), getToColor( p), progress);
  } else {
    vec2 offset = dir * sin(dist * amplitude - progress * speed);
    return mix(getFromColor( p + offset), getToColor( p), progress);
  }
}


void main() {
vec2 uv = FlutterFragCoord().xy / resolution.xy;
fragColor = transition(uv);
}