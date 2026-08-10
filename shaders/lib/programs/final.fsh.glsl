#include "/lib/common.glsl"
#include "/lib/post.glsl"
#include "/lib/nether.glsl"
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform int isEyeInWater;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float far;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 fogColor;
uniform float rainStrength;
uniform float chillNetherWastes;
uniform float chillCrimsonForest;
uniform float chillWarpedForest;
uniform float chillBasaltDeltas;
uniform float chillSoulValley;
varying vec2 chillTexCoord;

vec3 chillEmissionSample(vec2 uv) {
    return texture2D(colortex4, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

vec3 chillEmissionGlow(vec2 uv) {
    vec2 pixel = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec4 centreData = texture2D(colortex4, clamp(uv, vec2(0.001), vec2(0.999)));
    vec3 glow = centreData.rgb * 0.38;
#if POST_PROCESSING > 0
    // Balanced uses only the four cardinal neighbours. High adds diagonal and
    // wider taps; Potato bypasses this full-screen glow function entirely.
    vec2 nearOffset = pixel * 1.75;
    glow += chillEmissionSample(uv + vec2( nearOffset.x, 0.0)) * 0.090;
    glow += chillEmissionSample(uv + vec2(-nearOffset.x, 0.0)) * 0.090;
    glow += chillEmissionSample(uv + vec2(0.0,  nearOffset.y)) * 0.090;
    glow += chillEmissionSample(uv + vec2(0.0, -nearOffset.y)) * 0.090;
#if POST_PROCESSING > 1
    glow += chillEmissionSample(uv + vec2( nearOffset.x,  nearOffset.y)) * 0.042;
    glow += chillEmissionSample(uv + vec2(-nearOffset.x,  nearOffset.y)) * 0.042;
    glow += chillEmissionSample(uv + vec2( nearOffset.x, -nearOffset.y)) * 0.042;
    glow += chillEmissionSample(uv + vec2(-nearOffset.x, -nearOffset.y)) * 0.042;

    vec2 softOffset = pixel * 4.25;
    glow += chillEmissionSample(uv + vec2( softOffset.x, 0.0)) * 0.022;
    glow += chillEmissionSample(uv + vec2(-softOffset.x, 0.0)) * 0.022;
    glow += chillEmissionSample(uv + vec2(0.0,  softOffset.y)) * 0.022;
    glow += chillEmissionSample(uv + vec2(0.0, -softOffset.y)) * 0.022;
#endif
#endif
    glow *= 0.44;
    // Solid entities and the first-person hand write alpha 1 with no emission.
    // Do not let neighbouring glow taps paint the terrain behind them back over
    // their silhouettes. Actual emitters keep non-zero RGB and still bloom.
    float centreEmission = max(max(centreData.r, centreData.g), centreData.b);
    float opaqueOccluder = step(0.995, centreData.a) * (1.0 - step(0.0001, centreEmission));
    return mix(glow, vec3(0.0), opaqueOccluder);
}

vec3 chillFinalViewPosition(vec2 uv, float depth) {
    vec4 clipPosition = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPosition = gbufferProjectionInverse * clipPosition;
    return viewPosition.xyz / max(viewPosition.w, 0.0001);
}

float chillNetherHash(vec3 cell) {
    return chillHash3D(cell);
}

float chillNetherValueNoise(vec3 position) {
    vec3 cell = floor(position);
    vec3 local = fract(position);
    local = local * local * (3.0 - 2.0 * local);

    float n000 = chillNetherHash(cell + vec3(0.0, 0.0, 0.0));
    float n100 = chillNetherHash(cell + vec3(1.0, 0.0, 0.0));
    float n010 = chillNetherHash(cell + vec3(0.0, 1.0, 0.0));
    float n110 = chillNetherHash(cell + vec3(1.0, 1.0, 0.0));
    float n001 = chillNetherHash(cell + vec3(0.0, 0.0, 1.0));
    float n101 = chillNetherHash(cell + vec3(1.0, 0.0, 1.0));
    float n011 = chillNetherHash(cell + vec3(0.0, 1.0, 1.0));
    float n111 = chillNetherHash(cell + vec3(1.0, 1.0, 1.0));

    float lower = mix(mix(n000, n100, local.x), mix(n010, n110, local.x), local.y);
    float upper = mix(mix(n001, n101, local.x), mix(n011, n111, local.x), local.y);
    return mix(lower, upper, local.z);
}

float chillNetherSteam(vec3 worldPosition, float time) {
#if ATMOSPHERE_QUALITY == 0
    // Potato keeps a uniform low-cost haze; no 3D value-noise evaluations.
    return 0.50;
#else
    // Two slowly drifting, differently scaled volumes give the fog broad,
    // irregular variation without a repeating screen-space texture.
    vec3 p = mod(worldPosition, 4096.0) * vec3(0.010, 0.016, 0.010);
    p += vec3(time * 0.004, time * 0.010, -time * 0.003);
    float broad = chillNetherValueNoise(p);
#if ATMOSPHERE_QUALITY == 1
    return smoothstep(0.18, 0.82, broad);
#else
    float detail = chillNetherValueNoise(p * 2.07 + vec3(17.3, 5.1, 29.7));
    float vapour = broad * 0.72 + detail * 0.28;
    return smoothstep(0.18, 0.82, vapour);
#endif
#endif
}

vec3 chillUnderwaterDistanceBlur(vec2 uv, float amount) {
    vec2 pixel = vec2(1.0 / max(viewWidth, 1.0), 1.0 / max(viewHeight, 1.0));
    vec3 centre = texture2D(colortex1, uv).rgb;
    vec3 blurred = centre * 0.5;
    blurred += texture2D(colortex1, uv + vec2(pixel.x, 0.0)).rgb;
    blurred += texture2D(colortex1, uv - vec2(pixel.x, 0.0)).rgb;
    blurred += texture2D(colortex1, uv + vec2(0.0, pixel.y)).rgb;
    blurred += texture2D(colortex1, uv - vec2(0.0, pixel.y)).rgb;
    return mix(centre, blurred / 4.5, amount);
}
void main() {
    vec3 color = texture2D(colortex1, chillTexCoord).rgb;
#if POST_PROCESSING == 2
    color += chillBloom(colortex1, chillTexCoord) * 0.35;
#endif
    // Add radiance before medium and distance fog. This lets lava and Nether
    // vapour attenuate the halo together with its source instead of revealing
    // sharp, unfogged copies through the fog.
#if POST_PROCESSING > 0
    color += chillEmissionGlow(chillTexCoord);
#endif
    if (isEyeInWater == 1) {
        float depth = texture2D(depthtex0, chillTexCoord).r;
        float viewDistance = depth < 0.9999
            ? length(chillFinalViewPosition(chillTexCoord, depth))
            : far;

        // Smoothed eye light approximates the illumination that reaches the
        // water surface above the camera. Open daytime water stays clearer and
        // brighter; moonlit, rainy and cave water becomes denser and darker.
        float skyAccess = chillSaturate(float(eyeBrightnessSmooth.y) / 240.0);
        float blockLight = chillSaturate(float(eyeBrightnessSmooth.x) / 240.0);
        float day = chillDayFactor(normalize(sunPosition), normalize(upPosition));
        float daylightAtSurface = skyAccess * mix(0.10, 1.0, day) * (1.0 - rainStrength * 0.38);
        float surfaceLight = chillSaturate(max(daylightAtSurface, blockLight * 0.76));
        float exposureResponse = chillSaturate((EXPOSURE - 0.80) / 0.40);
        float visibleLight = chillSaturate(surfaceLight * mix(0.86, 1.12, exposureResponse));

#if WATER_QUALITY > 0
        float blurAmount = smoothstep(8.0, 52.0, viewDistance) * mix(0.38, 0.27, visibleLight);
        color = chillUnderwaterDistanceBlur(chillTexCoord, blurAmount);
#endif

        // Warm wavelengths attenuate first. Available surface light and the
        // exposure setting control both perceived visibility and scattering.
        float density = mix(0.036, 0.021, visibleLight) * FOG_DENSITY;
        density *= mix(1.08, 0.92, exposureResponse);
        vec3 extinction = mix(vec3(0.034, 0.019, 0.012), vec3(0.022, 0.012, 0.007), visibleLight);
        vec3 transmission = exp(-viewDistance * FOG_DENSITY * extinction);
        color *= mix(vec3(1.0), transmission, mix(0.58, 0.42, visibleLight));

        float waterFog = 1.0 - exp(-viewDistance * density);
        vec3 darkNearFog = vec3(0.018, 0.090, 0.135);
        vec3 darkFarFog = vec3(0.006, 0.030, 0.055);
        vec3 dayNearFog = vec3(0.105, 0.345, 0.425);
        vec3 dayFarFog = vec3(0.030, 0.155, 0.215);
        vec3 nearFog = mix(darkNearFog, dayNearFog, visibleLight);
        vec3 farFog = mix(darkFarFog, dayFarFog, visibleLight);
        float fogExposure = mix(0.84, 1.16, exposureResponse);
        nearFog *= fogExposure;
        farFog *= fogExposure;
        nearFog += vec3(0.025, 0.016, 0.004) * blockLight;
        vec3 waterFogColor = mix(nearFog, farFog, smoothstep(18.0, 88.0, viewDistance));
        color = mix(color, waterFogColor, chillSaturate(waterFog * mix(0.96, 0.88, visibleLight)));
    } else if (isEyeInWater == 2) {
        // Vanilla-style lava fog: only active while the camera is submerged.
        // Visibility falls off within a few blocks and settles into a deep,
        // warm orange instead of exposing the entire cave through the lava.
        float lavaDepth = texture2D(depthtex0, chillTexCoord).r;
        float lavaDistance = lavaDepth < 0.9999
            ? length(chillFinalViewPosition(chillTexCoord, lavaDepth))
            : far;
        float lavaFog = 1.0 - exp(-lavaDistance * 0.48);
        vec3 lavaTintedScene = color * vec3(1.16, 0.40, 0.075) + vec3(0.055, 0.006, 0.0);
        vec3 lavaFogColor = vec3(0.44, 0.052, 0.003);
        color = mix(lavaTintedScene, lavaFogColor, chillSaturate(lavaFog));
    } else {
        // Detect the Nether through smooth biome uniforms in every dimension.
        // Applying this in final guarantees that entities, particles, liquids
        // and terrain all receive the same fog even if a dimension-specific
        // composite program is skipped by the current Iris renderer.
        float netherWeight = chillNetherWastes + chillCrimsonForest + chillWarpedForest
                           + chillBasaltDeltas + chillSoulValley;
#ifdef CHILL_FORCE_NETHER
        netherWeight = max(netherWeight, 1.0);
#endif
        if (netherWeight > 0.001) {
            float netherDepth = texture2D(depthtex0, chillTexCoord).r;
            vec3 netherViewPosition = chillFinalViewPosition(chillTexCoord, min(netherDepth, 0.99999));
            float netherDistance = netherDepth < 0.9999 ? length(netherViewPosition) : far;
            float netherFogAmount = 1.0 - exp(-max(netherDistance - 5.0, 0.0) * 0.018 * FOG_DENSITY);
            vec3 netherWorldPosition = (gbufferModelViewInverse * vec4(netherViewPosition, 1.0)).xyz + cameraPosition;
            float steam = chillNetherSteam(netherWorldPosition, frameTimeCounter);
            // Keep vapour visible through the middle distance, then remove its
            // contrast from fully saturated far fog. This prevents the far
            // plane from turning the volume into a full-screen pattern.
            float steamVisibility = smoothstep(10.0, 34.0, netherDistance)
                                  * (1.0 - smoothstep(64.0, 128.0, netherDistance));
            steamVisibility *= 1.0 - step(0.9999, netherDepth);
            steam = mix(0.50, steam, steamVisibility);
            netherFogAmount *= mix(0.82, 1.14, steam);
            netherFogAmount = min(netherFogAmount, 0.92);
            vec3 netherFogColor = chillNetherBiomeFog(
                fogColor,
                chillNetherWastes,
                chillCrimsonForest,
                chillWarpedForest,
                chillBasaltDeltas,
                chillSoulValley
            );
            vec3 steamColor = netherFogColor * vec3(1.18, 1.12, 1.08) + vec3(0.010, 0.008, 0.007);
            netherFogColor = mix(netherFogColor, steamColor, steam * steamVisibility * 0.24);
            color = mix(color, netherFogColor, netherFogAmount);
        }
    }
    // colortex data is already displayed in Minecraft's expected range.
    // Applying HDR tone mapping here washed out all vanilla materials.
    gl_FragColor = vec4(chillSaturate(color), 1.0);
}
