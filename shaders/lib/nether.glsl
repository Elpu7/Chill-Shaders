#ifndef CHILL_NETHER_GLSL
#define CHILL_NETHER_GLSL

// Minecraft supplies a different fog colour for each Nether biome. Retain the
// hue differences while reducing the overwhelming red cast of the vanilla
// Nether atmosphere.
vec3 chillNetherFogColor(vec3 vanillaFog) {
    vec3 fog = clamp(vanillaFog, vec3(0.0), vec3(1.0));
    float peak = max(max(fog.r, fog.g), fog.b);
    if (peak < 0.004) fog = vec3(0.16, 0.045, 0.030);
    float luminance = dot(fog, vec3(0.299, 0.587, 0.114));
    fog = mix(fog, vec3(luminance), 0.28);
    fog = mix(fog, vec3(0.090, 0.072, 0.078), 0.30);
    return clamp(fog * 0.72, vec3(0.018), vec3(0.34));
}

vec3 chillNetherBiomeFog(
    vec3 vanillaFog,
    float wastes,
    float crimson,
    float warped,
    float basalt,
    float soulValley
) {
    float total = wastes + crimson + warped + basalt + soulValley;
    vec3 selected = wastes * vec3(0.165, 0.070, 0.045)
                  + crimson * vec3(0.175, 0.048, 0.060)
                  + warped * vec3(0.038, 0.145, 0.130)
                  + basalt * vec3(0.100, 0.092, 0.105)
                  + soulValley * vec3(0.072, 0.115, 0.155);
    selected /= max(total, 0.0001);
    return mix(chillNetherFogColor(vanillaFog), selected, chillSaturate(total));
}

#endif
