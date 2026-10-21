using System.Collections.Generic;
using UnityEngine;

/// <summary>Vérifications rapides des modèles et shaders, partagées par les tests et par la fenêtre « Testeur Route ».</summary>
public static class RouteChecks
{
    public static readonly string[] ModelNames = { "player", "enemy", "elite", "boss", "asteroid1", "asteroid2", "asteroid3", "station", "wreck" };
    public static readonly string[] StepTypes = { "combat", "elite", "gardien", "recolte", "epave", "repos", "inconnu" };

    public struct Result { public string name; public bool ok; public string detail; }

    public static List<Result> RunAll()
    {
        var res = new List<Result>();
        foreach (var n in ModelNames)
        {
            var go = Resources.Load<GameObject>("Models/" + n);
            if (go == null) { res.Add(new Result { name = "Modèle " + n, ok = false, detail = "introuvable dans Resources/Models" }); continue; }
            int meshes = go.GetComponentsInChildren<MeshFilter>().Length;
            var unknown = new List<string>();
            foreach (var r in go.GetComponentsInChildren<Renderer>()) foreach (var m in r.sharedMaterials) if (m != null && !ModelLook.Knows(m.name) && !unknown.Contains(m.name)) unknown.Add(m.name);
            res.Add(new Result { name = "Modèle " + n, ok = meshes > 0 && unknown.Count == 0, detail = meshes + " maillages" + (unknown.Count > 0 ? ", matériaux inconnus : " + string.Join(", ", unknown) : ", matériaux OK") });
        }
        foreach (var pair in new[] { new[] { "player", "cannon_tip" }, new[] { "enemy", "eye" }, new[] { "elite", "eye" }, new[] { "boss", "eye" } })
        {
            var prefab = Resources.Load<GameObject>("Models/" + pair[0]);
            if (prefab == null) continue;
            var inst = Object.Instantiate(prefab);
            bool flipped = ModelLook.FaceForward(inst, pair[1]);
            bool front = FrontIsPlusZ(inst, pair[1]);
            Object.DestroyImmediate(inst);
            res.Add(new Result { name = "Orientation " + pair[0], ok = front, detail = (flipped ? "retourné" : "déjà dans le bon sens") + ", avant vers +Z : " + (front ? "oui" : "non") });
        }
        foreach (var s in new[] { "Altopia/Additive", "Altopia/Bloom", "Standard" })
        {
            var sh = Shader.Find(s);
            res.Add(new Result { name = "Shader " + s, ok = sh != null && sh.isSupported, detail = sh == null ? "introuvable" : (sh.isSupported ? "disponible" : "non supporté sur cette machine") });
        }
        return res;
    }

    static bool FrontIsPlusZ(GameObject inst, string marker)
    {
        Transform m = null; foreach (var t in inst.GetComponentsInChildren<Transform>()) if (t.name.StartsWith(marker)) { m = t; break; }
        var rends = inst.GetComponentsInChildren<Renderer>();
        if (m == null || rends.Length == 0) return false;
        var all = rends[0].bounds; foreach (var r in rends) all.Encapsulate(r.bounds);
        var mr = m.GetComponentInChildren<Renderer>(); if (mr == null) return false;
        return inst.transform.InverseTransformPoint(mr.bounds.center).z > inst.transform.InverseTransformPoint(all.center).z;
    }
}
