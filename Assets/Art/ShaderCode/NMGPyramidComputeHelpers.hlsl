// Make sure this file is not included twice
#ifndef NMG_COMPUTE_HELPERS_INCLUDED
#define NMG_COMPUTE_HELPERS_INCLUDED

// Math

// Returns the normal of a plane containing the triangle defined by the three arguments
float3 GetNormalFromTriangle(float3 a, float3 b, float3 c) {
    return normalize(cross(b - a, c - a));
}

// Returns the center point of a triangle defined by the three arguments
float3 GetTriangleCenter(float3 a, float3 b, float3 c) {
    return (a + b + c) / 3.0;
}
float2 GetTriangleCenter(float2 a, float2 b, float2 c) {
    return (a + b + c) / 3.0;
}

#endif