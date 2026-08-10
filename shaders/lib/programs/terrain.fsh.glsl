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
varying float chillIceType;
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
    if (chillIceType > 0.5) {
        float coolTint = chillIceType > 1.5 ? 0.30 : 0.18;
        color = mix(color, color * vec3(0.82, 0.96, 1.10), coolTint);
    }
    float emissionMask = chillEmissionMask(albedo.rgb, albedo.a, chillEmissionType);
    color = chillEmissiveSurface(color, albedo.rgb, chillEmissionType, emissionMask);

    float day = chillDayFactor(sunDir, upDir);
    vec3 fog = chillSkyColor(normalize(chillWorldPos), sunDir, upDir, rainStrength, thunderStrength, 1.0 - day);
    vec3 foggedColor = chillApplyFog(color, fog, length(chillWorldPos), max(rainStrength, thunderStrength), day);
    gl_FragData[0] = vec4(foggedColor, albedo.a);

    if (chillIceType > 0.5) {
        float sampledLight = chillSaturate(max(max(sampledLightColor.r, sampledLightColor.g), sampledLightColor.b));
        float skyAccess = chillSaturate(chillLightmap.y);
        float blockAccess = chillSaturate(chillLightmap.x);
        float openSkyLight = skyAccess * mix(0.58, 1.0, day);
        openSkyLight *= 1.0 - max(rainStrength * 0.18, thunderStrength * 0.36);
        float surfaceLight = max(sampledLight, max(openSkyLight, blockAccess * 0.62));
        surfaceLight = pow(chillSaturate(surfaceLight), 1.10);
        float lightBits = floor(surfaceLight * 7.0 + 0.5);
        float skyBits = floor(skyAccess * 7.0 + 0.5);
        float materialBits = chillIceType > 1.5 ? 128.0 : 64.0;
        float packedLighting = (lightBits + skyBits * 8.0 + materialBits) / 255.0;
        vec3 iceNormal = normalize(chillPlayerNormal);
        gl_FragData[1] = vec4(iceNormal.xz * 0.5 + 0.5, 1.0, packedLighting);
    } else {
        gl_FragData[1] = vec4(0.0);
    }
    vec3 emissionColor = chillEmissionColor(chillEmissionType) * emissionMask;
    gl_FragData[2] = chillEmissionType > 0.5
        ? vec4(emissionColor, emissionMask)
        : vec4(0.0);
}
