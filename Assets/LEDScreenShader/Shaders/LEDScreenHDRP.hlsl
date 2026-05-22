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
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition-config/Runtime/ShaderConfig.cs.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureXR.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariablesGlobal.hlsl"

#if defined(USING_STEREO_MATRICES)
    #define _WorldSpaceCameraPos _XRWorldSpaceCameraPos[unity_StereoEyeIndex].xyz
#else
    #define _WorldSpaceCameraPos _WorldSpaceCameraPos_Internal.xyz
#endif

#ifndef DOTS_INSTANCING_ON
CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;
    float4x4 unity_WorldToObject;
    float4 unity_LODFade;
    float4 unity_WorldTransformParams;
    float4 unity_RenderingLayer;
    float4 unity_LightmapST;
    float4 unity_DynamicLightmapST;
    float4 unity_SHAr;
    float4 unity_SHAg;
    float4 unity_SHAb;
    float4 unity_SHBr;
    float4 unity_SHBg;
    float4 unity_SHBb;
    float4 unity_SHC;
    float4 unity_RendererBounds_Min;
    float4 unity_RendererBounds_Max;
    float4 unity_ProbeVolumeParams;
    float4x4 unity_ProbeVolumeWorldToObject;
    float4 unity_ProbeVolumeSizeInv;
    float4 unity_ProbeVolumeMin;
    float4 unity_ProbesOcclusion;
    float4x4 unity_MatrixPreviousM;
    float4x4 unity_MatrixPreviousMI;
    float4 unity_MotionVectorsParams;
CBUFFER_END
#endif

CBUFFER_START(UnityPerDrawRare)
    float4x4 glstate_matrix_transpose_modelview0;
CBUFFER_END

float4x4 OptimizeProjectionMatrix(float4x4 M)
{
    M._21_41 = 0;
    M._12_42 = 0;
    return M;
}

float4x4 LEDScreenApplyCameraTranslationToMatrix(float4x4 modelMatrix)
{
#if (SHADEROPTIONS_CAMERA_RELATIVE_RENDERING != 0)
    modelMatrix._m03_m13_m23 -= _WorldSpaceCameraPos.xyz;
#endif
    return modelMatrix;
}

float4x4 LEDScreenApplyCameraTranslationToInverseMatrix(float4x4 inverseModelMatrix)
{
#if (SHADEROPTIONS_CAMERA_RELATIVE_RENDERING != 0)
    float4x4 translationMatrix = {
        1.0, 0.0, 0.0, _WorldSpaceCameraPos.x,
        0.0, 1.0, 0.0, _WorldSpaceCameraPos.y,
        0.0, 0.0, 1.0, _WorldSpaceCameraPos.z,
        0.0, 0.0, 0.0, 1.0
    };
    return mul(inverseModelMatrix, translationMatrix);
#else
    return inverseModelMatrix;
#endif
}

#ifndef DOTS_INSTANCING_ON
float4x4 LEDScreenGetRawUnityObjectToWorld()     { return unity_ObjectToWorld; }
float4x4 LEDScreenGetRawUnityWorldToObject()     { return unity_WorldToObject; }
float4x4 LEDScreenGetRawUnityPrevObjectToWorld() { return unity_MatrixPreviousM; }
float4x4 LEDScreenGetRawUnityPrevWorldToObject() { return unity_MatrixPreviousMI; }

#define UNITY_MATRIX_M        LEDScreenApplyCameraTranslationToMatrix(LEDScreenGetRawUnityObjectToWorld())
#define UNITY_MATRIX_I_M      LEDScreenApplyCameraTranslationToInverseMatrix(LEDScreenGetRawUnityWorldToObject())
#define UNITY_PREV_MATRIX_M   LEDScreenApplyCameraTranslationToMatrix(LEDScreenGetRawUnityPrevObjectToWorld())
#define UNITY_PREV_MATRIX_I_M LEDScreenApplyCameraTranslationToInverseMatrix(LEDScreenGetRawUnityPrevWorldToObject())
#endif

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariablesMatrixDefsHDCamera.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

float3 LEDScreenGetCurrentViewPosition()
{
#if (defined(SHADERPASS) && (SHADERPASS != SHADERPASS_SHADOWS))
    return _WorldSpaceCameraPos;
#else
    return UNITY_MATRIX_I_V._14_24_34;
#endif
}

float3 LEDScreenGetWorldSpaceNormalizeViewDir(float3 positionRWS)
{
#if (SHADEROPTIONS_CAMERA_RELATIVE_RENDERING != 0)
    return normalize(-positionRWS);
#else
    return normalize(LEDScreenGetCurrentViewPosition() - positionRWS);
#endif
}

// ============================================================================
// Pipeline Abstraction Macros
// ============================================================================

// (LED_CAMERA_DISTANCE / LED_FOV_COT は AutoFade 移行により不要)

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

// LED Fade
float  _FadeStart;
float  _FadeEnd;
float  _FadeBias;

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

// Debug
float  _DebugFadeVis;

#endif // LEDSCREEN_HDRP_INCLUDED
