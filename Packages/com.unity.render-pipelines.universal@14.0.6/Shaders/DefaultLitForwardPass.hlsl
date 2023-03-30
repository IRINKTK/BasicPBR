#ifndef DEFAULT_LIT_FORWARD_PASS_INCLUDED
#define DEFAULT_LIT_FORWARD_PASS_INCLUDED


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShadingModels.hlsl"

struct AttributesDefaultLit
{
    float4 positionOS       : POSITION;

    half3  normalOS         : NORMAL;
#ifdef REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
    half4 tangentOS         : TANGENT;
#endif

    float2 texcoord         : TEXCOORD0;

#if LIGHTMAP_ON
    float2 staticLightmapUV : TEXCOORD1;
#endif

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VaryingsDefaultLit
{
    float2 texcoord         : TEXCOORD0;

    float3 normalWS         : TEXCOORD1;

#ifdef REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
    half4 tangentWS         : TEXCOORD2;
#endif

    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 3);

    float3 positionWS       : TEXCOORD4;

    float4 positionCS       : SV_POSITION;

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

VaryingsDefaultLit DefaultLitVertex(AttributesDefaultLit i)
{
    VaryingsDefaultLit o;
    UNITY_SETUP_INSTANCE_ID(i);
    UNITY_TRANSFER_INSTANCE_ID(i, o);

    // Position
    VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
    o.positionCS = vertexInput.positionCS;
    o.positionWS = vertexInput.positionWS;

    // Normal
#ifdef REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR
    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS, i.tangentOS);
    o.tangentWS = half4(normalInput.tangentWS, i.tangentOS.w);
    o.normalWS = normalInput.normalWS;
#else
    VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);
    o.normalWS = normalInput.normalWS;
#endif

    // GI
    OUTPUT_LIGHTMAP_UV(i.staticLightmapUV, unity_LightmapST, o.staticLightmapUV);
    OUTPUT_SH(o.normalWS.xyz, o.vertexSH);

    // UV
    o.texcoord = i.texcoord * _BaseMap_ST.xy + _BaseMap_ST.zw;

    return o;
}

void EvaluatePixelDataLit(VaryingsDefaultLit i, half facing, inout PixelData pixel)
{
    // Base color
    half4 baseColor = GetBaseMap(i.texcoord);
    
#if _ALPHATEST_ON
    AlphaTest(baseColor.a, _Cutoff, i.positionCS);
#endif

    // Get PBR Mix Value (Roughness, Metallic, Occlusion)
    half3 mixValue = GetMixMap(i.texcoord);

#if _FLIP_NORMAL
    i.normalWS *= facing;
#endif
#if _NORMALMAP
    half3 normalTS = GetNormalMap(i.texcoord);
    half3 bitangentWS = i.tangentWS.w * cross(i.normalWS, i.tangentWS.xyz);
    half3 normalWS  = normalize(TransformTangentToWorld(normalTS, half3x3(i.tangentWS.xyz, bitangentWS, i.normalWS)));
#else
    half3 normalWS  = normalize(i.normalWS);
#endif

    // Normal
    pixel.normalWS  = normalWS;

    // Base color
    pixel.baseColor = baseColor.rgb;

    // Alpha
    pixel.alpha = baseColor.a;

    // Metallic
    pixel.metallic = mixValue.g;
    
    // User setup roughness
    pixel.perceptualRoughness = mixValue.r;

    // Occlusion
    pixel.occlusion = mixValue.b;

    // Reflectance
    pixel.reflectance = _Reflectance;

    // Diffuse color
    pixel.diffuseColor = ComputeDiffuseColor(pixel.baseColor, pixel.metallic);
    
    // Specular color (F0)
    pixel.specularColor = ComputeSpecularColor(pixel.baseColor, pixel.reflectance, pixel.metallic);

    // Emission
#if _EMISSION
    pixel.giEmission = GetEmission(i.texcoord);
#endif

    // Shading model id
    pixel.shadingModelID = SHADINGMODELID_DEFAULT_LIT;
}


// Fragment Output
half4 DefaultLitFragment (VaryingsDefaultLit i, half facing : VFACE) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(i);

    // Evaluate pixel data except view.
    PixelData pixel = (PixelData)0;
    EvaluatePixelDataLit(i, facing, pixel);

    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);

    // Calculate lighting
#ifdef MAIN_LIGHT_CALCULATE_SHADOWS
    Light light = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
#else
    Light light = GetMainLight();
#endif
    light.distanceAttenuation = 1.0;

    // Calculate BxDF context
    BxDFContext context = (BxDFContext)0;
    InitBxDFContext(light.direction, viewDirWS, pixel.normalWS, context);

    // Env BRDF
    half2 energy = EnvBRDFApproxLazarov(pixel.perceptualRoughness, context.NoV);
    half3 envBRDF = EnvBRDFApprox(pixel.specularColor, energy);

    half3 color = 0.0;

    // Indirect light
    half3 bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, pixel.normalWS);
    color += CalculateIndirectLight(pixel, context, viewDirWS, envBRDF, bakedGI);

    // Emission
#if _EMISSION
    color += pixel.giEmission;    
#endif

    // Rim light
#if _RIM_LIGHT
    color += CalculateRimLight(_RimParams.x, _RimParams.y, _RimColor, context);
#endif

    // Direct light
    EvaluateBxDF(pixel, light, context, color);   

    // Additional Light
    int pixelLightCount = GetAdditionalLightsCount();
    for (int lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex) 
    { 
        Light addLight = GetAdditionalLight(lightIndex, i.positionWS);
        InitBxDFContext(addLight.direction, viewDirWS, pixel.normalWS, context);
        EvaluateBxDF(pixel, addLight, context, color);
    }

#if _DEBUG_DISPLAY_ON
    DebugDisplay(pixel, light, context, viewDirWS, envBRDF, bakedGI, color);
#endif

    return half4(color, pixel.alpha);
}

#endif // DEFAULT_LIT_FORWARD_PASS_INCLUDED