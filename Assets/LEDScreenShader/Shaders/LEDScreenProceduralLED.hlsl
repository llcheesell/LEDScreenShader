#ifndef LEDSCREEN_PROCEDURAL_LED_INCLUDED
#define LEDSCREEN_PROCEDURAL_LED_INCLUDED

// ============================================================================
// プロシージャル LED サブピクセルレンダリング
//
// SDF ベースで LED ドットを動的に描画。テクスチャ不要。
//
// パターン:
//   0 = Honeycomb Triangle (ハニカム三角形配置) — デフォルト
//       RGB ドットを均等な三角格子に配置し、六角格子で蜂の巣状にタイリング。
//       行ごとに半ピッチずらし、色は格子座標で循環させる。
//   1 = Horizontal Stripe (水平ストライプ — 従来互換)
//   2 = Vertical Rectangle (縦長矩形)
//
// 機能:
//   - アンチエイリアス (fwidth ベース)
//   - ホットスポット (中心輝度ピーク)
//   - グロー (ドット周囲のソフト発光)
//   - エネルギー補償 (ドット面積に反比例した輝度補正)
//   - 白色ハイライト (高輝度ピクセルの中心が白く飽和)
// ============================================================================

// ----------------------------------------------------------------------------
// SDF プリミティブ
// ----------------------------------------------------------------------------

float SDFCircle(float2 p, float2 center, float radius)
{
    return length(p - center) - radius;
}

float SDFRoundedRect(float2 p, float2 center, float2 halfSize, float cornerRadius)
{
    float2 d = abs(p - center) - halfSize + cornerRadius;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - cornerRadius;
}

// ----------------------------------------------------------------------------
// アンチエイリアス付き SDF マスク
// ----------------------------------------------------------------------------
float AntiAliasedSDFMask(float sdf, float2 sdfUV)
{
    float pixelWidth = max(length(ddx(sdfUV)), length(ddy(sdfUV)));
    float aaWidth = max(pixelWidth * 0.5, 0.001);
    return 1.0 - smoothstep(-aaWidth, aaWidth, sdf);
}

// ----------------------------------------------------------------------------
// ホットスポット: ドット中心が最も明るく端に向かって減衰
// ----------------------------------------------------------------------------
float ComputeHotspot(float normalizedDist, float strength)
{
    float falloff = 1.0 - normalizedDist * normalizedDist;
    return 1.0 + strength * falloff;
}

// ----------------------------------------------------------------------------
// グロー: ドット周囲のソフトな発光ハロー
// ----------------------------------------------------------------------------
float ComputeGlow(float sdf, float glowRadius, float glowIntensity)
{
    float glowDist = max(sdf, 0.0);
    float glow = 1.0 - smoothstep(0.0, glowRadius, glowDist);
    return glow * glow * glowIntensity;
}

// ----------------------------------------------------------------------------
// Honeycomb helpers
// ----------------------------------------------------------------------------
float PositiveModulo(float value, float period)
{
    return value - floor(value / period) * period;
}

float HoneycombColorWeight(float colorIndex, float targetIndex)
{
    return 1.0 - step(0.5, abs(colorIndex - targetIndex));
}

void AccumulateHoneycombDot(
    float2 p,
    float2 center,
    float colorIndex,
    float radius,
    inout float3 nearestSdf)
{
    float dotSdf = SDFCircle(p, center, radius);
    float3 colorWeight = float3(
        HoneycombColorWeight(colorIndex, 0.0),
        HoneycombColorWeight(colorIndex, 1.0),
        HoneycombColorWeight(colorIndex, 2.0));
    nearestSdf = lerp(nearestSdf, min(nearestSdf, float3(dotSdf, dotSdf, dotSdf)), colorWeight);
}

// ============================================================================
// メイン関数: プロシージャル LED サブピクセルレンダリング
//
// ledUV      : LED UV (タイリング済み)
// inputColor : 入力テクスチャ色 (リニア RGB)
// 戻り値     : LED サブピクセル発光色 (エネルギー補償済み)
// ============================================================================
float3 ProceduralSubpixelLED(float2 ledUV, float3 inputColor)
{
    int pattern         = (int)_ProceduralLEDPattern;
    float dotRadius     = _ProceduralDotRadius;
    float hotspotStr    = _ProceduralHotspotStrength;
    float glowRadius    = _ProceduralGlowRadius;
    float glowIntensity = _ProceduralGlowIntensity;
    float highlightStr  = _ProceduralHighlightStrength;

    // --- パターン別: セル UV、ドット中心、SDF、エネルギー補償 ---
    float3 sdf = float3(0, 0, 0);
    float3 centerDist = float3(0, 0, 0); // 正規化中心距離 (0=エッジ, 1=中心)
    float energyComp = 1.0;
    float2 sdfUV = ledUV; // AA 計算用 UV (パターンにより上書き)

    UNITY_BRANCH
    if (pattern == 0)
    {
        // ============================================================
        // ── Honeycomb Triangle (ハニカム三角形配置) ──
        //
        // RGB を矩形セル内の上下に固定せず、全体を三角格子として扱う。
        // 各行は半ピッチずつずれ、色は (column - row) mod 3 で循環する。
        // これにより任意の水平帯にも RGB が均等に含まれ、縮小時の
        // インターレース状の色偏りを抑える。
        // ============================================================

        float dotPitch = 0.5;
        float rowHeight = dotPitch * 0.8660254; // sqrt(3) / 2
        float sr = dotRadius * dotPitch * 0.44;

        sdf = float3(10000.0, 10000.0, 10000.0);
        sdfUV = ledUV;

        float nearestRow = floor(ledUV.y / rowHeight + 0.5);

        [unroll]
        for (int y = -1; y <= 1; y++)
        {
            float row = nearestRow + (float)y;
            float rowOffset = PositiveModulo(row, 2.0) * 0.5;
            float nearestColumn = floor(ledUV.x / dotPitch - rowOffset + 0.5);

            [unroll]
            for (int x = -1; x <= 1; x++)
            {
                float column = nearestColumn + (float)x;
                float2 center = float2((column + rowOffset) * dotPitch,
                                      row * rowHeight);
                float colorIndex = PositiveModulo(column - row, 3.0);
                AccumulateHoneycombDot(ledUV, center, colorIndex, sr, sdf);
            }
        }

        centerDist = saturate(-sdf / max(sr, 0.001));

        // エネルギー補償: 三角格子内の各色の平均面積が 1/3 になるよう補正。
        energyComp = min((dotPitch * rowHeight) / max(3.14159265 * sr * sr, 0.001), 20.0);
    }
    else if (pattern == 2)
    {
        // ============================================================
        // ── Vertical Rectangle (縦長矩形) ──
        // ============================================================
        float subW = 1.0 / 3.0;
        float2 cellUV = frac(ledUV);

        float2 cR = float2(subW * 0.5, 0.5);
        float2 cG = float2(subW * 1.5, 0.5);
        float2 cB = float2(subW * 2.5, 0.5);

        float hw = dotRadius * subW * 0.35; // 幅: 狭い
        float hh = dotRadius * 0.45;        // 高さ: 縦長
        float cr = min(hw, hh) * 0.3;       // 角丸
        float2 hs = float2(hw, hh);

        sdf.x = SDFRoundedRect(cellUV, cR, hs, cr);
        sdf.y = SDFRoundedRect(cellUV, cG, hs, cr);
        sdf.z = SDFRoundedRect(cellUV, cB, hs, cr);

        float diagLen = length(hs);
        centerDist = saturate(-sdf / max(diagLen, 0.001));
        energyComp = min((subW * 1.0) / max(4.0 * hw * hh, 0.001), 20.0);
    }
    else
    {
        // ============================================================
        // ── Horizontal Stripe (水平ストライプ — 従来互換, pattern 1) ──
        // ============================================================
        float subW = 1.0 / 3.0;
        float2 cellUV = frac(ledUV);

        float2 cR = float2(subW * 0.5, 0.5);
        float2 cG = float2(subW * 1.5, 0.5);
        float2 cB = float2(subW * 2.5, 0.5);

        float sr = dotRadius * subW * 0.5;

        sdf.x = SDFCircle(cellUV, cR, sr);
        sdf.y = SDFCircle(cellUV, cG, sr);
        sdf.z = SDFCircle(cellUV, cB, sr);

        centerDist = saturate(-sdf / max(sr, 0.001));
        energyComp = min((subW * 1.0) / max(3.14159265 * sr * sr, 0.001), 20.0);
    }

    // --- AA マスク ---
    float3 mask;
    mask.x = AntiAliasedSDFMask(sdf.x, sdfUV);
    mask.y = AntiAliasedSDFMask(sdf.y, sdfUV);
    mask.z = AntiAliasedSDFMask(sdf.z, sdfUV);

    // --- ホットスポット ---
    float3 hot;
    hot.x = ComputeHotspot(centerDist.x, hotspotStr);
    hot.y = ComputeHotspot(centerDist.y, hotspotStr);
    hot.z = ComputeHotspot(centerDist.z, hotspotStr);

    // --- グロー ---
    float3 glow;
    glow.x = ComputeGlow(sdf.x, glowRadius, glowIntensity);
    glow.y = ComputeGlow(sdf.y, glowRadius, glowIntensity);
    glow.z = ComputeGlow(sdf.z, glowRadius, glowIntensity);

    // --- 基本発光色 ---
    // ドット内部: 入力色 × マスク × ホットスポット × エネルギー補償
    // ドット外部: グローによる微弱な発光
    float3 result;
    result.r = inputColor.r * (mask.x * hot.x * energyComp + glow.x);
    result.g = inputColor.g * (mask.y * hot.y * energyComp + glow.y);
    result.b = inputColor.b * (mask.z * hot.z * energyComp + glow.z);

    // --- 白色ハイライト ---
    // 高輝度ピクセルの中心が白く飽和する効果。
    // 実際の LED は高電流時にダイが広帯域発光し、中心が白く見える。
    // inputColor² で高輝度のみに効果を限定、centerDist² で中心に集中。
    UNITY_BRANCH
    if (highlightStr > 0.001)
    {
        float3 hl = inputColor * inputColor
                   * centerDist * centerDist
                   * mask
                   * (highlightStr * energyComp);
        float totalWhite = hl.x + hl.y + hl.z;
        result += totalWhite;
    }

    return result;
}

#endif // LEDSCREEN_PROCEDURAL_LED_INCLUDED
