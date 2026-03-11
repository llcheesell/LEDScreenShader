#ifndef LEDSCREEN_CORE_INCLUDED
#define LEDSCREEN_CORE_INCLUDED

#include "LEDScreenProceduralLED.hlsl"

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
    float t = saturate((adjDist - _DistantFadeStart) /
                       max(_DistantFadeEnd - _DistantFadeStart, 0.001));
    // smoothstep カーブで自然な遷移（線形より滑らかなフェード）
    return t * t * (3.0 - 2.0 * t);
}

// ============================================================================
// DDX/DDY Auto-Fade
// ============================================================================

// LED ドットがスクリーン上でサブピクセル化した際、フラットエミッションにフェード。
// DistantFader より精密: 解像度、FOV、斜め視線角を考慮。
//
// TAA/DLSS 対策: ドットが完全にサブピクセル化する前にフェードを開始し、
// テンポラルフリッカーを防止する。smoothstep でより滑らかな遷移を実現。
float ComputeAutoFade(float2 ledUV)
{
    float2 dx = ddx(ledUV);
    float2 dy = ddy(ledUV);
    float coverage = max(length(dx), length(dy));

    // coverage < 0.3: LED ドットが十分解像 => フェードなし
    // coverage > 0.8: サブピクセル化 => 完全フェード
    // smoothstep で TAA/DLSS に優しい滑らかな遷移カーブ
    return smoothstep(0.3, 0.8, coverage);
}

// ============================================================================
// Subpixel LED Rendering (Core)
// ============================================================================

// ============================================================================
// LED サブピクセルレンダリング
//
// 2つのモードをサポート:
//   1. プロシージャルモード (_ProceduralLEDEnabled = 1):
//      SDF ベースで LED ドットを動的に描画。エネルギー補償付き。
//   2. テクスチャモード (_ProceduralLEDEnabled = 0):
//      従来の _LEDTex RGB マスクによるサブピクセル描画。
//
// 両モードとも共通のフェード処理で遠距離/サブピクセル時にフラットエミッションに遷移。
// ============================================================================
float4 ComputeSubpixelLED(float2 inputUV, float2 ledUV, float fade)
{
    // 入力テクスチャサンプリング
    float4 inputColor = SAMPLE_TEXTURE2D(_InputTex, sampler_InputTex, inputUV);

    // HDR 強度（二乗で高輝度互換性を維持、レガシー互換）
    float intensity = _IntensityMultiplier * _IntensityMultiplier;

    // 完全フェード時は LED 処理をスキップ
    UNITY_BRANCH
    if (fade >= 0.999)
    {
        float3 result = inputColor.rgb * intensity;
        result *= _DistantFadeBrightness.rgb;
        result *= _EmissionColor.rgb;
        return float4(result, 1.0);
    }

    // --- サブピクセルカラー計算（モード分岐） ---
    float3 subpixelColor;

    UNITY_BRANCH
    if (_ProceduralLEDEnabled > 0.5)
    {
        // プロシージャルモード: SDF ベースの LED ドット描画
        // エネルギー補償付きで、ドット面積に反比例した高輝度を実現
        subpixelColor = ProceduralSubpixelLED(ledUV, inputColor.rgb);
    }
    else
    {
        // テクスチャモード: 従来の LED マスクテクスチャによる描画
        float4 ledMask = SAMPLE_TEXTURE2D(_LEDTex, sampler_LEDTex, ledUV);
        subpixelColor = float3(
            inputColor.r * ledMask.r,
            inputColor.g * ledMask.g,
            inputColor.b * ledMask.b
        );
    }

    // --- 共通フェード処理 ---
    // 近距離: サブピクセル LED（高コントラスト）
    // 遠距離: フラットエミッション（入力色そのまま）
    float3 flatColor = inputColor.rgb;
    float3 ledColor  = lerp(subpixelColor, flatColor, fade);

    ledColor *= intensity;

    // 遠距離輝度補正
    ledColor = lerp(ledColor, ledColor * _DistantFadeBrightness.rgb, fade);

    // エミッションカラーティント
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
// Motion Vectors (camera-only) — 現在未使用
// ============================================================================
//
// 注意: URP/HDRP SubShader では MotionVectors パスを除去済み。
// 各パイプラインは MotionVectors パスが無いオブジェクトに対して、
// 深度バッファからカメラモーションベクターを自動再構築する。
// 静的な LED スクリーンにはこれで十分。
//
// CGPROGRAM ベースの実装には以下の問題があった:
// - UNITY_UV_STARTS_AT_TOP による Y フリップがパイプライン内部の処理と競合
// - _NonJitteredViewProjMatrix の値がパイプラインによって異なる設定タイミング
// - 高コントラスト発光面で TAA/DLSS ゴーストの原因となっていた
//
// 将来、オブジェクトモーション対応が必要になった場合は、
// HLSLPROGRAM + パイプライン固有のインクルードで再実装すること。

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

    // SV_POSITION must use the (possibly jittered) VP so the pixel
    // lands at the correct rasterisation position.
    output.positionCS = TransformWorldToHClip(posWS);

    // Motion-vector calculation: both frames use NON-JITTERED VP
    // so the delta represents only real camera motion.
    output.currentCS  = mul(LED_NONJITTERED_VP, float4(posWS, 1.0));

    // Previous frame — same world position (static surface),
    // different camera VP.
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
