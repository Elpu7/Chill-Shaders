#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/lighting.glsl"
#include "/lib/shadows.glsl"
#include "/lib/nether.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex1;
uniform float alphaTestRef;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float rainStrength;
uniform float thunderStrength;
uniform vec4 entityColor;
#ifdef CHILL_NETHER_ENTITY
uniform vec3 fogColor;
uniform float chillNetherWastes;
uniform float chillCrimsonForest;
uniform float chillWarpedForest;
uniform float chillBasaltDeltas;
uniform float chillSoulValley;
#endif
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying vec3 chillPlayerNormal;
varying vec3 chillWorldPos;
/* DRAWBUFFERS:024 */

void main() {
    // Minecraft supplies leather dye and text-display tint through gl_Color.
    // Keep that RGB data, then apply the separate hurt/overlay colour without
    // sacrificing material tinting.
    vec4 albedo = texture2D(gtexture, chillTexCoord) * chillColor;
    albedo.rgb = mix(albedo.rgb, entityColor.rgb, entityColor.a);
    if (albedo.a <= max(alphaTestRef, 0.01)) discard;
#ifdef CHILL_NETHER_ENTITY
    // Nether entities must not pass through the Overworld sun/shadow/fog path.
    // Light them from the local lightmap and write surviving texture pixels as
    // opaque; the shared final pass applies the same biome fog as the terrain.
    vec3 sampledLight = texture2D(lightmap, chillLightmap).rgb;
    vec3 biomeFog = chillNetherBiomeFog(
        fogColor,
        chillNetherWastes,
        chillCrimsonForest,
        chillWarpedForest,
        chillBasaltDeltas,
        chillSoulValley
    );
    float facingLight = 0.72 + max(chillNormal.y, 0.0) * 0.12;
    vec3 ambient = mix(vec3(0.235, 0.215, 0.220), biomeFog + vec3(0.085), 0.18);
    vec3 localLight = sampledLight * vec3(0.76, 0.58, 0.43);
    vec3 netherColor = albedo.rgb * (ambient * facingLight + localLight);
    // Minecraft's entity ground shadow is a nearly black texture whose
    // vertex alpha is intentionally soft. It shares the translucent-entity
    // program with real mob layers, so preserve opacity only for this dark,
    // already-translucent decal while keeping every actual entity pixel solid.
    float albedoLuminance = chillLuminance(albedo.rgb);
    float darkDecal = 1.0 - smoothstep(0.018, 0.095, albedoLuminance);
    float sourceTranslucency = 1.0 - smoothstep(0.960, 0.995, albedo.a);
    float softGroundShadow = darkDecal * sourceTranslucency;
    float groundShadowOpacity = albedo.a * 0.42;
    float outputOpacity = mix(1.0, groundShadowOpacity, softGroundShadow);
    vec3 groundShadowColor = biomeFog * 0.10 + vec3(0.010, 0.004, 0.003);
    netherColor = mix(netherColor, groundShadowColor, softGroundShadow);
    gl_FragData[0] = vec4(netherColor, outputOpacity);
    // Opaque mobs must also occlude water/material metadata and lava/fire
    // radiance already written by the terrain behind them. Leaving these
    // buffers untouched made bright Nether surfaces shine through mob bodies.
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, outputOpacity);
    // Alpha 1 is an occlusion marker for the later emission blur. Without it,
    // neighbouring lava/fire samples can be blurred back across a solid mob.
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, outputOpacity);
    return;
#endif
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir = normalize(upPosition);
    float shadow = chillShadowSample(
        shadowtex1,
        chillWorldPos,
        chillNormal,
        chillPlayerNormal,
        normalize(shadowLightPosition),
        shadowModelView,
        shadowProjection
    );
    vec3 color = chillSceneLighting(albedo.rgb, chillNormal, chillLightmap, texture2D(lightmap, chillLightmap).rgb, sunDir, upDir, shadow, rainStrength);
    float day = chillDayFactor(sunDir, upDir);
    vec3 fog = chillSkyColor(normalize(chillWorldPos), sunDir, upDir, rainStrength, thunderStrength, 1.0 - day);
    gl_FragData[0] = vec4(chillApplyFog(color, fog, length(chillWorldPos), max(rainStrength, thunderStrength), day), albedo.a);
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, albedo.a);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, albedo.a);
}
