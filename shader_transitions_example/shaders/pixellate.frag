#include <flutter/runtime_effect.glsl>

uniform vec2 resolution;
uniform float progress;
uniform float squaresMinVal/* = 20 */; // minimum number of squares (when the effect is at its higher level)
uniform int steps /* = 50 */; // zero disable the stepping
uniform sampler2D uTexture0;
uniform sampler2D uTexture1;
out vec4 fragColor;

ivec2 squaresMin = ivec2(squaresMinVal);

vec4 getFromColor(vec2 uv) {
 return texture(uTexture1, vec2(uv.x, 1 - uv.y));
}

vec4 getToColor(vec2 uv) {
 return texture(uTexture0, vec2(uv.x, 1 - uv.y));
}

float d = min(progress, 1.0 - progress);
float dist = steps>0 ? ceil(d * float(steps)) / float(steps) : d;
vec2 squareSize = 2.0 * dist / vec2(squaresMin);

vec4 transition(vec2 uv) {
  vec2 p = dist>0.0 ? (floor(uv / squareSize) + 0.5) * squareSize : uv;
  return mix(getFromColor(p), getToColor(p), progress);
}
void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
