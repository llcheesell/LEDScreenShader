using UnityEditor;
using UnityEngine;

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
    // Foldout state (persisted across inspector redraws via SessionState)
    // ========================================================================
    static bool _foldInputScreen     = true;
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
