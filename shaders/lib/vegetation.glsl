#ifndef CHILL_VEGETATION_GLSL
#define CHILL_VEGETATION_GLSL

#include "/lib/common.glsl"

vec2 chillFoliageOffset(vec3 worldPos, float time) {
#if CHILL_WIND_ENABLED == 1
    vec2 windDirection = normalize(vec2(0.82, 0.57));
    float longWave = sin(dot(worldPos.xz, windDirection) * 0.78 + time * 1.08);
    float crossWave = sin(dot(worldPos.xz, vec2(-0.57, 0.82)) * 1.32 + time * 0.71);
    float gust = 0.72 + 0.28 * sin(time * 0.31 + dot(worldPos.xz, vec2(0.11, 0.07)));
    return windDirection * (longWave + crossWave * 0.36) * gust * 0.038 * FOLIAGE_WAVING;
#else
    return vec2(0.0);
#endif
}
#endif
