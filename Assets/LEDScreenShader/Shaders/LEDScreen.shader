Shader "llcheesell/LEDScreen"
{
    Properties
    {
        // =====================================================================
        // Input Screen
        // =====================================================================
        [Header(Input Screen)]
        [Space(5)]
        _InputTex         ("Input Screen Texture", 2D)  = "white" {}

        // =====================================================================
        // LED Subpixel
        // =====================================================================
        [Space(10)]
        [Header(LED Subpixel)]
        [Space(5)]
        [NoScaleOffset]
        _LEDTex           ("LED Mask (RGB = subpixel mask)", 2D) = "white" {}
        _LEDTilingX       ("LED Columns", Float)  = 100
        _LEDTilingY       ("LED Rows",    Float)  = 56

        // =====================================================================
        // Procedural LED
        // =====================================================================
        [Space(10)]
        [Header(Procedural LED)]
        [Space(5)]
        [Toggle]
        _ProceduralLEDEnabled  ("Enable Procedural LED", Float) = 1.0
        [Enum(Honeycomb Triangle,0,Horizontal Stripe,1,Vertical Rectangle,2)]
        _ProceduralLEDPattern  ("Pattern", Float) = 0
        _ProceduralDotRadius   ("Dot Radius", Range(0.3, 1.0)) = 0.8
        _ProceduralHotspotStrength ("Hotspot Strength", Range(0, 1)) = 0.3
        _ProceduralGlowRadius  ("Glow Radius", Range(0, 0.5)) = 0.1
        _ProceduralGlowIntensity ("Glow Intensity", Range(0, 1)) = 0.15
        _ProceduralHighlightStrength ("Highlight Strength", Range(0, 2)) = 0.5

        // =====================================================================
        // Emission
        // =====================================================================
        [Space(10)]
        [Header(Emission)]
        [Space(5)]
        [HDR]
        _EmissionColor         ("Emission Color", Color) = (1,1,1,1)
        _IntensityMultiplier   ("Intensity", Range(0.1, 50)) = 1.0

        // =====================================================================
        // LED Fade (Screen-Space Density)
        // =====================================================================
        [Space(10)]
        [Header(LED Fade)]
        [Space(5)]
        _FadeStart             ("Fade Start (coarse = subpixel)", Range(0.05, 1.0)) = 0.3
        _FadeEnd               ("Fade End (fine = flat emission)", Range(0.1, 2.0)) = 0.8
        _FadeBias              ("Fade Bias", Range(0.1, 3.0)) = 1.0

        // =====================================================================
        // Cabinet Grid
        // =====================================================================
        [Space(10)]
        [Header(Cabinet Grid)]
        [Space(5)]
        [Toggle]
        _CabinetGridEnabled        ("Enable Cabinet Grid", Float) = 0.0
        _CabinetColumns            ("Columns",  Float)               = 10
        _CabinetRows               ("Rows",     Float)               = 6
        _CabinetSeamWidth          ("Seam Width",  Range(0, 0.05))   = 0.005
        _CabinetSeamDepth          ("Seam Depth",  Range(0, 1))      = 0.3
        _CabinetBrightnessVariance ("Brightness Variance", Range(0, 0.1)) = 0.02

        // =====================================================================
        // Surface Material
        // =====================================================================
        [Space(10)]
        [Header(Surface Material)]
        [Space(5)]
        [Toggle]
        _BaseMaterialEnabled ("Enable Base Material", Float) = 0.0
        [Toggle]
        _SurfaceUVLinkLED ("Link UV to LED Tiling", Float) = 1.0
        _BaseColor      ("Base Color", Color)  = (1, 1, 1, 1)
        _BaseMap        ("Base Map",   2D)     = "black" {}

        [Space(5)]
        [NoScaleOffset] [Normal]
        _NormalMap      ("Normal Map", 2D) = "bump" {}
        _NormalStrength ("Normal Strength", Range(0, 2)) = 1.0

        [Space(5)]
        [NoScaleOffset]
        _MaskMap        ("Mask Map (R=Metal G=AO B=Detail A=Smooth)", 2D) = "white" {}
        _Metallic       ("Metallic",   Range(0, 1)) = 0.0
        _Smoothness     ("Smoothness", Range(0, 1)) = 0.3
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 1.0

        // =====================================================================
        // Rendering
        // =====================================================================
        [Space(10)]
        [Header(Rendering)]
        [Space(5)]
        [Enum(UnityEngine.Rendering.CullMode)]
        _CullMode ("Cull Mode", Float) = 2

        [Space(10)]
        [Header(TAA Ghost Prevention)]
        [Space(5)]
        [Toggle]
        _InvalidateMotionVectors ("Force Large Motion Vectors", Float) = 1.0

        // =====================================================================
        // Debug
        // =====================================================================
        [Space(10)]
        [Header(Debug)]
        [Space(5)]
        [Enum(Off,0,Fade Value,1)]
        _DebugFadeVis ("Fade Visualization", Float) = 0
    }

    // ========================================================================
    // CGINCLUDE: Shared rendering code (Built-in compatible, compiles everywhere)
    //
    // Uses UnityCG.cginc / Lighting.cginc / AutoLight.cginc — available in
    // ALL pipeline configurations. Each SubShader only differs by Tags.
    // Runtime SubShader selection is driven by "RenderPipeline" tag.
    // ========================================================================
    CGINCLUDE

    #include "LEDScreenBuiltin.hlsl"
    #include "LEDScreenCore.hlsl"

    // ------------------------------------------------------------------
    // Forward pass structures + entry points
    // ------------------------------------------------------------------
    struct Attributes
    {
        float4 positionOS : POSITION;
        float3 normalOS   : NORMAL;
        float4 tangentOS  : TANGENT;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS   : SV_POSITION;
        float2 uv           : TEXCOORD0;
        float3 positionWS   : TEXCOORD1;
        float3 normalWS     : TEXCOORD2;
        float4 tangentWS    : TEXCOORD3;
        UNITY_FOG_COORDS(4)
        UNITY_SHADOW_COORDS(5)
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings vert(Attributes IN)
    {
        Varyings OUT;
        UNITY_INITIALIZE_OUTPUT(Varyings, OUT);
        UNITY_SETUP_INSTANCE_ID(IN);
        UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

        float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);

        OUT.positionCS = TransformWorldToHClip(posWS);
        OUT.positionWS = posWS;
        OUT.normalWS   = UnityObjectToWorldNormal(IN.normalOS);
        OUT.tangentWS  = float4(UnityObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w);
        OUT.uv         = IN.texcoord;

        UNITY_TRANSFER_FOG(OUT, OUT.positionCS);
        UNITY_TRANSFER_SHADOW(OUT, IN.texcoord);

        return OUT;
    }

    half4 frag(Varyings IN) : SV_Target
    {
        UNITY_SETUP_INSTANCE_ID(IN);

        // ---- UV computation ----
        float2 inputUV = GetInputUV(IN.uv);
        float2 ledUV   = GetLEDUV(IN.uv);

        // ---- LED fade ----
        float fade = ComputeFade(ledUV);

        // ---- Debug ----
        if (_DebugFadeVis > 0.5) return half4(DebugFadeColor(fade), 1.0);

        // ---- LED emission ----
        float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
        float3 emission  = ledResult.rgb;

        // ---- Cabinet grid (emission + normal) ----
        float3 normalTS = float3(0, 0, 1);
        float emissiveScale = 1.0;
        ApplyCabinetGrid(IN.uv, normalTS, emissiveScale);
        emission *= emissiveScale;

        // ---- Base Material OFF: emission only (PBR スキップ) ----
        UNITY_BRANCH
        if (_BaseMaterialEnabled < 0.5)
        {
            float3 finalColor = emission;
            UNITY_APPLY_FOG(IN.fogCoord, finalColor);
            return half4(finalColor, 1.0);
        }

        // ================================================================
        // Base Material ON: フル PBR ライティング
        // ================================================================
        float2 baseTexUV = GetBaseUV(IN.uv);

        // ---- Base color ----
        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseTexUV) * _BaseColor;

        // ---- Normal map (cabinet grid ノーマルに加算) ----
        half3 normalMapVal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, baseTexUV));
        normalTS.xy += normalMapVal.xy * _NormalStrength;
        normalTS = normalize(normalTS);

        // ---- Mask Map: R=Metallic, G=AO, B=Detail(unused), A=Smoothness ----
        half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, baseTexUV);
        float metallic            = maskMap.r * _Metallic;
        float ao                  = lerp(1.0, maskMap.g, _OcclusionStrength);
        float smoothness          = maskMap.a * _Smoothness;
        float perceptualRoughness = 1.0 - smoothness;
        float roughness           = max(perceptualRoughness * perceptualRoughness, 6.103515625e-5);

        // ---- TBN ----
        float sgn = IN.tangentWS.w;
        float3 bitangent = sgn * cross(IN.normalWS, IN.tangentWS.xyz);
        half3x3 TBN = half3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
        half3 normalWS = normalize(mul(normalTS, TBN));

        // ---- Lighting (GGX / Cook-Torrance) ----
        float3 viewDir  = normalize(_WorldSpaceCameraPos - IN.positionWS);
        float3 lightDir = _WorldSpaceLightPos0.xyz;

        float NdotV = max(saturate(dot(normalWS, viewDir)), 1e-4);
        float NdotL = saturate(dot(normalWS, lightDir));
        float3 halfDir = normalize(lightDir + viewDir);
        float NdotH = saturate(dot(normalWS, halfDir));
        float LdotH = saturate(dot(lightDir, halfDir));

        UNITY_LIGHT_ATTENUATION(atten, IN, IN.positionWS);
        float3 ambient = ShadeSH9(float4(normalWS, 1.0));

        float3 specColor    = lerp(float3(0.04, 0.04, 0.04), baseColor.rgb, metallic);
        float3 diffuseAlbedo = baseColor.rgb * (1.0 - metallic);

        // Direct lighting
        float  D = GGXTerm(NdotH, roughness);
        float  V = SmithJointGGXVisibilityTerm(NdotL, NdotV, roughness);
        float3 F = FresnelTerm(specColor, LdotH);

        float3 directSpecular = max(0.0, D * V * F * UNITY_PI);
        float3 directLighting = (diffuseAlbedo + directSpecular)
                              * _LightColor0.rgb * NdotL * atten;

        // Indirect lighting
        float3 ambientDiffuse = diffuseAlbedo * ambient * ao;

        float surfaceReduction = 1.0 / (roughness * roughness + 1.0);
        float grazingTerm = saturate(smoothness + (1.0 - max(max(specColor.r, specColor.g), specColor.b)));
        float3 envFresnel = FresnelLerp(specColor, grazingTerm, NdotV);

        float3 reflectDir = reflect(-viewDir, normalWS);
        float mip = perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;
        float3 envReflection = float3(0, 0, 0);
        #if defined(UNITY_SPECCUBE_BOX_PROJECTION)
            float3 projDir = reflectDir;
            UNITY_BRANCH
            if (unity_SpecCube0_ProbePosition.w > 0.0)
            {
                float3 nrDir = normalize(reflectDir);
                float3 rbmax = (unity_SpecCube0_BoxMax.xyz - IN.positionWS) / nrDir;
                float3 rbmin = (unity_SpecCube0_BoxMin.xyz - IN.positionWS) / nrDir;
                float3 rbminmax = (nrDir > 0.0) ? rbmax : rbmin;
                float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);
                projDir = IN.positionWS - unity_SpecCube0_ProbePosition.xyz + nrDir * fa;
            }
            envReflection = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, projDir, mip),
                                       unity_SpecCube0_HDR);
        #else
            envReflection = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectDir, mip),
                                       unity_SpecCube0_HDR);
        #endif
        float3 indirectSpecular = envReflection * envFresnel * surfaceReduction * ao;

        // ---- Combine ----
        float3 finalColor = directLighting + ambientDiffuse
                          + indirectSpecular
                          + emission;

        UNITY_APPLY_FOG(IN.fogCoord, finalColor);
        return half4(finalColor, 1.0);
    }

    // ------------------------------------------------------------------
    // Depth-only pass structures + entry points
    // ------------------------------------------------------------------
    struct DepthAttributes
    {
        float4 positionOS : POSITION;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct DepthVaryings
    {
        float4 positionCS : SV_POSITION;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    DepthVaryings vertDepth(DepthAttributes IN)
    {
        DepthVaryings OUT;
        UNITY_SETUP_INSTANCE_ID(IN);
        UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
        OUT.positionCS = TransformWorldToHClip(TransformObjectToWorld(IN.positionOS.xyz));
        return OUT;
    }

    half4 fragDepth(DepthVaryings IN) : SV_Target
    {
        return 0;
    }

    // ------------------------------------------------------------------
    // MotionVectors pass fragment (CG — SRP include 不要)
    //
    // 意図的に大きなモーションベクターを出力。
    // TAA/DLSS はリプロジェクション先が画面外となり、
    // ヒストリーサンプルを棄却して現在フレームのみを使用する。
    // ------------------------------------------------------------------
    half4 fragMotionVectors(DepthVaryings IN) : SV_Target
    {
        return (_InvalidateMotionVectors > 0.5)
            ? half4(2.0, 2.0, 0.0, 0.0)
            : half4(0.0, 0.0, 0.0, 0.0);
    }

    // ------------------------------------------------------------------
    // ShadowCaster pass (Built-in パイプライン用)
    //
    // V2F_SHADOW_CASTER / TRANSFER_SHADOW_CASTER_NORMALOFFSET /
    // SHADOW_CASTER_FRAGMENT は Built-in パイプライン専用のマクロ。
    // unity_LightShadowBias を用いて頂点シェーダーでバイアスを適用する。
    //
    // HDRP/URP ではバイアスをシャドウサンプリング時に処理するため、
    // これらのマクロは使用せず、vertDepth/fragDepth を流用する。
    // ------------------------------------------------------------------
    struct ShadowVaryings
    {
        V2F_SHADOW_CASTER;
        UNITY_VERTEX_INPUT_INSTANCE_ID
        UNITY_VERTEX_OUTPUT_STEREO
    };

    ShadowVaryings vertShadow(appdata_base v)
    {
        ShadowVaryings o;
        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_TRANSFER_INSTANCE_ID(v, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
        return o;
    }

    float4 fragShadow(ShadowVaryings i) : SV_Target
    {
        SHADOW_CASTER_FRAGMENT(i)
    }

    ENDCG

    // ========================================================================
    // URP SubShader
    // ========================================================================
    SubShader
    {
        PackageRequirements
        {
            "com.unity.render-pipelines.universal"
        }

        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Cull [_CullMode]

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            ENDCG
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0

            CGPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            // URP はシャドウバイアスをサンプリング時に適用するため、
            // 頂点シェーダーでは単純に深度を書き込むだけで良い。
            // Built-in 用の V2F_SHADOW_CASTER / TRANSFER_SHADOW_CASTER_NORMALOFFSET は
            // URP では不正なバイアスの原因となるため使用しない。
            CGPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing
            ENDCG
        }

        // MotionVectors パス: 大きなモーションベクターを出力し、
        // TAA/DLSS にヒストリーサンプルを棄却させる。
        // LED パネルは映像コンテンツが毎フレーム変化するため、
        // テンポラル蓄積がゴースト/残像の原因となる。
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            CGPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragMotionVectors
            #pragma multi_compile_instancing
            ENDCG
        }
    }

    // ========================================================================
    // HDRP SubShader
    // ========================================================================
    SubShader
    {
        PackageRequirements
        {
            "com.unity.render-pipelines.high-definition"
        }

        Tags
        {
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Cull [_CullMode]

        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }

            // HDRP: DepthForwardOnly が先に深度を書き込み、
            // ForwardOnly は ZTest Equal で一致ピクセルのみ描画。
            // HLSLPROGRAM + HDRP インクルードにより、両パスで同一の
            // 行列変換パスを使用し、深度値の一致を保証する。
            ZTest Equal
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex VertForwardHDRP
            #pragma fragment FragForwardHDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "LEDScreenHDRP.hlsl"
            #include "LEDScreenCore.hlsl"

            struct ForwardAttributesHDRP
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 texcoord   : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ForwardVaryingsHDRP
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 positionRWS  : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float4 tangentWS    : TEXCOORD3;
            };

            ForwardVaryingsHDRP VertForwardHDRP(ForwardAttributesHDRP input)
            {
                ForwardVaryingsHDRP output = (ForwardVaryingsHDRP)0;
                UNITY_SETUP_INSTANCE_ID(input);

                float3 posRWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS  = TransformWorldToHClip(posRWS);
                output.positionRWS = posRWS;
                output.normalWS    = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS   = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
                output.uv          = input.texcoord;
                return output;
            }

            float4 FragForwardHDRP(ForwardVaryingsHDRP input) : SV_Target
            {
                float2 inputUV = GetInputUV(input.uv);
                float2 ledUV   = GetLEDUV(input.uv);

                float fade = ComputeFade(ledUV);

                // Debug
                if (_DebugFadeVis > 0.5) return float4(DebugFadeColor(fade), 1.0);

                float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
                float3 emission  = ledResult.rgb;

                float3 normalTS = float3(0, 0, 1);
                float emissiveScale = 1.0;
                ApplyCabinetGrid(input.uv, normalTS, emissiveScale);
                emission *= emissiveScale;

                return float4(emission, 1.0);
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthForwardOnly"
            Tags { "LightMode" = "DepthForwardOnly" }
            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex VertDepthHDRP
            #pragma fragment FragDepthHDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            struct DepthAttributesHDRP
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct DepthVaryingsHDRP
            {
                float4 positionCS : SV_POSITION;
            };

            DepthVaryingsHDRP VertDepthHDRP(DepthAttributesHDRP input)
            {
                DepthVaryingsHDRP output;
                UNITY_SETUP_INSTANCE_ID(input);
                float3 posRWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(posRWS);
                return output;
            }

            float4 FragDepthHDRP(DepthVaryingsHDRP input) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            // HDRP のシャドウマップレンダリングでは、ライトの VP マトリクスが
            // SRP 固有の定数バッファ (ShaderVariablesGlobal) で設定される。
            // CGPROGRAM は UnityCG.cginc の変数宣言レイアウトが
            // HDRP の定数バッファと競合し、シャドウマップに不正な深度値が
            // 書き込まれるため、HLSLPROGRAM + HDRP インクルードを使用する。
            //
            // ShaderVariables.hlsl は以下を推移的にインクルード:
            //   - UnityInstancing.hlsl (インスタンシング対応)
            //   - SpaceTransforms.hlsl (TransformObjectToWorld, TransformWorldToHClip)
            HLSLPROGRAM
            #pragma vertex VertShadowHDRP
            #pragma fragment FragShadowHDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            struct ShadowAttributesHDRP
            {
                float3 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct ShadowVaryingsHDRP
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryingsHDRP VertShadowHDRP(ShadowAttributesHDRP input)
            {
                ShadowVaryingsHDRP output;
                UNITY_SETUP_INSTANCE_ID(input);
                float3 positionRWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(positionRWS);
                return output;
            }

            half4 FragShadowHDRP(ShadowVaryingsHDRP input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }

        // MotionVectors パス: TAA/DLSS ゴースト防止。
        //
        // LED パネルは映像コンテンツが毎フレーム変化するため、
        // TAA のテンポラル蓄積がゴースト/残像を引き起こす。
        // 意図的に大きなモーションベクターを出力し、
        // TAA にヒストリーサンプルを棄却させる。
        //
        // ステンシルビット 5 (ObjectMotionVector = 32) を書き込み、
        // HDRP の CameraMotionVectors パスが本パスの出力を
        // カメラベースのモーションベクターで上書きしないようにする。
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            // HDRP ObjectMotionVector ステンシル:
            // ビット 5 (値 32) をセットし、CameraMotionVectors パスの
            // Comp NotEqual テストでスキップさせる。
            Stencil
            {
                WriteMask 32
                Ref 32
                Comp Always
                Pass Replace
            }

            ZWrite On

            HLSLPROGRAM
            #pragma vertex VertMotionVectorsHDRP
            #pragma fragment FragMotionVectorsHDRP
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            float _InvalidateMotionVectors;

            struct MVAttributesHDRP
            {
                float3 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct MVVaryingsHDRP
            {
                float4 positionCS : SV_POSITION;
            };

            MVVaryingsHDRP VertMotionVectorsHDRP(MVAttributesHDRP input)
            {
                MVVaryingsHDRP output;
                UNITY_SETUP_INSTANCE_ID(input);
                float3 posRWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(posRWS);
                return output;
            }

            float4 FragMotionVectorsHDRP(MVVaryingsHDRP input) : SV_Target
            {
                return (_InvalidateMotionVectors > 0.5)
                    ? float4(2.0, 2.0, 0.0, 0.0)
                    : float4(0.0, 0.0, 0.0, 0.0);
            }
            ENDHLSL
        }
    }

    // ========================================================================
    // Built-in SubShader (fallback — no RenderPipeline tag)
    // ========================================================================
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        Cull [_CullMode]

        Pass
        {
            Name "ForwardBase"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            ENDCG
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            CGPROGRAM
            #pragma vertex vertShadow
            #pragma fragment fragShadow
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            ENDCG
        }
    }

    Fallback "Diffuse"
    CustomEditor "Llcheesell.LEDScreenShader.Editor.LEDScreenShaderGUI"
}
