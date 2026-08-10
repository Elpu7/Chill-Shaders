#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform float alphaTestRef;
varying vec2 chillTexCoord;
varying vec4 chillColor;
varying float chillShadowCaster;

void main() {
    if (chillShadowCaster < 0.5) discard;
    vec4 color = texture2D(gtexture, chillTexCoord) * chillColor;
    if (color.a < max(alphaTestRef, 0.1)) discard;
    gl_FragData[0] = vec4(1.0);
}
