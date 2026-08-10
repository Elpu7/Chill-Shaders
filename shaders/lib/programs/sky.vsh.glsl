#include "/lib/common.glsl"
uniform mat4 gbufferModelViewInverse;
varying vec3 chillWorldDir;
varying vec2 chillTexCoord;
varying vec4 chillColor;
varying float chillSmallCelestialQuad;
void main() {
    gl_Position = ftransform();
    // Derive the sky direction in the same view-space basis as Iris' sun/moon
    // uniforms so the celestial bodies stay fixed in the world instead of
    // drifting with camera movement.
    vec3 rawViewDir = (gl_ModelViewMatrix * gl_Vertex).xyz;
    float viewLength = max(length(rawViewDir), 0.0001);
    vec3 viewDir = rawViewDir / viewLength;
    // Remove the camera rotation before the procedural sky is sampled. A
    // direction-only world vector behaves like a true skybox: it stays fixed
    // while the player turns or moves and has no reachable world geometry.
    vec3 rawWorldDir = mat3(gbufferModelViewInverse) * viewDir;
    float worldLength = max(length(rawWorldDir), 0.0001);
    chillWorldDir = rawWorldDir / worldLength;
    chillTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    chillColor = gl_Color;
    // while every End-sky cube vertex is (±100, ±100, ±100). All four flash
    // vertices therefore receive exactly 1 and all cube vertices exactly 0;
    // interpolation cannot turn only part of the quad into the wrong path.
    float localExtent = max(max(abs(gl_Vertex.x), abs(gl_Vertex.y)), abs(gl_Vertex.z));
    chillSmallCelestialQuad = 1.0 - step(10.0, localExtent);
}
