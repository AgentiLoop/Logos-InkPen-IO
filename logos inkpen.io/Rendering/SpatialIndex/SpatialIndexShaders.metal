#include <metal_stdlib>
using namespace metal;
struct GridCell {
    int x;
    int y;
};
struct ObjectBounds {
    float4 bounds;
    uint objectIndex;
};
struct SpatialGridParams {
    float gridSize;
    uint maxObjectsPerCell;
    int gridMinX;
    int gridMinY;
    int gridMaxX;
    int gridMaxY;
    uint totalObjects;
};
kernel void build_spatial_index(
    device const ObjectBounds* objectBounds [[buffer(0)]],
    device atomic_uint* gridCellCounts [[buffer(1)]],
    device uint* gridCellObjects [[buffer(2)]],
    constant SpatialGridParams& params [[buffer(3)]],
    uint objectIdx [[thread_position_in_grid]]
) {
    if (objectIdx >= params.totalObjects) return;
    ObjectBounds obj = objectBounds[objectIdx];
    float2 minCell = floor(obj.bounds.xy / params.gridSize);
    float2 maxCell = floor(obj.bounds.zw / params.gridSize);
    int2 minCellXY = int2(minCell);
    int2 maxCellXY = int2(maxCell);
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    minCellXY = max(minCellXY, gridMin);
    maxCellXY = min(maxCellXY, gridMax);
    int minCellX = minCellXY.x;
    int maxCellX = maxCellXY.x;
    int minCellY = minCellXY.y;
    int maxCellY = maxCellXY.y;
    int gridWidth = params.gridMaxX - params.gridMinX + 1;
    for (int cellX = minCellX; cellX <= maxCellX; cellX++) {
        for (int cellY = minCellY; cellY <= maxCellY; cellY++) {
            int relX = cellX - params.gridMinX;
            int relY = cellY - params.gridMinY;
            uint cellIndex = relY * gridWidth + relX;
            uint slotIndex = atomic_fetch_add_explicit(
                &gridCellCounts[cellIndex],
                1,
                memory_order_relaxed
            );
            if (slotIndex < params.maxObjectsPerCell) {
                uint flatIndex = cellIndex * params.maxObjectsPerCell + slotIndex;
                gridCellObjects[flatIndex] = obj.objectIndex;
            }
        }
    }
}
kernel void query_point(
    device const atomic_uint* gridCellCounts [[buffer(0)]],
    device const uint* gridCellObjects [[buffer(1)]],
    device uint* candidateObjects [[buffer(2)]],
    device atomic_uint* candidateCount [[buffer(3)]],
    constant float2& queryPoint [[buffer(4)]],
    constant SpatialGridParams& params [[buffer(5)]],
    uint threadIdx [[thread_position_in_grid]]
) {
    if (threadIdx > 0) return;
    float2 cellFloat = floor(queryPoint / params.gridSize);
    int2 cell = int2(cellFloat);
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    if (any(cell < gridMin) || any(cell > gridMax)) {
        return;
    }
    int gridWidth = params.gridMaxX - params.gridMinX + 1;
    int2 relCell = cell - gridMin;
    uint cellIndex = relCell.y * gridWidth + relCell.x;
    uint objectCount = atomic_load_explicit(
        &gridCellCounts[cellIndex],
        memory_order_relaxed
    );
    objectCount = min(objectCount, params.maxObjectsPerCell);
    uint baseIndex = cellIndex * params.maxObjectsPerCell;
    for (uint i = 0; i < objectCount; i++) {
        uint objectIdx = gridCellObjects[baseIndex + i];
        uint outputIndex = atomic_fetch_add_explicit(
            candidateCount,
            1,
            memory_order_relaxed
        );
        candidateObjects[outputIndex] = objectIdx;
    }
}
kernel void query_rect(
    device const atomic_uint* gridCellCounts [[buffer(0)]],
    device const uint* gridCellObjects [[buffer(1)]],
    device uint* candidateObjects [[buffer(2)]],
    device atomic_uint* candidateCount [[buffer(3)]],
    constant float4& queryRect [[buffer(4)]],
    constant SpatialGridParams& params [[buffer(5)]],
    uint2 cellCoord [[thread_position_in_grid]]
) {
    float2 minCell = floor(queryRect.xy / params.gridSize);
    float2 maxCell = floor(queryRect.zw / params.gridSize);
    int2 minCellXY = int2(minCell);
    int2 maxCellXY = int2(maxCell);
    int2 gridMin = int2(params.gridMinX, params.gridMinY);
    int2 gridMax = int2(params.gridMaxX, params.gridMaxY);
    minCellXY = max(minCellXY, gridMin);
    maxCellXY = min(maxCellXY, gridMax);
    int minCellX = minCellXY.x;
    int maxCellX = maxCellXY.x;
    int minCellY = minCellXY.y;
    int maxCellY = maxCellXY.y;
    int cellX = minCellX + int(cellCoord.x);
    int cellY = minCellY + int(cellCoord.y);
    if (cellX > maxCellX || cellY > maxCellY) return;
    int gridWidth = params.gridMaxX - params.gridMinX + 1;
    int relX = cellX - params.gridMinX;
    int relY = cellY - params.gridMinY;
    uint cellIndex = relY * gridWidth + relX;
    uint objectCount = atomic_load_explicit(
        &gridCellCounts[cellIndex],
        memory_order_relaxed
    );
    objectCount = min(objectCount, params.maxObjectsPerCell);
    uint baseIndex = cellIndex * params.maxObjectsPerCell;
    for (uint i = 0; i < objectCount; i++) {
        uint objectIdx = gridCellObjects[baseIndex + i];
        uint outputIndex = atomic_fetch_add_explicit(
            candidateCount,
            1,
            memory_order_relaxed
        );
        candidateObjects[outputIndex] = objectIdx;
    }
}
kernel void clear_grid(
    device atomic_uint* gridCellCounts [[buffer(0)]],
    uint index [[thread_position_in_grid]]
) {
    atomic_store_explicit(&gridCellCounts[index], 0, memory_order_relaxed);
}
