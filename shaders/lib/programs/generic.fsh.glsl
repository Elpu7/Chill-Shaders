#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform float frameTimeCounter;
#ifdef CHILL_BLOCK_ENTITY
uniform int blockEntityId;
#endif
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;

mat2 chillPortalRotation(float angle) {
    float cosine = cos(angle);
    float sine = sin(angle);
    return mat2(cosine, -sine, sine, cosine);
}

float chillPortalStar(vec2 centeredUv, float scale, float rotation, vec2 drift) {
    vec2 coordinate = chillPortalRotation(rotation) * centeredUv * scale + 0.5 + drift;
    vec3 source = texture2D(gtexture, fract(coordinate)).rgb;
    // Brighten the original texture's dim blue pixels without inventing a new
    // star mask. A sub-linear response also reveals its finer vanilla detail.
    return pow(chillSaturate(max(max(source.r, source.g), source.b)), 0.62);
}

vec3 chillVanillaPortal(vec2 uv, float time) {
    vec2 centeredUv = uv - 0.5;
    float layer0 = chillPortalStar(centeredUv, 1.00,  0.00, vec2( 0.000,  time * 0.010));
    float layer1 = chillPortalStar(centeredUv, 1.55,  0.38, vec2( time * 0.006, -time * 0.008));
    float layer2 = chillPortalStar(centeredUv, 2.20, -0.51, vec2(-time * 0.008,  time * 0.004));
    float layer3 = chillPortalStar(centeredUv, 3.10,  0.82, vec2( time * 0.011,  time * 0.006));
    float layer4 = chillPortalStar(centeredUv, 4.35, -0.24, vec2(-time * 0.014, -time * 0.007));
    float layer5 = chillPortalStar(centeredUv, 5.80,  1.17, vec2( time * 0.018, -time * 0.010));

    vec3 portal = vec3(0.0025, 0.0070, 0.0120);
    portal += layer0 * vec3(0.16, 0.34, 0.52) * 0.58;
    portal += layer1 * vec3(0.08, 0.52, 0.58) * 0.42;
    portal += layer2 * vec3(0.20, 0.40, 0.78) * 0.34;
    portal += layer3 * vec3(0.10, 0.62, 0.48) * 0.25;
    portal += layer4 * vec3(0.28, 0.48, 0.86) * 0.19;
    portal += layer5 * vec3(0.16, 0.72, 0.76) * 0.14;
    return min(portal, vec3(0.72, 0.92, 1.0));
}

void main() {
    vec4 sampledTexture = texture2D(gtexture, chillTexCoord);
    vec4 color = sampledTexture * chillColor;
    if (color.a < alphaTestRef) discard;
#ifdef CHILL_FORCE_OPAQUE
    // First-person hands and held objects are solid scene geometry. Their
    // surviving texels must replace the Nether scene instead of alpha-blending
    // lava and fire back through the model.
    color.a = 1.0;
#endif
#ifdef CHILL_BLOCK_ENTITY
    // End portals and gateways are composed by Minecraft from several
    // animated, tinted texture layers. Preserve that vanilla composition
    // exactly; applying the ordinary block-entity lightmap here makes most
    // layers nearly black and leaves only a few dim stars visible.
    if (blockEntityId == 10022) {
        // Rebuild Minecraft's layered portal using only its original animated
        // star texture. This keeps the vanilla material while compensating for
        // modern Iris exposing only a sparse, almost-black layer to this pass.
        gl_FragData[0] = vec4(chillVanillaPortal(chillTexCoord, frameTimeCounter), max(color.a, sampledTexture.a));
        return;
    }
#endif
    color.rgb *= 0.48 + texture2D(lightmap, chillLightmap).rgb * 0.42;
    gl_FragData[0] = color;
#ifdef CHILL_OCCLUDE_SCENE_DATA
    // The hand pass happens after terrain. Clear water/material metadata and
    // mark the pixel as an opaque emission occluder so the final glow filter
    // cannot reconstruct lava or fire across the hand silhouette.
    gl_FragData[1] = vec4(0.0);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
#endif
}
