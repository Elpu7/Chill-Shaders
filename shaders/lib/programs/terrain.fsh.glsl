#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/lighting.glsl"
#include "/lib/shadows.glsl"
#include "/lib/emission.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform sampler2D shadowtex1;
uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
uniform vec3 upPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform float rainStrength;
uniform float thunderStrength;
uniform float alphaTestRef;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying vec3 chillPlayerNormal;
varying vec3 chillWorldPos;
varying float chillFoliage;
varying float chillEmissionType;

/* DRAWBUFFERS:024 */

void main() {
    vec4 albedo = texture2D(gtexture, chillTexCoord) * chillColor;
    if (albedo.a < alphaTestRef) discard;

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

    vec3 sampledLightColor = texture2D(lightmap, chillLightmap).rgb;
    vec3 color = chillSceneLighting(
        albedo.rgb,
        chillNormal,
        chillLightmap,
        sampledLightColor,
        sunDir,
        upDir,
        shadow,
        rainStrength
    );

    if (chillFoliage > 0.5) {
        color += vec3(0.10, 0.19, 0.075) * max(dot(-chillNormal, sunDir), 0.0) * 0.33;
    }
    float emissionMask = chillEmissionMask(albedo.rgb, albedo.a, chillEmissionType);
    color = chillEmissiveSurface(color, albedo.rgb, chillEmissionType, emissionMask);

    float day = chillDayFactor(sunDir, upDir);
    vec3 fog = chillSkyColor(normalize(chillWorldPos), sunDir, upDir, rainStrength, thunderStrength, 1.0 - day);
    vec3 foggedColor = chillApplyFog(color, fog, length(chillWorldPos), max(rainStrength, thunderStrength), day);
    gl_FragData[0] = vec4(foggedColor, albedo.a);

    gl_FragData[1] = vec4(0.0);

    vec3 emissionColor = chillEmissionColor(chillEmissionType) * emissionMask;
    gl_FragData[2] = chillEmissionType > 0.5
        ? vec4(emissionColor, emissionMask)
        : vec4(0.0);
}
