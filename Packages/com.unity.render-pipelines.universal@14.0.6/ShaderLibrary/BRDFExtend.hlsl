#ifndef BRDF_EXTEND_INCLUDED
#define BRDF_EXTEND_INCLUDED


#define MEDIUMP_FLT_MAX    65504.0
#define MEDIUMP_FLT_MIN    0.00006103515625
#define saturateMediump(x) min(x, 128)


// ref: unreal engine 5.1 MobileBasePassPixelShader.usf line 320
#ifndef MIN_PERCEPTUAL_ROUGHNESS
#define MIN_PERCEPTUAL_ROUGHNESS    0.089
#endif

#ifndef MIN_N_DOT_V
#define MIN_N_DOT_V 1e-4
#endif

#ifndef MIN_ROUGHNESS
#define MIN_ROUGHNESS               0.007921
#endif

#ifndef FGDTEXTURE_RESOLUTION
#define FGDTEXTURE_RESOLUTION       64       
#endif  

#ifndef kDieletricSpec
#define kDieletricSpec              half4(0.04, 0.04, 0.04, 1.0 - 0.04)
#endif

#ifndef kSkinSpec
#define kSkinSpec                   half3(0.028, 0.028, 0.028)
#endif

#ifndef kHairSpec
#define kHairSpec                   half3(0.046, 0.046, 0.046)
#endif

#ifndef kEyeSpec
#define kEyeSpec                    half3(0.025, 0.025, 0.025)
#endif

#ifndef kWaterSpec
#define kWaterSpec                  half3(0.02, 0.02, 0.02)
#endif


half3 ComputeDiffuseColor(half3 baseColor, half metallic)
{
    return baseColor * (1 - metallic);
}

half3 ComputeSpecularColor(half3 baseColor, half reflectance, half metallic)
{
    return lerp(0.16 * reflectance.xxx  * reflectance.xxx, baseColor, metallic.xxx);
}

half3 ComputeSpecularColorDefault(half3 baseColor, half metallic)
{
    return lerp(0.04, baseColor, metallic.xxx);
}

// Two-lobe Blinn-Phong, with double glossiness on second lobe
half TwoLobeSpecular(
    float NdotL, float GeomNdotL, float NdotH, float NdotV, float LdotH,
    half reflectance, half glossiness, half specLobeFactor) 
{
    // Directional light spec
    // Evaluate NDF and visibility function:
    // Two-lobe Blinn-Phong, with double glossiness on second lobe
    float specPower = exp2(glossiness * 13.0);
    float specPower0 = specPower;
    float specPower1 = sqrt(specPower);
            	
    float ndf0 = pow(NdotH, specPower0) * (specPower0 + 2.0) * 0.5;
    float schlickSmithFactor0 = rsqrt(specPower0 * (3.14159 * 0.25) + (3.14159 * 0.5));
    float visibilityFn0 = 0.25 / (lerp(schlickSmithFactor0, 1, NdotL) *lerp(schlickSmithFactor0, 1, NdotV));
            	
    float ndf1 = pow(NdotH, specPower1) * (specPower1 + 2.0) * 0.5;
    float schlickSmithFactor1 = rsqrt(specPower1 * (3.14159 * 0.25) + (3.14159 * 0.5));
    float visibilityFn1 = 0.25 / (lerp(schlickSmithFactor1, 1, NdotL) *lerp(schlickSmithFactor1, 1, NdotV));
            	
    float ndfResult = lerp(ndf0 * visibilityFn0, ndf1 * visibilityFn1, specLobeFactor);

    float fresnel = lerp(reflectance, 1.0, pow(1.0 - LdotH, 5.0));
    float specResult = ndfResult * fresnel;
    // Darken spec where the *geometric* NdotL gets too low -
    // avoids it showing up on bumps in shadowed areas
    float edgeDarken = saturate(5.0 * GeomNdotL);
    return specResult * edgeDarken * NdotL;
}

// [Burley 2012, "Physically-Based Shading at Disney"]
float3 Diffuse_Burley( float3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH )
{
	float FD90 = 0.5 + 2 * VoH * VoH * Roughness;
	float FdV = 1 + (FD90 - 1) * Pow5( 1 - NoV );
	float FdL = 1 + (FD90 - 1) * Pow5( 1 - NoL );
	return DiffuseColor * ( (1 / PI) * FdV * FdL );
}

// GGX / Trowbridge-Reitz
// [Walter et al. 2007, "Microfacet models for refraction through rough surfaces"]
float D_GGX_UE( float a2, float NoH )
{
	float d = ( NoH * a2 - NoH ) * NoH + 1;	// 2 mad
	return a2 / ( PI*d*d );					// 4 mul, 1 rcp
}

float D_Charlie_Filament(float roughness, float NoH) {
    // Estevez and Kulla 2017, "Production Friendly Microfacet Sheen BRDF"
    float invAlpha  = 1.0 / roughness;
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * PI);
}


half GGX_Unity(float NoH, half LoH2, half roughness2, half roughness2MinusOne, half normalizationTerm)
{
    // Normal Distribution & Fersnel
    float d = NoH * NoH * roughness2MinusOne + 1.00001f;
    half specularTerm = roughness2 / ((d * d) * max(0.1h, LoH2) * normalizationTerm);
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
    return specularTerm;
}

// Roughness is actually percepturalRoughness 
half GGX_Mobile(half Roughness, float NoH)
{
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"
	float OneMinusNoHSqr = 1.0 - NoH * NoH; 
	half a = Roughness * Roughness;
	half n = NoH * a;
	half p = a / (OneMinusNoHSqr + n * n);
	half d = (1.0) * p * p;
	// clamp to avoid overlfow in a bright env
	return saturateMediump(d);
}

half D_GGX_Anisotropic(half NoH, half ToH, half BoH, half at, half ab) 
{
    // Burley 2012, "Physically-Based Shading at Disney"
    // The values at and ab are perceptualRoughness^2, a2 is therefore perceptualRoughness^4
    // The dot product below computes perceptualRoughness^8. We cannot fit in fp16 without clamping
    // the roughness to too high values so we perform the dot product and the division in fp32
    half a2 = at * ab;
    float3 d =float3(ab * ToH, at * BoH, a2 * NoH);
    float d2 = dot(d, d);//max(dot(d, d), 1e-3);
    float b2 = a2 / d2;
    return saturateMediump(a2 * b2 * b2 * INV_PI);
}

// Anisotropic GGX
// [Burley 2012, "Physically-Based Shading at Disney"]
float D_GGXaniso(float NoH, float XoH, float YoH, float ax, float ay)
{
// The two formulations are mathematically equivalent
#if 1
	float a2 = ax * ay;
	float3 V = float3(ay * XoH, ax * YoH, a2 * NoH);
	float S = dot(V, V);

	return a2 * Pow2(a2 * rcp(S)) * INV_PI;
#else
	float d = XoH*XoH / (ax*ax) + YoH*YoH / (ay*ay) + NoH*NoH;
	return min(20, 1.0f / ( PI * ax*ay * d*d ));
#endif
}

// Note: this is Blinn-Phong, the original paper uses Phong.
half3 D_KajiyaKay(half ToH, half specularExponent)
{
    half sinTHSq = saturate(1.0 - ToH * ToH);

    half dirAttn = saturate(ToH + 1.0); // Evgenii: this seems like a hack? Do we really need this?

                                           // Note: Kajiya-Kay is not energy conserving.
                                           // We attempt at least some energy conservation by approximately normalizing Blinn-Phong NDF.
                                           // We use the formulation with the NdotL.
                                           // See http://www.thetenthplanet.de/archives/255.
    half n = specularExponent;
    half norm = (n + 2) * rcp(2 * PI);

    return dirAttn * norm * PositivePow(sinTHSq, 0.5 * n);
}

// Appoximation of joint Smith term for GGX
// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJointApprox( float a2, float NoV, float NoL )
{
	float a = sqrt(a2);
	float Vis_SmithV = NoL * ( NoV * ( 1 - a ) + a );
	float Vis_SmithL = NoV * ( NoL * ( 1 - a ) + a );
	return 0.5 * rcp( Vis_SmithV + Vis_SmithL );
}

float V_SmithGGXCorrelated_Fast(half roughness, half NoV, half NoL)
{
    // Hammon 2017, "PBR Diffuse Lighting for GGX+Smith Microsurfaces"
    float v = 0.5 / lerp(2.0 * NoL * NoV, NoL + NoV, roughness);
    return saturateMediump(v);
}

float V_SmithGGXCorrelated_Anisotropic(
    half ToV, half ToL, 
    half BoV, half BoL, 
    half NoV, half NoL,
    half at, half ab) 
{
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    // TODO: lambdaV can be pre-computed for all the lights, it should be moved out of this function
    half lambdaV = NoL * length(half3(at * ToV, ab * BoV, NoV));
    half lambdaL = NoV * length(half3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL);
    return saturateMediump(v);
}

// [Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"]
float Vis_SmithJoint_UE(float a2, float NoV, float NoL) 
{
	float Vis_SmithV = NoL * sqrt(NoV * (NoV - NoV * a2) + a2);
	float Vis_SmithL = NoV * sqrt(NoL * (NoL - NoL * a2) + a2);
	return 0.5 * rcp(Vis_SmithV + Vis_SmithL);
}

half V_Neubelt(half NoV, half NoL) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    return saturateMediump(rcp(4.0 * (NoL + NoV - NoL * NoV)));
}

half V_Kelemen(float LoH) {
    // Kelemen 2001, "A Microfacet Based Coupled Specular-Matte BRDF Model with Importance Sampling"
    return saturateMediump(0.25 / (LoH * LoH));
}


float Vis_Implicit()
{
	return 0.25;
}

// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
float3 F_Schlick_UE( float3 SpecularColor, float VoH )
{
	float Fc = Pow5( 1 - VoH );					// 1 sub, 3 mul
	//return Fc + (1 - Fc) * SpecularColor;		// 1 add, 3 mad
	
	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	return saturate( 50.0 * SpecularColor.g ) * Fc + (1 - Fc) * SpecularColor;
}






half3 F_Schlick_Fast(half3 f0, float VoH)
{
    half f = Pow5(1.0 - VoH);
    return f + f0 * (1.0 - f);
}

half3 F_SchlickRoughness(half cosTheta, half3 F0, half roughness)
{
    return F0 + (max(1.0 - roughness, F0) - F0) * pow(max(1.0 - cosTheta, 0.0), 5.0);
}


float Fresnel_Dielectric(float3 Incoming, float3 Normal, float eta)
{
    // compute fresnel reflectance without explicitly computing
    // the refracted direction
    float c = abs(dot(Incoming, Normal));
    float g = eta * eta - 1.0 + c * c;

    if (g > 0.0)
    {
        g = sqrt(g);
        float A = (g - c) / (g + c);
        float B = (c * (g + c) - 1.0) / (c * (g - c) + 1.0);

        return 0.5 * A * A * (1.0 + B * B);
    }

    return 1.0; // TIR (no refracted component)
}

half Fd_Lambert() {
    return INV_PI;
}

// Convert a roughness and an anisotropy factor into GGX alpha values respectively for the major and minor axis of the tangent frame
void GetAnisotropicRoughness(float Alpha, float Anisotropy, out float ax, out float ay)
{
#if 1
	// Anisotropic parameters: ax and ay are the roughness along the tangent and bitangent	
	// Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
	ax = max(Alpha * (1.0 + Anisotropy), 0.001f);
	ay = max(Alpha * (1.0 - Anisotropy), 0.001f);
#else
	float K = sqrt(1.0f - 0.95f * Anisotropy);
	ax = max(Alpha / K, 0.001f);
	ay = max(Alpha * K, 0.001f);
#endif
}

// Energy conserving wrap diffuse term, does *not* include the divide by pi
// http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
float Fd_Wrap(float NoL, float w) {
    return saturate((NoL + w) / Pow2(1.0 + w));
}

float D_InvGGX(float a2, float NoH)
{
    float A = 4;
    float d = (NoH - a2 * NoH) * NoH + a2;
    return rcp(PI * (1 + A * a2)) * (1 + 4 * a2 * a2 / (d * d));
}

float GGXAniso(float TOH, float BOH, float NOH, float roughT, float roughB)
{
    float f = TOH * TOH / (roughT * roughT) + BOH * BOH / (roughB *
        roughB) + NOH * NOH;
    return 1.0 / (f * f * roughT * roughB);
}


half2 EnvBRDFApproxLazarov(half Roughness, half NoV)
{
	// [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
	// Adaptation to fit our G term.
	half4 c0 = half4(-1.0h, -0.0275h, -0.572h, 0.022h);
	half4 c1 = half4(1.0h, 0.0425h, 1.04h, -0.04h);
	half4 r = Roughness * c0 + c1;
	half a004 = min(r.x * r.x, exp2(-9.28h * NoV)) * r.x + r.y;
	half2 AB = half2(-1.04h, 1.04h) * a004 + r.zw;
	return AB;
}

half3 EnvBRDFApprox( half3 specularColor, half2 energy)
{
	// Anything less than 2% is physically impossible and is instead considered to be shadowing
	// Note: this is needed for the 'specular' show flag to work, since it uses a SpecularColor of 0
	float F90 = saturate(50.0 * specularColor.g);

	return specularColor * energy.x + F90 * energy.y;
}

half3 EnergyCompensation(half3 specularColor, half2 energy)
{
	half multiscatterDFGX  = energy.x + energy.y;
    return 1.0 + specularColor * (rcp(multiscatterDFGX) - 1.0);
}

half EnvBRDFApproxNonmetal( half Roughness, half NoV )
{
	// Same as EnvBRDFApprox( 0.04, Roughness, NoV )
	const half2 c0 = { -1, -0.0275 };
	const half2 c1 = { 1, 0.0425 };
	half2 r = Roughness * c0 + c1;
	return min( r.x * r.x, exp2( -9.28 * NoV ) ) * r.x + r.y;
}


half DielectricSpecularToF0(half reflectance)
{
	return 0.08f * reflectance;
}

half3 computeF0(half3 baseColor, half metallic, half reflectance) 
{
    return lerp(DielectricSpecularToF0(reflectance).xxx, baseColor, metallic.xxx);
}



half3 SubsurfaceShadingTwoSided(half3 SubsurfaceColor, half3 L, half3 V, half3 N)
{
    // http://blog.stevemcauley.com/2011/12/03/energy-conserving-wrapped-diffuse/
    half Wrap = 0.5;
    half NoL = saturate((dot(-N, L) + Wrap) / ((1 + Wrap)*(1 + Wrap)));

    // GGX scatter distribution
    half VoL = saturate(dot(V, -L));
    half a = 0.6;
    half a2 = a * a;
    half d = (VoL * a2 - VoL) * VoL + 1;	// 2 mad
    half GGX = (a2 / 3.1415926) / (d * d);		// 2 mul, 1 rcp
    return NoL * GGX * SubsurfaceColor;
}


half3 SubsurfaceShadingSubsurface(half3 SubsurfaceColor, half Opacity, half3 L, half3 V, half3 N, half sssMax)
{
    half3 H = SafeNormalize(V + L);

    // to get an effect when you see through the material
    // hard coded pow constant
    half InScatter = pow(saturate(dot(L, -V)), 12) * lerp(3, .1, Opacity);

    // wrap around lighting, /(PI*2) to be energy consistent (hack do get some view dependnt and light dependent effect)
    // Opacity of 0 gives no normal dependent lighting, Opacity of 1 gives strong normal contribution
    half NormalContribution = saturate(dot(N, H) * Opacity + 1 - Opacity);

    half BackScatter = /*GBuffer.GBufferAO **/ NormalContribution / (PI * 2);

    // lerp to never exceed 1 (energy conserving)
    return SubsurfaceColor * lerp(BackScatter, sssMax, InScatter);
}


#endif // BRDF_EXTEND_INCLUDED