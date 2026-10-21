using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

/// <summary>
/// Fenêtre « Altopia → Testeur Route » : tout ce qu'il faut pour tester le prototype sans quitter l'éditeur.
///  • Vitrine : chaque modèle seul, éclairé comme dans Blender, à faire tourner à la souris (sans lancer le jeu).
///  • Scène : lancer / arrêter Play et déclencher chaque type d'étape.
///  • Vérifications : modèles, matériaux, orientation, shaders ; raccourci vers le Test Runner.
/// </summary>
public class RouteTesterWindow : EditorWindow
{
    [MenuItem("Altopia/Testeur Route")]
    static void Open() { var w = GetWindow<RouteTesterWindow>("Testeur Route"); w.minSize = new Vector2(420, 560); w.Show(); }

    int tab;
    static readonly string[] Tabs = { "Vitrine", "Scène", "Vérifications" };

    // vitrine
    PreviewRenderUtility preview; GameObject shown; string shownName = "";
    int modelIndex; Vector2 orbit = new Vector2(-30, 24); float dist = 11f;
    static readonly Dictionary<string, Vector3> Cams = new Dictionary<string, Vector3>   // caméras du studio Blender, converties en axes Unity (x, z, y)
    {
        { "player", new Vector3(6.5f, 4f, -7.5f) }, { "enemy", new Vector3(6.5f, 4f, -7.5f) }, { "elite", new Vector3(6.5f, 4f, -7.5f) },
        { "boss", new Vector3(14f, 12f, 24f) }, { "station", new Vector3(17f, 11f, -17f) }, { "wreck", new Vector3(15f, 8f, -15f) },
        { "asteroid1", new Vector3(3.6f, 2.2f, -3.6f) }, { "asteroid2", new Vector3(3.6f, 2.2f, -3.6f) }, { "asteroid3", new Vector3(3.6f, 2.2f, -3.6f) },
    };
    string markerOf(string n) { return n == "player" ? "cannon_tip" : (n == "enemy" || n == "elite" || n == "boss") ? "eye" : null; }
    string orientationNote = "";

    // vérifications
    List<RouteChecks.Result> results; Vector2 scroll;

    void OnEnable() { wantsMouseMove = false; }
    void OnDisable() { Cleanup(); }
    void Cleanup() { if (preview != null) { preview.Cleanup(); preview = null; } shown = null; shownName = ""; }

    void OnGUI()
    {
        tab = GUILayout.Toolbar(tab, Tabs, GUILayout.Height(26));
        EditorGUILayout.Space(4);
        if (tab == 0) DrawShowcase(); else if (tab == 1) DrawScene(); else DrawChecks();
    }

    // ---------- vitrine ----------
    void EnsurePreview()
    {
        if (preview != null) return;
        preview = new PreviewRenderUtility();
        preview.cameraFieldOfView = 28.5f;
        var c = preview.camera; c.clearFlags = CameraClearFlags.SolidColor; c.backgroundColor = new Color(0.075f, 0.106f, 0.21f); c.nearClipPlane = 0.1f; c.farClipPlane = 500f;
        preview.ambientColor = new Color(0.03f, 0.04f, 0.07f);
        preview.lights[0].intensity = 1.5f; preview.lights[0].color = new Color(1f, 0.95f, 0.88f); preview.lights[0].transform.rotation = Quaternion.Euler(50, 150, 0);
        preview.lights[1].intensity = 0.8f; preview.lights[1].color = new Color(0.45f, 0.6f, 1f); preview.lights[1].transform.rotation = Quaternion.Euler(20, -60, 0);
    }

    void ShowModel(string n)
    {
        EnsurePreview();
        if (shown != null) { Object.DestroyImmediate(shown); shown = null; }
        var prefab = Resources.Load<GameObject>("Models/" + n);
        if (prefab == null) { orientationNote = "modèle introuvable : " + n; return; }
        shown = Object.Instantiate(prefab); shown.hideFlags = HideFlags.HideAndDontSave;
        ModelLook.Apply(shown);
        var mk = markerOf(n); orientationNote = mk == null ? "modèle symétrique : pas de repère d'orientation" : (ModelLook.FaceForward(shown, mk) ? "avant retourné vers +Z" : "avant déjà vers +Z");
        preview.AddSingleGO(shown);
        shownName = n;
        var cam = Cams.ContainsKey(n) ? Cams[n] : new Vector3(6.5f, 4f, -7.5f);
        dist = cam.magnitude; orbit = new Vector2(Mathf.Atan2(cam.x, -cam.z) * Mathf.Rad2Deg, Mathf.Asin(cam.y / cam.magnitude) * Mathf.Rad2Deg);
    }

    void DrawShowcase()
    {
        var names = RouteChecks.ModelNames;
        int pick = GUILayout.Toolbar(modelIndex, names, EditorStyles.miniButton);
        if (pick != modelIndex || shownName != names[modelIndex]) { modelIndex = pick; ShowModel(names[modelIndex]); }
        var rect = GUILayoutUtility.GetRect(position.width - 10, position.height - 120);
        if (preview == null || shown == null) { EditorGUI.HelpBox(rect, "Aucun modèle affiché.", MessageType.Info); return; }

        var e = Event.current;
        if (rect.Contains(e.mousePosition))
        {
            if (e.type == EventType.MouseDrag) { orbit += new Vector2(e.delta.x, e.delta.y) * 0.5f; orbit.y = Mathf.Clamp(orbit.y, -85, 85); e.Use(); Repaint(); }
            if (e.type == EventType.ScrollWheel) { dist = Mathf.Clamp(dist * (1f + e.delta.y * 0.04f), 2f, 80f); e.Use(); Repaint(); }
        }
        if (e.type == EventType.Repaint)
        {
            preview.BeginPreview(rect, GUIStyle.none);
            var rot = Quaternion.Euler(orbit.y, orbit.x, 0);
            preview.camera.transform.position = rot * new Vector3(0, 0, -dist);
            preview.camera.transform.LookAt(Vector3.zero);
            preview.Render(true);
            GUI.DrawTexture(rect, preview.EndPreview(), ScaleMode.StretchToFill, false);
        }
        EditorGUILayout.LabelField(orientationNote + "  ·  glisser = tourner, molette = zoom", EditorStyles.miniLabel);
    }

    // ---------- scène ----------
    void DrawScene()
    {
        EditorGUILayout.HelpBox("La scène tourne en mode Play : RouteDirector s'installe tout seul dans n'importe quelle scène.", MessageType.None);
        using (new EditorGUILayout.HorizontalScope())
        {
            GUI.backgroundColor = EditorApplication.isPlaying ? new Color(1f, 0.5f, 0.5f) : new Color(0.5f, 1f, 0.6f);
            if (GUILayout.Button(EditorApplication.isPlaying ? "■ Arrêter" : "▶ Lancer la scène", GUILayout.Height(30))) EditorApplication.isPlaying = !EditorApplication.isPlaying;
            GUI.backgroundColor = Color.white;
            if (GUILayout.Button("Créer la scène Route", GUILayout.Height(30))) BuildRoute.PrepareScene();
        }
        var d = EditorApplication.isPlaying ? Object.FindObjectOfType<RouteDirector>() : null;
        using (new EditorGUI.DisabledScope(d == null))
        {
            if (d != null) d.auto = EditorGUILayout.Toggle("Mode auto", d.auto);
            EditorGUILayout.LabelField("Déclencher une étape", EditorStyles.boldLabel);
            using (new EditorGUI.DisabledScope(d != null && !d.IsIdle))
                foreach (var t in RouteChecks.StepTypes)
                    if (GUILayout.Button(t, GUILayout.Height(24)) && d != null) { d.auto = false; d.StartCoroutine(d.Play(t)); }
        }
        if (d == null) EditorGUILayout.HelpBox("Lance la scène pour activer les boutons.", MessageType.Info);
    }

    // ---------- vérifications ----------
    void DrawChecks()
    {
        using (new EditorGUILayout.HorizontalScope())
        {
            if (GUILayout.Button("Lancer les vérifications", GUILayout.Height(28))) results = RouteChecks.RunAll();
            if (GUILayout.Button("Ouvrir le Test Runner", GUILayout.Height(28))) EditorApplication.ExecuteMenuItem("Window/General/Test Runner");
        }
        if (results == null) { EditorGUILayout.HelpBox("Modèles présents, matériaux connus, avant vers +Z, shaders disponibles. Les tests complets (PlayMode : chaque étape) sont dans le Test Runner.", MessageType.None); return; }
        int bad = results.FindAll(r => !r.ok).Count;
        EditorGUILayout.HelpBox(bad == 0 ? "Tout est OK (" + results.Count + " vérifications)" : bad + " échec(s) sur " + results.Count, bad == 0 ? MessageType.Info : MessageType.Error);
        scroll = EditorGUILayout.BeginScrollView(scroll);
        foreach (var r in results)
        {
            var style = new GUIStyle(EditorStyles.label) { normal = { textColor = r.ok ? new Color(0.3f, 0.8f, 0.4f) : new Color(1f, 0.4f, 0.4f) } };
            EditorGUILayout.LabelField((r.ok ? "✓ " : "✕ ") + r.name, style);
            EditorGUILayout.LabelField("   " + r.detail, EditorStyles.miniLabel);
        }
        EditorGUILayout.EndScrollView();
    }
}
