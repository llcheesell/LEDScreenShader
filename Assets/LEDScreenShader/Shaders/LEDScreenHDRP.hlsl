#ifndef LEDSCREEN_HDRP_INCLUDED
#define LEDSCREEN_HDRP_INCLUDED

// ============================================================================
// HDRP Compatibility Header for LEDScreen
//
// HDRP ネイティブのインクルードを使用し、正しい定数バッファレイアウトで
// 行列変換とテクスチャサンプリングを行う。
//
// CGPROGRAM + UnityCG.cginc は HDRP の ShaderVariablesGlobal 定数バッファと
// レイアウトが競合するため、HDRP SubShader では使用しない。
// ============================================================================

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

// ============================================================================
// Pipeline Abstraction Macros
// ============================================================================

// HDRP はカメラ相対レンダリング: カメラ位置 = 原点
// positionRWS (Relative World Space) からカメラまでの距離 = length(posRWS)
#define LED_CAMERA_DISTANCE(worldPos) length(worldPos)

// FOV: HDRP projection matrix [1][1] = cot(verticalFOV / 2)
#define LED_FOV_COT UNITY_MATRIX_P[1][1]

// ============================================================================
// Texture Declarations (SRP Texture System)
// ============================================================================
TEXTURE2D(_InputTex);   SAMPLER(sampler_InputTex);
TEXTURE2D(_LEDTex);     SAMPLER(sampler_LEDTex);
TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
TEXTURE2D(_MaskMap);    SAMPLER(sampler_MaskMap);

// ============================================================================
// Material Properties
// ============================================================================

// Input Screen
float4 _InputTex_ST;

// LED Subpixel
float  _LEDTilingX;
float  _LEDTilingY;

// Emission
float4 _EmissionColor;
float  _IntensityMultiplier;

// Distant Fade
float  _DistantFadeStart;
float  _DistantFadeEnd;
float4 _DistantFadeBrightness;

// Cabinet Grid
float  _CabinetGridEnabled;
float  _CabinetColumns;
float  _CabinetRows;
float  _CabinetSeamWidth;
float  _CabinetSeamDepth;
float  _CabinetBrightnessVariance;

// Procedural LED
float  _ProceduralLEDEnabled;
float  _ProceduralLEDPattern;
float  _ProceduralDotRadius;
float  _ProceduralHotspotStrength;
float  _ProceduralGlowRadius;
float  _ProceduralGlowIntensity;
float  _ProceduralHighlightStrength;

// Surface Material
float  _BaseMaterialEnabled;
float  _SurfaceUVLinkLED;
float4 _BaseColor;
float4 _BaseMap_ST;
float  _NormalStrength;
float  _Metallic;
float  _Smoothness;
float  _OcclusionStrength;

// TAA Ghost Prevention
float  _InvalidateMotionVectors;

#endif // LEDSCREEN_HDRP_INCLUDED
