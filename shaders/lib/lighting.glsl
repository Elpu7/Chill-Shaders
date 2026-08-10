#ifndef CHILL_LIGHTING_GLSL
#define CHILL_LIGHTING_GLSL

#include "/lib/common.glsl"

vec3 chillDirectLight(vec3 normal, vec3 sunDir, vec3 upDir, float shadow, float rain) {
    float day = chillDayFactor(sunDir, upDir);
    float nl = max(dot(normalize(normal), normalize(sunDir)), 0.0);
    float sunset = chillSunsetFactor(sunDir, upDir);
    vec3 sunColor = mix(vec3(1.0, 0.64, 0.40), vec3(1.0, 0.975, 0.90), 1.0 - sunset);
    vec3 moonColor = vec3(0.22, 0.30, 0.48);
    vec3 lightColor = mix(moonColor, sunColor, day);
    float intensity = mix(0.14, 0.82, day) * mix(1.0, 0.74, rain);
    return lightColor * (0.10 + nl * 0.56) * mix(0.42, 1.0, shadow) * intensity;
}

vec3 chillSceneLighting(vec3 albedo, vec3 normal, vec2 lightCoord, vec3 vanillaLight, vec3 sunDir, vec3 upDir, float shadow, float rain) {
    float skyLight = chillSaturate(lightCoord.y);
    float day = chillDayFactor(sunDir, upDir);
    float sunset = chillSunsetFactor(sunDir, upDir);
    vec3 sunColor = mix(vec3(1.0, 0.64, 0.40), vec3(1.0, 0.975, 0.90), 1.0 - sunset);
    // Minecraft's lightmap is the base. Only sunlight/moonlight receives the
    // additional shadow multiplier, preserving vanilla material contrast.
    vec3 lit = albedo * vanillaLight;
    // Only direct skylight can make a cast shadow dark. In dusk, rain or a
    // dimly lit area the indirect Minecraft light remains, so shadows fade
    // naturally instead of becoming the same black shape at every light level.
    float directAvailability = skyLight * day * (1.0 - rain * 0.55);
    float shadowOpacity = mix(0.025, 0.48, directAvailability);
    float shadowFactor = 1.0 - (1.0 - shadow) * shadowOpacity;
    lit *= shadowFactor;
    // Preserve vanilla brightness while giving sun-facing surfaces a modest
    // directional form, so outdoor lighting does not read as a flat lightmap.
    float facing = max(dot(normalize(normal), normalize(sunDir)), 0.0);
    float directionalShape = mix(0.94, 1.055, facing);
    lit *= mix(1.0, directionalShape, skyLight * day * 0.50);
    // Very small temperature shift only; no extra brightness is introduced.
    lit = mix(lit, lit * sunColor, skyLight * day * (0.035 + sunset * 0.095));
    return lit;
}
#endif
