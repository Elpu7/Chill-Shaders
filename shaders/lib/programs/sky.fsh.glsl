#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"

uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float rainStrength;
uniform float thunderStrength;
uniform mat4 gbufferModelViewInverse;
uniform int renderStage;
varying vec3 chillWorldDir;
varying vec4 chillColor;

void main() {
#ifdef MC_RENDER_STAGE_STARS
    if (renderStage == MC_RENDER_STAGE_STARS) {
        // Keep Minecraft's own tiny hard-edged star quads, but make every star
        // a clean bright white pixel with no procedural circle or halo.
        float vanillaStar = max(max(chillColor.r, chillColor.g), chillColor.b);
        if (vanillaStar < 0.005) discard;
        float brightness = mix(0.82, 1.00, chillSaturate(vanillaStar * 1.65));
        gl_FragData[0] = vec4(vec3(brightness), chillColor.a);
        return;
    }
#endif

    mat3 viewToWorld = mat3(gbufferModelViewInverse);
    vec3 sunDir = normalize(viewToWorld * sunPosition);
    vec3 upDir = normalize(viewToWorld * upPosition);
    float day = chillDayFactor(sunDir, upDir);
    vec3 viewDir = normalize(chillWorldDir);

    vec3 sky = chillSkyColor(viewDir, sunDir, upDir, rainStrength, thunderStrength, 1.0 - day);

    gl_FragData[0] = vec4(sky, chillColor.a);
}
