#ifndef CHILL_POST_GLSL
#define CHILL_POST_GLSL

#include "/lib/common.glsl"
uniform float viewWidth;
uniform float viewHeight;

vec3 chillToneMap(vec3 color) {
    color *= EXPOSURE;
    color = color / (color + vec3(1.0));
    float luma = chillLuminance(color);
#if POST_PROCESSING == 0
    color = mix(vec3(luma), color, 1.0);
#elif POST_PROCESSING == 2
    color = mix(vec3(luma), color, 1.09);
#else
    color = mix(vec3(luma), color, 1.05);
#endif
    return pow(chillSaturate(color), vec3(1.0 / 2.2));
}

vec3 chillBloom(sampler2D colorTex, vec2 uv) {
#if CHILL_BLOOM_ENABLED == 1
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec3 glow = vec3(0.0);
    glow += texture2D(colorTex, uv + texel * vec2( 2.0, 0.0)).rgb;
    glow += texture2D(colorTex, uv + texel * vec2(-2.0, 0.0)).rgb;
    glow += texture2D(colorTex, uv + texel * vec2( 0.0, 2.0)).rgb;
    glow += texture2D(colorTex, uv + texel * vec2( 0.0,-2.0)).rgb;
    glow *= 0.25;
    return max(glow - vec3(0.62), 0.0) * BLOOM_INTENSITY;
#else
    return vec3(0.0);
#endif
}
#endif
