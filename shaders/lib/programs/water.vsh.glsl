#include "/lib/common.glsl"
#include "/lib/water.glsl"
attribute vec2 mc_Entity;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillViewPos;
varying vec3 chillWorldPos;
varying float chillIsWater;
varying float chillIceType;
varying vec3 chillSurfaceNormal;
varying float chillEmissionType;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
void main() {
    vec4 vertex = gl_Vertex;
    vec3 originalViewPos = (gl_ModelViewMatrix * vertex).xyz;
    vec3 originalWorldPos = (gbufferModelViewInverse * vec4(originalViewPos, 1.0)).xyz + cameraPosition;
    int materialId = int(mc_Entity.x);
    chillIsWater = (materialId == 8 || materialId == 9) ? 1.0 : 0.0;
    chillIceType = (materialId == 79 || materialId == 212) ? 1.0 : ((materialId == 174 || materialId == 266) ? 2.0 : 0.0);
    chillEmissionType = (materialId == 10010 || materialId == 10011) ? 1.0 : (materialId == 10012 ? 2.0 : 0.0);
    if (chillIsWater > 0.5 && gl_Normal.y > 0.5) {
        vertex.y += chillWaterHeight(originalWorldPos.xz, frameTimeCounter);
    }
    gl_Position = gl_ModelViewProjectionMatrix * vertex;
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    chillLightmap = chillLightmap / (30.0 / 32.0) - (1.0 / 32.0);
    chillColor = gl_Color;
    chillViewPos = (gl_ModelViewMatrix * vertex).xyz;
    chillWorldPos = (gbufferModelViewInverse * vec4(chillViewPos, 1.0)).xyz + cameraPosition;
    chillSurfaceNormal = normalize(mat3(gbufferModelViewInverse) * gl_NormalMatrix * gl_Normal);
}
