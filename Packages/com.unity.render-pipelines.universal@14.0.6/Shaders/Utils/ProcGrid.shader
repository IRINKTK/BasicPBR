Shader "Universal Render Pipeline/Procedural/ProcGrid"
{
    Properties
    {
        [HideInInspector]_BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _GridSize ("Grid Size", Float) = 1
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        HLSLINCLUDE

        // -------------------------------------
        // Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _SHADOWS_SOFT
        #pragma shader_feature _DEBUG_DISPLAY_ON

        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShadingModels.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4  _BaseMap_ST;
        half4   _BaseColor;
        half    _GridSize;
        half    _Cutoff;
        CBUFFER_END

        #define CHECKER_COLOR_1     half3(0.292, 0.292, 0.292) * _BaseColor.rgb
        #define CHECKER_COLOR_2     half3(0.24, 0.24, 0.24) * _BaseColor.rgb * 0.5
        #define CHECKER_ROUGH_1     0.5
        #define CHECKER_ROUGH_2     0.65
        #define LINE_COLOR          half3(0.339, 0.339, 0.339)
        #define EDGE_PARAMS         half3(1.04, 28.2, 0.3)

        void CalculateProcGrid(Texture2D gridMap, half gridSize, half3 normalWS, float3 positionWS, inout half checkerMask, inout half lineMask)
        {
            float3 texcoordWS = positionWS / gridSize;

            // Line
            half x0 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.xy).x;
            half x1 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.zy).x;
            half x2 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.xz).x;

            // Checker
            texcoordWS *= 0.5;
            half y0 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.xy).y;
            half y1 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.zy).y;
            half y2 = SAMPLE_TEXTURE2D(gridMap, sampler_LinearRepeat, texcoordWS.xz).y;

            // Normal
            half X = CheapContrast(abs(normalWS.x), 1);
            half Y = CheapContrast(abs(normalWS.y), 1);

            lineMask = 1 - lerp( lerp(x0, x1, X), x2, Y );
            checkerMask = 1 - lerp( lerp(y0, y1, X), y2, Y );
        }

        half CalculateEdgeDarken(half3 normalWS)
        {
            return saturate( pow( abs(normalWS.y * EDGE_PARAMS.x) + 1e-4, EDGE_PARAMS.y) + EDGE_PARAMS.z );
        }

        ENDHLSL



        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True" "ShaderModel"="4.5"}

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM
            #pragma vertex ProcGridVertex
            #pragma fragment ProcGridFragment

            struct AttributesProcGrid
            {
                float4 positionOS       : POSITION;
                half3  normalOS         : NORMAL;
                float2 texcoord         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsProcGrid
            {
                float2 texcoord         : TEXCOORD0;
                float3 normalWS         : TEXCOORD1;
                half3 vertexSH          : TEXCOORD2;
                float3 positionWS       : TEXCOORD3;
                float4 positionCS       : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            VaryingsProcGrid ProcGridVertex(AttributesProcGrid i)
            {
                VaryingsProcGrid o;
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_TRANSFER_INSTANCE_ID(i, o);

                // Position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(i.positionOS.xyz);
                o.positionCS = vertexInput.positionCS;
                o.positionWS = vertexInput.positionWS;

                // Normal
                VertexNormalInputs normalInput = GetVertexNormalInputs(i.normalOS);
                o.normalWS = normalInput.normalWS;

                // GI
                OUTPUT_SH(o.normalWS.xyz, o.vertexSH);

                // UV
                o.texcoord = i.texcoord * _GridSize.xx;

                return o;
            }

            void EvaluatePixelDataProcGrid(VaryingsProcGrid i, inout PixelData pixel)
            {
                half checkerMask = 0;
                half lineMask = 0;
                i.normalWS = normalize(i.normalWS);
                CalculateProcGrid(_BaseMap, _GridSize, i.normalWS, i.positionWS, checkerMask, lineMask);

                // Edge darken
                half edgeDarken = CalculateEdgeDarken(i.normalWS);

                // Base Color
                half3 gridColor = lerp(CHECKER_COLOR_1, CHECKER_COLOR_2, checkerMask) * edgeDarken;
                half3 baseColor = lerp(LINE_COLOR, gridColor, lineMask);
                pixel.baseColor = baseColor;

                // Normal
                pixel.normalWS = i.normalWS;

                // Roughness
                pixel.perceptualRoughness = lerp( 0.3, lerp(CHECKER_ROUGH_1, CHECKER_ROUGH_2, checkerMask), lineMask); 

                // Metallic
                pixel.metallic = 1 - lineMask;

                // Occlusion
                pixel.occlusion = 1;

                // Reflectance
                pixel.reflectance = 0.5;

                // Diffuse color
                pixel.diffuseColor = ComputeDiffuseColor(pixel.baseColor, pixel.metallic);
                
                // Specular color (F0)
                pixel.specularColor = ComputeSpecularColor(pixel.baseColor, pixel.reflectance, pixel.metallic);
    
                // Shading model id
                pixel.shadingModelID = SHADINGMODELID_DEFAULT_LIT;

            }

            half4 ProcGridFragment(VaryingsProcGrid i) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);

                // Calculate pixeldata
                PixelData pixel = (PixelData)0;
                EvaluatePixelDataProcGrid(i, pixel);

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

                // Direct light
                EvaluateBxDF(pixel, light, context, color); 

            #if _DEBUG_DISPLAY_ON
                DebugDisplay(pixel, light, context, viewDirWS, envBRDF, bakedGI, color);
            #endif   

                return half4(color, pixel.alpha);
            }
            
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            // -------------------------------------
            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            
            ENDHLSL
        }
    }
}
