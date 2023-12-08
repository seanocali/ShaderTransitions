#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float amplitude; // = 1.0
uniform float waves; // = 30.0
uniform float colorSeparation; // = 0.3
uniform sampler2D uTexture0;
uniform sampler2D uTexture1;
out vec4 fragColor;

vec4 getFromColor(vec2 uv) {
 return texture(uTexture1, vec2(uv.x, 1 - uv.y));
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

float PI = 3.14159265358979323846264;
float compute(vec2 p, float progress, vec2 center) {
vec2 o = p*sin(progress * amplitude)-center;
// horizontal vector
vec2 h = vec2(1., 0.);
// butterfly polar function (don't ask me why this one :))
float theta = acos(dot(o, h)) * waves;
return (exp(cos(theta)) - 2.*cos(4.*theta) + pow(sin((2.*theta - PI) / 24.), 5.)) / 10.;
}
vec4 transition(vec2 uv) {
  vec2 p = uv.xy / vec2(1.0).xy;
  float inv = 1.0 - progress;
  vec2 dir = p - vec2(0.5);
  float dist = length(dir);
  float disp = compute(p, progress, vec2(0.5, 0.5));
  vec4 texTo = getToColor(p + inv * disp);
  vec4 texFrom = vec4(
    getFromColor(p + progress * disp * (1.0 - colorSeparation)).rgb,
    getFromColor(p + progress * disp).a
  );
  float mixAlpha = texTo.a * progress + texFrom.a * inv;
  vec3 mixedColor = (texTo.rgb * progress + texFrom.rgb * inv) / mixAlpha;
  return vec4(mixedColor, mixAlpha);
}
void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
