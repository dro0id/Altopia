using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>Points d'entrée de build pour la CI et le menu Altopia : crée la scène vide (RouteDirector s'installe seul au lancement) et construit.</summary>
public static class BuildRoute
{
    const string ScenePath = "Assets/Scenes/Route.unity";

    [MenuItem("Altopia/Créer la scène Route")]
    public static string[] PrepareScene()
    {
        Directory.CreateDirectory("Assets/Scenes");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        EditorSceneManager.SaveScene(scene, ScenePath);
        IncludeShaders("Standard", "Altopia/Additive", "Altopia/Bloom");
        AssetDatabase.SaveAssets();
        return new[] { ScenePath };
    }

    /// <summary>Les shaders retrouvés par Shader.Find au lancement doivent être listés, sinon un build les retire.</summary>
    static void IncludeShaders(params string[] names)
    {
        var gs = AssetDatabase.LoadAssetAtPath<Object>("ProjectSettings/GraphicsSettings.asset");
        var so = new SerializedObject(gs);
        var list = so.FindProperty("m_AlwaysIncludedShaders");
        foreach (var n in names)
        {
            var sh = Shader.Find(n);
            if (sh == null) continue;
            bool have = false;
            for (int i = 0; i < list.arraySize; i++) if (list.GetArrayElementAtIndex(i).objectReferenceValue == sh) have = true;
            if (have) continue;
            list.arraySize++; list.GetArrayElementAtIndex(list.arraySize - 1).objectReferenceValue = sh;
        }
        so.ApplyModifiedProperties();
    }

    static void Build(BuildTarget target, string path)
    {
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions { scenes = PrepareScene(), locationPathName = path, target = target, options = BuildOptions.None });
        if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded) EditorApplication.Exit(1);
    }

    public static void Android()
    {
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.altopia.route");
        PlayerSettings.productName = "Altopia Route";
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.AutoRotation;
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
        PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
        Build(BuildTarget.Android, "Build/Android/AltopiaRoute.apk");
    }

    public static void WebGL() { PlayerSettings.productName = "Altopia Route"; Build(BuildTarget.WebGL, "Build/WebGL"); }
    public static void Windows() { PlayerSettings.productName = "Altopia Route"; Build(BuildTarget.StandaloneWindows64, "Build/Windows/AltopiaRoute.exe"); }
}
