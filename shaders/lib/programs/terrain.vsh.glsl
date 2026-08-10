#include "/lib/common.glsl"
#include "/lib/vegetation.glsl"

attribute vec4 mc_Entity;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
varying vec2 chillTexCoord;
varying vec2 chillLightmap;
varying vec4 chillColor;
varying vec3 chillNormal;
varying vec3 chillPlayerNormal;
varying vec3 chillWorldPos;
varying float chillFoliage;
varying float chillIceType;
varying float chillEmissionType;
varying float chillEndMaterialType;

void main() {
    vec4 vertex = gl_Vertex;
    vec3 worldPos = (gbufferModelViewInverse * gl_ModelViewMatrix * vertex).xyz;
    // Vanilla IDs: grasses/leaves are normally 31 and 18.
    chillFoliage = float(int(mc_Entity.x) == 18 || int(mc_Entity.x) == 31 || int(mc_Entity.x) == 106 || int(mc_Entity.x) == 111 || int(mc_Entity.x) == 161 || int(mc_Entity.x) == 175);
    int materialId = int(mc_Entity.x);
    chillIceType = (materialId == 79 || materialId == 212) ? 1.0 : ((materialId == 174 || materialId == 266) ? 2.0 : 0.0);
    chillEmissionType = (materialId == 10010 || materialId == 10011)
        ? 1.0
        : (materialId == 10012 ? 2.0 : ((materialId == 10021 || materialId == 10022) ? 3.0 : 0.0));
    chillEndMaterialType = materialId == 10020 ? 1.0 : 0.0;
    // Tree leaves must stay aligned with their shadow casters. Keep the gentle
    // animation on grass only; leaf-canopy motion would create moving shadow
    // noise even if the shadow map itself is perfectly stable.
    bool wavingGrass = int(mc_Entity.x) == 31;
    if (wavingGrass) {
        vertex.xz += chillFoliageOffset(worldPos + cameraPosition, frameTimeCounter);
    }

    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * vertex;
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillLightmap = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    chillLightmap = chillLightmap / (30.0 / 32.0) - (1.0 / 32.0);
    chillColor = gl_Color;

    chillNormal = normalize(gl_NormalMatrix * gl_Normal);
    chillPlayerNormal = normalize(mat3(gbufferModelViewInverse) * chillNormal);
    chillWorldPos = worldPos;
}
