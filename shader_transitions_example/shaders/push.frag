#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture1;
uniform sampler2D uTexture0;
uniform float uResolutionX;
uniform float uResolutionY;
uniform float progress;  // Value between 0.0 (start) and 1.0 (end)
uniform float direction;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(uResolutionX, uResolutionY);

    // Convert direction to radians
    float angle = radians(direction);

    // Calculate the offsets based on progress and direction.
    vec2 offset = progress * vec2(cos(angle), sin(angle));

    // UV coordinates for texture1 and texture2
    vec2 texture1UV = uv + offset;
    vec2 texture2UV = uv + offset - vec2(cos(angle), sin(angle));

    vec4 color1 = texture(uTexture1, texture1UV);
    vec4 color2 = texture(uTexture0, texture2UV);

    bool withinTexture1Bounds = texture1UV.x >= 0.0 && texture1UV.x <= 1.0 && texture1UV.y >= 0.0 && texture1UV.y <= 1.0;
    bool withinTexture2Bounds = texture2UV.x >= 0.0 && texture2UV.x <= 1.0 && texture2UV.y >= 0.0 && texture2UV.y <= 1.0;

    if (withinTexture1Bounds && color1.a > 0.1) {
        fragColor = color1;
    } else if (withinTexture2Bounds) {
        fragColor = color2;
    } else {
        fragColor = vec4(0.0);
    }
}
