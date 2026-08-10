#version 120
#include "/lib/settings.glsl"
const int shadowMapResolution = SHADOW_RESOLUTION; // [512 1024 2048 4096]
const float shadowDistance = SHADOW_DISTANCE; // [48 72 112 160]
const float shadowDistanceRenderMul = 1.0;
// Match the vertex pass exactly: caster generation and receiver sampling use
// the same unmodified Iris shadow matrix.
const float shadowIntervalSize = SHADOW_INTERVAL_SIZE;
// Raw shadow-map depth is required for stable depth comparisons. Linear depth
// sampling blends blocker depths together and can make shadow fragments pop
// in and out while the camera moves.
const bool shadowtex0Nearest = true;
const bool shadowtex1Nearest = true;
const bool shadowHardwareFiltering = false;
#include "/lib/programs/shadow.fsh.glsl"
