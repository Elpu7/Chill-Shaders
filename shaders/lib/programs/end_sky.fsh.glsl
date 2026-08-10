#include "/lib/common.glsl"
uniform float frameTimeCounter;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform float viewWidth;
uniform float viewHeight;
varying vec3 chillWorldDir;

#ifdef CHILL_END_SKY_TEXTURED
uniform sampler2D gtexture;
uniform float endFlashIntensity;
uniform float previousEndFlashIntensity;
varying vec2 chillTexCoord;
varying float chillSmallCelestialQuad;
#endif

vec3 chillEndScreenDirection() {
    // Reconstruct one direction from the actual screen pixel. Both Minecraft
    // End-sky draw calls then sample exactly the same point in procedural
    // space, so the cube covers the complete view without revealing a face.
    vec2 viewport = max(vec2(viewWidth, viewHeight), vec2(1.0));
    vec2 screenUv = gl_FragCoord.xy / viewport;
    vec2 ndc = screenUv * 2.0 - 1.0;
    vec4 viewPosition = gbufferProjectionInverse * vec4(ndc, 1.0, 1.0);
    vec3 viewDirection = normalize(viewPosition.xyz / max(abs(viewPosition.w), 0.0001));
    return normalize(mat3(gbufferModelViewInverse) * viewDirection);
}

float chillEndHash(vec3 position) {
    return chillHash3D(position);
}

float chillEndNoise(vec3 position) {
    vec3 cell = floor(position);
    vec3 local = fract(position);
    local = local * local * (3.0 - 2.0 * local);
    float n000 = chillEndHash(cell + vec3(0.0, 0.0, 0.0));
    float n100 = chillEndHash(cell + vec3(1.0, 0.0, 0.0));
    float n010 = chillEndHash(cell + vec3(0.0, 1.0, 0.0));
    float n110 = chillEndHash(cell + vec3(1.0, 1.0, 0.0));
    float n001 = chillEndHash(cell + vec3(0.0, 0.0, 1.0));
    float n101 = chillEndHash(cell + vec3(1.0, 0.0, 1.0));
    float n011 = chillEndHash(cell + vec3(0.0, 1.0, 1.0));
    float n111 = chillEndHash(cell + vec3(1.0, 1.0, 1.0));
    float lower = mix(mix(n000, n100, local.x), mix(n010, n110, local.x), local.y);
    float upper = mix(mix(n001, n101, local.x), mix(n011, n111, local.x), local.y);
    return mix(lower, upper, local.z);
}

float chillEndNebula(vec3 direction, float time) {
    vec3 position = direction * 3.4 + vec3(time * 0.006, -time * 0.0035, time * 0.0045);
    float firstOctave = chillEndNoise(position);
#if ATMOSPHERE_QUALITY == 0
    return firstOctave;
#elif ATMOSPHERE_QUALITY == 1
    position = position * 2.03 + vec3(11.7, 4.2, 8.9);
    return firstOctave * 0.68 + chillEndNoise(position) * 0.32;
#else
    position = position * 2.03 + vec3(11.7, 4.2, 8.9);
    float noiseValue = firstOctave * 0.56 + chillEndNoise(position) * 0.29;
    position = position * 2.01 + vec3(3.4, 17.2, 5.8);
    noiseValue += chillEndNoise(position) * 0.15;
    return noiseValue;
#endif
}

float chillEndStars(vec3 direction, float scale, float threshold, float time) {
    vec3 starPosition = direction * scale;
    vec3 cell = floor(starPosition);
    vec3 local = fract(starPosition) - 0.5;
    float randomValue = chillEndHash(cell);
    float starPoint = 1.0 - smoothstep(0.025, 0.115, length(local));
    float starExists = smoothstep(threshold, 1.0, randomValue);
    float twinkle = 0.78 + 0.22 * sin(time * 0.62 + randomValue * 19.0);
    return starPoint * starExists * twinkle;
}

void main() {
#ifdef CHILL_END_SKY_TEXTURED
    // Minecraft 26.2 draws the periodic End flash through the same textured
    // sky program as the End cube. The vertex shader marks the flash from its
    // local ±1 geometry and the cube from its ±100 geometry. This value is
    // constant across each primitive and therefore independent of camera
    // angle, resolution, FOV, atlas layout, and texture filtering.
    float flashStrength = chillSaturate(max(endFlashIntensity, previousEndFlashIntensity));
    float isEndFlash = step(0.5, chillSmallCelestialQuad);

    if (isEndFlash > 0.5) {
        // Never let an inactive or between-ticks celestial quad fall through
        // to the opaque procedural sky path.
        if (flashStrength < 0.0001) discard;

        vec3 flashTexture = texture2D(gtexture, chillTexCoord).rgb;
        float flashMask = max(max(flashTexture.r, flashTexture.g), flashTexture.b);
        float softHalo = smoothstep(0.006, 0.30, flashMask);
        float brightCore = smoothstep(0.20, 0.70, flashMask);
        float flashAlpha = softHalo * flashStrength * mix(0.40, 0.68, brightCore);

        // The texture itself supplies the round falloff. Discarding its black
        // border guarantees that the underlying celestial quad can never be
        // seen, even when it rotates against a brighter part of the nebula.
        if (flashAlpha < 0.002) discard;

        vec3 haloColor = mix(
            vec3(0.28, 0.14, 0.44),
            vec3(0.62, 0.38, 0.79),
            brightCore
        );
        // This writes only the visible sky color. No emission data or terrain
        // lighting is produced, so the flash does not illuminate the world.
        gl_FragData[0] = vec4(haloColor, flashAlpha);
        return;
    }
#endif

    vec3 reconstructedDirection = chillEndScreenDirection();
    float reconstructedLength = length(reconstructedDirection);
    float varyingLength = length(chillWorldDir);
    vec3 direction = reconstructedLength > 0.0001
        ? reconstructedDirection / reconstructedLength
        : (varyingLength > 0.0001 ? chillWorldDir / varyingLength : vec3(0.0, 1.0, 0.0));
    float time = frameTimeCounter;
    float height = clamp(abs(direction.y), 0.0, 1.0);

    // The upper sky remains one uniform space color. The fog below uses one
    // continuous spherical field, so it surrounds the complete horizon
    // instead of collecting into a single bright patch.
    vec3 deepSpace = vec3(0.085, 0.055, 0.135);
    vec3 fogColor = vec3(0.540, 0.350, 0.660);
    vec3 fogPosition = direction * vec3(2.35, 0.70, 2.35)
        + vec3(time * 0.0010, -time * 0.0005, 9.4 + time * 0.0008);
#if ATMOSPHERE_QUALITY == 0
    float fogDetail = 0.50;
    float fogNoise = 0.50;
#elif ATMOSPHERE_QUALITY == 1
    float fogDetail = chillEndNoise(fogPosition);
    float fogNoise = fogDetail;
#else
    float fogLarge = chillEndNoise(fogPosition);
    float fogDetail = chillEndNoise(fogPosition * 2.07 + vec3(5.1, 13.7, 2.8));
    float fogNoise = fogLarge * 0.72 + fogDetail * 0.28;
#endif

    // A low-density exponential falloff replaces the thick horizon band.
    // It spreads the mist much farther vertically while remaining thin and
    // continuous, with no distinct edge that could look like another layer.
    float verticalFog = exp2(-height * 3.00);
    float fogDensity = chillSaturate(verticalFog * (0.25 + fogNoise * 0.09));
    vec3 color = mix(deepSpace, fogColor, fogDensity);
    float softWisps = verticalFog * (fogDetail - 0.5);
    color += vec3(0.080, 0.044, 0.105) * softWisps * 0.10;

    // Three sparse scales keep the stars pixel-small while making the field
    // richer like the reference sky. They stay neutral white, not circles.
    float fineStars = chillEndStars(direction, 255.0, 0.930, time);
    float brightStars = chillEndStars(direction, 132.0, 0.984, time + 7.0);
#if ATMOSPHERE_QUALITY > 0
    float dustStars = chillEndStars(direction, 410.0, 0.880, time + 3.0);
    color += vec3(0.82, 0.82, 0.90) * dustStars * 0.28;
#endif
    color += vec3(0.92, 0.91, 1.00) * fineStars * 0.60;
    color += vec3(1.00, 0.98, 1.00) * brightStars * 0.92;
    gl_FragData[0] = vec4(chillSaturate(color), 1.0);
}
