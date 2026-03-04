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
    // In Built-in, textures are declared as sampler2D directly.
    // The TEXTURE2D/SAMPLER macros are no-ops; declarations below handle it.
#endif

#define TransformObjectToWorld(pos) mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz
#define TransformWorldToHClip(pos)  mul(UNITY_MATRIX_VP, float4(pos, 1.0))

// Built-in does not use CBUFFER for SRP Batcher (no SRP Batcher in Built-in)
sampler2D _InputTex;
sampler2D _LEDTex;
sampler2D _BaseMap;
sampler2D _NormalMap;
sampler2D _MaskMap;

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

#endif // LEDSCREEN_BUILTIN_INCLUDED
