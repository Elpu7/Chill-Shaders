#include "/lib/common.glsl"
varying vec2 chillTexCoord;
varying vec4 chillColor;
void main() {
    gl_Position = ftransform();
    // Preserve Minecraft's atlas coordinates so the original sun and current
    // moon-phase textures keep their vanilla shape and appearance.
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillColor = gl_Color;
}
