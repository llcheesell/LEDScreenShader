using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Llcheesell.LEDScreenShader.Editor
{
/// <summary>
/// Custom ShaderGUI for LEDScreen shader.
/// Provides foldable sections for all property groups and
/// a checkbox+foldout combo for the Cabinet Grid toggle group.
/// </summary>
public class LEDScreenShaderGUI : ShaderGUI
{
    // ========================================================================
    // Foldout state kept in static fields across inspector redraws.
    // ========================================================================
    static bool _foldInputScreen     = true;
    static bool _foldSurfaceOptions  = true;
    static bool _foldLEDSubpixel     = true;
    static bool _foldProceduralLED   = true;
    static bool _foldEmission        = true;
    static bool _foldLEDFade         = true;
    static bool _foldCabinetGrid     = false;
    static bool _foldSurfaceMaterial = false;
    static bool _foldRendering       = true;
    static bool _foldDebug           = false;

    // ========================================================================
    // OnGUI
    // ========================================================================
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        // Surface Type / Blend Mode の変更をブレンドステートへ反映するため、全体を監視する
        EditorGUI.BeginChangeCheck();

        // ----------------------------------------------------------------
        // Input Screen
        // ----------------------------------------------------------------
        _foldInputScreen = Section("Input Screen", _foldInputScreen, () =>
        {
            MaterialProperty inputTex = FindProp("_InputTex", properties);
            materialEditor.TexturePropertySingleLine(
                new GUIContent("Input Screen Texture"), inputTex);
            EditorGUI.indentLevel += 2;
            materialEditor.TextureScaleOffsetProperty(inputTex);
            EditorGUI.indentLevel -= 2;
        });

        // ----------------------------------------------------------------
        // Surface Options (Opaque / Transparent)
        // ----------------------------------------------------------------
        DrawSurfaceOptionsSection(materialEditor, properties);

        // ----------------------------------------------------------------
        // LED Subpixel
        // ----------------------------------------------------------------
        _foldLEDSubpixel = Section("LED Subpixel", _foldLEDSubpixel, () =>
        {
            // プロシージャルモード有効時は LED テクスチャを非表示
            MaterialProperty procEnabled = FindProp("_ProceduralLEDEnabled", properties);
            if (procEnabled.floatValue < 0.5f)
            {
                materialEditor.TexturePropertySingleLine(
                    new GUIContent("LED Mask (RGB = subpixel mask)"),
                    FindProp("_LEDTex", properties));
            }
            else
            {
                EditorGUILayout.HelpBox(
                    "プロシージャルモード有効。LED テクスチャは使用されません。",
                    MessageType.Info);
            }
            materialEditor.ShaderProperty(FindProp("_LEDTilingX", properties), "LED Columns");
            materialEditor.ShaderProperty(FindProp("_LEDTilingY", properties), "LED Rows");
        });

        // ----------------------------------------------------------------
        // Procedural LED (Toggle + Foldout)
        // ----------------------------------------------------------------
        DrawProceduralLEDSection(materialEditor, properties);

        // ----------------------------------------------------------------
        // Emission
        // ----------------------------------------------------------------
        _foldEmission = Section("Emission", _foldEmission, () =>
        {
            materialEditor.ShaderProperty(FindProp("_EmissionColor", properties), "Emission Color");
            materialEditor.ShaderProperty(FindProp("_IntensityMultiplier", properties), "Intensity");
        });

        // ----------------------------------------------------------------
        // LED Fade
        // ----------------------------------------------------------------
        _foldLEDFade = Section("LED Fade", _foldLEDFade, () =>
        {
            materialEditor.ShaderProperty(FindProp("_FadeStart", properties),
                new GUIContent("Fade Start",
                    "これ以下の密度ではフェードなし（サブピクセル LED 表示）。\n" +
                    "値が小さいほど、より粗い（近い）状態でもフェードを開始。"));
            materialEditor.ShaderProperty(FindProp("_FadeEnd", properties),
                new GUIContent("Fade End",
                    "これ以上の密度では完全フェード（フラットエミッション）。\n" +
                    "値が大きいほど、より細かい（遠い）状態まで LED が残る。"));
            materialEditor.ShaderProperty(FindProp("_FadeBias", properties),
                new GUIContent("Fade Bias",
                    "< 1.0: フェードが早く始まる（残像軽減に有効）\n" +
                    "= 1.0: デフォルト\n" +
                    "> 1.0: フェードが遅い（LED ドットが鮮明）"));
        });

        // ----------------------------------------------------------------
        // Cabinet Grid (Toggle + Foldout)
        // ----------------------------------------------------------------
        DrawCabinetGridSection(materialEditor, properties);

        // ----------------------------------------------------------------
        // Surface Material
        // ----------------------------------------------------------------
        DrawSurfaceMaterialSection(materialEditor, properties);

        // ----------------------------------------------------------------
        // Rendering
        // ----------------------------------------------------------------
        _foldRendering = Section("Rendering", _foldRendering, () =>
        {
            materialEditor.ShaderProperty(FindProp("_CullMode", properties), "Cull Mode");
            EditorGUILayout.Space(5);
            materialEditor.ShaderProperty(
                FindProp("_InvalidateMotionVectors", properties),
                new GUIContent("Force Large Motion Vectors",
                    "TAA/DLSS ゴースト防止。大きなモーションベクターを出力し、テンポラル蓄積を棄却させます。"));
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
        });

        // ----------------------------------------------------------------
        // Debug
        // ----------------------------------------------------------------
        _foldDebug = Section("Debug", _foldDebug, () =>
        {
            materialEditor.ShaderProperty(FindProp("_DebugFadeVis", properties),
                new GUIContent("Fade Visualization",
                    "青=フェードなし  緑=遷移中  赤=完全フェード"));
        });

        if (EditorGUI.EndChangeCheck())
        {
            foreach (Object target in materialEditor.targets)
            {
                Material material = target as Material;
                if (material != null) SetupMaterialBlendState(material);
            }
        }
    }

    // ========================================================================
    // Material setup
    // ========================================================================
    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);
        SetupMaterialBlendState(material);
    }

#if UNITY_2021_2_OR_NEWER
    public override void ValidateMaterial(Material material)
    {
        SetupMaterialBlendState(material);
    }
#endif

    static readonly string[] k_OpaqueOnlyPasses =
    {
        "DepthOnly", "DepthForwardOnly", "ShadowCaster", "MotionVectors",
    };

    /// <summary>
    /// Surface Type / Blend Mode からブレンドステート、Render Queue、
    /// RenderType タグ、深度系パスの有効/無効を設定する。
    /// Opaque のマテリアルは既定値のままなので、既存マテリアルに差分は発生しない。
    /// </summary>
    public static void SetupMaterialBlendState(Material material)
    {
        if (material == null || !material.HasProperty("_LEDSurfaceType")) return;

        bool transparent = material.GetFloat("_LEDSurfaceType") > 0.5f;
        bool additive = transparent && material.GetFloat("_LEDBlendMode") > 0.5f;

        // RGB はシェーダー内でアルファ乗算済み（プリマルチプライド）
        BlendMode dstBlend = !transparent ? BlendMode.Zero
                           : additive     ? BlendMode.One
                                          : BlendMode.OneMinusSrcAlpha;
        SetFloatIfChanged(material, "_LEDSrcBlend", (float)BlendMode.One);
        SetFloatIfChanged(material, "_LEDDstBlend", (float)dstBlend);
        SetFloatIfChanged(material, "_LEDZWrite", transparent ? 0f : 1f);
        // HDRP: Opaque は DepthForwardOnly と一致したピクセルのみ描画 (Equal)。
        // Transparent は深度プリパスが描かれないため LessEqual。
        SetFloatIfChanged(material, "_LEDZTestForwardHDRP",
            (float)(transparent ? CompareFunction.LessEqual : CompareFunction.Equal));

        material.SetOverrideTag("RenderType", transparent ? "Transparent" : "");

        // 透過時は深度・影・モーションベクター（TAA ゴースト対策）パスを無効化
        foreach (string pass in k_OpaqueOnlyPasses)
        {
            if (material.GetShaderPassEnabled(pass) == transparent)
                material.SetShaderPassEnabled(pass, !transparent);
        }

        // Render Queue: 範囲外のときだけ補正し、ユーザー指定の値は尊重する
        int queue = material.renderQueue;
        if (transparent && queue <= (int)RenderQueue.GeometryLast)
            material.renderQueue = (int)RenderQueue.Transparent;
        else if (!transparent && queue > (int)RenderQueue.GeometryLast)
            material.renderQueue = -1;
    }

    static void SetFloatIfChanged(Material material, string name, float value)
    {
        if (!material.HasProperty(name)) return;
        if (!Mathf.Approximately(material.GetFloat(name), value))
            material.SetFloat(name, value);
    }

    // ========================================================================
    // Surface Options
    // ========================================================================
    void DrawSurfaceOptionsSection(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        _foldSurfaceOptions = Section("Surface Options", _foldSurfaceOptions, () =>
        {
            MaterialProperty surfaceType = FindProp("_LEDSurfaceType", properties);
            materialEditor.ShaderProperty(surfaceType, new GUIContent("Surface Type",
                "Opaque: 不透明（従来動作）\n" +
                "Transparent: アルファ合成 / 加算合成"));

            bool transparent = surfaceType.hasMixedValue || surfaceType.floatValue > 0.5f;
            if (!transparent) return;

            materialEditor.ShaderProperty(FindProp("_LEDBlendMode", properties), new GUIContent("Blend Mode",
                "Alpha: アルファブレンド（背景を隠す）\n" +
                "Additive: 加算合成（黒は透明、アルファは明るさとして作用）"));

            EditorGUILayout.Space(2);
            MaterialProperty alphaSource = FindProp("_LEDAlphaSource", properties);
            materialEditor.ShaderProperty(alphaSource, new GUIContent("Alpha Source",
                "None: Opacity のみ\n" +
                "Input Texture Alpha: Input Screen Texture の A チャンネル\n" +
                "Alpha Map: 独自のアルファマップテクスチャ"));

            bool useAlphaMap = alphaSource.hasMixedValue || alphaSource.floatValue > 1.5f;
            if (useAlphaMap)
            {
                EditorGUI.indentLevel++;
                MaterialProperty alphaMap = FindProp("_LEDAlphaMap", properties);
                materialEditor.TexturePropertySingleLine(new GUIContent("Alpha Map"), alphaMap);
                materialEditor.ShaderProperty(FindProp("_LEDAlphaMapChannel", properties), "Channel");

                MaterialProperty useInputUV = FindProp("_LEDAlphaMapUseInputUV", properties);
                materialEditor.ShaderProperty(useInputUV, new GUIContent("Use Input UV",
                    "有効: Input Screen Texture の Tiling/Offset に追従\n" +
                    "無効: Alpha Map 独自の Tiling/Offset を使用"));
                if (useInputUV.hasMixedValue || useInputUV.floatValue < 0.5f)
                {
                    EditorGUI.indentLevel += 2;
                    materialEditor.TextureScaleOffsetProperty(alphaMap);
                    EditorGUI.indentLevel -= 2;
                }
                EditorGUI.indentLevel--;
            }

            using (new EditorGUI.DisabledScope(!alphaSource.hasMixedValue && alphaSource.floatValue < 0.5f))
            {
                materialEditor.ShaderProperty(FindProp("_LEDAlphaInvert", properties), "Invert Alpha");
            }
            materialEditor.ShaderProperty(FindProp("_LEDOpacity", properties), "Opacity");

            EditorGUILayout.HelpBox(
                "Transparent では深度・影・モーションベクター（TAA ゴースト対策）パスを無効化します。",
                MessageType.Info);
        });
    }

    // ========================================================================
    // Foldable section helper
    // ========================================================================
    static bool Section(string title, bool foldout, System.Action drawContent)
    {
        EditorGUILayout.Space(4);
        foldout = EditorGUILayout.BeginFoldoutHeaderGroup(foldout, title);
        if (foldout)
        {
            EditorGUI.indentLevel++;
            drawContent();
            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
        return foldout;
    }

    // ========================================================================
    // Procedural LED: foldout header with enable checkbox inside
    // ========================================================================
    void DrawProceduralLEDSection(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.Space(4);

        MaterialProperty enableProp = FindProp("_ProceduralLEDEnabled", properties);
        bool enabled = enableProp.floatValue > 0.5f;

        // 標準のフォールドアウトヘッダー
        _foldProceduralLED = EditorGUILayout.BeginFoldoutHeaderGroup(
            _foldProceduralLED, "Procedural LED");

        if (_foldProceduralLED)
        {
            EditorGUI.indentLevel++;

            // 有効/無効チェックボックス
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = enableProp.hasMixedValue;
            bool newEnabled = EditorGUILayout.Toggle("Enable", enabled);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                enableProp.floatValue = newEnabled ? 1.0f : 0.0f;
                enabled = newEnabled;
            }

            // プロシージャル LED パラメータ — 無効時はグレーアウト
            using (new EditorGUI.DisabledScope(!enabled))
            {
                materialEditor.ShaderProperty(FindProp("_ProceduralLEDPattern", properties), "Pattern");
                materialEditor.ShaderProperty(FindProp("_ProceduralDotRadius", properties), "Dot Radius");
                materialEditor.ShaderProperty(FindProp("_ProceduralHotspotStrength", properties), "Hotspot Strength");
                materialEditor.ShaderProperty(FindProp("_ProceduralGlowRadius", properties), "Glow Radius");
                materialEditor.ShaderProperty(FindProp("_ProceduralGlowIntensity", properties), "Glow Intensity");
                materialEditor.ShaderProperty(FindProp("_ProceduralHighlightStrength", properties), "Highlight Strength");
            }

            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    // ========================================================================
    // Cabinet Grid: foldout header with enable checkbox inside
    // ========================================================================
    void DrawCabinetGridSection(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.Space(4);

        MaterialProperty enableProp = FindProp("_CabinetGridEnabled", properties);
        bool enabled = enableProp.floatValue > 0.5f;

        // Use standard foldout header
        _foldCabinetGrid = EditorGUILayout.BeginFoldoutHeaderGroup(
            _foldCabinetGrid, "Cabinet Grid");

        if (_foldCabinetGrid)
        {
            EditorGUI.indentLevel++;

            // Enable checkbox as first item inside the group
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = enableProp.hasMixedValue;
            bool newEnabled = EditorGUILayout.Toggle("Enable", enabled);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                enableProp.floatValue = newEnabled ? 1.0f : 0.0f;
                enabled = newEnabled;
            }

            // Grid settings — grayed out when disabled
            using (new EditorGUI.DisabledScope(!enabled))
            {
                materialEditor.ShaderProperty(FindProp("_CabinetColumns", properties), "Columns");
                materialEditor.ShaderProperty(FindProp("_CabinetRows", properties), "Rows");
                materialEditor.ShaderProperty(FindProp("_CabinetSeamWidth", properties), "Seam Width");
                materialEditor.ShaderProperty(FindProp("_CabinetSeamDepth", properties), "Seam Depth");
                materialEditor.ShaderProperty(FindProp("_CabinetBrightnessVariance", properties), "Brightness Variance");
            }

            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    // ========================================================================
    // Surface Material: foldout header with enable checkbox inside
    // ========================================================================
    void DrawSurfaceMaterialSection(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.Space(4);

        MaterialProperty enableProp = FindProp("_BaseMaterialEnabled", properties);
        bool enabled = enableProp.floatValue > 0.5f;

        _foldSurfaceMaterial = EditorGUILayout.BeginFoldoutHeaderGroup(
            _foldSurfaceMaterial, "Surface Material");

        if (_foldSurfaceMaterial)
        {
            EditorGUI.indentLevel++;

            // 有効/無効チェックボックス
            EditorGUI.BeginChangeCheck();
            EditorGUI.showMixedValue = enableProp.hasMixedValue;
            bool newEnabled = EditorGUILayout.Toggle("Enable", enabled);
            EditorGUI.showMixedValue = false;
            if (EditorGUI.EndChangeCheck())
            {
                enableProp.floatValue = newEnabled ? 1.0f : 0.0f;
                enabled = newEnabled;
            }

            if (!enabled)
            {
                EditorGUILayout.HelpBox(
                    "無効時は LED エミッションのみ。PBR ライティングはスキップされます。",
                    MessageType.Info);
            }

            // PBR パラメータ — 無効時はグレーアウト
            using (new EditorGUI.DisabledScope(!enabled))
            {
                MaterialProperty uvLink = FindProp("_SurfaceUVLinkLED", properties);
                materialEditor.ShaderProperty(uvLink, "Link UV to LED Tiling");

                EditorGUILayout.Space(2);
                materialEditor.ShaderProperty(FindProp("_BaseColor", properties), "Base Color");

                MaterialProperty baseMap = FindProp("_BaseMap", properties);
                materialEditor.TexturePropertySingleLine(
                    new GUIContent("Base Map"), baseMap);

                if (uvLink.floatValue < 0.5f)
                {
                    EditorGUI.indentLevel += 2;
                    materialEditor.TextureScaleOffsetProperty(baseMap);
                    EditorGUI.indentLevel -= 2;
                }
                else
                {
                    EditorGUI.indentLevel += 2;
                    EditorGUILayout.HelpBox(
                        "UV linked to LED Tiling. Disable to set custom Tiling/Offset.",
                        MessageType.Info);
                    EditorGUI.indentLevel -= 2;
                }

                EditorGUILayout.Space(5);
                materialEditor.TexturePropertySingleLine(
                    new GUIContent("Normal Map"),
                    FindProp("_NormalMap", properties),
                    FindProp("_NormalStrength", properties));

                EditorGUILayout.Space(5);
                materialEditor.TexturePropertySingleLine(
                    new GUIContent("Mask Map (R=Metal G=AO A=Smooth)"),
                    FindProp("_MaskMap", properties));

                EditorGUI.indentLevel += 2;
                EditorGUILayout.HelpBox(
                    "Mask Map 使用時は Metallic/Smoothness を 1.0 に設定してテクスチャ値を使用。",
                    MessageType.None);
                materialEditor.ShaderProperty(FindProp("_Metallic", properties), "Metallic");
                materialEditor.ShaderProperty(FindProp("_Smoothness", properties), "Smoothness");
                materialEditor.ShaderProperty(FindProp("_OcclusionStrength", properties), "Occlusion Strength");
                EditorGUI.indentLevel -= 2;
            }

            EditorGUI.indentLevel--;
        }
        EditorGUILayout.EndFoldoutHeaderGroup();
    }

    // ========================================================================
    // Utility
    // ========================================================================
    static MaterialProperty FindProp(string name, MaterialProperty[] properties)
    {
        return FindProperty(name, properties);
    }

}
}
