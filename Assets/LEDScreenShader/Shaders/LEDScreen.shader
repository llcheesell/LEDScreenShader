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

        // Lighting (Built-in compatible — works across all pipelines)
        float metallic   = maskMap.r;
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

    // MotionVectors: vertMotionVectors / fragMotionVectors defined in LEDScreenCore.hlsl

    ENDCG

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

        // --------------------------------------------------------------------
        // Pass: ForwardLit (URP)
        // --------------------------------------------------------------------
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

        // --------------------------------------------------------------------
        // Pass: DepthOnly (URP)
        // --------------------------------------------------------------------
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

        // --------------------------------------------------------------------
        // Pass: MotionVectors (URP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            ColorMask RG

            CGPROGRAM
            #pragma vertex vertMotionVectors
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
        Tags
        {
            "RenderPipeline" = "HDRenderPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        // --------------------------------------------------------------------
        // Pass: ForwardOnly (HDRP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "ForwardOnly"
            Tags { "LightMode" = "ForwardOnly" }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            ENDCG
        }

        // --------------------------------------------------------------------
        // Pass: DepthForwardOnly (HDRP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "DepthForwardOnly"
            Tags { "LightMode" = "DepthForwardOnly" }

            ZWrite On
            ColorMask 0

            CGPROGRAM
            #pragma vertex vertDepth
            #pragma fragment fragDepth
            #pragma multi_compile_instancing
            ENDCG
        }

        // --------------------------------------------------------------------
        // Pass: MotionVectors (HDRP)
        // --------------------------------------------------------------------
        Pass
        {
            Name "MotionVectors"
            Tags { "LightMode" = "MotionVectors" }

            ColorMask RG

            CGPROGRAM
            #pragma vertex vertMotionVectors
            #pragma fragment fragMotionVectors
            #pragma multi_compile_instancing
            ENDCG
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
            ENDCG
        }
    }

    Fallback "Diffuse"
}
