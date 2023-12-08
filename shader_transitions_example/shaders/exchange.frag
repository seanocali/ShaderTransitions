#include <flutter/runtime_effect.glsl>

uniform sampler2D uTexture0;
uniform sampler2D uTexture1;
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
    vec2 offsetForOutgoing = 2.0 * progress * vec2(cos(angle), sin(angle));
    vec2 offsetForIncoming = -2.0 * (progress - 0.5) * vec2(cos(angle), sin(angle)); // Invert the sign here.

    vec2 texture1UV = uv + offsetForOutgoing;
    vec2 texture2UV = uv - vec2(cos(angle), sin(angle)) + offsetForIncoming;  // The offset direction for the second texture is now inverted.

    bool inRangeTexture1 = texture1UV.x >= 0.0 && texture1UV.x < 1.0 && texture1UV.y >= 0.0 && texture1UV.y < 1.0;
    bool inRangeTexture2 = texture2UV.x >= 0.0 && texture2UV.x < 1.0 && texture2UV.y >= 0.0 && texture2UV.y < 1.0;

    if (progress <= 0.5 && inRangeTexture1) {
        fragColor = texture(uTexture1, texture1UV);
    } else if (progress > 0.5 && inRangeTexture2) {
        fragColor = texture(uTexture0, texture2UV);
    } else {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0); // Transparent pixels
    }
}
