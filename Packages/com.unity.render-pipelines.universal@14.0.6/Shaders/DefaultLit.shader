// todo : remove unused feature

Shader "Universal Render Pipeline/DefaultLit"
{
    Properties
    {
        // Base
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)

        // PBR
        [NoScaleOffset] _MixMap("Roughness, Metallic, Occlussion", 2D) = "white" {}
        _Roughness ("Rougthness", Range(0, 1)) = 0.75
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Occlusion ("Occlusion", Range(0, 1)) = 1
        _Reflectance ("Reflectance", Range(0, 1)) = 0.5

        // Normal
        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Range(0, 2)) = 1.0

        // Emission
        [Toggle(_EMISSION)] _Emission ("Emission", Float) = 0.0
        _EmissionMap ("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor("Emission", Color) = (0, 0, 0)

        // Laser
        [Toggle(_LASER)] _Laser ("Laser", Float) = 0.0
        _LaserMap ("Laser Map", 2D) = "white" {}
        _LaserValue ("Laser Value", Range(0, 1)) = 0.5

        // Rim Light
        [Toggle(_RIM_LIGHT)] _Rim ("Rim Light", Float) = 0.0
        [HDR]_RimColor ("Rim Color", Color) = (1, 1, 1)
        _RimParams ("Rim Params", Vector) = (0, 1, 1)
        _RimDirection ("Rim Direction", Float) = 0.0

        // Surface parameters
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _ReceiveShadows("Receive Shadows", Float) = 1.0
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
        [Toggle(_DITHER_CLIPPING)] [HideInInspector] _DitherClipping ("Enable Dither Clipping", Float) = 0.0
        [Toggle(_FLIP_NORMAL)] [HideInInspector] _FlipNormal ("Flip Normal", Float) = 0.0

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)

    }

    SubShader
    {
        HLSLINCLUDE

        // -------------------------------------
        // Material Keywords
        #pragma shader_feature _ALPHATEST_ON
        #pragma shader_feature _DITHER_CLIPPING
        #pragma shader_feature _FLIP_NORMAL
        #pragma shader_feature _RECEIVE_SHADOWS_OFF
        #pragma shader_feature _NORMALMAP
        #pragma shader_feature _MIXMAP
        #pragma shader_feature _EMISSION
        #pragma shader_feature _LASER
        #pragma shader_feature _RIM_LIGHT 
        #pragma shader_feature _ _RIM_FRONT _RIM_BACK

        // -------------------------------------
        // Pipeline keywords
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
        #pragma multi_compile _ _ADDITIONAL_LIGHTS _ADDITIONAL_LIGHTS_VERTEX 
        #pragma multi_compile _SHADOWS_SOFT
        #pragma multi_compile _ LIGHTMAP_ON
        #pragma shader_feature _DEBUG_DISPLAY_ON

        //--------------------------------------
        // GPU Instancing
        #pragma multi_compile_instancing
        #pragma multi_compile _ DOTS_INSTANCING_ON
        // #pragma enable_d3d11_debug_symbols

        #include "Packages/com.unity.render-pipelines.universal/Shaders/DefaultLitInput.hlsl"
        
        ENDHLSL


        // Universal Pipeline tag is required. If Universal render pipeline is not set in the graphics settings
        // this Subshader will fail. One can add a subshader below or fallback to Standard built-in to make this
        // material work with both Universal Render Pipeline and Builtin Unity Pipeline
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "True"}

        Pass
        {
            // Lightmode matches the ShaderPassName set in UniversalRenderPipeline.cs. SRPDefaultUnlit and passes with
            // no LightMode tag are also rendered by Universal Render Pipeline
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}
            Blend [_SrcBlend][_DstBlend]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma vertex DefaultLitVertex
            #pragma fragment DefaultLitFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DefaultLitForwardPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags {"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float2 uv0          : TEXCOORD0;
                float2 uv1          : TEXCOORD1;
                float2 uv2          : TEXCOORD2;
            #ifdef _TANGENT_TO_WORLD
                float4 tangentOS     : TANGENT;
            #endif
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Varyings UniversalVertexMeta(Attributes input)
            {
                Varyings output;
                output.positionCS = MetaVertexPosition(input.positionOS, input.uv1, input.uv2, unity_LightmapST, unity_DynamicLightmapST);
                output.uv = TRANSFORM_TEX(input.uv0, _BaseMap);
                return output;
            }

            half4 UniversalFragmentMeta(Varyings input) : SV_Target
            {
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_LinearRepeat, input.uv) * _BaseColor;
                #if _ALPHATEST_ON
                    clip(baseColor.a - _Cutoff);
                #endif

                half4 mixValue = SAMPLE_TEXTURE2D(_MixMap, sampler_LinearRepeat, input.uv);
                half a2 = Pow4(clamp(mixValue.b, MIN_PERCEPTUAL_ROUGHNESS, 1.0h));
                half metallic = mixValue.a;

                half3 diffuseColor = ComputeDiffuseColor(baseColor.rgb, metallic);
                half3 specularColor = ComputeSpecularColorDefault(baseColor.rgb, metallic);
            #if _EMISSION
                half3 emission = GetEmission(input.uv);
            #else
                half3 emission = 0;
            #endif

                MetaInput metaInput;
                metaInput.Albedo = diffuseColor * specularColor * a2 * 0.5;
                metaInput.Emission = emission;
                return  MetaFragment(metaInput);
            }
            ENDHLSL
        }
    }

    CustomEditor "DefaultLitShaderGUI"
    FallBack "Hidden/InternalErrorShader"
}
