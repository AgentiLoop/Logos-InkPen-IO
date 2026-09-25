#include <metal_stdlib>
using namespace metal;
kernel void transformPoints(
    device const float2 *inputPoints [[buffer(0)]],
    device float2 *outputPoints [[buffer(1)]],
    device const float3x3 *transform [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    float3 point = float3(inputPoints[index], 1.0);
    float3 transformed = (*transform) * point;
    outputPoints[index] = transformed.xy;
}
kernel void batchTransformPoints(
    device const float2 *inputPoints [[buffer(0)]],
    device float2 *outputPoints [[buffer(1)]],
    device const float3x3 *transforms [[buffer(2)]],
    device const uint *pointCounts [[buffer(3)]],
    device const uint *pointOffsets [[buffer(4)]],
    uint batchIndex [[threadgroup_position_in_grid]],
    uint localIndex [[thread_position_in_threadgroup]]
) {
    uint offset = pointOffsets[batchIndex];
    uint count = pointCounts[batchIndex];
    if (localIndex < count) {
        uint index = offset + localIndex;
        float3 point = float3(inputPoints[index], 1.0);
        float3 transformed = transforms[batchIndex] * point;
        outputPoints[index] = transformed.xy;
    }
}
kernel void multiplyMatrices(
    device const float3x3 *matrices1 [[buffer(0)]],
    device const float3x3 *matrices2 [[buffer(1)]],
    device float3x3 *results [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    results[index] = matrices1[index] * matrices2[index];
}
struct Rectangle {
    float2 min;
    float2 max;
};
kernel void calculateBounds(
    device const float2 *points [[buffer(0)]],
    device Rectangle *output [[buffer(1)]],
    uint index [[thread_position_in_grid]],
    uint gridSize [[threads_per_grid]]
) {
    float2 localMin = points[index];
    float2 localMax = points[index];
    for (uint i = index + gridSize; i < gridSize; i += gridSize) {
        localMin = min(localMin, points[i]);
        localMax = max(localMax, points[i]);
    }
    output[index] = Rectangle{localMin, localMax};
}
kernel void mergeBounds(
    device Rectangle *bounds [[buffer(0)]],
    uint index [[thread_position_in_grid]],
    uint stride [[threads_per_threadgroup]]
) {
    threadgroup Rectangle shared[256];
    shared[index] = bounds[index];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = stride / 2; s > 0; s >>= 1) {
        if (index < s) {
            shared[index].min = min(shared[index].min, shared[index + s].min);
            shared[index].max = max(shared[index].max, shared[index + s].max);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index == 0) {
        bounds[0] = shared[0];
    }
}
kernel void batchCalculateDistances(
    device const float2 *origin [[buffer(0)]],
    device const float2 *points [[buffer(1)]],
    device float *distances [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    float2 diff = points[index] - (*origin);
    distances[index] = length(diff);
}
kernel void perpendicularDistances(
    device const float2 *points [[buffer(0)]],
    device const float2 *lineStart [[buffer(1)]],
    device const float2 *lineEnd [[buffer(2)]],
    device float *distances [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    float2 lineVec = (*lineEnd) - (*lineStart);
    float lineLengthSq = dot(lineVec, lineVec);
    if (lineLengthSq > 0) {
        float2 pointVec = points[index] - (*lineStart);
        float cross = abs(pointVec.x * lineVec.y - pointVec.y * lineVec.x);
        distances[index] = cross / sqrt(lineLengthSq);
    } else {
        distances[index] = 0;
    }
}
struct CubicCurve {
    float2 p0;
    float2 p1;
    float2 p2;
    float2 p3;
};
kernel void evaluateCubicBezier(
    device const CubicCurve *curve [[buffer(0)]],
    device const float *tValues [[buffer(1)]],
    device float2 *outputPoints [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    float t = tValues[index];
    float oneMinusT = 1.0 - t;
    float oneMinusT2 = oneMinusT * oneMinusT;
    float oneMinusT3 = oneMinusT2 * oneMinusT;
    float t2 = t * t;
    float t3 = t2 * t;
    float4 basis = float4(
        oneMinusT3,
        3.0 * oneMinusT2 * t,
        3.0 * oneMinusT * t2,
        t3
    );
    float2 point = basis.x * curve->p0 +
                   basis.y * curve->p1 +
                   basis.z * curve->p2 +
                   basis.w * curve->p3;
    outputPoints[index] = point;
}
kernel void calculateCurveFlatness(
    device const CubicCurve *curves [[buffer(0)]],
    device float *flatness [[buffer(1)]],
    uint index [[thread_position_in_grid]]
) {
    CubicCurve curve = curves[index];
    float2 lineVec = curve.p3 - curve.p0;
    float lineLength = length(lineVec);
    if (lineLength > 0) {
        float2 lineNorm = lineVec / lineLength;
        float2 toCP1 = curve.p1 - curve.p0;
        float proj1 = dot(toCP1, lineNorm);
        float2 perpVec1 = toCP1 - proj1 * lineNorm;
        float dist1 = length(perpVec1);
        float2 toCP2 = curve.p2 - curve.p0;
        float proj2 = dot(toCP2, lineNorm);
        float2 perpVec2 = toCP2 - proj2 * lineNorm;
        float dist2 = length(perpVec2);
        flatness[index] = max(dist1, dist2);
    } else {
        flatness[index] = 0;
    }
}
kernel void batchCheckCollinearity(
    device const float2 *p1 [[buffer(0)]],
    device const float2 *p2 [[buffer(1)]],
    device const float2 *p3 [[buffer(2)]],
    device bool *results [[buffer(3)]],
    constant float *tolerance [[buffer(4)]],
    uint index [[thread_position_in_grid]]
) {
    float2 v1 = p2[index] - p1[index];
    float2 v2 = p3[index] - p1[index];
    float cross = v1.x * v2.y - v1.y * v2.x;
    results[index] = abs(cross) < (*tolerance);
}
kernel void batchRectIntersections(
    constant float4 *testRect [[buffer(0)]],
    device const float4 *rects [[buffer(1)]],
    device bool *results [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    float4 rect = rects[index];
    results[index] = testRect->x <= rect.z &&
                     testRect->z >= rect.x &&
                     testRect->y <= rect.w &&
                     testRect->w >= rect.y;
}
kernel void parallelMax(
    device const float *input [[buffer(0)]],
    device float *output [[buffer(1)]],
    uint index [[thread_position_in_grid]],
    uint stride [[threads_per_threadgroup]]
) {
    threadgroup float shared[256];
    shared[index] = input[index];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = stride / 2; s > 0; s >>= 1) {
        if (index < s) {
            shared[index] = max(shared[index], shared[index + s]);
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index == 0) {
        output[0] = shared[0];
    }
}
kernel void parallelMaxWithIndex(
    device const float *input [[buffer(0)]],
    device float *maxValue [[buffer(1)]],
    device uint *maxIndex [[buffer(2)]],
    uint index [[thread_position_in_grid]],
    uint stride [[threads_per_threadgroup]]
) {
    threadgroup float sharedValue[256];
    threadgroup uint sharedIndex[256];
    sharedValue[index] = input[index];
    sharedIndex[index] = index;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = stride / 2; s > 0; s >>= 1) {
        if (index < s) {
            if (sharedValue[index + s] > sharedValue[index]) {
                sharedValue[index] = sharedValue[index + s];
                sharedIndex[index] = sharedIndex[index + s];
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index == 0) {
        *maxValue = sharedValue[0];
        *maxIndex = sharedIndex[0];
    }
}
kernel void batchInterpolate(
    device const float2 *startPoints [[buffer(0)]],
    device const float2 *endPoints [[buffer(1)]],
    device const float *tValues [[buffer(2)]],
    device float2 *results [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    float t = tValues[index];
    results[index] = mix(startPoints[index], endPoints[index], t);
}
