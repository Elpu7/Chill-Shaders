#version 120

#include "/lib/settings.glsl"

// Alpha-cutout casters use exactly the same light-camera configuration as
// opaque casters. Foliage is deliberately static in the shadow pass: animated
// casters create obvious temporal popping when the player moves.
const int shadowMapResolution = SHADOW_RESOLUTION;
const float shadowDistance = SHADOW_DISTANCE;
const float shadowDistanceRenderMul = 1.0;
const float sunPathRotation = 0.0;
const float shadowIntervalSize = SHADOW_INTERVAL_SIZE;

#include "/lib/programs/shadow.vsh.glsl"
