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
// Screen-Space Density Fade
// ============================================================================
//
// LED ドットのスクリーン上のピクセル密度を ddx/ddy で測定し、
// ドットがサブピクセル化するにつれてフラットエミッションにフェードする。
//
// 解像度、FOV、視線角すべてを暗黙的に考慮するため、
// カメラパラメータに依存せず一貫した結果を返す。
//
// coverage = 1スクリーンピクセルあたりの LED セル数 (UV 変化量)
//   値が小さい → LED ドットが大きく見える (サブピクセル表示)
//   値が大きい → LED ドットが細かい (フェードしてフラット表示)
//
// _FadeStart: これ以下の coverage ではフェードなし (サブピクセル表示)
// _FadeEnd:   これ以上の coverage では完全フェード (フラット表示)
// _FadeBias:  フェードカーブの形状 (<1=早期ブレンド, >1=遅延ブレンド)
//
float ComputeFade(float2 ledUV)
{
    float2 dx = ddx(ledUV);
    float2 dy = ddy(ledUV);
    float coverage = max(length(dx), length(dy));

    float fade = smoothstep(_FadeStart, max(_FadeEnd, _FadeStart + 0.01), coverage);

    return pow(fade, _FadeBias);
}

// ============================================================================
// Debug: Fade Visualization
//
// _DebugFadeVis:
//   0 = Off
//   1 = Fade Value
//
// 青 = フェードなし (LED ドット表示)
// 緑 = 部分フェード (遷移中)
// 赤 = 完全フェード (フラットカラー)
// ============================================================================
float3 DebugFadeColor(float fadeValue)
{
    float3 col = float3(0, 0, 0);
    col.g = saturate(1.0 - abs(fadeValue - 0.5) * 2.0);
    col.r = saturate(fadeValue);
    col.b = saturate(1.0 - fadeValue * 3.0);
    return col;
}

// ============================================================================
// Subpixel LED Rendering (Core)
// ============================================================================
//
// 2つのモードをサポート:
//   1. プロシージャルモード (_ProceduralLEDEnabled = 1):
//      SDF ベースで LED ドットを動的に描画。エネルギー補償付き。
//   2. テクスチャモード (_ProceduralLEDEnabled = 0):
//      従来の _LEDTex RGB マスクによるサブピクセル描画。
//
// fade (0..1) に応じてサブピクセル LED ⇔ フラットエミッションを補間。
// ============================================================================
float4 ComputeSubpixelLED(float2 inputUV, float2 ledUV, float fade)
{
    // 入力テクスチャサンプリング
    float4 inputColor = SAMPLE_TEXTURE2D(_InputTex, sampler_InputTex, inputUV);

    // HDR 強度（二乗で高輝度互換性を維持、レガシー互換）
    float intensity = _IntensityMultiplier * _IntensityMultiplier;

    float3 ledColor = float3(0, 0, 0);

    UNITY_BRANCH
    if (fade >= 0.999)
    {
        // 完全フェード時は LED 処理をスキップ
        ledColor = inputColor.rgb;
    }
    else
    {
        // --- サブピクセルカラー計算（モード分岐） ---
        float3 subpixelColor = float3(0, 0, 0);

        UNITY_BRANCH
        if (_ProceduralLEDEnabled > 0.5)
        {
            subpixelColor = ProceduralSubpixelLED(ledUV, inputColor.rgb);
        }
        else
        {
            float4 ledMask = SAMPLE_TEXTURE2D(_LEDTex, sampler_LEDTex, ledUV);
            subpixelColor = float3(
                inputColor.r * ledMask.r,
                inputColor.g * ledMask.g,
                inputColor.b * ledMask.b
            );
        }

        // --- フェード補間 ---
        // 近距離: サブピクセル LED（高コントラスト）
        // 遠距離: フラットエミッション（入力色そのまま）
        ledColor = lerp(subpixelColor, inputColor.rgb, fade);
    }

    // 輝度 + エミッションカラーティント
    ledColor *= intensity * _EmissionColor.rgb;

    // .a は入力テクスチャのアルファ（Alpha Source = Input Texture Alpha で使用）
    return float4(ledColor, inputColor.a);
}

// ============================================================================
// Transparency (Surface Type / Blend Mode / Alpha Source)
// ============================================================================
//
// _LEDSurfaceType:  0 = Opaque, 1 = Transparent
// _LEDBlendMode:    0 = Alpha    (Blend One OneMinusSrcAlpha, RGB はシェーダー内で乗算済み)
//                1 = Additive (Blend One One, RGB にアルファを乗算して加算)
// _LEDAlphaSource:  0 = None (Opacity のみ)
//                1 = Input Texture Alpha (映像入力と同じテクスチャの A チャンネル)
//                2 = Alpha Map (独自テクスチャの指定チャンネル)
//
// ブレンドステート (_LEDSrcBlend / _LEDDstBlend / _LEDZWrite / _LEDZTestForwardHDRP) は
// ShaderGUI が Surface Type / Blend Mode から自動設定する。
// ============================================================================

bool IsTransparentSurface()
{
    return _LEDSurfaceType > 0.5;
}

bool IsAdditiveBlend()
{
    return _LEDSurfaceType > 0.5 && _LEDBlendMode > 0.5;
}

float ComputeScreenAlpha(float2 uv, float inputAlpha)
{
    UNITY_BRANCH
    if (!IsTransparentSurface()) return 1.0;

    float alpha = 1.0;

    UNITY_BRANCH
    if (_LEDAlphaSource > 1.5)
    {
        // Alpha Map: Input Texture の Tiling/Offset に追従するか、独自の Tiling/Offset を使う
        float2 alphaUV = (_LEDAlphaMapUseInputUV > 0.5)
            ? GetInputUV(uv)
            : uv * _LEDAlphaMap_ST.xy + _LEDAlphaMap_ST.zw;
        float4 alphaMap = SAMPLE_TEXTURE2D(_LEDAlphaMap, sampler_LEDAlphaMap, alphaUV);
        float4 channelMask = step(abs(float4(0.0, 1.0, 2.0, 3.0) - _LEDAlphaMapChannel), 0.5);
        alpha = dot(alphaMap, channelMask);
    }
    else if (_LEDAlphaSource > 0.5)
    {
        alpha = inputAlpha;
    }

    if (_LEDAlphaSource > 0.5 && _LEDAlphaInvert > 0.5)
        alpha = 1.0 - alpha;

    return saturate(alpha * _LEDOpacity);
}

// 最終出力。Opaque はアルファ 1 固定。
// Transparent は RGB にアルファを乗算（プリマルチプライド）して返す。
// Additive はレンダーターゲットのアルファを変えないよう A=0 を出力する。
float4 ApplyBlendOutput(float3 color, float alpha)
{
    if (!IsTransparentSurface()) return float4(color, 1.0);

    color *= alpha;
    return float4(color, IsAdditiveBlend() ? 0.0 : alpha);
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

    // Anti-aliased seam mask at the edges of each cabinet cell.
    // Avoid deriving a hard step mask; it creates large normal spikes that shimmer under PBR lighting.
    float2 edgeDistance = min(cabinetUV, 1.0 - cabinetUV);
    float2 seamAA = max(fwidth(cabinetUV) * 1.5, 1e-4);
    float2 seamMask = 1.0 - smoothstep(_CabinetSeamWidth.xx, _CabinetSeamWidth.xx + seamAA, edgeDistance);
    float seam = saturate(max(seamMask.x, seamMask.y));

    // Soft finite bevel. This keeps cabinet seams visible without producing specular aliasing.
    float2 edgeDirection = lerp(1.0.xx, -1.0.xx, step(0.5.xx, cabinetUV));
    normalTS.xy += seamMask * edgeDirection * (_CabinetSeamDepth * 0.08);
    normalTS = normalize(normalTS);

    // Per-cabinet brightness variance (deterministic hash)
    float2 cabinetID = floor(uv * cabinetTiling);
    float hash = frac(sin(dot(cabinetID, float2(127.1, 311.7))) * 43758.5453);
    float variance = (hash - 0.5) * _CabinetBrightnessVariance * 2.0;
    emissiveScale *= (1.0 + variance);

    // Dim emission at seam locations
    emissiveScale *= lerp(1.0, 0.3, seam);
}

#endif // LEDSCREEN_CORE_INCLUDED
