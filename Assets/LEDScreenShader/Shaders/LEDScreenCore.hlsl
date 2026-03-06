#ifndef LEDSCREEN_CORE_INCLUDED
#define LEDSCREEN_CORE_INCLUDED

// ============================================================================
// UV Helpers
// ============================================================================

// Input Texture UV (Tiling/Offset from texture inspector)
float2 GetInputUV(float2 baseUV)
{
    return baseUV * _InputTex_ST.xy + _InputTex_ST.zw;
}

// LED texture UV (tile count from _LEDTilingX / _LEDTilingY)
float2 GetLEDUV(float2 baseUV)
{
    return baseUV * float2(_LEDTilingX, _LEDTilingY);
}

// Base material UV (Tiling/Offset from BaseMap texture inspector)
// Shared by BaseMap, NormalMap, and MaskMap
float2 GetBaseUV(float2 baseUV)
{
    if (_SurfaceUVLinkLED > 0.5)
        return baseUV * float2(_LEDTilingX, _LEDTilingY);
    else
        return baseUV * _BaseMap_ST.xy + _BaseMap_ST.zw;
}

// ============================================================================
// Distant Fader (FOV-corrected)
// ============================================================================

float GetFOVAdjustedDistance(float3 worldPos)
{
    float dist = distance(worldPos, _WorldSpaceCameraPos);

    // unity_CameraProjection[1][1] = cot(verticalFOV / 2)
    // Normalize against FOV 60deg baseline: cot(30deg) = sqrt(3) ~ 1.732
    // Telephoto (small FOV) => larger value => fades in sooner
    float fovCot = LED_FOV_COT;
    float normalizedFov = fovCot / 1.7320508; // sqrt(3)

    return dist * normalizedFov;
}

float ComputeDistantFade(float3 worldPos)
{
    float adjDist = GetFOVAdjustedDistance(worldPos);
    return saturate((adjDist - _DistantFadeStart) /
                    max(_DistantFadeEnd - _DistantFadeStart, 0.001));
}

// ============================================================================
// DDX/DDY Auto-Fade
// ============================================================================

// When LED dots are sub-pixel on screen, auto-fade to flat emission.
// More precise than DistantFader: handles resolution, FOV, and oblique angles.
float ComputeAutoFade(float2 ledUV)
{
    float2 dx = ddx(ledUV);
    float2 dy = ddy(ledUV);
    float coverage = max(length(dx), length(dy));

    // coverage < 0.7: LED dots are well-resolved on screen => no fade
    // coverage > 1.3: sub-pixel => full fade
    return saturate((coverage - 0.7) / 0.6);
}

// ============================================================================
// Subpixel LED Rendering (Core)
// ============================================================================

// LED texture RGB channels serve as per-subpixel masks:
//   R channel: red subpixel area   (white = lit, black = off)
//   G channel: green subpixel area
//   B channel: blue subpixel area
//
// Input texture RGB is multiplied per-channel with these masks,
// so a red input lights only the red subpixels — matching real LED panels.
float4 ComputeSubpixelLED(float2 inputUV, float2 ledUV, float fade)
{
    // Sample input texture
    float4 inputColor = SAMPLE_TEXTURE2D(_InputTex, sampler_InputTex, inputUV);

    // HDR intensity (squared for high-luminance compatibility, matches legacy)
    float intensity = _IntensityMultiplier * _IntensityMultiplier;

    // Early return when fully faded — skip LED texture sampling
    UNITY_BRANCH
    if (fade >= 0.999)
    {
        float3 result = inputColor.rgb * intensity;
        result *= _DistantFadeBrightness.rgb;
        result *= _EmissionColor.rgb;
        return float4(result, 1.0);
    }

    // Sample LED subpixel mask
    float4 ledMask = SAMPLE_TEXTURE2D(_LEDTex, sampler_LEDTex, ledUV);

    // Per-channel multiplication: input.r * mask.r, input.g * mask.g, input.b * mask.b
    float3 subpixelColor = float3(
        inputColor.r * ledMask.r,
        inputColor.g * ledMask.g,
        inputColor.b * ledMask.b
    );

    // Blend: close = subpixel LED, far = flat emission
    float3 flatColor = inputColor.rgb;
    float3 ledColor  = lerp(subpixelColor, flatColor, fade);

    ledColor *= intensity;

    // Distant fade brightness correction
    ledColor = lerp(ledColor, ledColor * _DistantFadeBrightness.rgb, fade);

    // Emission color tint
    ledColor *= _EmissionColor.rgb;

    return float4(ledColor, 1.0);
}

// ============================================================================
// Cabinet Grid
// ============================================================================

// _CabinetColumns/_CabinetRows: panel divided into cols x rows of cabinet modules
// _CabinetSeamWidth: seam width in UV space
// _CabinetSeamDepth: normal map indent strength
// _CabinetBrightnessVariance: per-cabinet luminance variation range
void ApplyCabinetGrid(
    float2 uv,
    inout float3 normalTS,
    inout float emissiveScale)
{
    if (_CabinetGridEnabled < 0.5) return;

    float2 cabinetTiling = float2(_CabinetColumns, _CabinetRows);
    float2 cabinetUV = frac(uv * cabinetTiling);

    // Seam mask: edges of each cabinet cell
    float2 edgeMask = step(1.0 - _CabinetSeamWidth, cabinetUV) +
                      step(cabinetUV, _CabinetSeamWidth.xx);
    float seam = saturate(edgeMask.x + edgeMask.y);

    // Normal perturbation at seam edges (bevel effect)
    float2 seamGradient = float2(ddx(seam), ddy(seam)) * _CabinetSeamDepth * 10.0;
    normalTS.xy += seamGradient;
    normalTS = normalize(normalTS);

    // Per-cabinet brightness variance (deterministic hash)
    float2 cabinetID = floor(uv * cabinetTiling);
    float hash = frac(sin(dot(cabinetID, float2(127.1, 311.7))) * 43758.5453);
    float variance = (hash - 0.5) * _CabinetBrightnessVariance * 2.0;
    emissiveScale *= (1.0 + variance);

    // Dim emission at seam locations
    emissiveScale *= lerp(1.0, 0.3, seam);
}

// ============================================================================
// Motion Vectors (camera-only)
// ============================================================================

// Outputs camera motion only — no object motion vectors.
// This ensures LED screen does not interfere with TAA ghost rejection
// of objects moving in front of it.
//
// Requires _PrevViewProjMatrix (set by URP MotionVectors render pass).
// Built-in pipeline: no MotionVectors LightMode — pass never executes.
// HDRP: may use a different variable name; motion vectors may be zero.

struct MVAttributes
{
    float4 positionOS : POSITION;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct MVVaryings
{
    float4 positionCS  : SV_POSITION;
    float4 currentCS   : TEXCOORD0;
    float4 previousCS  : TEXCOORD1;
};

MVVaryings vertMotionVectors(MVAttributes input)
{
    MVVaryings output;
    UNITY_SETUP_INSTANCE_ID(input);

    float3 posWS = TransformObjectToWorld(input.positionOS.xyz);

    // Current frame clip space
    output.positionCS = TransformWorldToHClip(posWS);
    output.currentCS  = output.positionCS;

    // Previous frame clip space using previous VP matrix
    // Object transform is identical (static surface) => only camera motion appears
    output.previousCS = mul(LED_PREV_VP, float4(posWS, 1.0));

    return output;
}

float2 fragMotionVectors(MVVaryings input) : SV_Target
{
    float2 currentNDC  = input.currentCS.xy  / input.currentCS.w;
    float2 previousNDC = input.previousCS.xy / input.previousCS.w;

    #if UNITY_UV_STARTS_AT_TOP
    currentNDC.y  = -currentNDC.y;
    previousNDC.y = -previousNDC.y;
    #endif

    return (currentNDC - previousNDC) * 0.5;
}

#endif // LEDSCREEN_CORE_INCLUDED
