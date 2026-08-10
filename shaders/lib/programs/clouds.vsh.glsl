#include "/lib/common.glsl"
varying vec2 chillTexCoord;
varying vec4 chillColor;
varying vec3 chillCloudNormal;
void main() {
    vec4 vertex = gl_Vertex;
    gl_Position = gl_ModelViewProjectionMatrix * vertex;
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillColor = gl_Color;
    chillCloudNormal = normalize(gl_NormalMatrix * gl_Normal);
}
