#ifndef CHILL_ATMOSPHERE_GLSL
#define CHILL_ATMOSPHERE_GLSL

#include "/lib/common.glsl"

vec3 chillSkyColor(vec3 viewDir, vec3 sunDir, vec3 upDir, float rain, float thunder, float nightMix) {
    rain = chillSaturate(rain);
    thunder = chillSaturate(thunder);
    float sunset = chillSunsetFactor(sunDir, upDir) * (1.0 - rain * 0.92) * (1.0 - thunder);
    float day = 1.0 - nightMix;
    float skyHeight = chillSaturate(dot(normalize(viewDir), normalize(upDir)));
    float horizon = pow(1.0 - skyHeight, 1.35);

    vec3 clearNight = mix(vec3(0.022, 0.032, 0.068), vec3(0.070, 0.090, 0.135), horizon);
    vec3 clearDay = mix(vec3(0.40, 0.66, 1.00), vec3(0.72, 0.83, 0.94), horizon);
    vec3 dawnSky = vec3(0.42, 0.38, 0.56);
    vec3 sunsetTint = vec3(0.96, 0.58, 0.38);
    vec3 sky = mix(clearNight, clearDay, day);
    sky = mix(sky, dawnSky, sunset * 0.20);
    sky = mix(sky, sunsetTint, sunset * 0.24);

    vec3 rainyNight = mix(vec3(0.024, 0.032, 0.046), vec3(0.070, 0.078, 0.088), horizon);
    vec3 rainyDay = mix(vec3(0.29, 0.35, 0.41), vec3(0.48, 0.51, 0.54), horizon);
    vec3 rainySky = mix(rainyNight, rainyDay, day);

    vec3 thunderNight = mix(vec3(0.010, 0.014, 0.024), vec3(0.036, 0.040, 0.048), horizon);
    vec3 thunderDay = mix(vec3(0.105, 0.130, 0.165), vec3(0.245, 0.265, 0.285), horizon);
    vec3 thunderSky = mix(thunderNight, thunderDay, day);

    sky = mix(sky, rainySky, rain * 0.90);
    sky = mix(sky, thunderSky, thunder * 0.96);
    return sky;
}

vec3 chillApplyFog(vec3 color, vec3 fogColor, float viewDistance, float rain, float day) {
#if ATMOSPHERE_QUALITY == 0
    float density = 0.0021 * FOG_DENSITY;
#elif ATMOSPHERE_QUALITY == 2
    float density = (0.0025 + rain * 0.0018) * FOG_DENSITY;
#else
    float density = (0.0023 + rain * 0.0015) * FOG_DENSITY;
#endif
    density *= mix(1.16, 0.86, day);
    float fog = 1.0 - exp(-viewDistance * density);
    vec3 dayAerial = mix(fogColor, vec3(0.72, 0.76, 0.80), (1.0 - rain) * 0.20);
    vec3 nightAerial = mix(fogColor, vec3(0.075, 0.095, 0.150), 0.28);
    vec3 aerialColor = mix(nightAerial, dayAerial, day);
    return mix(color, aerialColor, chillSaturate(fog));
}
#endif
