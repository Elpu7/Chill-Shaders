#include "/lib/common.glsl"
#include "/lib/water.glsl"
#include "/lib/emission.glsl"
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float thunderStrength;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillViewPos;
varying vec3 chillWorldPos;
varying float chillIsWater;
varying float chillIceType;
varying vec3 chillSurfaceNormal;
varying float chillEmissionType;
/* DRAWBUFFERS:024 */
void main() {
    vec4 vanillaWater = texture2D(gtexture, chillTexCoord) * chillColor;
    vec3 light = texture2D(lightmap, chillLightmap).rgb;
    if (chillEmissionType > 0.5) {
        float emissionMask = chillEmissionMask(vanillaWater.rgb, vanillaWater.a, chillEmissionType);
        vec3 litEmitter = vanillaWater.rgb * (vec3(0.48) + light * 0.52);
        vec3 emitterColor = chillEmissiveSurface(litEmitter, vanillaWater.rgb, chillEmissionType, emissionMask);
        gl_FragData[0] = vec4(emitterColor, vanillaWater.a);
        // An opaque emitter clears water/ice data behind it and replaces the
        // visible emission buffer with its own warm or soul-blue radiance.
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        gl_FragData[2] = vec4(chillEmissionColor(chillEmissionType) * emissionMask, vanillaWater.a);
        return;
    }
    if (chillIsWater < 0.5 && chillIceType < 0.5) {
        vanillaWater.rgb *= vec3(0.48) + light * 0.52;
        gl_FragData[0] = vanillaWater;
        // Transparent glass keeps the water marker, while its more opaque
        // borders attenuate it by the same alpha used for the visible pane.
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        gl_FragData[2] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        return;
    }
    vec3 normal;
    if (chillIsWater > 0.5) {
        normal = chillWaterNormal(chillWorldPos.xz, frameTimeCounter, rainStrength);
    } else {
        normal = normalize(chillSurfaceNormal);
        if (normal.y > 0.55) {
            // Stationary, very fine irregularities break a perfectly flat
            // mirror without turning the ice into moving water.
            float microX = chillWaterNoise(chillWorldPos.xz * 0.82 + vec2(3.2, 7.1)) - 0.5;
            float microZ = chillWaterNoise(chillWaterRotate(chillWorldPos.xz) * 0.82 + vec2(11.4, 1.8)) - 0.5;
            float microStrength = chillIceType > 1.5 ? 0.030 : 0.014;
            normal = normalize(normal + vec3(microX, 0.0, microZ) * microStrength);
        }
    }
    // The fullscreen pass supplies reflection and transmission. Keep a thin,
    // animated world-space surface layer for a readable lake even when SSR
    // cannot find an on-screen object to reflect.
    // Keep the water's own surface layer tied to Minecraft's local lightmap.
    // Do not clamp it to a bright blue minimum: in a cave, water must inherit
    // the darkness or local torchlight of the space around it.
    // Use both sampled light and access to the open sky. Full skylight keeps a
    // moonlit lake readable even when the night lightmap RGB itself is dark.
    float sampledLight = chillSaturate(max(max(light.r, light.g), light.b));
    float skyAccess = chillSaturate(chillLightmap.y);
    float blockAccess = chillSaturate(chillLightmap.x);
    float day = chillDayFactor(normalize(sunPosition), normalize(upPosition));
    float openSkyLight = skyAccess * mix(0.58, 1.0, day);
    openSkyLight *= 1.0 - max(rainStrength * 0.18, thunderStrength * 0.36);
    float surfaceLight = max(sampledLight, max(openSkyLight, blockAccess * 0.62));
    surfaceLight = pow(chillSaturate(surfaceLight), 1.10);
    if (chillIsWater > 0.5) {
        float ripple = chillWaterSurfacePattern(chillWorldPos.xz, frameTimeCounter, rainStrength, normal);
        vec3 base = vec3(0.020, 0.075, 0.105) * mix(0.18, 1.0, surfaceLight);
        base *= mix(0.74, 1.28, ripple);
        base += vec3(0.010, 0.022, 0.026) * pow(ripple, 3.0) * surfaceLight;
        gl_FragData[0] = vec4(base, vanillaWater.a * 0.38);
    } else {
        // Retain the Minecraft ice detail beneath a cool, polished surface.
        // Reflections are added in composite after opaque scenery is complete.
        vec3 iceBase = vanillaWater.rgb * (vec3(0.48) + light * 0.52);
        float coolTint = chillIceType > 1.5 ? 0.34 : 0.20;
        iceBase = mix(iceBase, iceBase * vec3(0.82, 0.96, 1.10), coolTint);
        float iceAlpha = max(vanillaWater.a, chillIceType > 1.5 ? 0.90 : 0.58);
        gl_FragData[0] = vec4(iceBase, iceAlpha);
    }

    // Three light bits, three sky-access bits and two material bits fit in A.
    // Material 0 is water, 1 is clear/frosted ice and 2 is packed/blue ice.
    float lightBits = floor(chillSaturate(surfaceLight) * 7.0 + 0.5);
    float skyBits = floor(chillSaturate(skyAccess) * 7.0 + 0.5);
    float materialBits = chillIceType > 1.5 ? 128.0 : (chillIceType > 0.5 ? 64.0 : 0.0);
    float packedLighting = (lightBits + skyBits * 8.0 + materialBits) / 255.0;
    gl_FragData[1] = vec4(normal.xz * 0.5 + 0.5, 1.0, packedLighting);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
}
