Shader "llcheesell/LEDScreen"
{
    Properties
    {
        // --- Input ---
        _InputTex         ("Input Texture", 2D)          = "white" {}
        _InputTex_ST      ("Input Tiling/Offset", Vector) = (1,1,0,0)

        // --- LED Texture ---
        // RGB channels = subpixel masks (R=red area, G=green area, B=blue area)
        _LEDTex           ("LED Texture (RGB=subpixel mask)", 2D) = "white" {}
        _LEDTiling        ("LED Tiling (X/Y)", Vector)   = (100, 56, 0, 0)

        // --- Brightness ---
        _IntensityMultiplier ("Intensity Multiplier", Float) = 1.0

        // --- Distant Fader ---
        _DistantFadeStart      ("Distant Fade Start", Float)  = 3.0
        _DistantFadeEnd        ("Distant Fade End", Float)    = 6.0
        _DistantFadeBrightness ("Distant Fade Brightness", Color) = (1,1,1,1)

        // --- Cabinet Grid ---
        _CabinetGridEnabled       ("Cabinet Grid Enabled", Float)          = 0.0
        _CabinetTiling            ("Cabinet Tiling (cols, rows)", Vector)  = (10, 6, 0, 0)
        _CabinetSeamWidth         ("Cabinet Seam Width", Range(0,0.05))   = 0.005
        _CabinetSeamDepth         ("Cabinet Seam Depth", Range(0,1))      = 0.3
        _CabinetBrightnessVariance("Cabinet Brightness Variance", Range(0,0.1)) = 0.02

        // --- Base Material ---
        _BaseMap    ("Base Texture", 2D)                    = "black" {}
        [Normal]
        _NormalMap  ("Normal Map", 2D)                      = "bump"  {}
        _MaskMap    ("Mask Map (Metallic/AO/Smoothness)", 2D) = "white" {}
    }

    // ========================================================================
    // URP SubShader
    // ========================================================================
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        // Only compile this SubShader when URP package is installed
        PackageRequirements { "com.unity.render-pipelines.universal": "" }

        // --------------------------------------------------------------------
        // Pass: ForwardLit (URP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "LEDScreenURP.hlsl"
            #include "LEDScreenCore.hlsl"

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
                float4 tangentWS    : TEXCOORD3; // xyz = tangent, w = sign
                float  fogFactor    : TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                VertexPositionInputs posInputs = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs   norInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                OUT.positionCS = posInputs.positionCS;
                OUT.positionWS = posInputs.positionWS;
                OUT.normalWS   = norInputs.normalWS;
                OUT.tangentWS  = float4(norInputs.tangentWS, IN.tangentOS.w);
                OUT.uv         = IN.texcoord;
                OUT.fogFactor  = ComputeFogFactor(posInputs.positionCS.z);

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // UV
                float2 inputUV = GetInputUV(IN.uv);
                float2 ledUV   = GetLEDUV(IN.uv);

                // Fade
                float distFade = ComputeDistantFade(IN.positionWS);
                float autoFade = ComputeAutoFade(ledUV);
                float fade     = max(distFade, autoFade);

                // LED emission
                float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
                float3 emission  = ledResult.rgb;

                // Base material
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, ledUV);
                half3 normalTS  = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, ledUV));
                half4 maskMap   = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, ledUV);

                // Cabinet grid
                float emissiveScale = 1.0;
                ApplyCabinetGrid(IN.uv, normalTS, emissiveScale);
                emission *= emissiveScale;

                // TBN: tangent-space normal to world-space
                float sgn = IN.tangentWS.w * GetOddNegativeScale();
                float3 bitangent = sgn * cross(IN.normalWS, IN.tangentWS.xyz);
                half3x3 TBN = half3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                // URP PBR Lighting
                InputData inputData = (InputData)0;
                inputData.positionWS              = IN.positionWS;
                inputData.normalWS                = normalWS;
                inputData.viewDirectionWS         = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                inputData.shadowCoord             = TransformWorldToShadowCoord(IN.positionWS);
                inputData.fogCoord                = IN.fogFactor;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.positionCS);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo     = baseColor.rgb;
                surfaceData.metallic   = maskMap.r;
                surfaceData.smoothness = maskMap.a;
                surfaceData.normalTS   = normalTS;
                surfaceData.occlusion  = maskMap.g;
                surfaceData.emission   = emission;
                surfaceData.alpha      = 1.0;

                half4 color = UniversalFragmentPBR(inputData, surfaceData);
                color.rgb = MixFog(color.rgb, IN.fogFactor);

                return color;
            }
            ENDHLSL
        }

        // --------------------------------------------------------------------
        // Pass: DepthOnly (URP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing

            #include "LEDScreenURP.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vertDepth(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                return OUT;
            }

            half4 fragDepth(Varyings IN) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }

        // --------------------------------------------------------------------
        // Pass: MotionVectors (URP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            ColorMask RG

            HLSLPROGRAM
            #pragma vertex vertMotionVectors
            #pragma fragment fragMotionVectors
            #pragma multi_compile_instancing

            #include "LEDScreenURP.hlsl"
            #include "LEDScreenCore.hlsl"
            ENDHLSL
        }
    }

    // ========================================================================
    // HDRP SubShader
    // ========================================================================
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        // Only compile this SubShader when HDRP package is installed
        PackageRequirements { "com.unity.render-pipelines.high-definition": "" }

        // --------------------------------------------------------------------
        // Pass: ForwardOnly (HDRP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fragment _ SHADOWS_SHADOWMASK
            #pragma multi_compile_instancing

            #include "LEDScreenHDRP.hlsl"

            // HDRP lighting utilities
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"

            #include "LEDScreenCore.hlsl"

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
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);

                OUT.positionCS = TransformWorldToHClip(posWS);
                OUT.positionWS = posWS;
                OUT.normalWS   = TransformObjectToWorldNormal(IN.normalOS);
                OUT.tangentWS  = float4(TransformObjectToWorldDir(IN.tangentOS.xyz), IN.tangentOS.w);
                OUT.uv         = IN.texcoord;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

                // UV
                float2 inputUV = GetInputUV(IN.uv);
                float2 ledUV   = GetLEDUV(IN.uv);

                // Fade
                float distFade = ComputeDistantFade(IN.positionWS);
                float autoFade = ComputeAutoFade(ledUV);
                float fade     = max(distFade, autoFade);

                // LED emission
                float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
                float3 emission  = ledResult.rgb;

                // Base material
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, ledUV);
                half3 normalTS  = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, ledUV));
                half4 maskMap   = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, ledUV);

                // Cabinet grid
                float emissiveScale = 1.0;
                ApplyCabinetGrid(IN.uv, normalTS, emissiveScale);
                emission *= emissiveScale;

                // TBN: tangent-space normal to world-space
                float sgn = IN.tangentWS.w;
                float3 bitangent = sgn * cross(IN.normalWS, IN.tangentWS.xyz);
                half3x3 TBN = half3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                // Simplified HDRP lighting: directional light + ambient
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);

                // Ambient from spherical harmonics
                float3 ambient = SampleSH(normalWS);

                // Main directional light
                float3 lightDir = _DirectionalLightDatas[0].forward.xyz;
                float3 lightColor = _DirectionalLightDatas[0].color.rgb;
                float NdotL = saturate(dot(normalWS, -lightDir));

                // Basic PBR approximation
                float metallic   = maskMap.r;
                float smoothness = maskMap.a;
                float occlusion  = maskMap.g;
                float roughness  = 1.0 - smoothness;

                float3 diffuse = baseColor.rgb * (1.0 - metallic);
                float3 directLighting = diffuse * lightColor * NdotL;
                float3 ambientLighting = diffuse * ambient * occlusion;

                float3 finalColor = directLighting + ambientLighting + emission;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }

        // --------------------------------------------------------------------
        // Pass: MotionVectors (HDRP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            ColorMask RG

            HLSLPROGRAM
            #pragma vertex vertMotionVectors
            #pragma fragment fragMotionVectors
            #pragma multi_compile_instancing

            #include "LEDScreenHDRP.hlsl"
            #include "LEDScreenCore.hlsl"
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

        // --------------------------------------------------------------------
        // Pass: ForwardBase (Built-in)
        // --------------------------------------------------------------------
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

            #include "LEDScreenBuiltin.hlsl"
            #include "LEDScreenCore.hlsl"

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

                // UV
                float2 inputUV = GetInputUV(IN.uv);
                float2 ledUV   = GetLEDUV(IN.uv);

                // Fade
                float distFade = ComputeDistantFade(IN.positionWS);
                float autoFade = ComputeAutoFade(ledUV);
                float fade     = max(distFade, autoFade);

                // LED emission
                float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
                float3 emission  = ledResult.rgb;

                // Base material
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, ledUV);
                half3 normalTS  = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, ledUV));
                half4 maskMap   = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, ledUV);

                // Cabinet grid
                float emissiveScale = 1.0;
                ApplyCabinetGrid(IN.uv, normalTS, emissiveScale);
                emission *= emissiveScale;

                // TBN: tangent-space normal to world-space
                float sgn = IN.tangentWS.w;
                float3 bitangent = sgn * cross(IN.normalWS, IN.tangentWS.xyz);
                half3x3 TBN = half3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
                half3 normalWS = normalize(mul(normalTS, TBN));

                // Built-in lighting
                float metallic   = maskMap.r;
                float smoothness = maskMap.a;
                float occlusion  = maskMap.g;

                // Ambient (spherical harmonics)
                float3 ambient = ShadeSH9(float4(normalWS, 1.0));

                // Main directional light
                float NdotL = saturate(dot(normalWS, _WorldSpaceLightPos0.xyz));
                UNITY_LIGHT_ATTENUATION(atten, IN, IN.positionWS);

                float3 diffuse = baseColor.rgb * (1.0 - metallic);
                float3 directLighting = diffuse * _LightColor0.rgb * NdotL * atten;
                float3 ambientLighting = diffuse * ambient * occlusion;

                float3 finalColor = directLighting + ambientLighting + emission;

                // Fog
                UNITY_APPLY_FOG(IN.fogCoord, finalColor);

                return half4(finalColor, 1.0);
            }
            ENDCG
        }
    }

    Fallback "Diffuse"
}
