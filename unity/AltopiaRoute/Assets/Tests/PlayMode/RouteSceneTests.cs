using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

/// <summary>Joue chaque type d'étape de bout en bout : la scène doit se terminer sans erreur dans la console.</summary>
public class RouteSceneTests
{
    [UnityTest]
    public IEnumerator EveryStepTypePlaysWithoutErrors()
    {
        yield return null;
        var d = Object.FindObjectOfType<RouteDirector>();
        Assert.NotNull(d, "RouteDirector non démarré");
        d.auto = false;
        while (!d.IsIdle) yield return null;
        foreach (var t in new[] { "combat", "elite", "gardien", "recolte", "epave", "repos", "inconnu" })
        {
            yield return d.StartCoroutine(d.Play(t));
            yield return d.StartCoroutine(d.Leave());
        }
        LogAssert.NoUnexpectedReceived();
    }
}
