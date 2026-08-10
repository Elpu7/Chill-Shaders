#version 120

// Chill performs its own visibility-space PCF, so raw blocker depth must stay
// nearest-filtered. We interpolate the comparison result in lib/shadows.glsl.
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowHardwareFiltering = false;

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
