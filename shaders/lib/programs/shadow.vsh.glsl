#include "/lib/common.glsl"

attribute vec4 mc_Entity;
varying vec2 chillTexCoord;
varying vec4 chillColor;
varying float chillShadowCaster;

void main() {
    // Use Iris' shadow matrices exactly as supplied. No cameraPosition-based
    // clip correction, world-space banding or artificial pixelisation is
    // applied here. Caster and receiver therefore share one linear projection.
    gl_Position = ftransform();

    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillColor = gl_Color;

    // Thin short-grass geometry produces long one-pixel shadow streaks that
    // sweep over terrain as the sun moves. Trees/leaves and all solid blocks
    // still cast full shadows; only the decorative grass group is suppressed.
    chillShadowCaster = float(int(mc_Entity.x) != 31);
}
