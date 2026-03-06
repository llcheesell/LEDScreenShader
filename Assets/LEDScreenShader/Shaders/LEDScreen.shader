Shader "llcheesell/LEDScreen"
{
    Properties
    {
        // =====================================================================
        // Input Screen
        // =====================================================================
        [Header(Input Screen)]
        [Space(5)]
        _InputTex         ("Texture", 2D)  = "white" {}

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
        // Emission
        // =====================================================================
        [Space(10)]
        [Header(Emission)]
        [Space(5)]
        [HDR]
        _EmissionColor         ("Emission Color", Color) = (1,1,1,1)
        _IntensityMultiplier   ("Intensity", Range(0.1, 10)) = 1.0

        // =====================================================================
        // Distant Fade
        // =====================================================================
        [Space(10)]
        [Header(Distant Fade)]
        [Space(5)]
        _DistantFadeStart      ("Start Distance", Float)   = 3.0
        _DistantFadeEnd        ("End Distance",   Float)   = 6.0
        _DistantFadeBrightness ("Fade Brightness", Color)  = (1,1,1,1)

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

        // ---- UV computation ----
        float2 inputUV   = GetInputUV(IN.uv);     // Input texture (own Tiling/Offset)
        float2 ledUV     = GetLEDUV(IN.uv);       // LED mask (columns x rows)
        float2 baseTexUV = GetBaseUV(IN.uv);       // Base/Normal/Mask (shared Tiling/Offset)

        // ---- LED fade ----
        float distFade = ComputeDistantFade(IN.positionWS);
        float autoFade = ComputeAutoFade(ledUV);
        float fade     = max(distFade, autoFade);

        // ---- LED emission ----
        float4 ledResult = ComputeSubpixelLED(inputUV, ledUV, fade);
        float3 emission  = ledResult.rgb;

        // ---- Base material sampling (using base UV) ----
        half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseTexUV) * _BaseColor;

        // Normal map with strength
        half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, baseTexUV));
        normalTS.xy *= _NormalStrength;
        normalTS = normalize(normalTS);

        // Mask Map: R=Metallic, G=AO, B=Detail(unused), A=Smoothness
        half4 maskMap = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, baseTexUV);
        float metallic   = maskMap.r * _Metallic;
        float ao         = lerp(1.0, maskMap.g, _OcclusionStrength);
        float smoothness = maskMap.a * _Smoothness;
        float roughness  = 1.0 - smoothness;

        // ---- Cabinet grid ----
        float emissiveScale = 1.0;
        ApplyCabinetGrid(IN.uv, normalTS, emissiveScale);
        emission *= emissiveScale;

        // ---- TBN: tangent-space normal to world-space ----
        float sgn = IN.tangentWS.w;
        float3 bitangent = sgn * cross(IN.normalWS, IN.tangentWS.xyz);
        half3x3 TBN = half3x3(IN.tangentWS.xyz, bitangent, IN.normalWS);
        half3 normalWS = normalize(mul(normalTS, TBN));

        // ---- Lighting ----
        float3 viewDir = normalize(_WorldSpaceCameraPos - IN.positionWS);

        // Ambient (spherical harmonics)
        float3 ambient = ShadeSH9(float4(normalWS, 1.0));

        // Main directional light
        float NdotL = saturate(dot(normalWS, _WorldSpaceLightPos0.xyz));
        UNITY_LIGHT_ATTENUATION(atten, IN, IN.positionWS);

        // Diffuse
        float3 diffuseAlbedo = baseColor.rgb * (1.0 - metallic);
        float3 directDiffuse = diffuseAlbedo * _LightColor0.rgb * NdotL * atten;
        float3 ambientDiffuse = diffuseAlbedo * ambient * ao;

        // Specular (Blinn-Phong approximation)
        float specPower = max(1.0, pow(8192.0, smoothness)); // perceptual mapping
        float3 halfDir = normalize(_WorldSpaceLightPos0.xyz + viewDir);
        float NdotH = saturate(dot(normalWS, halfDir));
        float specIntensity = pow(NdotH, specPower) * smoothness;

        // F0: dielectric=0.04, metallic=baseColor
        float3 specColor = lerp(float3(0.04, 0.04, 0.04), baseColor.rgb, metallic);
        float3 directSpecular = specColor * _LightColor0.rgb * specIntensity * NdotL * atten;

        // Fresnel (Schlick approximation) for environment reflection
        float NdotV = saturate(dot(normalWS, viewDir));
        float fresnel = pow(1.0 - NdotV, 5.0);
        float3 envSpecColor = lerp(specColor, float3(1, 1, 1), fresnel);

        // Environment reflection (reflection probe / fallback)
        float3 reflectDir = reflect(-viewDir, normalWS);
        float mip = roughness * 6.0; // rough = blurry cubemap
        float3 envReflection = float3(0, 0, 0);
        #if defined(UNITY_SPECCUBE_BOX_PROJECTION)
            // Box projection: correct reflection direction for finite-size probes
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
        float3 indirectSpecular = envReflection * envSpecColor * ao;

        // ---- Combine ----
        float3 finalColor = directDiffuse + ambientDiffuse
                          + directSpecular + indirectSpecular
                          + emission;

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

        Cull [_CullMode]

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
    }

    Fallback "Diffuse"
    CustomEditor "LEDScreenShaderGUI"
}
