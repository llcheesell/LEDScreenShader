#ifndef LEDSCREEN_BUILTIN_INCLUDED
#define LEDSCREEN_BUILTIN_INCLUDED

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"
#include "UnityStandardBRDF.cginc"

// Built-in compatibility macros — bridge SRP texture API to legacy tex2D
#ifndef SAMPLE_TEXTURE2D
    #define SAMPLE_TEXTURE2D(tex, samp, uv) tex2D(tex, uv)
#endif

#ifndef TEXTURE2D_DEFINED
    #define TEXTURE2D_DEFINED
#endif

#define TransformObjectToWorld(pos) mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz
#define TransformWorldToHClip(pos)  mul(UNITY_MATRIX_VP, float4(pos, 1.0))

// Pipeline abstraction macros
#define LED_FOV_COT unity_CameraProjection[1][1]

// Motion-vector matrices for MotionVectors pass.
// URP / HDRP set these globals per-frame.
// In Built-in, no MotionVectors LightMode exists so the pass never runs.
//
// _NonJitteredViewProjMatrix : current-frame VP **without** TAA jitter
// _PrevViewProjMatrix        : previous-frame VP (also non-jittered)
//
// Both must be non-jittered so that the motion-vector delta contains
// only real camera/object motion, not per-frame TAA sub-pixel offsets.
float4x4 _NonJitteredViewProjMatrix;
float4x4 _PrevViewProjMatrix;
#define LED_NONJITTERED_VP _NonJitteredViewProjMatrix
#define LED_PREV_VP        _PrevViewProjMatrix

// ============================================================================
// Texture declarations
// ============================================================================
sampler2D _InputTex;
sampler2D _LEDTex;
sampler2D _BaseMap;
sampler2D _NormalMap;
sampler2D _MaskMap;

// ============================================================================
// Material properties
// ============================================================================

// Input Screen
float4 _InputTex_ST;        // auto-generated from texture Tiling/Offset

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

// Surface Material
float  _SurfaceUVLinkLED;    // toggle: link surface UV to LED tiling
float4 _BaseColor;
float4 _BaseMap_ST;          // auto-generated from texture Tiling/Offset
float  _NormalStrength;
float  _Metallic;
float  _Smoothness;
float  _OcclusionStrength;

#endif // LEDSCREEN_BUILTIN_INCLUDED
