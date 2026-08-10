#include "/lib/common.glsl"
#include "/lib/emission.glsl"
uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform float frameTimeCounter;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying vec3 chillWorldPos;
varying float chillEmissionType;
varying float chillEndMaterialType;
/* DRAWBUFFERS:024 */
void main() {
    vec4 albedo = texture2D(gtexture, chillTexCoord) * chillColor;
    if (albedo.a < alphaTestRef) discard;
    vec3 blockLight = texture2D(lightmap, chillLightmap).rgb;
    float upward = max(chillNormal.y, 0.0);
    vec3 voidAmbient = vec3(0.145, 0.105, 0.225) + blockLight * vec3(0.62, 0.47, 0.92) + upward * vec3(0.045, 0.026, 0.085);
    vec3 color = albedo.rgb * voidAmbient;
    float endStonePulse = 0.72 + 0.28 * sin(frameTimeCounter * 0.18);
    vec3 endStoneGlow = albedo.rgb * vec3(0.075, 0.045, 0.105) * endStonePulse;
    color += endStoneGlow * chillEndMaterialType;
    float emissionMask = chillEmissionMask(albedo.rgb, albedo.a, chillEmissionType);
    color = chillEmissiveSurface(color, albedo.rgb, chillEmissionType, emissionMask);
    // Apply End haze in the terrain pass. This avoids a dimension-specific
    // final-pass inverse-matrix reconstruction, whose invalid direction could
    // propagate NaN values and clamp the entire frame to white on Iris.
    float endDistance = length(chillWorldPos);
    float endFog = smoothstep(58.0, 280.0, endDistance) * 0.34 * FOG_DENSITY;
    vec3 endFogColor = vec3(0.105, 0.038, 0.175);
    color = mix(color, endFogColor, chillSaturate(endFog));
    gl_FragData[0] = vec4(color, albedo.a);
    gl_FragData[1] = vec4(0.0);
    gl_FragData[2] = chillEmissionType > 0.5
        ? vec4(chillEmissionColor(chillEmissionType) * emissionMask, emissionMask)
        : vec4(0.0);
}
