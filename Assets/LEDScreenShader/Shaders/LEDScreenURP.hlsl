#ifndef LEDSCREEN_URP_INCLUDED
#define LEDSCREEN_URP_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

// SRP Batcher compatible: all per-material properties in UnityPerMaterial CBUFFER
CBUFFER_START(UnityPerMaterial)
    float4 _InputTex_ST;
    float4 _LEDTiling;
    float  _IntensityMultiplier;
    float  _DistantFadeStart;
    float  _DistantFadeEnd;
    float4 _DistantFadeBrightness;
    float  _CabinetGridEnabled;
    float4 _CabinetTiling;
    float  _CabinetSeamWidth;
    float  _CabinetSeamDepth;
    float  _CabinetBrightnessVariance;
CBUFFER_END

TEXTURE2D(_InputTex);   SAMPLER(sampler_InputTex);
TEXTURE2D(_LEDTex);     SAMPLER(sampler_LEDTex);
TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);

// Pipeline abstraction macros
#define LED_FOV_COT unity_CameraProjection[1][1]
#define LED_PREV_VP unity_MatrixPreviousVP

#endif // LEDSCREEN_URP_INCLUDED
