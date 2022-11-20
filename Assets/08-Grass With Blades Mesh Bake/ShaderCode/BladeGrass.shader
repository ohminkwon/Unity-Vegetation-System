Shader "Grass/BakedGrassBlade" 
{
    Properties
    {
        _BaseColor("Base color", Color) = (0, 0.5, 0, 1) // Color of the lowest layer
        _TipColor("Tip color", Color) = (0, 1, 0, 1) // Color of the highest layer
        _RandomJitterRadius("Random jitter radius", Float) = 0.1
        _WindTexture("Wind texture", 2D) = "white" {}
        _WindFrequency("Wind frequency", Float) = 0.1
        _WindAmplitude("Wind strength", Float) = 0.5
    }

    SubShader
    {
        // UniversalPipeline needed to have this render in URP
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        
        // Forward Lit Pass
        Pass 
        {

            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Cull Off

            HLSLPROGRAM
            // Signal this shader requires a compute buffer
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            // Lighting and shadow keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            // Register our functions
            #pragma vertex Vertex
            #pragma fragment Fragment

            // Incude our logic file
            #include "BladeGrass.hlsl"    

            ENDHLSL
        }
    }
}
