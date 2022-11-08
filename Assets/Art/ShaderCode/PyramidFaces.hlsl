// Make sure this file is not included twice
#ifndef PYRAMIDFACES_INCLUDED
#define PYRAMIDFACES_INCLUDED

// Include helper functions from URP
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "NMGPyramidGraphicsHelpers.hlsl"

// This describes a vertex on the generated mesh, it should match that in the compute shader!
struct DrawVertex {
    float3 positionWS; // position in world space
    float2 uv; // UV
};
// A triangle
struct DrawTriangle {
    float3 normalWS; // normal in world space. All points share this normal
    DrawVertex vertices[3];
};
// The buffer to draw from
StructuredBuffer<DrawTriangle> _DrawTriangles;

// This structure is generated by the vertex function and passed to the geometry function
struct VertexOutput {
    float3 positionWS   : TEXCOORD0; // Position in world space
    float3 normalWS     : TEXCOORD1; // Normal vector in world space
    float2 uv           : TEXCOORD2; // UVs
    float4 positionCS   : SV_POSITION; // Position in clip space
};

// The _MainTex property. The sampler and scale/offset vector is also created
TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex); float4 _MainTex_ST;

// Vertex functions

// The SV_VertexID semantic is an index we can use to get a vertex to work on
// The max value of this is the first argument in the indirect args buffer
// The system will create triangles out of each three consecutive vertices
VertexOutput Vertex(uint vertexID: SV_VertexID) {
    // Initialize the output struct
    VertexOutput output = (VertexOutput)0;

    // Get the vertex from the buffer
    // Since the buffer is structured in triangles, we need to divide the vertexID by three
    // to get the triangle, and then modulo by 3 to get the vertex on the triangle
    DrawTriangle tri = _DrawTriangles[vertexID / 3];
    DrawVertex input = tri.vertices[vertexID % 3];

    output.positionWS = input.positionWS;
    output.normalWS = tri.normalWS;
    output.uv = TRANSFORM_TEX(input.uv, _MainTex);
    // Apply shadow caster logic to the CS position
    output.positionCS = CalculatePositionCSWithShadowCasterLogic(input.positionWS, tri.normalWS);

    return output;
}

// Fragment functions

// The SV_Target semantic tells the compiler that this function outputs the pixel color
float4 Fragment(VertexOutput input) : SV_Target{

#ifdef SHADOW_CASTER_PASS
    // If in the shadow caster pass, we can just return now
    // It's enough to signal that should will cast a shadow
    return 0;
#else
    // Initialize some information for the lighting function
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = input.normalWS; // No need to renormalize, since triangles all share normals
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(input.positionWS);
    lightingInput.shadowCoord = CalculateShadowCoord(input.positionWS, input.positionCS);

    // Read the main texture
    float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).rgb;

    // Call URP's simple lighting function
    // The arguments are lightingInput, albedo color, specular color, smoothness, emission color, and alpha

    return UniversalFragmentBlinnPhong(lightingInput, albedo, 1, 0, 0, 1);
#endif
}

#endif