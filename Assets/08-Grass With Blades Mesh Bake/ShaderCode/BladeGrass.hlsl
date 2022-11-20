// Make sure this file is not included twice
#ifndef GRASSBLADES_INCLUDED
#define GRASSBLADES_INCLUDED

// Include some helper functions
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "NMGBladeGrassGraphicsHelpers.hlsl"

struct Attributes {
    float3 positionOS       : POSITION;
    float3 normalOS         : NORMAL;
    float2 uv               : TEXCOORD0;
    float3 bladeAnchorOS    : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertexOutput {
    float2 uv           : TEXCOORD0; // The height of this vertex on the grass blade
    float3 positionWS   : TEXCOORD1; // Position in world space
    float3 normalWS     : TEXCOORD2; // Normal vector in world space

    float4 positionCS   : SV_POSITION; // Position in clip space
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

// Properties
float4 _BaseColor;
float4 _TipColor;
float _RandomJitterRadius;

TEXTURE2D(_WindTexture); SAMPLER(sampler_WindTexture);
float4 _WindTexture_ST;
float _WindFrequency;
float _WindAmplitude;

// Vertex functions

VertexOutput Vertex(Attributes input) {
    // Initialize the output struct
    VertexOutput output = (VertexOutput)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
 
    float3 bladeAnchorWS = GetVertexPositionInputs(input.bladeAnchorOS).positionWS;
    // Get a plane perpendicular to the normal
    float3 normalWS = GetVertexNormalInputs(input.normalOS).normalWS;
    float3 tangentWS, bitangentWS;
    GetPerpendicularPlane(normalWS, tangentWS, bitangentWS);

    // Calculate a random jitter amount based on world space position. Use the blade anchor so the entire blade
    // has the same jitter offset
    float3 randomOffset = tangentWS * randNegative1to1(bladeAnchorWS, 0) + bitangentWS * randNegative1to1(bladeAnchorWS, 1);
    randomOffset *= _RandomJitterRadius;
    bladeAnchorWS += randomOffset; // Apply jitter to the anchor for wind

    // Calculate the wind axis, which also encodes the wind strength
    // The windUV is affected by the world position and time. TRANSFORM_TEX applies _WindTexture_ST values
    float2 windUV = TRANSFORM_TEX(bladeAnchorWS.xz, _WindTexture) + _Time.y * _WindFrequency;
    // Sample the wind noise texture and remap it to range between -1 and 1
    float2 windNoise = SAMPLE_TEXTURE2D_LOD(_WindTexture, sampler_WindTexture, windUV, 0).xy * 2 - 1;
    // Offset blade points in a vector perpendular to it's normal, but also consistent
    // across blades.
    float3 windOffset = cross(normalWS, float3(windNoise.x, 0, windNoise.y));
    // Then scale by the amplitude and UV.y, so points near the base of the blade are blown less
    windOffset *= _WindAmplitude * input.uv.y;

    float3 positionWS = GetVertexPositionInputs(input.positionOS).positionWS + randomOffset + windOffset;

    output.positionWS = positionWS;
    output.normalWS = normalWS;
    output.uv = input.uv;
    output.positionCS = TransformWorldToHClip(positionWS);

    return output;
}

// Fragment functions

half4 Fragment(VertexOutput input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);

    // Gather some data for the lighting algorithm
    InputData lightingInput = (InputData)0;
    lightingInput.positionWS = input.positionWS;
    lightingInput.normalWS = input.normalWS; // No need to normalize, triangles share a normal
    lightingInput.viewDirectionWS = GetViewDirectionFromPosition(input.positionWS); // Calculate the view direction
    lightingInput.shadowCoord = CalculateShadowCoord(input.positionWS, input.positionCS);

    // Lerp between the base and tip color based on the blade height
    float colorLerp = input.uv.y;
    float3 albedo = lerp(_BaseColor.rgb, _TipColor.rgb, colorLerp);

    // The URP simple lit algorithm
    // The arguments are lighting input data, albedo color, specular color, smoothness, emission color, and alpha

    SurfaceData surfaceInput = (SurfaceData)0;
    surfaceInput.albedo = albedo;
    surfaceInput.alpha = 1;
    surfaceInput.specular = 1;
    surfaceInput.occlusion = 1;

    return UniversalFragmentBlinnPhong(lightingInput, surfaceInput);

    //return UniversalFragmentBlinnPhong(lightingInput, albedo, 1, 0, 0, 1);
}

#endif

