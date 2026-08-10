#ifndef CHILL_WATER_GLSL
#define CHILL_WATER_GLSL

#include "/lib/common.glsl"

float chillWaterHash(vec2 cell) {
    return chillHash2D(cell);
}

float chillWaterNoise(vec2 position) {
    vec2 cell = floor(position);
    vec2 fraction = fract(position);
    fraction = fraction * fraction * (3.0 - 2.0 * fraction);
    float bottom = mix(chillWaterHash(cell), chillWaterHash(cell + vec2(1.0, 0.0)), fraction.x);
    float top = mix(chillWaterHash(cell + vec2(0.0, 1.0)), chillWaterHash(cell + vec2(1.0)), fraction.x);
    return mix(bottom, top, fraction.y);
}

vec2 chillWaterRotate(vec2 value) {
    return vec2(value.x * 0.80 - value.y * 0.60, value.x * 0.60 + value.y * 0.80);
}

float chillWaterHeight(vec2 worldXZ, float time) {
    // Animated 2D value noise replaces all full-width sine crests. Two broad
    // warp fields bend the coordinates before three independently advected
    // scales are combined, so no continuous repeating stripes can form.
    vec2 broadDrift = vec2(time * 0.110, time * 0.047);
    vec2 warpCoordinates = worldXZ * 0.055 + broadDrift * 0.45;
    vec2 warp = vec2(
        chillWaterNoise(warpCoordinates),
        chillWaterNoise(warpCoordinates + vec2(19.70, 7.30))
    ) - 0.5;
    vec2 warpedXZ = worldXZ + warp * 5.0;

    float broad = chillWaterNoise(warpedXZ * 0.115 + broadDrift) - 0.5;
    vec2 mediumXZ = chillWaterRotate(warpedXZ);
    float medium = chillWaterNoise(mediumXZ * 0.240 + vec2(-time * 0.150, time * 0.090) + vec2(8.1, 3.7)) - 0.5;
    vec2 detailXZ = chillWaterRotate(mediumXZ);
    float detail = chillWaterNoise(detailXZ * 0.520 + vec2(time * 0.260, -time * 0.130) + vec2(2.4, 15.2)) - 0.5;
    return broad * 0.170 + medium * 0.075 + detail * 0.030;
}

vec3 chillWaterNormal(vec2 worldXZ, float time, float rain) {
    // Derive the optical normal from the exact height field used by the vertex
    // shader, so reflections travel with the displaced surface instead of
    // sliding across stationary geometry.
    float stepSize = 0.10;
    float heightCenter = chillWaterHeight(worldXZ, time);
    float heightRight = chillWaterHeight(worldXZ + vec2(stepSize, 0.0), time);
    float heightFront = chillWaterHeight(worldXZ + vec2(0.0, stepSize), time);
    vec2 slope = vec2(heightRight - heightCenter, heightFront - heightCenter) / stepSize;
    float rainRipple = cos(dot(worldXZ, vec2(4.7, 3.9)) + time * 4.3) * rain * 0.018;
    slope += vec2(rainRipple, rainRipple * 0.72);
    return normalize(vec3(-slope.x, 1.0, -slope.y));
}

float chillWaterSurfacePattern(vec2 worldXZ, float time, float rain, vec3 normal) {
    vec2 drift = vec2(time * 0.220, time * 0.095);
    float shimmerA = chillWaterNoise(chillWaterRotate(worldXZ) * 0.410 + drift + vec2(4.2, 11.8));
    float shimmerB = chillWaterNoise(worldXZ * 0.760 + vec2(-time * 0.310, time * 0.170) + vec2(13.1, 1.9));
    float slopeHighlight = chillSaturate((1.0 - normal.y) * 7.0);
    float rainRipple = sin(dot(worldXZ, vec2(4.7, 3.9)) + time * 4.3) * rain;
    return chillSaturate(0.34 + shimmerA * 0.28 + shimmerB * 0.14 + slopeHighlight * 0.22 + rainRipple * 0.035);
}

float chillWaterCaustic(vec2 worldXZ, float time) {
    // Two inexpensive, world-space wave patterns create soft sunlight bands
    // on the visible bed. World coordinates keep the pattern continuous when
    // crossing water-block boundaries or moving the camera.
    float waveA = sin(dot(worldXZ, vec2(0.92, 0.48)) * 2.15 + time * 1.10);
    float waveB = sin(dot(worldXZ, vec2(-0.53, 0.86)) * 2.80 - time * 0.82);
    // A broad, low-contrast field reads as refracted sunlight.  The previous
    // fourth-power highlight isolated small circular bright dots on sand and
    // gravel, which looked like glowing particles rather than caustics.
    return smoothstep(0.36, 0.82, 0.50 + 0.25 * (waveA + waveB));
}

vec3 chillWaterColor(vec3 original, vec3 reflected, vec3 normal, vec3 viewDir, vec3 sunDir, float depthHint, float localIllumination) {
    float viewCosine = max(dot(normalize(normal), normalize(viewDir)), 0.0);
    // Keep a visible but still restrained mirror response at normal incidence;
    // the reflection becomes dominant only at a grazing angle.
    // Low normal-incidence Fresnel keeps water transparent from elevated
    // viewpoints. The steep grazing curve still creates a readable mirror at
    // shore level.
    // Water's physical normal-incidence reflectance is close to four percent.
    // Keeping that low preserves transparency when looking down while grazing
    // angles still reflect the sky strongly.
    float fresnel = 0.038 + 0.962 * pow(1.0 - viewCosine, 5.0);
    // A broad glint sits beneath a tight highlight. The multi-scale normal
    // breaks both lobes across moving crests instead of painting one flat spot.
    float specularAlignment = max(dot(reflect(-normalize(sunDir), normalize(normal)), normalize(viewDir)), 0.0);
    float sunSpecular = pow(specularAlignment, WATER_QUALITY == 2 ? 176.0 : 128.0);
    float broadSpecular = pow(specularAlignment, 30.0) * 0.20;
    float depthFactor = 1.0 - exp(-max(depthHint, 0.0) * 0.065);
    // Beer-Lam-style channel absorption lets shallow bottoms remain visible
    // while deeper water gains a naturally darker blue-green body colour.
    vec3 transmission = exp(-max(depthHint, 0.0) * vec3(0.055, 0.022, 0.009));
    vec3 shallowWater = vec3(0.050, 0.210, 0.240);
    vec3 deepWater = vec3(0.012, 0.060, 0.120);
    vec3 waterBody = mix(shallowWater, deepWater, depthFactor);
    // Everything seen through the surface, including mobs and players, must
    // inherit the same water colour and available light as the surrounding
    // bed. The near-depth response starts gently so shallow rivers remain
    // clear, while red light is absorbed first as in real water.
    float submergedView = 1.0 - exp(-max(depthHint, 0.0) * 0.42);
    vec3 waterFilter = mix(vec3(1.0), vec3(0.60, 0.84, 0.96), submergedView);
    float transmissionLight = mix(0.80, 1.0, pow(chillSaturate(localIllumination), 1.10));
    // Keep the Minecraft bed clearly visible: this is transparent river water,
    // not an opaque blue surface. The body colour only fills in the deepest
    // parts and preserves a readable sense of depth.
    vec3 absorbed = original * transmission * waterFilter * transmissionLight;
    absorbed = mix(absorbed, waterBody, submergedView * 0.105);
    // Fine waves modulate the reflected light very gently, creating a moving
    // surface instead of a uniformly coloured sheet of water.
    float localLight = pow(chillSaturate(localIllumination), 1.35);
    float surfaceLight = (0.90 + 0.10 * max(dot(normalize(normal), normalize(sunDir)), 0.0)) * (0.18 + 0.82 * localLight);
    float waveEnergy = chillSaturate((1.0 - normal.y) * 6.0);
    float reflectionAmount = chillSaturate(fresnel * (0.94 + WATER_REFLECTION_STRENGTH * 1.08) + waveEnergy * 0.038);
    vec3 result = mix(absorbed, reflected * surfaceLight, reflectionAmount);
    result += vec3(1.0, 0.82, 0.60) * (sunSpecular * 0.15 + broadSpecular * 0.075) * localLight;
    return result;
}
#endif
