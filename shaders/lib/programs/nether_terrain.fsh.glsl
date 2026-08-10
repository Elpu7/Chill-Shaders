#include "/lib/common.glsl"
#include "/lib/emission.glsl"
#include "/lib/nether.glsl"
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform float rainStrength;
uniform vec3 fogColor;
uniform float chillNetherWastes;
uniform float chillCrimsonForest;
uniform float chillWarpedForest;
uniform float chillBasaltDeltas;
uniform float chillSoulValley;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying float chillEmissionType;
/* DRAWBUFFERS:024 */
void main() {
    vec4 albedo = texture2D(gtexture, chillTexCoord) * chillColor;
    if (albedo.a < alphaTestRef) discard;
    vec3 blockLight = texture2D(lightmap, chillLightmap).rgb;
    float rim = pow(1.0 - abs(chillNormal.y), 2.0);
    vec3 biomeFog = chillNetherBiomeFog(
        fogColor,
        chillNetherWastes,
        chillCrimsonForest,
        chillWarpedForest,
        chillBasaltDeltas,
        chillSoulValley
    );
    float fogLuminance = dot(biomeFog, vec3(0.299, 0.587, 0.114));
    vec3 biomeAmbient = mix(vec3(0.205, 0.185, 0.190), biomeFog + fogLuminance * 0.35, 0.28);
    vec3 localLight = blockLight * vec3(0.78, 0.56, 0.38);
    vec3 color = albedo.rgb * (biomeAmbient + localLight + rim * vec3(0.040, 0.032, 0.034));
    float emissionMask = chillEmissionMask(albedo.rgb, albedo.a, chillEmissionType);
    color = chillEmissiveSurface(color, albedo.rgb, chillEmissionType, emissionMask);
    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = vec4(0.0);
    gl_FragData[2] = chillEmissionType > 0.5
        ? vec4(chillEmissionColor(chillEmissionType) * emissionMask, emissionMask)
        : vec4(0.0);
}
