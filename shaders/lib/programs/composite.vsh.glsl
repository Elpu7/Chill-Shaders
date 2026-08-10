#include "/lib/common.glsl"
varying vec2 chillTexCoord;
void main() {
    gl_Position = ftransform();
    chillTexCoord = gl_MultiTexCoord0.xy;
}
