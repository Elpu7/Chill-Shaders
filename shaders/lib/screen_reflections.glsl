#ifndef CHILL_SCREEN_REFLECTIONS_GLSL
#define CHILL_SCREEN_REFLECTIONS_GLSL

vec2 chillReflectionProject(vec3 viewPosition) {
    vec4 clipPosition = gbufferProjection * vec4(viewPosition, 1.0);
    if (clipPosition.w <= 0.0001) return vec2(-2.0);
    return clipPosition.xy / clipPosition.w * 0.5 + 0.5;
}

float chillReflectionEdgeFade(vec2 uv) {
    vec2 edgeDistance = min(uv, vec2(1.0) - uv);
    return smoothstep(0.008, 0.085, min(edgeDistance.x, edgeDistance.y));
}

vec3 chillReflectionColor(vec2 uv, float radius) {
    vec2 pixelSize = vec2(
        1.0 / max(viewWidth, 1.0),
        1.0 / max(viewHeight, 1.0)
    ) * radius;
    vec2 diagonal = pixelSize * 0.72;
    vec3 center = texture2D(colortex0, uv).rgb * 0.50;
    center += texture2D(colortex0, uv + vec2( diagonal.x,  diagonal.y)).rgb * 0.125;
    center += texture2D(colortex0, uv + vec2(-diagonal.x,  diagonal.y)).rgb * 0.125;
    center += texture2D(colortex0, uv + vec2( diagonal.x, -diagonal.y)).rgb * 0.125;
    center += texture2D(colortex0, uv + vec2(-diagonal.x, -diagonal.y)).rgb * 0.125;
    return center;
}

vec4 chillTraceScreenReflection(
    float surfaceDepth,
    vec3 surfaceNormal,
    vec3 surfaceViewPosition,
    float blurRadius
) {
    vec3 eyeRay = normalize(surfaceViewPosition);
    vec3 reflectedRay = normalize(reflect(eyeRay, surfaceNormal));
    if (reflectedRay.z >= -0.035) return vec4(0.0);

    const int maximumSteps = WATER_QUALITY == 2 ? 20 : 12;
    const int correctionSteps = WATER_QUALITY == 2 ? 3 : 2;
    float travel = max(0.55, -surfaceViewPosition.z * 0.0018);
    float stride = travel;
    vec3 frontPoint = surfaceViewPosition;
    vec2 frontUv = chillReflectionProject(surfaceViewPosition);
    float frontGap = 0.0;
    bool hasFrontSample = false;
    vec3 surfaceWorldPosition = (gbufferModelViewInverse * vec4(surfaceViewPosition, 1.0)).xyz;

    for (int stepIndex = 0; stepIndex < 20; ++stepIndex) {
        if (stepIndex >= maximumSteps) break;

        vec3 testPoint = surfaceViewPosition + reflectedRay * travel;
        vec2 testUv = chillReflectionProject(testPoint);
        if (testUv.x <= 0.0 || testUv.x >= 1.0 || testUv.y <= 0.0 || testUv.y >= 1.0) break;

        float sceneDepth = texture2D(depthtex1, testUv).x;
        if (sceneDepth < 0.999999) {
            vec3 scenePoint = chillViewPositionFromDepth(testUv, sceneDepth);
            float gap = testPoint.z - scenePoint.z;
            float screenStep = length(testUv - frontUv);
            float allowedGap = 0.16 + min(-scenePoint.z * 0.0018, 0.62);

            if (hasFrontSample && gap <= 0.0 && frontGap > 0.0 &&
                gap > -allowedGap && screenStep < 0.11) {
                vec3 nearPoint = frontPoint;
                vec3 farPoint = testPoint;
                vec2 hitUv = testUv;
                float hitDepth = sceneDepth;
                bool validHit = true;

                for (int correctionIndex = 0; correctionIndex < 3; ++correctionIndex) {
                    if (correctionIndex >= correctionSteps) break;
                    vec3 middlePoint = mix(nearPoint, farPoint, 0.5);
                    vec2 middleUv = chillReflectionProject(middlePoint);
                    if (middleUv.x <= 0.0 || middleUv.x >= 1.0 ||
                        middleUv.y <= 0.0 || middleUv.y >= 1.0) {
                        validHit = false;
                        break;
                    }
                    float middleDepth = texture2D(depthtex1, middleUv).x;
                    if (middleDepth >= 0.999999) {
                        validHit = false;
                        break;
                    }
                    vec3 middleScene = chillViewPositionFromDepth(middleUv, middleDepth);
                    float middleGap = middlePoint.z - middleScene.z;
                    if (middleGap > 0.0) {
                        nearPoint = middlePoint;
                    } else {
                        farPoint = middlePoint;
                        hitUv = middleUv;
                        hitDepth = middleDepth;
                    }
                }

                if (!validHit) return vec4(0.0);
                vec3 hitScenePoint = chillViewPositionFromDepth(hitUv, hitDepth);
                float finalGap = abs(farPoint.z - hitScenePoint.z);
                float finalThickness = 0.10 + min(-hitScenePoint.z * 0.0015, 0.48);
                if (finalGap > finalThickness) return vec4(0.0);

                // An above-water reflection may only use geometry on or above
                // the water plane. This rejects the lake floor that otherwise
                // appears as long dark strips across shallow water. From below,
                // use the inverse half-space so submerged scenery still works.
                vec3 hitWorldPosition = (gbufferModelViewInverse * vec4(hitScenePoint, 1.0)).xyz;
                float waterSide = hitWorldPosition.y - surfaceWorldPosition.y;
                float heightConfidence;
                if (isEyeInWater == 1) {
                    heightConfidence = smoothstep(0.28, 1.10, -waterSide);
                } else {
                    heightConfidence = smoothstep(0.38, 1.20, waterSide);
                }
                if (heightConfidence <= 0.001) return vec4(0.0);

                // Never reflect another water/ice marker. Opaque terrain at the
                // same screen location remains available through depthtex1.
                if (texture2D(colortex2, hitUv).b > 0.025) return vec4(0.0);
                if (hitDepth + 0.0001 <= surfaceDepth) return vec4(0.0);
                float facing = chillSaturate(dot(surfaceNormal, -eyeRay));
                float grazing = 1.0 - facing;
                float angularConfidence = smoothstep(0.04, 0.82, grazing);
                float depthConfidence = 1.0 - smoothstep(finalThickness * 0.30, finalThickness, finalGap);
                float stepConfidence = 1.0 - smoothstep(0.035, 0.11, screenStep);
                float confidence = chillReflectionEdgeFade(hitUv) * angularConfidence;
                confidence *= depthConfidence * stepConfidence * heightConfidence * 0.82;
                return vec4(chillReflectionColor(hitUv, blurRadius), confidence);
            }

            frontPoint = testPoint;
            frontUv = testUv;
            frontGap = gap;
            hasFrontSample = true;
        } else {
            // A sky sample breaks the depth bracket. Do not connect the next
            // piece of terrain to an unrelated point from an earlier step.
            hasFrontSample = false;
        }

        stride = min(stride * 1.08 + 0.04, 4.0);
        travel += stride;
    }

    return vec4(0.0);
}

#endif
