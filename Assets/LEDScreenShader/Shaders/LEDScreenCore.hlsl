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
    float dist = LED_CAMERA_DISTANCE(worldPos);

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

    float3 ledColor = float3(0, 0, 0);

    UNITY_BRANCH
    if (fade >= 0.999)
    {
        // 完全フェード時は LED 処理をスキップ
        ledColor = inputColor.rgb * intensity;
        ledColor *= _DistantFadeBrightness.rgb;
    }
    else
    {
        // --- サブピクセルカラー計算（モード分岐） ---
        float3 subpixelColor = float3(0, 0, 0);

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
        ledColor = lerp(subpixelColor, flatColor, fade);

        ledColor *= intensity;

        // 遠距離輝度補正
        ledColor = lerp(ledColor, ledColor * _DistantFadeBrightness.rgb, fade);
    }

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
// Motion Vectors
// ============================================================================
//
// LED パネルは映像コンテンツが毎フレーム変化するため、
// TAA/DLSS のテンポラル蓄積がゴースト/残像を引き起こす。
//
// 対策: URP/HDRP の MotionVectors パスで意図的に大きなモーションベクターを
// 出力し、TAA/DLSS にヒストリーサンプルを棄却させる。
// これにより各フレームの現在値のみが使用され、ゴーストが防止される。
//
// 実装は LEDScreen.shader 内の各パイプライン SubShader に
// HLSLPROGRAM ベースの専用パスとして配置。
// CGPROGRAM は UnityCG.cginc の定数バッファレイアウトが
// パイプラインの期待と競合するため使用しない。

#endif // LEDSCREEN_CORE_INCLUDED
