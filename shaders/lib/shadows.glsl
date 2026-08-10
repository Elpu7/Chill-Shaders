#ifndef CHILL_SHADOWS_GLSL
#define CHILL_SHADOWS_GLSL

#include "/lib/common.glsl"

// Raw depth comparison used by the manual PCF path. Shadow depth textures are
// kept nearest-filtered so blocker depth itself is never interpolated; instead
// we interpolate the binary visibility result below. This avoids false blocker
// depths while still letting a moving shadow edge travel smoothly between
// shadow texels.
float chillShadowCompare(sampler2D shadowMap, vec2 uv, float receiverDepth) {
    return step(receiverDepth, texture2D(shadowMap, uv).r);
}

// Bilinear interpolation of four *comparison results*. This is effectively a
// stable 2x2 PCF sample and removes the hard one-texel jumps that made shadows
// sweep over the terrain as visible bands when the sun moved.
float chillShadowBilinear(sampler2D shadowMap, vec2 uv, float receiverDepth) {
    float resolution = float(SHADOW_RESOLUTION);
    vec2 texel = vec2(1.0 / resolution);
    vec2 mapPos = uv * resolution - vec2(0.5);
    vec2 base = floor(mapPos);
    vec2 blend = fract(mapPos);
    vec2 baseUV = (base + vec2(0.5)) * texel;

    vec2 minUV = texel * 0.5;
    vec2 maxUV = vec2(1.0) - minUV;

    float s00 = chillShadowCompare(shadowMap, clamp(baseUV, minUV, maxUV), receiverDepth);
    float s10 = chillShadowCompare(shadowMap, clamp(baseUV + vec2(texel.x, 0.0), minUV, maxUV), receiverDepth);
    float s01 = chillShadowCompare(shadowMap, clamp(baseUV + vec2(0.0, texel.y), minUV, maxUV), receiverDepth);
    float s11 = chillShadowCompare(shadowMap, clamp(baseUV + texel, minUV, maxUV), receiverDepth);

    return mix(mix(s00, s10, blend.x), mix(s01, s11, blend.x), blend.y);
}

float chillShadowPCF(sampler2D shadowMap, vec2 uv, float receiverDepth) {
#if SHADOW_FILTER == 0
    return chillShadowCompare(shadowMap, uv, receiverDepth);
#elif SHADOW_FILTER == 1
    return chillShadowBilinear(shadowMap, uv, receiverDepth);
#else
    vec2 texel = vec2(1.0 / float(SHADOW_RESOLUTION));

    // Five bilinear visibility taps replace the former nine-tap kernel on the
    // balanced profile (20 raw depth reads instead of 36). The fixed diagonal
    // pattern remains round and temporally stable without random rotation.
    float radius = SHADOW_FILTER == 2 ? 1.28 : 1.62;
    float diagonal = radius * 0.70710678;
    float sum = chillShadowBilinear(shadowMap, uv, receiverDepth) * 2.0;
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2( diagonal,  diagonal), receiverDepth);
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2(-diagonal,  diagonal), receiverDepth);
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2( diagonal, -diagonal), receiverDepth);
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2(-diagonal, -diagonal), receiverDepth);
    float weight = 6.0;

#if SHADOW_FILTER >= 3
    // High adds only one four-tap outer ring (36 reads total instead of 52).
    float outer = radius * 1.38;
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2( outer, 0.0), receiverDepth) * 0.65;
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2(-outer, 0.0), receiverDepth) * 0.65;
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2(0.0,  outer), receiverDepth) * 0.65;
    sum += chillShadowBilinear(shadowMap, uv + texel * vec2(0.0, -outer), receiverDepth) * 0.65;
    weight += 2.6;
#endif

    return sum / weight;
#endif
}

float chillShadowSample(
    sampler2D shadowMap,
    vec3 feetPos,
    vec3 receiverNormalView,
    vec3 receiverNormalPlayer,
    vec3 shadowLightDirView,
    mat4 shadowModelView,
    mat4 shadowProjection
) {
    vec3 normalView = normalize(receiverNormalView);
    vec3 normalPlayer = normalize(receiverNormalPlayer);
    vec3 lightDirView = normalize(shadowLightDirView);

    float ndotl = max(dot(normalView, lightDirView), 0.0);
    float receiverDistance = length(feetPos);

    // Normal-offset bias in player space. A pure depth bias is not enough on
    // long Minecraft block faces: as the light rotates, depth quantisation can
    // form large moving self-shadow bands. Moving the receiver a fraction of a
    // shadow texel away from its own surface keeps genuine occluders intact but
    // prevents the face from repeatedly shadowing itself.
    float worldTexel = (2.0 * float(SHADOW_DISTANCE)) / float(SHADOW_RESOLUTION);
    float slope = 1.0 - ndotl;
    float distanceScale = mix(
        1.0,
        1.42,
        clamp(receiverDistance / max(float(SHADOW_DISTANCE), 1.0), 0.0, 1.0)
    );
    float normalBias = worldTexel * mix(0.90, 2.10, slope) * distanceScale;
    normalBias = min(normalBias, 0.26);

    vec3 biasedFeetPos = feetPos + normalPlayer * normalBias;
    vec4 shadowClip = shadowProjection * shadowModelView * vec4(biasedFeetPos, 1.0);

    // Small residual clip-space depth bias for raster precision. Most of the
    // acne suppression is handled by the normal offset above, so this value can
    // stay small enough to avoid detached / peter-panning shadows.
    float clipBias = mix(0.00032, 0.00072, slope);
    shadowClip.z -= clipBias * shadowClip.w;

    vec3 coord = shadowClip.xyz / max(abs(shadowClip.w), 0.0001);
    coord = coord * 0.5 + 0.5;

    if (coord.x <= 0.002 || coord.x >= 0.998 ||
        coord.y <= 0.002 || coord.y >= 0.998 ||
        coord.z <= 0.0   || coord.z >= 1.0) {
        return 1.0;
    }

    float visibility = chillShadowPCF(shadowMap, coord.xy, coord.z);

    // Fade only at the finite shadow-map boundary. This does not move nearby
    // shadows and prevents a hard ring when a caster leaves shadowDistance.
    float distanceRatio = dot(feetPos, feetPos) /
        max(float(SHADOW_DISTANCE * SHADOW_DISTANCE), 1.0);
    float edgeFade = 1.0 - smoothstep(0.82, 1.0, distanceRatio);
    return mix(1.0, visibility, edgeFade);
}

#endif
