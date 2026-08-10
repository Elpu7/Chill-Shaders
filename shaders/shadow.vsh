#version 120
#include "/lib/settings.glsl"
const int shadowMapResolution = SHADOW_RESOLUTION; // [512 1024 2048 4096]
const float shadowDistance = SHADOW_DISTANCE; // [48 72 112 160]
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = 0.0;
// Keep the shadow transform entirely Iris-native. No custom camera-position
// stabilization transform is applied by Chill.
const float shadowIntervalSize = SHADOW_INTERVAL_SIZE;
#include "/lib/programs/shadow.vsh.glsl"
