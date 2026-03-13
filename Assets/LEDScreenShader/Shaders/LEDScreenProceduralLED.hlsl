#ifndef LEDSCREEN_PROCEDURAL_LED_INCLUDED
#define LEDSCREEN_PROCEDURAL_LED_INCLUDED

// ============================================================================
// プロシージャル LED サブピクセルレンダリング
//
// SDF ベースで LED ドットを動的に描画。テクスチャ不要。
//
// パターン:
//   0 = Honeycomb Triangle (ハニカム三角形配置) — デフォルト
//       RGB ドットを正三角形に配置し、六角格子で蜂の巣状にタイリング。
//       偶数行は逆三角 ▽、奇数行は正三角 △ + X 半セルオフセット。
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
    float3 sdf;
    float3 centerDist; // 正規化中心距離 (0=エッジ, 1=中心)
    float energyComp;
    float2 sdfUV = ledUV; // AA 計算用 UV (パターンにより上書き)

    UNITY_BRANCH
    if (pattern == 0)
    {
        // ============================================================
        // ── Honeycomb Triangle (ハニカム三角形配置) ──
        //
        // 六角格子アスペクト補正:
        //   Y 軸を 2/sqrt(3) ≈ 1.1547 で拡大し、
        //   各セルの実効高さを sqrt(3)/2 ≈ 0.866 に圧縮。
        //   これにより六角格子の行間隔に近い比率になる。
        //
        // ドット配置:
        //   セル内で RGB 3 ドットが正三角形を形成。
        //   底辺 0.5、高さ sqrt(3)/4 ≈ 0.433。
        //   偶数行: ▽ (R 左上, B 右上, G 中央下)
        //   奇数行: △ (R 左下, B 右下, G 中央上) + X 0.5 オフセット
        //
        //   隣接セルのドットが視覚的に蜂の巣パターンを形成。
        // ============================================================

        // Hex aspect correction
        float2 hexUV = ledUV;
        hexUV.y *= 1.1547005; // 2.0 / sqrt(3.0)

        float row = floor(hexUV.y);
        float isOddRow = step(0.25, frac(row * 0.5));
        hexUV.x += isOddRow * 0.5;

        float2 cellUV = frac(hexUV);
        sdfUV = hexUV;

        // 正三角形の頂点座標 (セル中央配置)
        // base = 0.5, height = sqrt(3)/4 ≈ 0.433
        // Y 範囲: [0.5 - 0.217, 0.5 + 0.217] = [0.283, 0.717]
        float yTop = 0.283;
        float yBot = 0.717;

        // 偶数行 ▽: R(左上) B(右上) G(中央下)
        // 奇数行 △: R(左下) B(右下) G(中央上)
        float2 cR = float2(0.25, lerp(yTop, yBot, isOddRow));
        float2 cG = float2(0.50, lerp(yBot, yTop, isOddRow));
        float2 cB = float2(0.75, lerp(yTop, yBot, isOddRow));

        // ドット半径: 最大 dotRadius=1.0 で sr=0.22
        // ドット境界: yTop - sr = 0.063, 1.0 - yBot - sr = 0.063 → セル内に収まる
        float sr = dotRadius * 0.22;

        sdf.x = SDFCircle(cellUV, cR, sr);
        sdf.y = SDFCircle(cellUV, cG, sr);
        sdf.z = SDFCircle(cellUV, cB, sr);

        centerDist = saturate(-sdf / max(sr, 0.001));

        // エネルギー補償: 各ドットがセルの 1/3 を担当
        // comp = (1/3) / (π × sr²) → ドット面積に反比例
        energyComp = min((1.0 / 3.0) / max(3.14159265 * sr * sr, 0.001), 20.0);
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
