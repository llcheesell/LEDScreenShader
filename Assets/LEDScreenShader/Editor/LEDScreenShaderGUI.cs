using UnityEditor;
using UnityEngine;

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
    static bool _foldInputScreen    = true;
    static bool _foldLEDSubpixel    = true;
    static bool _foldEmission       = true;
    static bool _foldDistantFade    = true;
    static bool _foldCabinetGrid    = false;
    static bool _foldSurfaceMaterial = true;
    static bool _foldRendering      = true;

    // ========================================================================
    // OnGUI
    // ========================================================================
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        Material material = materialEditor.target as Material;

        // ----------------------------------------------------------------
        // Input Screen
        // ----------------------------------------------------------------
        _foldInputScreen = Section("Input Screen", _foldInputScreen, () =>
        {
            materialEditor.ShaderProperty(FindProp("_InputTex", properties), "Texture");
            // Show Tiling/Offset for _InputTex
            materialEditor.TextureScaleOffsetProperty(FindProp("_InputTex", properties));
        });

        // ----------------------------------------------------------------
        // LED Subpixel
        // ----------------------------------------------------------------
        _foldLEDSubpixel = Section("LED Subpixel", _foldLEDSubpixel, () =>
        {
            materialEditor.ShaderProperty(FindProp("_LEDTex", properties), "LED Mask (RGB = subpixel mask)");
            materialEditor.ShaderProperty(FindProp("_LEDTilingX", properties), "LED Columns");
            materialEditor.ShaderProperty(FindProp("_LEDTilingY", properties), "LED Rows");
        });

        // ----------------------------------------------------------------
        // Emission
        // ----------------------------------------------------------------
        _foldEmission = Section("Emission", _foldEmission, () =>
        {
            materialEditor.ShaderProperty(FindProp("_EmissionColor", properties), "Emission Color");
            materialEditor.ShaderProperty(FindProp("_IntensityMultiplier", properties), "Intensity");
        });

        // ----------------------------------------------------------------
        // Distant Fade
        // ----------------------------------------------------------------
        _foldDistantFade = Section("Distant Fade", _foldDistantFade, () =>
        {
            materialEditor.ShaderProperty(FindProp("_DistantFadeStart", properties), "Start Distance");
            materialEditor.ShaderProperty(FindProp("_DistantFadeEnd", properties), "End Distance");
            materialEditor.ShaderProperty(FindProp("_DistantFadeBrightness", properties), "Fade Brightness");
        });

        // ----------------------------------------------------------------
        // Cabinet Grid (Toggle + Foldout combo)
        // ----------------------------------------------------------------
        DrawCabinetGridSection(materialEditor, properties);

        // ----------------------------------------------------------------
        // Surface Material
        // ----------------------------------------------------------------
        _foldSurfaceMaterial = Section("Surface Material", _foldSurfaceMaterial, () =>
        {
            MaterialProperty uvLink = FindProp("_SurfaceUVLinkLED", properties);
            materialEditor.ShaderProperty(uvLink, "Link UV to LED Tiling");

            EditorGUILayout.Space(2);
            materialEditor.ShaderProperty(FindProp("_BaseColor", properties), "Base Color");

            MaterialProperty baseMap = FindProp("_BaseMap", properties);
            materialEditor.TexturePropertySingleLine(
                new GUIContent("Base Map"), baseMap);

            // Only show Tiling/Offset when UV is NOT linked to LED
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
            materialEditor.ShaderProperty(FindProp("_Metallic", properties), "Metallic");
            materialEditor.ShaderProperty(FindProp("_Smoothness", properties), "Smoothness");
            materialEditor.ShaderProperty(FindProp("_OcclusionStrength", properties), "Occlusion Strength");
            EditorGUI.indentLevel -= 2;
        });

        // ----------------------------------------------------------------
        // Rendering
        // ----------------------------------------------------------------
        _foldRendering = Section("Rendering", _foldRendering, () =>
        {
            materialEditor.ShaderProperty(FindProp("_CullMode", properties), "Cull Mode");
            materialEditor.RenderQueueField();
            materialEditor.EnableInstancingField();
            materialEditor.DoubleSidedGIField();
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
    // Cabinet Grid: checkbox in header + foldable content
    // ========================================================================
    void DrawCabinetGridSection(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        EditorGUILayout.Space(4);

        MaterialProperty enableProp = FindProp("_CabinetGridEnabled", properties);
        bool enabled = enableProp.floatValue > 0.5f;

        // Draw a custom header with checkbox + foldout
        Rect headerRect = GUILayoutUtility.GetRect(
            GUIContent.none, EditorStyles.foldoutHeader);

        // Checkbox rect (left side of header)
        Rect checkRect = new Rect(headerRect.x + 18, headerRect.y, 16, headerRect.height);

        // Handle checkbox click before foldout processes the event
        Event evt = Event.current;
        if (evt.type == EventType.MouseDown && checkRect.Contains(evt.mousePosition))
        {
            enableProp.floatValue = enabled ? 0.0f : 1.0f;
            enabled = !enabled;
            evt.Use();
        }

        // Draw foldout header
        _foldCabinetGrid = EditorGUI.BeginFoldoutHeaderGroup(headerRect, _foldCabinetGrid, "    Cabinet Grid");

        // Draw checkbox on top of the header
        EditorGUI.showMixedValue = enableProp.hasMixedValue;
        EditorGUI.BeginChangeCheck();
        bool newEnabled = EditorGUI.Toggle(checkRect, enabled);
        if (EditorGUI.EndChangeCheck())
        {
            enableProp.floatValue = newEnabled ? 1.0f : 0.0f;
        }
        EditorGUI.showMixedValue = false;

        if (_foldCabinetGrid)
        {
            EditorGUI.indentLevel++;
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
    // Utility
    // ========================================================================
    static MaterialProperty FindProp(string name, MaterialProperty[] properties)
    {
        return FindProperty(name, properties);
    }
}
