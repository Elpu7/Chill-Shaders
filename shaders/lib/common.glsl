#ifndef CHILL_COMMON_GLSL
#define CHILL_COMMON_GLSL

#include "/lib/settings.glsl"

const float CHILL_PI = 3.14159265;

float chillSaturate(float value) { return clamp(value, 0.0, 1.0); }
vec3 chillSaturate(vec3 value) { return clamp(value, 0.0, 1.0); }
float chillLuminance(vec3 color) { return dot(color, vec3(0.2126, 0.7152, 0.0722)); }

// Project-local deterministic hashes. Their arithmetic is deliberately kept
// here so every procedural effect shares the same stable random field.
float chillHash2D(vec2 coordinate) {
    vec2 folded = fract(coordinate * vec2(0.3187, 0.2791) + vec2(0.173, 0.619));
    folded = fract(folded + folded.yx * (folded + vec2(1.137, 0.731)));
    float mixed = dot(folded, vec2(17.17, 29.41)) + folded.x * folded.y * 23.73;
    return fract(mixed);
}

float chillHash3D(vec3 coordinate) {
    vec3 folded = fract(coordinate * vec3(0.3187, 0.2791, 0.2417) + vec3(0.173, 0.619, 0.347));
    folded = fract(folded + folded.yzx * (folded.zxy + vec3(0.913, 1.271, 0.667)));
    float mixed = dot(folded, vec3(17.17, 29.41, 11.83))
        + (folded.x * folded.y + folded.y * folded.z + folded.z * folded.x) * 13.57;
    return fract(mixed);
}

float chillBayer2(vec2 pixel) {
    vec2 p = mod(floor(pixel), 2.0);
    return (p.x + p.y * 2.0) * 0.25;
}
float chillDayFactor(vec3 sunDir, vec3 upDir) {
    return smoothstep(-0.12, 0.12, dot(normalize(sunDir), normalize(upDir)));
}
float chillSunsetFactor(vec3 sunDir, vec3 upDir) {
    float altitude = abs(dot(normalize(sunDir), normalize(upDir)));
    return 1.0 - smoothstep(0.04, 0.34, altitude);
}
#endif
