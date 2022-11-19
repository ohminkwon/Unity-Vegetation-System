// Make sure this file is not included twice
#ifndef GRASSLAYERS_INCLUDED
#define GRASSLAYERS_INCLUDED

// Include some helper functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "NMGGrassLayersHelpers.hlsl"

// Change this to change the number of layers created by the geometry function
#define GRASS_LAYERS 16

// The vertex function input
struct Attributes {
    float4 positionOS   : POSITION; // Vertex position in object space
    float3 normalOS     : NORMAL; // Vertex normal vector in object space
    float4 tangentOS    : TANGENT; // Vertex tangent vector in object space (plus bitangent sign)
    float2 uv           : TEXCOORD0; // Vertex uv
};

// Vertex function output and geometry function input
struct VertexOutput {
    float3 positionWS   : TEXCOORD0; // Position in world space
    float3 normalWS     : TEXCOORD1; // Normal vector in world space
    float2 uv           : TEXCOORD2; // UV, no scaling applied
};

// Geometry function output and fragment function input
struct GeometryOutput {
    float3 uv           : TEXCOORD0; // UV, no scaling applied, plus the layer height in the z-coord
    float3 positionWS   : TEXCOORD1; // Position in world space
    float3 normalWS     : TEXCOORD2; // Normal vector in world space

    float4 positionCS   : SV_POSITION; // Position in clip space
};

// Properties
float4 _BaseColor;
float4 _TopColor;
float _TotalHeight; // Height of the top layer
// These two textures are combined to create the grass pattern in the fragment function
TEXTURE2D(_DetailNoiseTexture); SAMPLER(sampler_DetailNoiseTexture); float4 _DetailNoiseTexture_ST;
float _DetailDepthScale;
TEXTURE2D(_SmoothNoiseTexture); SAMPLER(sampler_SmoothNoiseTexture); float4 _SmoothNoiseTexture_ST;
float _SmoothDepthScale;
// Wind properties
TEXTURE2D(_WindNoiseTexture); SAMPLER(sampler_WindNoiseTexture); float4 _WindNoiseTexture_ST;
float _WindTimeMult;
float _WindAmplitude;

// Vertex functions

VertexOutput Vertex(Attributes input) {
    // Initialize the output struct
    VertexOutput output = (VertexOutput)0;

    // Calculate position and normal in world space
    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
    output.positionWS = vertexInput.positionWS;
    output.normalWS = normalInput.normalWS;

    // Pass through the UV
    output.uv = input.uv;
    return output;
}

// Geometry functions

// This function sets values in output after calculating position based on height
void SetupVertex(in VertexOutput input, inout GeometryOutput output, float height) {

    // Extrude the position outwards along the normal based on the passed in height
    float3 positionWS = input.positionWS + input.normalWS * (height * _TotalHeight);

    output.positionWS = positionWS;
    output.normalWS = input.normalWS;
    output.uv = float3(input.uv, height); // Store the layer height in uv.z
    output.positionCS = CalculatePositionCSWithShadowCasterLogic(positionWS, input.normalWS);
}

// We create GRASS_LAYERS triangles which have 3 vertices each
[maxvertexcount(3 * GRASS_LAYERS)]
void Geometry(triangle VertexOutput inputs[3], inout TriangleStream<GeometryOutput> outputStream) {
    // Initialize the output struct
    GeometryOutput output = (GeometryOutput)0;

    // For each layer...
    for (int l = 0; l < GRASS_LAYERS; l++) {
        // Calculate the height percent
        float h = l / (float)(GRASS_LAYERS - 1);
        // For each point in the triangle...
        for (int t = 0; t < 3; t++) {
            // Calculate the output data and add the vertex to the output stream
            SetupVertex(inputs[t], output, h);
            outputStream.Append(output);
        }
        // Each triangle is disconnected, so we need to call this to restart the triangle strip
        outputStream.RestartStrip();
    }
}

// Fragment functions

half4 Fragment(GeometryOutput input) : SV_Target{

    // Height percent is uv.z
    float height = input.uv.z;

// Calculate wind
// Get the wind noise texture uv by applying scale and offset and then adding a time offset
float2 windUV = TRANSFORM_TEX(input.uv.xy, _WindNoiseTexture) + _Time.y * _WindTimeMult;
// Sample the wind noise texture and remap to range from -1 to 1
float2 windNoise = SAMPLE_TEXTURE2D(_WindNoiseTexture, sampler_WindNoiseTexture, windUV).xy * 2 - 1;
// Offset the grass UV by the wind. Higher layers are affected more
float2 uv = input.uv.xy + windNoise * (_WindAmplitude * height);

// Sample the two noise textures, applying their scale and offset
float detailNoise = SAMPLE_TEXTURE2D(_DetailNoiseTexture, sampler_DetailNoiseTexture, TRANSFORM_TEX(uv, _DetailNoiseTexture)).r;
float smoothNoise = SAMPLE_TEXTURE2D(_SmoothNoiseTexture, sampler_SmoothNoiseTexture, TRANSFORM_TEX(uv, _SmoothNoiseTexture)).r;
// Combine the textures together using these scale variables. Lower values will reduce a texture's influence
detailNoise = 1 - (1 - detailNoise) * _DetailDepthScale;
smoothNoise = 1 - (1 - smoothNoise) * _SmoothDepthScale;
// If detailNoise * smoothNoise is less than height, this pixel will be discarded by the renderer
// I.E. this pixel will not render. The fragment function returns as well
clip(detailNoise* smoothNoise - height);

// If the code reaches this far, this pixel should render

#ifdef SHADOW_CASTER_PASS
    // If we're in the shadow caster pass, it's enough to return now. We don't care about color
    return 0;
#else
    // Gather some data for the lighting algorithm
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = NormalizeNormalPerPixel(input.normalWS); // Renormalize the normal to reduce interpolation errors
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(input.positionWS); // Calculate the view direction
    lightingInput.shadowCoord = CalculateShadowCoord(input.positionWS, input.positionCS); // Calculate the shadow map coord

    // Lerp between the two grass colors based on layer height
    float3 albedo = lerp(_BaseColor, _TopColor, height).rgb;

    // The URP simple lit algorithm
    // The arguments are lighting input data, albedo color, specular color, smoothness, emission color, and alpha

    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = albedo;
    surfaceInput.alpha = 1;
    surfaceInput.specular = 1;
    surfaceInput.occlusion = 1;

    return UniversalFragmentBlinnPhong(lightingInput, surfaceInput);

    //return UniversalFragmentBlinnPhong(lightingInput, albedo, 1, 0, 0, 1);
#endif
}

#endif