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

    /// <summary>Remet l'avant du modèle vers +Z (avant d'Unity). L'avant est repéré par un objet nommé du modèle (« cannon_tip » pour le vaisseau,
    /// « eye » pour les ennemis et le boss) : si ce repère est derrière le centre, on retourne le modèle. Retourne vrai si le modèle a été retourné.</summary>
    public static bool FaceForward(GameObject root, string frontMarker)
    {
        Transform marker = null;
        foreach (var t in root.GetComponentsInChildren<Transform>()) if (t.name.StartsWith(frontMarker)) { marker = t; break; }
        var rends = root.GetComponentsInChildren<Renderer>();
        if (marker == null || rends.Length == 0) return false;
        var all = rends[0].bounds; foreach (var r in rends) all.Encapsulate(r.bounds);
        var mr = marker.GetComponentInChildren<Renderer>();
        Vector3 mc = mr != null ? mr.bounds.center : marker.position;
        float dz = root.transform.InverseTransformPoint(mc).z - root.transform.InverseTransformPoint(all.center).z;
        if (dz >= 0f) return false;
        root.transform.localRotation = Quaternion.Euler(0, 180, 0) * root.transform.localRotation;
        return true;
    }

    /// <summary>Noms de matériaux connus (utilisé par les tests pour vérifier qu'aucun matériau d'un modèle n'est oublié).</summary>
    public static bool Knows(string materialName)
    {
        int dot = materialName.IndexOf('.'); if (dot > 0) materialName = materialName.Substring(0, dot);
        return Table.ContainsKey(materialName);
    }
}
