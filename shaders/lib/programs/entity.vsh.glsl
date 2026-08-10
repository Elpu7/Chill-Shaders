#include "/lib/common.glsl"

uniform mat4 gbufferModelViewInverse;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying vec3 chillPlayerNormal;
varying vec3 chillWorldPos;

void main() {
    gl_Position = ftransform();
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    chillLightmap = chillLightmap / (30.0 / 32.0) - (1.0 / 32.0);
    chillColor = gl_Color;

    chillNormal = normalize(gl_NormalMatrix * gl_Normal);
    chillPlayerNormal = normalize(mat3(gbufferModelViewInverse) * chillNormal);
    chillWorldPos = (gbufferModelViewInverse * gl_ModelViewMatrix * gl_Vertex).xyz;
}
