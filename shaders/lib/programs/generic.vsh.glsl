#include "/lib/common.glsl"
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
void main() {
    gl_Position = ftransform();
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    chillLightmap = chillLightmap / (30.0 / 32.0) - (1.0 / 32.0);
    chillColor = gl_Color;
}
