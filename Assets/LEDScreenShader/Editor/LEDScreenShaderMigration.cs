using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

namespace Llcheesell.LEDScreenShader.Editor
{
[InitializeOnLoad]
public static class LEDScreenShaderMigration
{
    const string NativeShaderName = "llcheesell/LEDScreen";
    const string NativeShaderGuid = "2272d0b0b07a14fd9b3a99b038da5401";
    const string PromptVersion = "2.0.0";

    static readonly HashSet<string> LegacyShaderGuids = new HashSet<string>
    {
        "7abaa2c3967eb2c43880aa8fb27d88de", // Legacy HDRP Shader Graph
        "e7cea1252f1974843b14167ae6777494", // Legacy URP Shader Graph
        "67fde91b781998e4c819c856f1077acb", // Legacy Built-in shader
    };

    static readonly HashSet<string> LegacyShaderNames = new HashSet<string>
    {
        "Shader Graphs/LEDScreenHDRP",
        "Shader Graphs/LEDScreenURP",
        "LEDScreenShader",
    };

    static LEDScreenShaderMigration()
    {
        EditorApplication.delayCall += ShowPromptIfNeeded;
    }

    [MenuItem("Tools/LEDScreenShader/Migrate Legacy Materials to Native Shader")]
    public static void MigrateLegacyMaterialsMenu()
    {
        Shader nativeShader = FindNativeShader();
        if (nativeShader == null)
        {
            EditorUtility.DisplayDialog(
                "LEDScreenShader Migration",
                "Native shader was not found: " + NativeShaderName + "\n" +
                "ネイティブシェーダーが見つかりませんでした。",
                "OK");
            return;
        }

        List<LegacyMaterial> materials = FindLegacyMaterials();
        if (materials.Count == 0)
        {
            EditorUtility.DisplayDialog(
                "LEDScreenShader Migration",
                "No legacy LEDScreenShader materials were found.\n" +
                "移行対象の旧LEDScreenShaderマテリアルは見つかりませんでした。",
                "OK");
            return;
        }

        bool shouldMigrate = EditorUtility.DisplayDialog(
            "LEDScreenShader Migration",
            "Found " + materials.Count + " legacy LEDScreenShader material(s).\n\n" +
            "This will switch them to " + NativeShaderName + " and copy compatible properties.\n" +
            "旧マテリアルをネイティブシェーダーへ切り替え、互換性のある設定を引き継ぎます。",
            "Migrate",
            "Cancel");

        if (shouldMigrate)
        {
            MigrateMaterials(materials, nativeShader, true);
        }
    }

    [MenuItem("Tools/LEDScreenShader/Scan Legacy Materials")]
    public static void ScanLegacyMaterialsMenu()
    {
        List<LegacyMaterial> materials = FindLegacyMaterials();
        if (materials.Count == 0)
        {
            EditorUtility.DisplayDialog(
                "LEDScreenShader Migration",
                "No legacy LEDScreenShader materials were found.\n" +
                "移行対象の旧LEDScreenShaderマテリアルは見つかりませんでした。",
                "OK");
            return;
        }

        string message = "Found " + materials.Count + " legacy LEDScreenShader material(s):\n" +
            "移行対象の旧LEDScreenShaderマテリアルが見つかりました。\n\n";
        int visibleCount = Mathf.Min(materials.Count, 20);
        for (int i = 0; i < visibleCount; i++)
        {
            message += materials[i].Path + "\n";
        }

        if (materials.Count > visibleCount)
        {
            message += "...and " + (materials.Count - visibleCount) + " more.";
        }

        EditorUtility.DisplayDialog("LEDScreenShader Migration", message, "OK");
    }

    public static void MigrateAllLegacyMaterialsWithoutPrompt()
    {
        Shader nativeShader = FindNativeShader();
        if (nativeShader == null)
        {
            Debug.LogError("LEDScreenShader migration failed. Native shader was not found: " + NativeShaderName);
            return;
        }

        List<LegacyMaterial> materials = FindLegacyMaterials();
        MigrateMaterials(materials, nativeShader, false);
        Debug.Log("LEDScreenShader migration complete. Scanned legacy material count: " + materials.Count);
    }

    static void ShowPromptIfNeeded()
    {
        if (Application.isBatchMode)
        {
            return;
        }

        if (EditorApplication.isCompiling || EditorApplication.isUpdating)
        {
            EditorApplication.delayCall += ShowPromptIfNeeded;
            return;
        }

        string sessionKey = "LEDScreenShader.MigrationPrompt.Session." + PromptVersion;
        string dontShowKey = "LEDScreenShader.MigrationPrompt.DoNotShow." + PromptVersion + "." + Application.dataPath;

        if (SessionState.GetBool(sessionKey, false) || EditorPrefs.GetBool(dontShowKey, false))
        {
            return;
        }

        List<LegacyMaterial> materials = FindLegacyMaterials();
        if (materials.Count == 0)
        {
            return;
        }

        int choice = EditorUtility.DisplayDialogComplex(
            "LEDScreenShader 2.0 Migration",
            "Found " + materials.Count + " material(s) using the previous LEDScreenShader Shader Graph or legacy shader.\n\n" +
            "旧Shader Graphまたは旧シェーダーを使用しているマテリアルが見つかりました。\n\n" +
            "They can be migrated to the native shader: " + NativeShaderName + "\n\n" +
            "ネイティブシェーダーへ移行できます: " + NativeShaderName + "\n\n" +
            "Materials with Missing Shader are also detected when their serialized shader GUID matches a known legacy shader.",
            "Migrate Now",
            "Later",
            "Don't Show Again");

        if (choice == 0)
        {
            Shader nativeShader = FindNativeShader();
            if (nativeShader != null)
            {
                MigrateMaterials(materials, nativeShader, true);
            }

            SessionState.SetBool(sessionKey, true);
        }
        else if (choice == 1)
        {
            SessionState.SetBool(sessionKey, true);
        }
        else
        {
            EditorPrefs.SetBool(dontShowKey, true);
        }
    }

    static Shader FindNativeShader()
    {
        Shader shader = Shader.Find(NativeShaderName);
        if (shader != null)
        {
            return shader;
        }

        string path = AssetDatabase.GUIDToAssetPath(NativeShaderGuid);
        return string.IsNullOrEmpty(path) ? null : AssetDatabase.LoadAssetAtPath<Shader>(path);
    }

    static List<LegacyMaterial> FindLegacyMaterials()
    {
        List<LegacyMaterial> results = new List<LegacyMaterial>();
        string[] materialGuids = AssetDatabase.FindAssets("t:Material");

        foreach (string guid in materialGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            if (string.IsNullOrEmpty(path) || !path.EndsWith(".mat"))
            {
                continue;
            }

            LegacyMaterial legacyMaterial;
            if (TryGetLegacyMaterial(path, out legacyMaterial))
            {
                results.Add(legacyMaterial);
            }
        }

        return results;
    }

    static bool TryGetLegacyMaterial(string path, out LegacyMaterial legacyMaterial)
    {
        legacyMaterial = null;

        Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (material == null)
        {
            return false;
        }

        string shaderName = material.shader != null ? material.shader.name : string.Empty;
        string shaderGuid = ReadSerializedShaderGuid(path);

        bool isLegacyName = !string.IsNullOrEmpty(shaderName) && LegacyShaderNames.Contains(shaderName);
        bool isLegacyGuid = !string.IsNullOrEmpty(shaderGuid) && LegacyShaderGuids.Contains(shaderGuid);

        if (!isLegacyName && !isLegacyGuid)
        {
            return false;
        }

        legacyMaterial = new LegacyMaterial(path, material, shaderName, shaderGuid);
        return true;
    }

    static string ReadSerializedShaderGuid(string path)
    {
        string fullPath = Path.GetFullPath(path);
        if (!File.Exists(fullPath))
        {
            return string.Empty;
        }

        string text;
        try
        {
            text = File.ReadAllText(fullPath);
        }
        catch
        {
            return string.Empty;
        }

        Match match = Regex.Match(text, @"m_Shader:\s*\{[^}]*guid:\s*([0-9a-fA-F]{32})");
        return match.Success ? match.Groups[1].Value.ToLowerInvariant() : string.Empty;
    }

    static void MigrateMaterials(List<LegacyMaterial> materials, Shader nativeShader, bool showResult)
    {
        int migrated = 0;
        int skipped = 0;

        try
        {
            AssetDatabase.StartAssetEditing();

            foreach (LegacyMaterial legacyMaterial in materials)
            {
                if (legacyMaterial.Material == null)
                {
                    skipped++;
                    continue;
                }

                if (!AssetDatabase.IsOpenForEdit(legacyMaterial.Path))
                {
                    skipped++;
                    Debug.LogWarning("LEDScreenShader migration skipped locked material: " + legacyMaterial.Path);
                    continue;
                }

                Undo.RecordObject(legacyMaterial.Material, "Migrate LEDScreenShader Material");
                MaterialSnapshot snapshot = MaterialSnapshot.Capture(legacyMaterial.Material);
                int renderQueue = legacyMaterial.Material.renderQueue;

                legacyMaterial.Material.shader = nativeShader;
                ApplyLegacyProperties(legacyMaterial.Material, snapshot);
                ResetLegacyShaderState(legacyMaterial.Material);

                if (renderQueue >= -1)
                {
                    legacyMaterial.Material.renderQueue = renderQueue;
                }

                EditorUtility.SetDirty(legacyMaterial.Material);
                migrated++;
            }
        }
        finally
        {
            AssetDatabase.StopAssetEditing();
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }

        if (showResult)
        {
            EditorUtility.DisplayDialog(
                "LEDScreenShader Migration",
                "Migration complete.\n" +
                "マテリアルの移行が完了しました。\n\n" +
                "Migrated: " + migrated + "\nSkipped: " + skipped,
                "OK");
        }
    }

    static void ResetLegacyShaderState(Material material)
    {
        material.shaderKeywords = new string[0];
        material.SetShaderPassEnabled("Forward", true);
        material.SetShaderPassEnabled("ForwardOnly", true);
        material.SetShaderPassEnabled("DepthOnly", true);
        material.SetShaderPassEnabled("DepthForwardOnly", true);
        material.SetShaderPassEnabled("ShadowCaster", true);
        material.SetShaderPassEnabled("MotionVectors", true);
        material.SetShaderPassEnabled("MOTIONVECTORS", true);
    }

    static void ApplyLegacyProperties(Material material, MaterialSnapshot snapshot)
    {
        ApplyInputScreenTexture(material, snapshot);
        ApplyTexture(material, snapshot, "_LEDTex", "Texture2D_1627220F", "_LEDTexture", "_LEDTex");
        ApplyTexture(material, snapshot, "_BaseMap", "Texture2D_89152ed9783a433ea8ce3c853cc0d050", "_BaseTexture");
        ApplyTexture(material, snapshot, "_NormalMap", "Texture2D_7a86fc08d4f4453bab8f62dd990e067a", "_NormalTexture", "_NormalMap");
        ApplyTexture(material, snapshot, "_MaskMap", "Texture2D_0b70190c450a4342ab4f4a426b1eaf09", "_MaskMap");

        float ledTilingX;
        if (TryGetFloat(snapshot, out ledTilingX, "TilingLEDX", "_LEDTilingX"))
        {
            material.SetFloat("_LEDTilingX", ledTilingX);
        }

        float ledTilingY;
        if (TryGetFloat(snapshot, out ledTilingY, "TilingLEDY", "_LEDTilingY"))
        {
            material.SetFloat("_LEDTilingY", ledTilingY);
        }

        ApplyInputTextureTransform(material, snapshot);

        Color inputColor;
        if (TryGetColor(snapshot, out inputColor, "Color_B7810F92", "_EmissionColor"))
        {
            material.SetColor("_EmissionColor", inputColor);
        }

        Color intensityColor;
        if (TryGetColor(snapshot, out intensityColor, "Color_941038397df743edb971942aa6a65b41"))
        {
            material.SetFloat("_IntensityMultiplier", Mathf.Max(intensityColor.r, intensityColor.g, intensityColor.b));
        }
        else
        {
            float intensity;
            if (TryGetFloat(snapshot, out intensity, "_IntensityMultiplier"))
            {
                material.SetFloat("_IntensityMultiplier", intensity);
            }
            else if (TryGetFloat(snapshot, out intensity, "_BrightnessIntensity", "BrightnessIntensity"))
            {
                material.SetFloat("_IntensityMultiplier", Mathf.Clamp(intensity / 50.0f, 0.1f, 50.0f));
            }
        }

        float cullMode;
        if (TryGetFloat(snapshot, out cullMode, "_CullMode", "_Cull"))
        {
            material.SetFloat("_CullMode", cullMode);
        }

        bool hasSurfaceTexture =
            HasTexture(snapshot, "Texture2D_89152ed9783a433ea8ce3c853cc0d050", "_BaseTexture") ||
            HasTexture(snapshot, "Texture2D_7a86fc08d4f4453bab8f62dd990e067a", "_NormalTexture", "_NormalMap") ||
            HasTexture(snapshot, "Texture2D_0b70190c450a4342ab4f4a426b1eaf09", "_MaskMap");

        material.SetFloat("_ProceduralLEDEnabled", 0.0f);
        material.SetFloat("_BaseMaterialEnabled", hasSurfaceTexture ? 1.0f : 0.0f);
        material.SetFloat("_SurfaceUVLinkLED", 1.0f);
    }

    static void ApplyInputScreenTexture(Material material, MaterialSnapshot snapshot)
    {
        // Legacy Shader Graphs used Texture2D_38C18792 for the video/input screen.
        // Some older URP materials also serialize the same input under _BaseMap.
        ApplyTexture(material, snapshot, "_InputTex", "Texture2D_38C18792", "_InputVideo", "_InputTex", "_BaseMap");
    }

    static void ApplyTexture(Material material, MaterialSnapshot snapshot, string newName, params string[] oldNames)
    {
        TextureInfo textureInfo;
        if (!snapshot.TryGetTexture(out textureInfo, oldNames))
        {
            return;
        }

        material.SetTexture(newName, textureInfo.Texture);
        material.SetTextureScale(newName, textureInfo.Scale);
        material.SetTextureOffset(newName, textureInfo.Offset);
    }

    static void ApplyInputTextureTransform(Material material, MaterialSnapshot snapshot)
    {
        Vector2 scale = material.GetTextureScale("_InputTex");
        Vector2 offset = material.GetTextureOffset("_InputTex");

        float value;
        if (TryGetFloat(snapshot, out value, "TilingVideoX"))
        {
            scale.x = value;
        }

        if (TryGetFloat(snapshot, out value, "TilingVideoY"))
        {
            scale.y = value;
        }

        if (TryGetFloat(snapshot, out value, "OffsetVideoX"))
        {
            offset.x = value;
        }

        if (TryGetFloat(snapshot, out value, "OffsetVideoY"))
        {
            offset.y = value;
        }

        material.SetTextureScale("_InputTex", scale);
        material.SetTextureOffset("_InputTex", offset);
    }

    static bool HasTexture(MaterialSnapshot snapshot, params string[] names)
    {
        TextureInfo info;
        return snapshot.TryGetTexture(out info, names) && info.Texture != null;
    }

    static bool TryGetFloat(MaterialSnapshot snapshot, out float value, params string[] names)
    {
        foreach (string name in names)
        {
            if (snapshot.Floats.TryGetValue(name, out value))
            {
                return true;
            }
        }

        value = 0.0f;
        return false;
    }

    static bool TryGetColor(MaterialSnapshot snapshot, out Color value, params string[] names)
    {
        foreach (string name in names)
        {
            if (snapshot.Colors.TryGetValue(name, out value))
            {
                return true;
            }
        }

        value = Color.white;
        return false;
    }

    class LegacyMaterial
    {
        public readonly string Path;
        public readonly Material Material;
        public readonly string ShaderName;
        public readonly string ShaderGuid;

        public LegacyMaterial(string path, Material material, string shaderName, string shaderGuid)
        {
            Path = path;
            Material = material;
            ShaderName = shaderName;
            ShaderGuid = shaderGuid;
        }
    }

    struct TextureInfo
    {
        public Texture Texture;
        public Vector2 Scale;
        public Vector2 Offset;
    }

    class MaterialSnapshot
    {
        public readonly Dictionary<string, TextureInfo> Textures = new Dictionary<string, TextureInfo>();
        public readonly Dictionary<string, float> Floats = new Dictionary<string, float>();
        public readonly Dictionary<string, Color> Colors = new Dictionary<string, Color>();

        public static MaterialSnapshot Capture(Material material)
        {
            MaterialSnapshot snapshot = new MaterialSnapshot();
            SerializedObject serializedObject = new SerializedObject(material);

            CaptureTextures(serializedObject, snapshot);
            CaptureFloats(serializedObject, snapshot);
            CaptureColors(serializedObject, snapshot);

            return snapshot;
        }

        public bool TryGetTexture(out TextureInfo textureInfo, params string[] names)
        {
            TextureInfo firstExisting = default(TextureInfo);
            bool hasExisting = false;

            foreach (string name in names)
            {
                TextureInfo candidate;
                if (!Textures.TryGetValue(name, out candidate))
                {
                    continue;
                }

                if (!hasExisting)
                {
                    firstExisting = candidate;
                    hasExisting = true;
                }

                if (candidate.Texture != null)
                {
                    textureInfo = candidate;
                    return true;
                }
            }

            textureInfo = firstExisting;
            return hasExisting;
        }

        static void CaptureTextures(SerializedObject serializedObject, MaterialSnapshot snapshot)
        {
            SerializedProperty array = serializedObject.FindProperty("m_SavedProperties.m_TexEnvs");
            if (array == null)
            {
                return;
            }

            for (int i = 0; i < array.arraySize; i++)
            {
                SerializedProperty entry = array.GetArrayElementAtIndex(i);
                SerializedProperty name = entry.FindPropertyRelative("first");
                SerializedProperty value = entry.FindPropertyRelative("second");
                if (name == null || value == null)
                {
                    continue;
                }

                SerializedProperty texture = value.FindPropertyRelative("m_Texture");
                SerializedProperty scale = value.FindPropertyRelative("m_Scale");
                SerializedProperty offset = value.FindPropertyRelative("m_Offset");

                TextureInfo info = new TextureInfo
                {
                    Texture = texture != null ? texture.objectReferenceValue as Texture : null,
                    Scale = scale != null ? scale.vector2Value : Vector2.one,
                    Offset = offset != null ? offset.vector2Value : Vector2.zero,
                };

                snapshot.Textures[name.stringValue] = info;
            }
        }

        static void CaptureFloats(SerializedObject serializedObject, MaterialSnapshot snapshot)
        {
            SerializedProperty array = serializedObject.FindProperty("m_SavedProperties.m_Floats");
            if (array == null)
            {
                return;
            }

            for (int i = 0; i < array.arraySize; i++)
            {
                SerializedProperty entry = array.GetArrayElementAtIndex(i);
                SerializedProperty name = entry.FindPropertyRelative("first");
                SerializedProperty value = entry.FindPropertyRelative("second");
                if (name != null && value != null)
                {
                    snapshot.Floats[name.stringValue] = value.floatValue;
                }
            }
        }

        static void CaptureColors(SerializedObject serializedObject, MaterialSnapshot snapshot)
        {
            SerializedProperty array = serializedObject.FindProperty("m_SavedProperties.m_Colors");
            if (array == null)
            {
                return;
            }

            for (int i = 0; i < array.arraySize; i++)
            {
                SerializedProperty entry = array.GetArrayElementAtIndex(i);
                SerializedProperty name = entry.FindPropertyRelative("first");
                SerializedProperty value = entry.FindPropertyRelative("second");
                if (name != null && value != null)
                {
                    snapshot.Colors[name.stringValue] = value.colorValue;
                }
            }
        }
    }
}
}
