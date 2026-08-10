#include "/lib/common.glsl"

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;

void main() {
    vec4 weather = texture2D(gtexture, chillTexCoord) * chillColor;
    if (weather.a < alphaTestRef) discard;

    // Rain uses a strongly blue vanilla particle texture. Shift it to a pale,
    // rain-coloured grey-blue. The brighter opaque part of the texture is also
    // used by splashes, so impacts read as a light wet sparkle on the ground.
    vec3 sampledLight = texture2D(lightmap, chillLightmap).rgb;
    float lightLevel = chillSaturate(max(max(sampledLight.r, sampledLight.g), sampledLight.b));
    float brightness = mix(0.64, 1.02, lightLevel);
    float luma = chillLuminance(weather.rgb);
    float splash = smoothstep(0.38, 0.90, weather.a);
    vec3 rainTint = vec3(luma) * vec3(0.90, 0.96, 1.00);
    weather.rgb = mix(weather.rgb, rainTint, 0.88) * brightness;
    weather.rgb *= mix(1.00, 1.18, splash);
    weather.a *= mix(0.38, 0.46, splash);

    gl_FragData[0] = weather;
}
