#include "/lib/common.glsl"
#include "/lib/water.glsl"
#include "/lib/emission.glsl"
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform mat4 gbufferModelViewInverse;
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
    if (chillIceType > 0.5) {
        // Ice keeps Minecraft's own texture, tint, alpha and ordinary
        // lightmap shading. The material marker only tells the fullscreen
        // water pass to leave this pixel untouched.
        vanillaWater.rgb *= light;
        gl_FragData[0] = vanillaWater;
        float materialBits = chillIceType > 1.5 ? 192.0 : 128.0;
        gl_FragData[1] = vec4(0.5, 0.5, 1.0, materialBits / 255.0);
        gl_FragData[2] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        return;
    }
    if (chillIsWater < 0.5) {
        vanillaWater.rgb *= vec3(0.48) + light * 0.52;
        gl_FragData[0] = vanillaWater;
        // Transparent glass keeps the water marker, while its more opaque
        // borders attenuate it by the same alpha used for the visible pane.
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        gl_FragData[2] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
        return;
    }
    vec3 geometryNormal = normalize(chillSurfaceNormal);
    vec3 worldSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
    vec3 worldUpDir = normalize(mat3(gbufferModelViewInverse) * upPosition);
    float upwardExposure = abs(dot(geometryNormal, worldUpDir));
    float horizontalWaterFace = smoothstep(0.42, 0.86, upwardExposure);
    vec3 waveNormal = chillWaterNormal(chillWorldPos.xz, frameTimeCounter, rainStrength);
    if (dot(geometryNormal, worldUpDir) < 0.0) waveNormal.y = -waveNormal.y;
    // Only horizontal water receives the full height-field normal. A
    // waterfall keeps its actual wall-facing normal instead of behaving
    // like a bright horizontal lake rotated onto the mountainside.
    vec3 normal = normalize(mix(geometryNormal, waveNormal, horizontalWaterFace));
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
    float day = chillDayFactor(worldSunDir, worldUpDir);
    float directSun = max(dot(geometryNormal, worldSunDir), 0.0) * day;
    float sideSkyLight = mix(0.16, 0.34, day);
    float topSkyLight = mix(0.58, 0.92, day);
    float openSkyLight = skyAccess * chillSaturate(mix(sideSkyLight, topSkyLight, upwardExposure) + directSun * 0.46);
    openSkyLight *= 1.0 - max(rainStrength * 0.18, thunderStrength * 0.36);
    float orientationAttenuation = mix(0.40, 1.0, upwardExposure);
    float orientedSampledLight = sampledLight * orientationAttenuation;
    float surfaceLight = max(orientedSampledLight, max(openSkyLight, blockAccess * 0.62));
    surfaceLight = pow(chillSaturate(surfaceLight), 1.10);
    vec2 waterPatternPosition = chillWorldPos.xz;
    if (horizontalWaterFace < 0.5) {
        waterPatternPosition = abs(geometryNormal.x) > abs(geometryNormal.z)
            ? chillWorldPos.zy
            : chillWorldPos.xy;
    }
    float ripple = chillWaterSurfacePattern(waterPatternPosition, frameTimeCounter, rainStrength, normal);
    // Vertical streams get restrained streak detail, not the intense
    // crest highlight intended for a sunlit horizontal wave surface.
    ripple = mix(0.36 + (ripple - 0.36) * 0.42, ripple, horizontalWaterFace);
    vec3 base = vec3(0.020, 0.075, 0.105) * mix(0.18, 1.0, surfaceLight);
    base *= mix(0.74, 1.28, ripple);
    base += vec3(0.010, 0.022, 0.026) * pow(ripple, 3.0) * surfaceLight;
    // A falling sheet is mostly transmitted scenery with a restrained
    // blue tint. Keeping the lake alpha on a vertical face made mountain
    // streams read as solid, self-lit white slabs.
    float waterSurfaceAlpha = mix(0.18, 0.38, horizontalWaterFace);
    gl_FragData[0] = vec4(base, vanillaWater.a * waterSurfaceAlpha);

    // Water stores local illumination in the remaining payload.
    float lightBits = floor(chillSaturate(surfaceLight) * 7.0 + 0.5);
    float skyBits = floor(chillSaturate(skyAccess) * 7.0 + 0.5);
    float packedLighting = (lightBits + skyBits * 8.0) / 255.0;
    gl_FragData[1] = vec4(normal.xz * 0.5 + 0.5, 1.0, packedLighting);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, vanillaWater.a);
}
