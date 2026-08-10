#ifndef CHILL_SETTINGS_GLSL
#define CHILL_SETTINGS_GLSL

// User options. Keep these declarations central so Iris and OptiFine see one
// consistent value in every program that includes this file.
#define SHADOW_RESOLUTION 2048 // [1024 2048 4096] Shadow-map resolution
#define SHADOW_DISTANCE 112 // [48 112 160] Shadow rendering distance in blocks
#define SHADOW_FILTER 2 // [0 1 2 3] Shadow filtering quality
// Iris stabilizes its shadow camera by snapping it to a world-space grid. A
// one-shadow-texel interval makes the map update many times per walked block,
// which looks like a shadow edge vibrating back and forth. Snap only at stable
// two-block boundaries; the deterministic PCF kernel hides the rare transition.
#define SHADOW_INTERVAL_SIZE 2.0
#define EXPOSURE 1.00 // [0.80 0.90 1.00 1.10 1.20] Reserved post-process exposure
#define FOG_DENSITY 1.00 // [0.55 0.75 1.00 1.20 1.30 1.65] Distance-fog density
#define WATER_REFLECTION_STRENGTH 0.50 // [0.00 0.10 0.25 0.35 0.45 0.50 0.60] Water reflection strength
#define FOLIAGE_WAVING 1.00 // [0.00 0.40 0.70 1.00 1.20 1.35] Foliage wind amplitude
#define BLOOM_INTENSITY 0.18 // [0.00 0.08 0.18 0.30 0.45] Bloom intensity
#define WATER_QUALITY 1 // [0 1 2] Water refraction/reflection quality
#define ATMOSPHERE_QUALITY 1 // [0 1 2] Atmospheric quality
#define POST_PROCESSING 1 // [0 1 2] Post-processing quality

#define BLOOM // Enables the restrained post-process bloom
#define FOLIAGE_WIND // Enables vegetation animation
#define WATER_REFLECTIONS // Enables subtle analytic sky reflections on water

#ifdef BLOOM
  #define CHILL_BLOOM_ENABLED 1
#else
  #define CHILL_BLOOM_ENABLED 0
#endif
#ifdef FOLIAGE_WIND
  #define CHILL_WIND_ENABLED 1
#else
  #define CHILL_WIND_ENABLED 0
#endif
#ifdef WATER_REFLECTIONS
  #define CHILL_REFLECTIONS_ENABLED 1
#else
  #define CHILL_REFLECTIONS_ENABLED 0
#endif

#endif
