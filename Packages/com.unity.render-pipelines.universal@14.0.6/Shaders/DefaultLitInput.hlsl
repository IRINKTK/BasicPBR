#ifndef DEFAULT_LIT_INPUT_INCLUDED
#define DEFAULT_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
// Base
float4  _BaseMap_ST;
half4   _BaseColor;
half    _Cutoff;

// PBR
half    _BumpScale;
half    _Roughness;
half    _Metallic;
half    _Occlusion;
half    _Reflectance;

// Emission
half3   _EmissionColor;

// Rim Light
half3   _RimColor;
half3   _RimParams;

// Laser
half     _LaserValue;

CBUFFER_END

TEXTURE2D_HALF(_MixMap);
TEXTURE2D_HALF(_LaserMap);


///////////////////////////////////////////////////////////////////////////////
//                      Material Property Helpers                            //
///////////////////////////////////////////////////////////////////////////////

half4 GetBaseMap(float2 uv)
{
    return SAMPLE_TEXTURE2D(_BaseMap, sampler_LinearRepeat, uv) * _BaseColor;
}

half3 GetNormalMap(float2 uv)
{
    half4 n = SAMPLE_TEXTURE2D(_BumpMap, sampler_LinearRepeat, uv);
    return UnpackNormalScale(n, _BumpScale);
}

half3 GetMixMap(float2 uv)
{
    half3 mixValue = half3(_Roughness, _Metallic, _Occlusion);
#if _MIXMAP
    mixValue *= SAMPLE_TEXTURE2D(_MixMap, sampler_LinearRepeat, uv).rgb;
#endif
    return mixValue;
}

#if _EMISSION
half3 GetEmission(float2 uv)
{
    return SAMPLE_TEXTURE2D(_EmissionMap, sampler_LinearRepeat, uv).rgb * _EmissionColor.rgb;
} 
#endif

#if _LASER
half3 GetLaserMap(half3 reflectVector)
{
    float X = dot(UNITY_MATRIX_V[0].xyz, reflectVector);
    float Y = dot(UNITY_MATRIX_V[1].xyz, reflectVector);
    float2 laserUV = float2(X, Y) * 0.5 + 0.5;
    return SAMPLE_TEXTURE2D(_LaserMap, sampler_LinearRepeat, laserUV).rgb * _LaserValue;   
}
#endif

#endif // DEFAULT_LIT_INPUT_INCLUDED