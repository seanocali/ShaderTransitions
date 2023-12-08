#include <flutter/runtime_effect.glsl>

precision mediump float;

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

vec4 transition(vec2 p) {
    vec2 block = floor(p.xy / vec2(16));
    vec2 uv_noise = block / vec2(64);
    uv_noise += floor(vec2(progress) * vec2(1200.0, 3500.0)) / vec2(64);
    vec2 dist = progress > 0.0 ? (fract(uv_noise) - 0.5) * 0.3 *(1.0 -progress) : vec2(0.0);
    vec2 red = p + dist * 0.2;
    vec2 green = p + dist * .3;
    vec2 blue = p + dist * .5;

    float fromAlpha = getFromColor(p).a;
    float toAlpha = getToColor(p).a;

    return vec4(
        mix(getFromColor(red), getToColor(red), progress).r,
        mix(getFromColor(green), getToColor(green), progress).g,
        mix(getFromColor(blue), getToColor(blue), progress).b,
        mix(fromAlpha, toAlpha, progress)
    );
}

void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
