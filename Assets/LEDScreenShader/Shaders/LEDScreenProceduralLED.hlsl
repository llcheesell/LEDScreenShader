#ifndef LEDSCREEN_PROCEDURAL_LED_INCLUDED
#define LEDSCREEN_PROCEDURAL_LED_INCLUDED

// ============================================================================
// プロシージャル LED サブピクセルレンダリング
//
// SDF (Signed Distance Function) ベースで LED ドットを動的に描画する。
// テクスチャ不要で、TAA/DLSS フレンドリー。
//
// レイアウト: RGB ストライプ（各セルを水平3分割）
// ドット形状: 円形
// ============================================================================

// ----------------------------------------------------------------------------
// SDF: 円の符号付き距離関数
// p      : 評価点
// center : 円の中心
// radius : 円の半径
// 戻り値 : 負=内部, 0=境界, 正=外部
// ----------------------------------------------------------------------------
float SDFCircle(float2 p, float2 center, float radius)
{
    return length(p - center) - radius;
}

// ----------------------------------------------------------------------------
// アンチエイリアス付き SDF マスク
// fwidth() でスクリーン空間のピクセル幅を取得し、
// 解像度に適応したスムーズなエッジを生成する。
// sdf    : 符号付き距離値
// ledUV  : LED UV（fwidth 計算の基準）
// 戻り値 : 0.0=完全に外, 1.0=完全に内
// ----------------------------------------------------------------------------
float AntiAliasedSDFMask(float sdf, float2 ledUV)
{
    // スクリーン空間での LED UV の変化量からピクセル幅を推定
    float pixelWidth = max(length(ddx(ledUV)), length(ddy(ledUV)));
    // AA 幅: 最低でも SDF 空間で意味のある幅を確保
    float aaWidth = max(pixelWidth * 0.5, 0.001);
    return 1.0 - smoothstep(-aaWidth, aaWidth, sdf);
}

// ----------------------------------------------------------------------------
// ホットスポット: ドット中心が最も明るく、端に向かって減衰
// normalizedDist : ドット中心からの正規化距離 (0=中心, 1=エッジ)
// strength       : ホットスポットの強さ (0=均一, 1=強い中心集中)
// 戻り値         : 輝度倍率 (1.0 ～ 1.0+strength)
// ----------------------------------------------------------------------------
float ComputeHotspot(float normalizedDist, float strength)
{
    // 中心ほど明るいガウシアン風の減衰
    float falloff = 1.0 - normalizedDist * normalizedDist;
    return 1.0 + strength * falloff;
}

// ----------------------------------------------------------------------------
// グロー: ドット周囲のソフトな発光ハロー
// sdf           : 符号付き距離値（正=ドット外部）
// glowRadius    : グローの到達半径
// glowIntensity : グローの強度
// 戻り値        : グロー輝度 (0..glowIntensity)
// ----------------------------------------------------------------------------
float ComputeGlow(float sdf, float glowRadius, float glowIntensity)
{
    // ドット外部のみグローを適用（内部は SDF マスクでカバー）
    float glowDist = max(sdf, 0.0);
    float glow = 1.0 - smoothstep(0.0, glowRadius, glowDist);
    return glow * glow * glowIntensity; // 二乗で自然な減衰
}

// ----------------------------------------------------------------------------
// エネルギー補償: ドット面積の逆数で輝度を補正
//
// LED パネルの物理特性:
//   - 各ドットは非常に小さいが、極めて高輝度
//   - 遠距離では多数のドットが1ピクセルに混合され、平均色に見える
//   - エネルギー保存: 近距離の点光源と遠距離の平均色が同じ総エネルギー
//
// dotRadius     : ドット半径（セル幅に対する比率）
// subpixelWidth : サブピクセル幅（= 1/3 セル幅）
// 戻り値        : 輝度補償係数
// ----------------------------------------------------------------------------
float ComputeEnergyCompensation(float dotRadius, float subpixelWidth)
{
    // ドット面積 = π * r² （サブピクセル領域内）
    // サブピクセル面積 = subpixelWidth * 1.0（セル高さ=1）
    // 補償 = サブピクセル面積 / ドット面積
    float dotArea = 3.14159265 * dotRadius * dotRadius;
    float subpixelArea = subpixelWidth * 1.0;
    // クランプして極端な値を防止（最大20倍）
    return min(subpixelArea / max(dotArea, 0.001), 20.0);
}

// ----------------------------------------------------------------------------
// メイン関数: プロシージャル LED サブピクセルレンダリング
//
// ledUV      : LED UV 座標（_LEDTilingX * _LEDTilingY のタイリング済み）
// inputColor : 入力テクスチャの色（リニア RGB）
// 戻り値     : LED サブピクセル発光色（エネルギー補償済み）
// ----------------------------------------------------------------------------
float3 ProceduralSubpixelLED(float2 ledUV, float3 inputColor)
{
    // --- セル内のローカル座標 ---
    float2 cellUV = frac(ledUV);

    // --- パラメータ取得 ---
    float dotRadius     = _ProceduralDotRadius;
    float hotspotStr    = _ProceduralHotspotStrength;
    float glowRadius    = _ProceduralGlowRadius;
    float glowIntensity = _ProceduralGlowIntensity;

    // --- サブピクセル幅（セルを3分割） ---
    float subW = 1.0 / 3.0;

    // --- 各サブピクセルの中心座標 ---
    // R: x = 1/6,  G: x = 3/6,  B: x = 5/6,  Y: 全て 0.5
    float2 centerR = float2(subW * 0.5,       0.5);
    float2 centerG = float2(subW * 1.5,       0.5);
    float2 centerB = float2(subW * 2.5,       0.5);

    // --- ドット半径（サブピクセル幅に対する比率をセル座標に変換） ---
    float scaledRadius = dotRadius * subW * 0.5;

    // --- 各サブピクセルの SDF 計算 ---
    float sdfR = SDFCircle(cellUV, centerR, scaledRadius);
    float sdfG = SDFCircle(cellUV, centerG, scaledRadius);
    float sdfB = SDFCircle(cellUV, centerB, scaledRadius);

    // --- アンチエイリアス付きマスク ---
    float maskR = AntiAliasedSDFMask(sdfR, ledUV);
    float maskG = AntiAliasedSDFMask(sdfG, ledUV);
    float maskB = AntiAliasedSDFMask(sdfB, ledUV);

    // --- ホットスポット（ドット内部のみ） ---
    float hotR = ComputeHotspot(saturate(-sdfR / max(scaledRadius, 0.001)), hotspotStr);
    float hotG = ComputeHotspot(saturate(-sdfG / max(scaledRadius, 0.001)), hotspotStr);
    float hotB = ComputeHotspot(saturate(-sdfB / max(scaledRadius, 0.001)), hotspotStr);

    // --- グロー（ドット外部のソフトハロー） ---
    float glowR = ComputeGlow(sdfR, glowRadius, glowIntensity);
    float glowG = ComputeGlow(sdfG, glowRadius, glowIntensity);
    float glowB = ComputeGlow(sdfB, glowRadius, glowIntensity);

    // --- エネルギー補償 ---
    float energyComp = ComputeEnergyCompensation(scaledRadius, subW);

    // --- 各チャンネルの発光色を合成 ---
    // ドット内部: 入力色 × マスク × ホットスポット × エネルギー補償
    // ドット外部: グローによる微弱な発光
    float3 result;
    result.r = inputColor.r * (maskR * hotR * energyComp + glowR);
    result.g = inputColor.g * (maskG * hotG * energyComp + glowG);
    result.b = inputColor.b * (maskB * hotB * energyComp + glowB);

    return result;
}

#endif // LEDSCREEN_PROCEDURAL_LED_INCLUDED
