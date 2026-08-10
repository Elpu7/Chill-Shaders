#include "/lib/common.glsl"

// Sky textures and clouds already contain their intended vanilla light/color.
// Sampling the block lightmap here darkens or overwrites the sky.
uniform sampler2D gtexture;
uniform float alphaTestRef;
varying vec2 chillTexCoord;
varying vec4 chillColor;
void main() {
    vec4 color = texture2D(gtexture, chillTexCoord) * chillColor;
    if (color.a < alphaTestRef) discard;
    gl_FragData[0] = color;
}
