#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform vec4 shadow_colour; // = vec4(0.,0.,0.,.6)
uniform float shadow_height; // = 0.075
uniform float bounces; // = 3.0
uniform sampler2D uTexture0;
uniform sampler2D uTexture1;

out vec4 fragColor;
vec4 getFromColor(vec2 uv) {
 return texture(uTexture1, vec2(uv.x, 1 - uv.y));
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

const float PI = 3.14159265358;


vec4 transition(vec2 uv) {
  float time = progress;
  float stime = sin(time * PI / 2.);
  float phase = time * PI * bounces;
  float y = (abs(cos(phase))) * (1.0 - stime);
  float d = uv.y - y;

  vec4 fromColor = getFromColor(vec2(uv.x, uv.y + (1.0 - y)));
  vec4 toColor = getToColor(uv);

  if (fromColor.a == 0.0) {
    return toColor;  // If foreground is fully transparent, use background color
  }

  float transitionFactor = step(d, 0.0);
  return mix(toColor, fromColor, transitionFactor);
}

void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
