using NUnit.Framework;
using UnityEngine;

/// <summary>Vérifie les modèles Blender importés : présents, matériaux connus, avant tourné vers +Z, shaders disponibles.</summary>
public class ModelTests
{
    static readonly string[] Names = { "player", "enemy", "elite", "boss", "asteroid1", "asteroid2", "asteroid3", "station", "wreck" };

    [Test]
    public void AllModelsLoad()
    {
        foreach (var n in Names)
        {
            var go = Resources.Load<GameObject>("Models/" + n);
            Assert.NotNull(go, "modèle manquant : " + n);
            Assert.Greater(go.GetComponentsInChildren<MeshFilter>().Length, 0, n + " n'a aucun maillage");
        }
    }

    [Test]
    public void EveryMaterialHasALook()
    {
        foreach (var n in Names)
            foreach (var r in Resources.Load<GameObject>("Models/" + n).GetComponentsInChildren<Renderer>())
                foreach (var m in r.sharedMaterials)
                    Assert.IsTrue(ModelLook.Knows(m.name), n + " : matériau inconnu « " + m.name + " » (à ajouter dans ModelLook)");
    }

    [TestCase("player", "cannon_tip")]
    [TestCase("enemy", "eye")]
    [TestCase("elite", "eye")]
    [TestCase("boss", "eye")]
    public void FrontMarkerEndsUpInFront(string model, string marker)
    {
        var inst = Object.Instantiate(Resources.Load<GameObject>("Models/" + model));
        try
        {
            ModelLook.FaceForward(inst, marker);
            Transform m = null; foreach (var t in inst.GetComponentsInChildren<Transform>()) if (t.name.StartsWith(marker)) { m = t; break; }
            Assert.NotNull(m, "repère " + marker + " introuvable dans " + model);
            var rends = inst.GetComponentsInChildren<Renderer>(); var all = rends[0].bounds; foreach (var r in rends) all.Encapsulate(r.bounds);
            var mr = m.GetComponentInChildren<Renderer>();
            Assert.Greater(inst.transform.InverseTransformPoint(mr.bounds.center).z, inst.transform.InverseTransformPoint(all.center).z, model + " : l'avant n'est pas vers +Z");
        }
        finally { Object.DestroyImmediate(inst); }
    }

    [Test]
    public void ShadersAreAvailable()
    {
        foreach (var n in new[] { "Altopia/Additive", "Altopia/Bloom", "Standard" })
        {
            var sh = Shader.Find(n);
            Assert.NotNull(sh, "shader introuvable : " + n);
            Assert.IsTrue(sh.isSupported, "shader non supporté : " + n);
        }
    }
}
