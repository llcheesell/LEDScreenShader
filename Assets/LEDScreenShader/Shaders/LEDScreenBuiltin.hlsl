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

// Procedural LED
float  _ProceduralLEDEnabled;        // トグル: 0=テクスチャ, 1=プロシージャル
float  _ProceduralLEDPattern;        // 0=Honeycomb, 1=HStripe, 2=VRect
float  _ProceduralDotRadius;         // ドット半径 (0.3..1.0)
float  _ProceduralHotspotStrength;   // 中心ホットスポット (0..1)
float  _ProceduralGlowRadius;        // グロー半径 (0..0.5)
float  _ProceduralGlowIntensity;     // グロー強度 (0..1)
float  _ProceduralHighlightStrength; // 白色ハイライト強度 (0..2)

// Surface Material
float  _BaseMaterialEnabled; // toggle: enable PBR base material
float  _SurfaceUVLinkLED;    // toggle: link surface UV to LED tiling
float4 _BaseColor;
float4 _BaseMap_ST;          // auto-generated from texture Tiling/Offset
float  _NormalStrength;
float  _Metallic;
float  _Smoothness;
float  _OcclusionStrength;

#endif // LEDSCREEN_BUILTIN_INCLUDED
