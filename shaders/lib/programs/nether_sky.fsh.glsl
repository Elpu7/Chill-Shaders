#include "/lib/common.glsl"
#include "/lib/nether.glsl"
uniform vec3 fogColor;
uniform float chillNetherWastes;
uniform float chillCrimsonForest;
uniform float chillWarpedForest;
uniform float chillBasaltDeltas;
uniform float chillSoulValley;
varying vec4 chillColor;
void main() {
    vec3 biomeFog = chillNetherBiomeFog(
        fogColor,
        chillNetherWastes,
        chillCrimsonForest,
        chillWarpedForest,
        chillBasaltDeltas,
        chillSoulValley
    );
    vec3 sky = mix(vec3(0.024, 0.020, 0.024), biomeFog, 0.64);
    gl_FragData[0] = vec4(sky * mix(vec3(1.0), chillColor.rgb, 0.18), chillColor.a);
}
