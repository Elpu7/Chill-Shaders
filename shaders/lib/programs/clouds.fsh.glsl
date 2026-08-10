#include "/lib/common.glsl"
uniform sampler2D gtexture;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float thunderStrength;
varying vec2 chillTexCoord;
varying vec4 chillColor;
varying vec3 chillCloudNormal;
/* DRAWBUFFERS:034 */
void main() {
    // Scale the cloud-mask filter with the selected atmosphere quality. Potato
    // keeps one vanilla sample, Chill rounds the cardinal edges with five, and
    // High retains the full nine-tap rounded mask.
    const float cloudTexel = 1.75 / 256.0;
    vec2 texel = vec2(cloudTexel);
#if ATMOSPHERE_QUALITY == 0
    float softAlpha = texture2D(gtexture, chillTexCoord).a;
#else
    float softAlpha = texture2D(gtexture, chillTexCoord).a * 0.25;
    softAlpha += texture2D(gtexture, chillTexCoord + vec2(texel.x, 0.0)).a * 0.125;
    softAlpha += texture2D(gtexture, chillTexCoord - vec2(texel.x, 0.0)).a * 0.125;
    softAlpha += texture2D(gtexture, chillTexCoord + vec2(0.0, texel.y)).a * 0.125;
    softAlpha += texture2D(gtexture, chillTexCoord - vec2(0.0, texel.y)).a * 0.125;
#if ATMOSPHERE_QUALITY == 1
    softAlpha *= 1.3333333;
#else
    softAlpha += texture2D(gtexture, chillTexCoord + vec2(texel.x, texel.y)).a * 0.0625;
    softAlpha += texture2D(gtexture, chillTexCoord + vec2(-texel.x, texel.y)).a * 0.0625;
    softAlpha += texture2D(gtexture, chillTexCoord + vec2(texel.x, -texel.y)).a * 0.0625;
    softAlpha += texture2D(gtexture, chillTexCoord - texel).a * 0.0625;
#endif
#endif
    softAlpha *= chillColor.a;

    vec3 normal = normalize(chillCloudNormal);
    vec3 sunDir = normalize(sunPosition);
    vec3 upDir = normalize(upPosition);
    float topFacing = abs(dot(normal, upDir));
    float roundedShape = smoothstep(0.075, 0.84, softAlpha);
    float faceOpacity = mix(0.52, 0.72, smoothstep(0.10, 0.86, topFacing));
    float weatherStrength = max(rainStrength, thunderStrength);
    float alpha = roundedShape * faceOpacity * mix(1.0, 1.16, weatherStrength);
    if (alpha < 0.008) discard;

    float day = chillDayFactor(sunDir, upDir);
    float sunset = chillSunsetFactor(sunDir, upDir) * (1.0 - rainStrength * 0.88) * (1.0 - thunderStrength);
    float directLight = max(dot(normal, sunDir), 0.0) * day;
    float illumination = 0.28 + topFacing * 0.28 + directLight * 0.44;

    // Clear weather: neutral white in daylight, warm at sunrise/sunset and
    // dim blue-grey under moonlight.
    vec3 clearDay = mix(vec3(0.68, 0.72, 0.78), vec3(1.00, 1.00, 0.995), illumination);
    vec3 clearNight = mix(vec3(0.025, 0.035, 0.060), vec3(0.130, 0.150, 0.205), illumination);
    vec3 clearCloud = mix(clearNight, clearDay, day);
    vec3 twilightShade = vec3(0.30, 0.235, 0.255);
    vec3 twilightBright = vec3(0.88, 0.56, 0.39);
    vec3 twilightCloud = mix(twilightShade, twilightBright, illumination);
    clearCloud = mix(clearCloud, twilightCloud, sunset * 0.62);

    // Rain uses a substantially darker neutral palette at both day and night.
    vec3 rainyDay = mix(vec3(0.22, 0.255, 0.295), vec3(0.57, 0.60, 0.63), illumination);
    vec3 rainyNight = mix(vec3(0.012, 0.018, 0.028), vec3(0.065, 0.075, 0.095), illumination);
    vec3 rainyCloud = mix(rainyNight, rainyDay, day);

    // Thunderstorms darken even sun-facing tops, leaving only restrained
    // directional shading so the cloud mass remains three-dimensional.
    vec3 thunderDay = mix(vec3(0.060, 0.075, 0.095), vec3(0.245, 0.270, 0.300), illumination);
    vec3 thunderNight = mix(vec3(0.004, 0.007, 0.013), vec3(0.026, 0.032, 0.044), illumination);
    vec3 thunderCloud = mix(thunderNight, thunderDay, day);

    vec3 cloudColor = mix(clearCloud, rainyCloud, rainStrength * 0.92);
    cloudColor = mix(cloudColor, thunderCloud, thunderStrength * 0.97);
    gl_FragData[0] = vec4(cloudColor, alpha);
    // Preserve cloud coverage independently from visible colour. Composite
    // uses this mask to stop water reflections from being applied over clouds.
    gl_FragData[1] = vec4(vec3(alpha), 1.0);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, alpha);
}
