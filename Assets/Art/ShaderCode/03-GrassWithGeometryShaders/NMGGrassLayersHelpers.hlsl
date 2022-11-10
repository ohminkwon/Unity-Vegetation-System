// Make sure this file is not included twice
#ifndef NMG_HELPERS_INCLUDED
#define NMG_HELPERS_INCLUDED

// Math

// Returns the view direction in world space
float3 GetViewDirectionFromPosition(float3 positionWS) {
    return normalize(GetCameraPositionWS() - positionWS);
}

// URP Helpers

// If this is the shadow caster pass, we also need this variable, which URP sets
#ifdef SHADOW_CASTER_PASS
float3 _LightDirection;
#endif

// Calculates the position in clip space, taking into account various strategies
// to improve shadow quality in the shadow caster pass
float4 CalculatePositionCSWithShadowCasterLogic(float3 positionWS, float3 normalWS) {
    float4 positionCS;

#ifdef SHADOW_CASTER_PASS
    // From URP's ShadowCasterPass.hlsl
    // If this is the shadow caster pass, we need to adjust the clip space position to account
    // for shadow bias and offset (this helps reduce shadow artifacts)
    positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
#else
    // This built in function transforms from world space to clip space
    positionCS = TransformWorldToHClip(positionWS);
#endif

    return positionCS;
}

// Calculates the shadow texture coordinate for lighting calculations
float4 CalculateShadowCoord(float3 positionWS, float4 positionCS) {
    // Calculate the shadow coordinate depending on the type of shadows currently in use
#if SHADOWS_SCREEN
    return ComputeScreenPos(positionCS);
#else
    return TransformWorldToShadowCoord(positionWS);
#endif
}

#endif