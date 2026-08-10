#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/water.glsl"
uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float thunderStrength;
uniform int isEyeInWater;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
#ifdef CHILL_NETHER
uniform vec3 fogColor;
uniform float chillNetherWastes;
uniform float chillCrimsonForest;
uniform float chillWarpedForest;
uniform float chillBasaltDeltas;
uniform float chillSoulValley;
#include "/lib/nether.glsl"
#endif
varying vec2 chillTexCoord;
/* DRAWBUFFERS:1 */

vec3 chillViewPositionFromDepth(vec2 uv, float depth) {
    vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
    vec4 position = gbufferProjectionInverse * vec4(ndc, 1.0);
    return position.xyz / max(position.w, 0.0001);
}

#include "/lib/screen_reflections.glsl"

void main() {
    vec4 scene = texture2D(colortex0, chillTexCoord);
    vec4 waterData = texture2D(colortex2, chillTexCoord);
    float waterVisibility = chillSaturate(waterData.b);
    if (waterVisibility > 0.025) {
        vec3 sceneBeforeWater = scene.rgb;
        vec2 horizontalNormal = (waterData.rg / max(waterVisibility, 0.001)) * 2.0 - 1.0;
        float verticalNormal = sqrt(max(1.0 - dot(horizontalNormal, horizontalNormal), 0.001));
        vec3 normal = normalize(vec3(horizontalNormal.x, verticalNormal, horizontalNormal.y));
        // Glass blending produces A = glassOpacity + packedData * transmission.
        // Recover and unpack local light plus open-sky access while B controls
        // seam visibility.
        float glassOpacity = 1.0 - waterVisibility;
        float packedLighting = chillSaturate((waterData.a - glassOpacity) / max(waterVisibility, 0.001));
        float lightingByte = floor(packedLighting * 255.0 + 0.5);
        // Two high bits identify water, glossy ice, or rough packed/blue ice.
        // The remaining six bits retain local light and open-sky access.
        float materialCode = floor(lightingByte / 64.0);
        float lightingPayload = lightingByte - materialCode * 64.0;
        float waterIllumination = mod(lightingPayload, 8.0) / 7.0;
        float waterSkyAccess = floor(lightingPayload / 8.0) / 7.0;
        float isIceMaterial = step(0.5, materialCode);
        float roughIce = step(1.5, materialCode);
        float depth = texture2D(depthtex0, chillTexCoord).r;
        vec3 waterViewPosition = chillViewPositionFromDepth(chillTexCoord, depth);
        vec3 viewRay = normalize(waterViewPosition);
        vec3 worldRay = normalize(mat3(gbufferModelViewInverse) * viewRay);
        float opaqueDepth = texture2D(depthtex1, chillTexCoord).r;
        vec3 opaqueViewPosition = chillViewPositionFromDepth(chillTexCoord, opaqueDepth);
        float rayDepth = max(length(opaqueViewPosition) - length(waterViewPosition), 0.0);
        // Approximate vertical depth early so shallow water can avoid unstable
        // screen-space hits while retaining its stable sky reflection.
        float waterDepth = clamp(rayDepth * max(dot(-worldRay, normal), 0.12), 0.0, 16.0);
        vec3 worldSunDir = normalize(mat3(gbufferModelViewInverse) * sunPosition);
        vec3 worldUpDir = normalize(mat3(gbufferModelViewInverse) * upPosition);
        vec3 reflectedRay = reflect(worldRay, normal);
        // Wave normals can point a grazing reflection a fraction below the
        // mathematical horizon. Sampling that direction produced a black band
        // on distant evening water. Keep environmental reflection directions
        // just above the horizon while leaving their horizontal bearing intact.
        float reflectedElevation = dot(reflectedRay, worldUpDir);
        reflectedRay = normalize(reflectedRay + worldUpDir * max(0.045 - reflectedElevation, 0.0));
        float day = chillDayFactor(worldSunDir, worldUpDir);
        // Reflect the analytical sky direction, not the screen color buffer.
        // This produces a stable Fresnel reflection when the camera turns.
        vec3 reflection = chillSkyColor(reflectedRay, worldSunDir, worldUpDir, rainStrength, thunderStrength, 1.0 - day);
        // From below, the water surface reflects the underwater scene rather
        // than the sky. SSR below replaces this inexpensive fallback whenever
        // the reflected ray reaches visible opaque terrain.
        if (isEyeInWater == 1) reflection = scene.rgb * vec3(0.72, 0.84, 0.94);
        // Preserve a restrained surface sheen in darkness, but prevent sky
        // reflections from making cave water look lit by daylight.
        float waterLightResponse = mix(0.16, 1.0, pow(waterIllumination, 1.20));
        vec4 screenReflection = vec4(0.0);
#if WATER_QUALITY > 0
        reflection = mix(vec3(0.055, 0.115, 0.150), reflection, 0.92);
#if CHILL_REFLECTIONS_ENABLED == 1 && WATER_QUALITY > 0
        // Trace visible terrain and entities on both sides of the surface.
        // The analytical environment remains the stable fallback outside the
        // screen, while Chill uses fewer trace steps than the High profile.
        vec3 viewNormal = normalize(mat3(gbufferModelView) * normal);
        vec3 traceNormal = isEyeInWater == 1 ? -viewNormal : viewNormal;
        float reflectionBlur;
        if (isIceMaterial > 0.5) {
            reflectionBlur = roughIce > 0.5
                ? (WATER_QUALITY == 2 ? 1.10 : 1.45)
                : (WATER_QUALITY == 2 ? 0.42 : 0.68);
        } else {
            reflectionBlur = isEyeInWater == 1
                ? (WATER_QUALITY == 2 ? 1.35 : 1.85)
                : (WATER_QUALITY == 2 ? 0.70 : 1.05);
        }
        screenReflection = chillTraceScreenReflection(depth, traceNormal, waterViewPosition, reflectionBlur);
        float ssrLuma = chillLuminance(screenReflection.rgb);
        float ssrStrength;
        if (isIceMaterial > 0.5) {
            ssrStrength = roughIce > 0.5
                ? (WATER_QUALITY == 2 ? 0.62 : 0.48)
                : (WATER_QUALITY == 2 ? 0.92 : 0.76);
        } else {
            ssrStrength = WATER_QUALITY == 2 ? 0.88 : 0.70;
            if (isEyeInWater == 1) ssrStrength *= 0.80;
            else ssrStrength *= smoothstep(0.55, 1.85, waterDepth);
        }
        // Squaring confidence turns hit/miss boundaries into a soft fade and
        // removes the remaining contour-like layers across shallow lakes.
        float ssrConfidence = screenReflection.a * screenReflection.a;
        float ssrWeight = ssrConfidence * smoothstep(0.008, 0.04, ssrLuma) * ssrStrength;
        reflection = mix(reflection, screenReflection.rgb, ssrWeight);
#endif
#if WATER_QUALITY == 2
        reflection += vec3(0.025, 0.045, 0.055) * (normal.x * normal.x + normal.z * normal.z);
#endif
#else
        // Potato keeps this stable analytical sky fallback instead of SSR.
        // It is cheap, avoids a black water surface, and remains independent
        // of screen-space camera motion.
        reflection = mix(vec3(0.060, 0.115, 0.150), reflection, 0.86);
#endif
        // Open water receives its environment light from the sky even when
        // the sampled lightmap RGB is dim at dusk or at night. This prevents
        // distant lakes from becoming black while roofed cave water remains
        // controlled by its local block light.
        float openSkyResponse = waterSkyAccess * mix(0.62, 1.0, day);
        openSkyResponse *= 1.0 - max(rainStrength * 0.16, thunderStrength * 0.30);
        float reflectionLightResponse = max(waterLightResponse, openSkyResponse);
        reflection *= reflectionLightResponse;

        // Let nearby block light leave a restrained warm trace on wave crests.
        // The sky-access subtraction prevents the whole lake from receiving
        // this tint merely because it is outdoors.
        float localWaterLight = chillSaturate(waterIllumination - waterSkyAccess * 0.42);
        float crestResponse = chillSaturate((1.0 - normal.y) * 9.0 + 0.12);
        reflection += vec3(0.12, 0.055, 0.020) * localWaterLight * crestResponse;
        if (isEyeInWater != 1) {
            // At night a low viewing angle is almost pure reflection. Preserve
            // a restrained moon-blue floor only for water exposed to the sky;
            // roofed and cave water therefore remains correctly dark.
            float viewCosine = chillSaturate(dot(normal, -worldRay));
            float grazing = 1.0 - viewCosine;
            float openNightWater = (1.0 - day) * smoothstep(0.55, 0.95, waterSkyAccess);
            openNightWater *= smoothstep(0.35, 0.88, grazing);
            openNightWater *= (1.0 - rainStrength * 0.42) * (1.0 - thunderStrength * 0.68);
            vec3 moonReflectionFloor = vec3(0.038, 0.060, 0.095) * openNightWater;
            reflection = max(reflection, moonReflectionFloor);
        }
        // Convert the along-view-ray distance to an approximate vertical water
        // depth. This prevents distant, shallow water from becoming inky blue.
        // Keep the water bed free of an extra procedural caustic pass. At
        // Minecraft block scale that pattern resolved into bright sparkle dots.
        // Transmission stays at the original screen pixel: a normal-offset
        // scene lookup makes shorelines and the water surface slide as the
        // camera moves.
        if (isIceMaterial > 0.5) {
            // Clear/frosted ice behaves like a smooth frozen lake, while
            // packed and blue ice retain a broader, more restrained sheen.
            float viewCosine = chillSaturate(dot(normal, -worldRay));
            float grazing = pow(1.0 - viewCosine, 3.5);
            float baseReflectance = mix(0.22, 0.12, roughIce);
            float edgeReflectance = mix(0.92, 0.68, roughIce);
            float reflectionAmount = mix(baseReflectance, edgeReflectance, grazing);
            reflectionAmount *= mix(0.42, 1.0, waterIllumination);
            vec3 iceBase = scene.rgb;
            iceBase = mix(iceBase, iceBase * vec3(0.88, 0.97, 1.06), mix(0.22, 0.34, roughIce));
            scene.rgb = mix(iceBase, reflection, chillSaturate(reflectionAmount));

            float specularAlignment = max(dot(reflect(-worldSunDir, normal), -worldRay), 0.0);
            float iceGlint = pow(specularAlignment, roughIce > 0.5 ? 72.0 : 220.0);
            iceGlint *= day * waterIllumination * (1.0 - rainStrength * 0.72) * (1.0 - thunderStrength * 0.88);
            scene.rgb += vec3(1.0, 0.86, 0.68) * iceGlint * mix(0.16, 0.30, 1.0 - roughIce);
        } else if (isEyeInWater == 1) {
            // Underwater surface reflection must not be made from mirrored
            // screen UVs: that would rotate with the camera. Use the traced
            // world hit when available, with a stable optical fallback only.
            float incidentCosine = chillSaturate(abs(dot(normal, -worldRay)));
            float grazing = 1.0 - incidentCosine;
            // A broad, low-strength Fresnel curve avoids the bright circular
            // critical-angle boundary that previously appeared overhead.
            float undersideReflection = 0.055 + 0.355 * pow(grazing, 2.35);
            scene.rgb = mix(scene.rgb, reflection, undersideReflection);
        } else {
            // worldRay points from camera to surface; Fresnel needs surface to camera.
            scene.rgb = chillWaterColor(scene.rgb, reflection, normal, -worldRay, worldSunDir, waterDepth, waterIllumination);
        }
        // Apply water only through the transparent portion of glass. The
        // cloud mask also prevents the later water pass from darkening water
        // through a cloud that has already been blended into the scene.
        float glassWaterVisibility = smoothstep(0.10, 0.78, waterVisibility);
        float cloudCoverage = chillSaturate(texture2D(colortex3, chillTexCoord).r);
        float cloudWaterVisibility = 1.0 - smoothstep(0.08, 0.62, cloudCoverage);
        float waterPostVisibility = glassWaterVisibility * cloudWaterVisibility;
        scene.rgb = mix(sceneBeforeWater, scene.rgb, waterPostVisibility);
    }
#ifdef CHILL_NETHER
    // Apply a single dimension-wide fog pass after transparent materials so
    // terrain, entities, particles and liquids all share Minecraft's current
    // biome fog colour. The tint is deliberately desaturated to avoid the old
    // solid-red Nether cast.
    float netherDepth = texture2D(depthtex0, chillTexCoord).r;
    if (netherDepth < 0.99999) {
        vec3 netherViewPosition = chillViewPositionFromDepth(chillTexCoord, netherDepth);
        float netherDistance = length(netherViewPosition);
        // Exponential density stays stable with Distant Horizons and very
        // large render distances. The previous far-relative range often put
        // the fog start hundreds of blocks away, making it effectively absent.
        float netherFogAmount = 1.0 - exp(-max(netherDistance - 8.0, 0.0) * 0.0125 * FOG_DENSITY);
        netherFogAmount = min(netherFogAmount, 0.84);
        vec3 netherFog = chillNetherBiomeFog(
            fogColor,
            chillNetherWastes,
            chillCrimsonForest,
            chillWarpedForest,
            chillBasaltDeltas,
            chillSoulValley
        );
        scene.rgb = mix(scene.rgb, netherFog, netherFogAmount);
    }
#endif
    gl_FragData[0] = scene;
}
