using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Redonne aux modèles Blender (FBX) leur apparence d'origine : l'export FBX perd le métal, la rugosité et l'émission.
/// Les valeurs reprennent celles de tools/blender/build_assets.py (nom du matériau → métal, rugosité, force d'émission).
/// </summary>
public static class ModelLook
{
    struct Look { public float metal, rough, emit; public Look(float m, float r, float e) { metal = m; rough = r; emit = e; } }

    static readonly Dictionary<string, Look> Table = new Dictionary<string, Look>
    {
        { "hull", new Look(0.75f, 0.28f, 0f) }, { "dark", new Look(0.85f, 0.35f, 0f) }, { "panel", new Look(0.8f, 0.4f, 0f) },
        { "accent", new Look(0.2f, 0.3f, 6f) }, { "canopy", new Look(0.9f, 0.04f, 0.5f) }, { "engine", new Look(0f, 0.2f, 14f) },
        { "ehull", new Look(0.85f, 0.32f, 0f) }, { "eplate", new Look(0.8f, 0.4f, 0f) }, { "eglow", new Look(0f, 0.3f, 9f) },
        { "bhull", new Look(0.85f, 0.3f, 0f) }, { "bplate", new Look(0.8f, 0.4f, 0f) }, { "bglow", new Look(0f, 0.3f, 10f) }, { "pupil", new Look(0f, 0.2f, 12f) },
        { "rock", new Look(0.05f, 0.92f, 0f) }, { "crystal", new Look(0.1f, 0.1f, 2.5f) },
        { "shull", new Look(0.8f, 0.32f, 0f) }, { "sdark", new Look(0.85f, 0.35f, 0f) }, { "swin", new Look(0f, 0.3f, 5f) }, { "swarn", new Look(0f, 0.3f, 8f) }, { "solar", new Look(0.9f, 0.18f, 0f) },
        { "whull", new Look(0.8f, 0.55f, 0f) }, { "wrust", new Look(0.6f, 0.7f, 0f) }, { "whot", new Look(0f, 0.4f, 7f) },
        { "navL", new Look(0f, 0.3f, 8f) }, { "navR", new Look(0f, 0.3f, 8f) },
    };

    /// <summary>Applique l'apparence (émission en HDR pour que le bloom la fasse briller). k adoucit toutes les émissions (0,25 dans le prototype web).</summary>
    public static void Apply(GameObject root, float emissionScale = 0.25f)
    {
        foreach (var r in root.GetComponentsInChildren<Renderer>(true))
        {
            var mats = r.materials;
            for (int i = 0; i < mats.Length; i++)
            {
                var m = mats[i];
                string key = m.name.Replace(" (Instance)", "");
                int dot = key.IndexOf('.'); if (dot > 0) key = key.Substring(0, dot);
                if (!Table.TryGetValue(key, out var look)) continue;
                var std = new Material(Shader.Find("Standard")) { name = key, color = m.color };
                std.SetFloat("_Metallic", look.metal);
                std.SetFloat("_Glossiness", 1f - look.rough);
                if (look.emit > 0f)
                {
                    std.EnableKeyword("_EMISSION");
                    std.globalIlluminationFlags = MaterialGlobalIlluminationFlags.RealtimeEmissive;
                    std.SetColor("_EmissionColor", m.color.linear * look.emit * emissionScale);
                }
                mats[i] = std;
            }
            r.materials = mats;
        }
    }

    /// <summary>Remet le nez du modèle vers +Z (avant d'Unity). Le sens dépend de l'import FBX : on le déduit de la forme
    /// (le nez est l'extrémité la plus étroite). Les modèles symétriques (boss, station…) ne sont pas touchés.</summary>
    public static void FaceForward(GameObject root)
    {
        var verts = new List<Vector3>();
        foreach (var f in root.GetComponentsInChildren<MeshFilter>())
            if (f.sharedMesh != null) foreach (var v in f.sharedMesh.vertices) verts.Add(root.transform.InverseTransformPoint(f.transform.TransformPoint(v)));
        if (verts.Count == 0) return;
        float zmin = float.MaxValue, zmax = float.MinValue;
        foreach (var v in verts) { zmin = Mathf.Min(zmin, v.z); zmax = Mathf.Max(zmax, v.z); }
        float slab = (zmax - zmin) * 0.12f, xa = 0, xb = 0;
        foreach (var v in verts)
        {
            if (v.z > zmax - slab) xa = Mathf.Max(xa, Mathf.Abs(v.x));
            if (v.z < zmin + slab) xb = Mathf.Max(xb, Mathf.Abs(v.x));
        }
        if (xb < xa) root.transform.localRotation = Quaternion.Euler(0, 180, 0) * root.transform.localRotation;   // nez vers -Z : on retourne
    }
}
