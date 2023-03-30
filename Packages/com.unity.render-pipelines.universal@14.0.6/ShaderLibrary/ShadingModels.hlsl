#ifndef SHADING_MODELS_INCLUDED
#define SHADING_MODELS_INCLUDED

#define SHADINGMODELID_UNLIT				    0
#define SHADINGMODELID_DEFAULT_LIT              1

// All pixel datas from forward render pass
struct PixelData
{
    // [0, 1], sRGB value.
    half3   baseColor; 

    // [0, 1], translucent.
    half    alpha;

    // [-1, 1], normalized world space bump normal.
    half3   normalWS;

    // [0, 1], clamped user input roughness.
    half    perceptualRoughness;

    // [0, 1], linear value.
    half    metallic; 

    // [0, 1], ambient occlusion.
    half    occlusion;  

    // [0, 1], 0.5 as default value.
    half    reflectance;  

    // [0, 1], color for non-metal.
    half3   diffuseColor;

    // [0, 1], color for metal.
    // Unreal & Unity style calls SpecularColor,
    // Filament style calls f0 straight forward.
    half3   specularColor;

    // HDR values
    half3   giEmission;

    // Shading model id
    uint    shadingModelID;
};


// Clamped bxdf context
struct BxDFContext
{
    // Half vector
    float3 H;

    // Clamped common bxdf vectors
    half NoL;
	half NoV;
	half NoH;
    half VoL;
	half VoH;

// #if _ANISOTROPIC
    // // Anisotropic, none clamped vectors
	// half ToV;
	// half ToL;
	// half ToH;
	// half BoV;
	// half BoL;
	// half BoH;
// #endif
};


//-----------------------------------------------------------------------------
// BxDF Context
//-----------------------------------------------------------------------------
void InitBxDFContext(half3 lightDirWS, half3 viewDirWS, half3 normalWS, inout BxDFContext context)
{
    float3 H = SafeNormalize(lightDirWS + viewDirWS);
    context.H = H;
    context.NoL = saturate(dot(normalWS, lightDirWS));
    context.NoV = max(dot(normalWS, viewDirWS), MIN_N_DOT_V);
    context.NoH = saturate(dot(normalWS, H));
    context.VoL = saturate(dot(viewDirWS, lightDirWS));
    context.VoH = saturate(dot(viewDirWS, H));
}

// #if _ANISOTROPIC
// void InitBxDFContextAnisotropic(half3 lightDirWS, half3 viewDirWS, half3 tangentWS, half3 bitangentWS, inout BxDFContext context)
// {
//     context.ToV = dot(tangentWS, viewDirWS);
//     context.ToL = dot(tangentWS, lightDirWS);
//     context.ToH = dot(tangentWS, context.H);

//     context.BoV = dot(bitangentWS, viewDirWS);
//     context.BoL = dot(bitangentWS, lightDirWS);
//     context.BoH = dot(bitangentWS, context.H);
// }
// #endif


//-----------------------------------------------------------------------------
// Calculate Shadow
//-----------------------------------------------------------------------------
half GetLightAttenuation(Light light)
{
    // Calculate shadows
#if defined (MAIN_LIGHT_CALCULATE_SHADOWS) || defined(ADDITIONAL_LIGHT_CALCULATE_SHADOWS) || defined(_PerObjectVolume)
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
#else
    half lightAttenuation = light.distanceAttenuation;
#endif
    return lightAttenuation;
}


//-----------------------------------------------------------------------------
// Custom Lighting
//-----------------------------------------------------------------------------
#if _RIM_LIGHT
half3 CalculateRimLight(half rimMin, half rimMax, half3 rimColor, BxDFContext context)
{
    half OneMinusNdotV = 1 - context.NoV;
    half3 rim = smoothstep(rimMin, rimMax, OneMinusNdotV) * rimColor;

#if _RIM_FRONT
    rim *= context.NoL;
#elif _RIM_BACK
    rim *= (1 - context.NoL);
#endif

    // Output
    return rim;

}
#endif

//-----------------------------------------------------------------------------
// Diffuse Lobe
//-----------------------------------------------------------------------------
half3 DiffuseLobe(half3 diffuseColor) 
{
    return diffuseColor;
}

//-----------------------------------------------------------------------------
// Specular Lobe
//-----------------------------------------------------------------------------
half3 IsotropicLobe(PixelData pixel, BxDFContext context)
{
    half a = pixel.perceptualRoughness * pixel.perceptualRoughness;
	half D = GGX_Mobile(pixel.perceptualRoughness, context.NoH);
    float V = V_SmithGGXCorrelated_Fast(a, context.NoV, context.NoL);
	half3 F = F_Schlick_UE(pixel.specularColor, context.VoH);

	return  (D * V) * F;
}

//-----------------------------------------------------------------------------
// Indirect Lighting
//-----------------------------------------------------------------------------
half3 CalculateIndirectLight(PixelData pixel, BxDFContext context, half3 viewDirWS, half3 envBRDF, half3 bakedGI)
{
#if _DEBUG_DISPLAY_ON
    if (_DebugDisplayMode == DEBUG_DISPLAY_MODE_DETAIL_LIGHTING)
    {
        pixel.baseColor = 1;
        pixel.diffuseColor = ComputeDiffuseColor(pixel.baseColor, pixel.metallic);
        pixel.specularColor = ComputeSpecularColor(pixel.baseColor, pixel.reflectance, pixel.metallic);
    }
#endif

    // Reflection
    half3 reflectVector = reflect(-viewDirWS, pixel.normalWS);
    
    // Diffuse
    half3 indirectDiffuse = pixel.diffuseColor * pixel.occlusion;

    // Specular
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, pixel.perceptualRoughness, pixel.occlusion);
#if _LASER
    indirectSpecular += GetLaserMap(reflectVector) * context.NoV;
#endif

    // Final calculation
    return indirectDiffuse * bakedGI + indirectSpecular * envBRDF;
}



//-----------------------------------------------------------------------------
// Shading Models
//-----------------------------------------------------------------------------
void DefaultLitBxDF(PixelData pixel, Light light, half lightAttenuation, BxDFContext context, inout half3 color)
{
    // Diffuse
    half3 Fd = DiffuseLobe(pixel.diffuseColor);

    // Specular
    half3 Fr = IsotropicLobe(pixel, context);

    // Final Calculation
    half3 lo = (Fd + Fr);
    color += ((lo * light.color)* (lightAttenuation * context.NoL));
}


void EvaluateBxDF(PixelData pixel, Light light, BxDFContext context, inout half3 color)
{
    // Calculate shadows
    half lightAttenuation = GetLightAttenuation(light);

    // Clamp roughness
    pixel.perceptualRoughness = clamp(pixel.perceptualRoughness, MIN_PERCEPTUAL_ROUGHNESS ,1.0h);

    // Shading
    DefaultLitBxDF(pixel, light, lightAttenuation, context, color);
	// switch(pixel.shadingModelID)
	// {
	// 	case SHADINGMODELID_DEFAULT_LIT:
	// 		DefaultLitBxDF(pixel, light, lightAttenuation, context, color);
    //         break;
	// 	default:
	// 		break;
	// }
}


#if _DEBUG_DISPLAY_ON
void DebugDisplay(PixelData pixel, Light light, BxDFContext context, half3 viewDirWS, half3 envBRDF, half3 bakedGI, inout half3 color)
{
    switch(_DebugDisplayMode)
    {
        case DEBUG_DISPLAY_MODE_ALBEDO:
            color = pixel.baseColor;
            break;
        case DEBUG_DISPLAY_MODE_ROUGHNESS:
            color = pixel.perceptualRoughness.xxx;
            break;
        case DEBUG_DISPLAY_MODE_METALLIC:
            color = pixel.metallic.xxx;
            break;
        case DEBUG_DISPLAY_MODE_OCCLUSION:
            color = pixel.occlusion.xxx;
            break;
        case DEBUG_DISPLAY_MODE_NORMAL:
            color = pixel.normalWS * 0.5 + 0.5;
            break;
        case DEBUG_DISPLAY_MODE_DETAIL_LIGHTING:
            pixel.baseColor = 1;
            pixel.diffuseColor = ComputeDiffuseColor(pixel.baseColor, pixel.metallic);
            pixel.specularColor = ComputeSpecularColor(pixel.baseColor, pixel.reflectance, pixel.metallic);
            color = CalculateIndirectLight(pixel, context, viewDirWS, envBRDF, bakedGI);
            EvaluateBxDF(pixel, light, context, color);   
            break;
        default:
            break;
        
    }
}
#endif


#endif // SHADING_MODELS_INCLUDED