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

float Hash( vec2 p)
{
    vec3 p2 = vec3(p.xy,1.0);
    return fract(sin(dot(p2,vec3(37.1,61.7, 12.4)))*3758.5453123);
}

float noise(in vec2 p)
{
    vec2 i = floor(p);
    vec2 f = fract(p);
    f *= f * (3.0-2.0*f);

    return mix(mix(Hash(i + vec2(0.,0.)), Hash(i + vec2(1.,0.)),f.x),
        mix(Hash(i + vec2(0.,1.)), Hash(i + vec2(1.,1.)),f.x),
        f.y);
}

float fbm(vec2 p)
{
    float v = 0.0;
    v += noise(p*1.)*.5;
    v += noise(p*2.)*.25;
    v += noise(p*4.)*.125;
    return v;
}

vec4 transition(vec2 uv)
{
    vec4 srcColor = getFromColor(uv);
    vec3 src = srcColor.rgb;
    float srcAlpha = srcColor.a;

    vec4 tgtColor = getToColor(uv);
    vec3 tgt = tgtColor.rgb;
    float tgtAlpha = tgtColor.a;

    if (progress >= 1.0) return vec4(tgt, tgtAlpha);

    vec3 col = src;

    uv.x -= 1.5;

    float ctime = progress * mod(1.35, 2.5);

    float d = uv.x + uv.y*0.5 + 0.5*fbm(uv*15.1) + ctime*1.3;
    if (d > 0.35) col = clamp(col - (d-0.35)*10.0, 0.0, 1.0);
    if (d > 0.47)
    {
        if (d < 0.5) col += (d-0.4)*33.0*0.5*(0.0 + noise(100.0*uv + vec2(-ctime*2.0, 0.0))) * vec3(1.5, 0.5, 0.0);
        else {
            col = tgt;
            srcAlpha = tgtAlpha; // Use target alpha
        }
    }

    // Blending colors based on alpha
    vec3 finalColor = col * srcAlpha + tgt * tgtAlpha * (1.0 - srcAlpha);

    // Blending alpha
    float outAlpha = srcAlpha + (1.0 - srcAlpha) * tgtAlpha;

    return vec4(finalColor, outAlpha);
}


void main() {
vec2 uv = vec2(FlutterFragCoord().x, resolution.y - FlutterFragCoord().y) / resolution.xy;
  fragColor = transition(uv);
}
