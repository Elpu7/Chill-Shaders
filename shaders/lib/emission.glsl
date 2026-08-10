#ifndef CHILL_EMISSION_GLSL
#define CHILL_EMISSION_GLSL

#include "/lib/common.glsl"

vec3 chillEmissionColor(float emissionType) {
    if (emissionType > 2.5) return vec3(0.58, 0.25, 1.24);
    if (emissionType > 1.5) return vec3(0.10, 0.55, 1.30);
    return vec3(1.30, 0.29, 0.025);
}

float chillEmissionMask(vec3 albedo, float alpha, float emissionType) {
    float luminance = chillLuminance(albedo);
    float threshold = emissionType > 2.5 ? 0.10 : (emissionType > 1.5 ? 0.08 : 0.12);
    return alpha * smoothstep(threshold, 0.78, luminance);
}

vec3 chillEmissiveSurface(vec3 litColor, vec3 albedo, float emissionType, float emissionMask) {
    if (emissionType < 0.5) return litColor;
    vec3 sourceColor = chillEmissionColor(emissionType);
    vec3 materialTint = emissionType > 2.5
        ? vec3(1.08, 0.86, 1.34)
        : (emissionType > 1.5 ? vec3(0.72, 1.04, 1.38) : vec3(1.30, 1.02, 0.72));
    vec3 emissiveColor = albedo * materialTint + sourceColor * (0.08 + emissionMask * 0.18);
    return max(litColor, mix(litColor, emissiveColor, 0.64 + emissionMask * 0.30));
}

#endif
