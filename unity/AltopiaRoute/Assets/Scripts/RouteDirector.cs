using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// Scène « Route » d'Altopia en 3D (prototype Unity séparé du jeu Godot) : le convoi vole vers les étapes, chaque étape a son décor et son action
/// (combat, embuscade, gardien, récolte, épave, repos, inconnu). Tout est construit par code : ouvrir le projet, lancer n'importe quelle scène vide.
/// Avant = +Z. Les modèles viennent de Resources/Models (FBX exportés depuis Blender par tools/blender/build_assets.py).
/// </summary>
public class RouteDirector : MonoBehaviour
{
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Boot() { new GameObject("Route").AddComponent<RouteDirector>(); }

    // --- réglages ---
    public float travelTime = 1.3f;
    const float FarZ = 150f, NearZ = 24f;

    // --- décor ---
    Camera cam; Transform fleet; Transform player, escortL, escortR;
    ParticleSystem stars, sparks;
    ParticleSystem.MainModule starsMain; ParticleSystemRenderer starsRend;
    Light key, fill, back;
    readonly List<ParticleSystem> flames = new List<ParticleSystem>();
    GameObject current;                   // objet de l'étape en cours
    readonly List<Transform> enemies = new List<Transform>();
    string currentType = "";
    bool busy; public bool auto = true; string status = "";
    float warp;                           // 0 = croisière, 1 = distorsion
    float shake, flash;
    Texture2D glow;

    public bool IsIdle { get { return !busy; } }

    void Start()
    {
        Application.targetFrameRate = 60;
        glow = MakeGlow();
        BuildCamera(); BuildLights(); BuildStars(); BuildSparks(); BuildFleet();
        StartCoroutine(AutoRoutine());
    }

    // ---------- construction ----------
    void BuildCamera()
    {
        var go = new GameObject("Camera");
        cam = go.AddComponent<Camera>();
        cam.clearFlags = CameraClearFlags.SolidColor; cam.backgroundColor = new Color(0.01f, 0.014f, 0.035f);
        cam.fieldOfView = 70; cam.nearClipPlane = 0.1f; cam.farClipPlane = 1000f; cam.allowHDR = true;
        go.tag = "MainCamera";
        foreach (var other in FindObjectsOfType<Camera>()) if (other != cam) other.gameObject.SetActive(false);
        go.AddComponent<SimpleBloom>();
    }

    void BuildLights()
    {
        // mêmes trois lumières que le studio Blender (blanche chaude, bleue, orange), plus un fond sombre
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.02f, 0.03f, 0.06f);
        key = Dir("Key", new Color(1f, 0.95f, 0.88f), 1.5f, new Vector3(6, 7, -4));
        fill = Dir("Fill", new Color(0.45f, 0.6f, 1f), 0.8f, new Vector3(-7, 3, 2));
        back = Dir("Back", new Color(1f, 0.5f, 0.35f), 1.1f, new Vector3(0, -2, 8));
    }

    Light Dir(string n, Color c, float i, Vector3 from)
    {
        var go = new GameObject(n); var l = go.AddComponent<Light>();
        l.type = LightType.Directional; l.color = c; l.intensity = i; l.shadows = LightShadows.None;
        go.transform.position = from; go.transform.rotation = Quaternion.LookRotation(-from.normalized);
        return l;
    }

    void BuildStars()
    {
        // des étoiles qui défilent vers l'arrière : la vitesse et l'étirement montent pendant la distorsion
        var go = new GameObject("Stars"); go.transform.position = new Vector3(0, 0, 330);
        stars = go.AddComponent<ParticleSystem>();
        var main = stars.main; main.loop = true; main.startLifetime = 6f; main.startSpeed = 60f; main.startSize = 0.35f; main.maxParticles = 1500;
        main.simulationSpace = ParticleSystemSimulationSpace.World; main.startColor = new ParticleSystem.MinMaxGradient(new Color(0.7f, 0.8f, 1f), new Color(1f, 0.85f, 0.7f));
        var em = stars.emission; em.rateOverTime = 260f;
        var sh = stars.shape; sh.shapeType = ParticleSystemShapeType.Box; sh.scale = new Vector3(260, 150, 4);
        stars.transform.rotation = Quaternion.LookRotation(Vector3.back);          // émet vers -Z
        starsRend = go.GetComponent<ParticleSystemRenderer>();
        starsRend.renderMode = ParticleSystemRenderMode.Stretch; starsRend.lengthScale = 2f; starsRend.velocityScale = 0.02f;
        starsRend.material = AdditiveMat(Color.white);
        starsMain = main;
        stars.Simulate(6f, true, true); stars.Play();
    }

    void BuildSparks()
    {
        var go = new GameObject("Sparks"); sparks = go.AddComponent<ParticleSystem>();
        var main = sparks.main; main.loop = false; main.playOnAwake = false; main.startLifetime = 1.0f; main.startSpeed = 8f; main.startSize = 0.5f; main.maxParticles = 2000;
        main.simulationSpace = ParticleSystemSimulationSpace.World; main.startColor = new Color(1f, 0.7f, 0.3f);
        var em = sparks.emission; em.enabled = false;
        var sh = sparks.shape; sh.shapeType = ParticleSystemShapeType.Sphere; sh.radius = 0.3f;
        var col = sparks.colorOverLifetime; col.enabled = true;
        var g = new Gradient(); g.SetKeys(new[] { new GradientColorKey(new Color(1, 0.9f, 0.6f), 0), new GradientColorKey(new Color(1, 0.3f, 0.1f), 1) }, new[] { new GradientAlphaKey(1, 0), new GradientAlphaKey(0, 1) });
        col.color = g;
        sparks.GetComponent<ParticleSystemRenderer>().material = AdditiveMat(Color.white);
    }

    void BuildFleet()
    {
        fleet = new GameObject("Fleet").transform;
        player = Spawn("player", fleet, 0.7f); escortL = Spawn("player", fleet, 0.4f); escortR = Spawn("player", fleet, 0.4f);
        escortL.localPosition = new Vector3(-4.2f, -0.5f, -2.4f); escortR.localPosition = new Vector3(4.2f, -0.5f, -2.4f);
        foreach (var s in new[] { player, escortL, escortR })
        {
            float k = s.localScale.x;
            foreach (int sd in new[] { -1, 1 }) flames.Add(Flame(s, new Vector3(sd * 0.72f, 0, -2.78f) , k));
        }
    }

    ParticleSystem Flame(Transform parent, Vector3 localPos, float scale)
    {
        // le modèle est déjà à l'échelle : on place la flamme en coordonnées locales non mises à l'échelle
        var go = new GameObject("Flame"); go.transform.SetParent(parent, false); go.transform.localPosition = localPos; go.transform.localRotation = Quaternion.LookRotation(Vector3.back);
        var ps = go.AddComponent<ParticleSystem>();
        var main = ps.main; main.startLifetime = 0.35f; main.startSpeed = 6f; main.startSize = 0.45f; main.simulationSpace = ParticleSystemSimulationSpace.World; main.maxParticles = 150;
        main.startColor = new ParticleSystem.MinMaxGradient(new Color(0.4f, 0.9f, 1f), new Color(1f, 1f, 1f));
        var em = ps.emission; em.rateOverTime = 90f;
        var sh = ps.shape; sh.shapeType = ParticleSystemShapeType.Cone; sh.angle = 4; sh.radius = 0.12f;
        var size = ps.sizeOverLifetime; size.enabled = true; size.size = new ParticleSystem.MinMaxCurve(1f, new AnimationCurve(new Keyframe(0, 1), new Keyframe(1, 0.1f)));
        var r = go.GetComponent<ParticleSystemRenderer>(); r.material = AdditiveMat(Color.white);
        return ps;
    }

    // ---------- modèles ----------
    Transform Spawn(string model, Transform parent, float scale)
    {
        var prefab = Resources.Load<GameObject>("Models/" + model);
        var holder = new GameObject(model).transform; holder.SetParent(parent, false);
        if (prefab == null) { Debug.LogWarning("Modèle manquant : " + model); return holder; }
        var inst = Instantiate(prefab, holder); inst.transform.localPosition = Vector3.zero; inst.transform.localRotation = Quaternion.identity;
        ModelLook.Apply(inst);
        if (model == "player") ModelLook.FaceForward(inst, "cannon_tip");
        else if (model == "enemy" || model == "elite" || model == "boss") ModelLook.FaceForward(inst, "eye");
        holder.localScale = Vector3.one * scale;
        return holder;
    }

    // ---------- étapes ----------
    void ClearCurrent() { if (current) Destroy(current); current = null; enemies.Clear(); }

    GameObject Build(string type)
    {
        var root = new GameObject(type); root.transform.position = new Vector3(0, 1.2f, FarZ);
        switch (type)
        {
            case "combat": case "elite":
                int n = type == "elite" ? 4 : 3;
                for (int i = 0; i < n; i++)
                {
                    var e = Spawn(type == "elite" ? "elite" : "enemy", root.transform, type == "elite" ? 1.0f : 0.9f);
                    e.localPosition = new Vector3((i - (n - 1) / 2f) * 6.2f, (i % 2) * 2.2f - 0.6f, (i % 2) * 3f);
                    e.localRotation = Quaternion.Euler(0, 180, 0);   // les ennemis regardent le convoi
                    enemies.Add(e);
                }
                break;
            case "gardien":
                var b = Spawn("boss", root.transform, 0.95f); b.localRotation = Quaternion.Euler(0, 180, 0); enemies.Add(b);
                break;
            case "recolte":
                for (int i = 0; i < 14; i++)
                {
                    var a = Spawn("asteroid" + (1 + Random.Range(0, 3)), root.transform, Random.Range(0.8f, 2.4f));
                    float ang = Random.value * 6.28f, r = Random.Range(1.5f, 10f);
                    a.localPosition = new Vector3(Mathf.Cos(ang) * r, Random.Range(-2.5f, 2.5f), Mathf.Sin(ang) * r * 0.6f);
                    a.localRotation = Random.rotation; a.gameObject.AddComponent<Spin>().axis = Random.onUnitSphere * 25f;
                }
                break;
            case "epave":
                var w = Spawn("wreck", root.transform, 1.3f); w.gameObject.AddComponent<Spin>().axis = new Vector3(0, 6, 0);
                foreach (var t in w.GetComponentsInChildren<Transform>()) if (t.name.StartsWith("scrap")) t.gameObject.AddComponent<Spin>().axis = Random.onUnitSphere * 40f;
                var fire = new GameObject("Fire").AddComponent<Light>(); fire.transform.SetParent(root.transform, false); fire.color = new Color(1, 0.55f, 0.2f); fire.intensity = 3; fire.range = 30; fire.gameObject.AddComponent<Flicker>();
                break;
            case "repos":
                var s = Spawn("station", root.transform, 1.0f); s.localRotation = Quaternion.Euler(20, 0, 0);
                var spin = new GameObject("Spin").transform; spin.SetParent(s, false);
                foreach (var t in new List<Transform>(s.GetComponentsInChildren<Transform>())) if (t.name.StartsWith("ring") || t.name.StartsWith("window") || t.name.StartsWith("spoke")) t.SetParent(spin, true);
                spin.gameObject.AddComponent<Spin>().axis = new Vector3(0, 0, 25);
                var lt = new GameObject("Lt").AddComponent<Light>(); lt.transform.SetParent(root.transform, false); lt.color = new Color(0.3f, 1f, 0.6f); lt.intensity = 2; lt.range = 40;
                break;
            default:   // inconnu : anneaux qui tournent autour d'un cœur lumineux
                for (int i = 0; i < 5; i++) Ring(root.transform, 2f + i * 1.6f, i % 2 == 0 ? new Color(0.35f, 0.9f, 1f) : new Color(0.55f, 0.5f, 1f), (i % 2 == 0 ? 1 : -1) * (30 + i * 18));
                var core = new GameObject("Core").AddComponent<Light>(); core.transform.SetParent(root.transform, false); core.color = new Color(0.6f, 0.9f, 1f); core.intensity = 4; core.range = 30;
                break;
        }
        return root;
    }

    void Ring(Transform parent, float radius, Color c, float speed)
    {
        var go = new GameObject("Ring"); go.transform.SetParent(parent, false);
        var lr = go.AddComponent<LineRenderer>(); lr.useWorldSpace = false; lr.loop = true; lr.positionCount = 64; lr.widthMultiplier = 0.18f; lr.material = AdditiveMat(c); lr.startColor = lr.endColor = c * 2f;
        for (int i = 0; i < 64; i++) { float a = i / 64f * 6.2832f; lr.SetPosition(i, new Vector3(Mathf.Cos(a) * radius, Mathf.Sin(a) * radius, 0)); }
        go.AddComponent<Spin>().axis = new Vector3(0, 0, speed);
    }

    public IEnumerator Travel(string type)
    {
        busy = true; currentType = type; status = "En route : " + type;
        if (current) { yield return Leave(); }
        current = Build(type);
        float t = 0, bank = (Random.value - 0.5f) * 0.6f;
        while (t < travelTime)
        {
            t += Time.deltaTime; float q = Mathf.Clamp01(t / travelTime), e = 1f - Mathf.Pow(1f - q, 2.2f);
            current.transform.position = new Vector3(Mathf.Lerp(bank * 14f, 0, e), 1.2f, Mathf.Lerp(FarZ, NearZ, e));
            warp = q < 0.72f ? 1f : 1f - (q - 0.72f) / 0.28f;
            fleet.localRotation = Quaternion.Euler(0, 0, -bank * 30f * (1f - q));
            yield return null;
        }
        warp = 0; flash = 0.35f; fleet.localRotation = Quaternion.identity;
        busy = false;
    }

    public IEnumerator Leave()
    {
        if (!current) yield break;
        busy = true; float t = 0;
        while (t < 0.9f) { t += Time.deltaTime; warp = Mathf.Clamp01(t * 2f); current.transform.position += Vector3.back * 110f * Time.deltaTime; yield return null; }
        ClearCurrent(); warp = 0; busy = false;
    }

    public IEnumerator Fight(bool win)
    {
        busy = true; status = win ? "Combat gagné" : "Combat perdu";
        var targets = enemies.Count > 0 ? enemies : new List<Transform> { current.transform };
        for (int i = 0; i < 10; i++)
        {
            var from = (i % 2 == 0 ? player : (i % 4 == 1 ? escortL : escortR)).position + new Vector3(0, 0, 2f);
            var to = targets[i % targets.Count].position;
            StartCoroutine(Bolt(from, to, new Color(0.35f, 0.9f, 1f)));
            if (!win && i % 2 == 0) StartCoroutine(Bolt(to, player.position, new Color(1f, 0.35f, 0.2f)));
            yield return new WaitForSeconds(0.09f);
        }
        yield return new WaitForSeconds(0.4f);
        if (win)
        {
            foreach (var t in targets) { if (!t) continue; Explode(t.position, 3f); t.gameObject.SetActive(false); shake = 0.6f; yield return new WaitForSeconds(0.17f); }
        }
        else { Explode(player.position, 2.2f); shake = 1f; flash = 0.6f; }
        yield return new WaitForSeconds(0.8f);
        busy = false;
    }

    IEnumerator Bolt(Vector3 from, Vector3 to, Color c)
    {
        var go = new GameObject("Bolt"); var lr = go.AddComponent<LineRenderer>(); lr.positionCount = 2; lr.widthMultiplier = 0.22f; lr.material = AdditiveMat(c); lr.startColor = lr.endColor = c * 2.5f;
        float d = Mathf.Max(0.25f, Vector3.Distance(from, to) / 160f), t = 0;
        while (t < d) { t += Time.deltaTime; var p = Vector3.Lerp(from, to, t / d); lr.SetPosition(0, p - (to - from).normalized * 3f); lr.SetPosition(1, p); yield return null; }
        Burst(to, 8, new Color(1, 0.8f, 0.4f)); Destroy(go);
    }

    public IEnumerator Harvest()
    {
        busy = true; status = "Récolte";
        var go = new GameObject("Beam"); var lr = go.AddComponent<LineRenderer>(); lr.positionCount = 2; lr.widthMultiplier = 0.5f; lr.material = AdditiveMat(new Color(0.35f, 0.9f, 1f)); lr.startColor = lr.endColor = new Color(0.4f, 1f, 1f) * 2f;
        float t = 0;
        while (t < 1.2f && current)
        {
            t += Time.deltaTime; lr.SetPosition(0, player.position + new Vector3(0, 0, 2.5f)); lr.SetPosition(1, current.transform.position);
            lr.widthMultiplier = 0.5f + Mathf.Sin(t * 40f) * 0.1f; Burst(current.transform.position + Random.insideUnitSphere * 5f, 1, new Color(0.4f, 1f, 1f)); yield return null;
        }
        Destroy(go); yield return Leave();
    }

    public IEnumerator Rest()
    {
        busy = true; status = "Repos : coque et équipage récupèrent";
        for (int k = 0; k < 3; k++) { StartCoroutine(HealRing()); yield return new WaitForSeconds(0.25f); }
        yield return new WaitForSeconds(0.9f); yield return Leave();
    }

    IEnumerator HealRing()
    {
        var go = new GameObject("Heal"); var lr = go.AddComponent<LineRenderer>(); lr.useWorldSpace = false; lr.loop = true; lr.positionCount = 48; lr.widthMultiplier = 0.15f; lr.material = AdditiveMat(Color.green);
        lr.startColor = lr.endColor = new Color(0.3f, 1f, 0.6f) * 2f; go.transform.position = player.position;
        for (int i = 0; i < 48; i++) { float a = i / 48f * 6.2832f; lr.SetPosition(i, new Vector3(Mathf.Cos(a), 0, Mathf.Sin(a))); }
        float t = 0; while (t < 0.9f) { t += Time.deltaTime; go.transform.localScale = Vector3.one * (1 + t * 9f); yield return null; }
        Destroy(go);
    }

    public IEnumerator Incident(bool ok)
    {
        busy = true; status = ok ? "Événement réussi" : "Événement raté";
        Burst(player.position + new Vector3(0, 1, 5), ok ? 60 : 25, ok ? new Color(1, 0.85f, 0.4f) : new Color(1, 0.35f, 0.3f));
        if (!ok) { shake = 0.5f; flash = 0.5f; }
        yield return new WaitForSeconds(0.9f); yield return Leave();
    }

    // ---------- effets ----------
    void Burst(Vector3 pos, int n, Color c)
    {
        var emit = new ParticleSystem.EmitParams { position = pos, startColor = c, startSize = Random.Range(0.3f, 0.7f) };
        for (int i = 0; i < n; i++) { emit.velocity = Random.onUnitSphere * Random.Range(3f, 11f); emit.startLifetime = Random.Range(0.5f, 1.2f); sparks.Emit(emit, 1); }
    }

    void Explode(Vector3 pos, float size)
    {
        Burst(pos, 70, new Color(1f, 0.65f, 0.25f)); Burst(pos, 30, new Color(1f, 0.95f, 0.8f));
        var l = new GameObject("BoomLight").AddComponent<Light>(); l.transform.position = pos; l.color = new Color(1, 0.7f, 0.35f); l.intensity = 8; l.range = 40 * size; Destroy(l.gameObject, 0.35f);
        for (int i = 0; i < 8; i++)
        {
            var d = GameObject.CreatePrimitive(PrimitiveType.Cube); Destroy(d.GetComponent<Collider>()); d.transform.position = pos; d.transform.localScale = new Vector3(0.5f, 0.12f, 0.35f) * size;
            d.GetComponent<Renderer>().material.color = new Color(0.25f, 0.27f, 0.3f); var rb = d.AddComponent<Debris>(); rb.v = Random.onUnitSphere * Random.Range(4f, 10f) * size; Destroy(d, 1.6f);
        }
    }

    // ---------- séquence automatique ----------
    IEnumerator AutoRoutine()
    {
        var order = new[] { "recolte", "epave", "combat", "repos", "elite", "inconnu", "recolte", "gardien" };
        int i = 0;
        while (true)
        {
            if (auto && !busy)
            {
                string t = order[i++ % order.Length];
                yield return Play(t);
                yield return new WaitForSeconds(0.4f);
            }
            else yield return null;
        }
    }

    public IEnumerator Play(string type)
    {
        yield return Travel(type);
        yield return new WaitForSeconds(0.5f);
        switch (type)
        {
            case "combat": case "elite": case "gardien": yield return Fight(Random.value < 0.85f); yield return Leave(); break;
            case "recolte": yield return Harvest(); break;
            case "repos": yield return Rest(); break;
            case "epave": case "inconnu": yield return Incident(Random.value < 0.7f); break;
        }
    }

    // ---------- boucle ----------
    void Update()
    {
        // caméra de poursuite derrière le convoi, légèrement au-dessus
        Vector3 shk = Random.insideUnitSphere * shake * 0.6f; shake = Mathf.Max(0, shake - Time.deltaTime);
        cam.transform.position = new Vector3(fleet.position.x * 0.6f, 3.1f, -12f + warp * 1.5f) + shk;
        cam.transform.LookAt(new Vector3(0, -2f, 14f));
        cam.fieldOfView = Mathf.Lerp(cam.fieldOfView, 70f + warp * 22f, Time.deltaTime * 8f);
        starsMain.simulationSpeed = Mathf.Lerp(starsMain.simulationSpeed, 1f + warp * 5f, Time.deltaTime * 6f);
        starsRend.velocityScale = Mathf.Lerp(starsRend.velocityScale, 0.02f + warp * 0.05f, Time.deltaTime * 6f);
        // bob doux des vaisseaux
        float t = Time.time;
        player.localPosition = new Vector3(0, Mathf.Sin(t * 1.6f) * 0.18f, 0);
        escortL.localPosition = new Vector3(-4.2f, -0.5f + Mathf.Sin(t * 1.6f + 1.7f) * 0.18f, -2.4f);
        escortR.localPosition = new Vector3(4.2f, -0.5f + Mathf.Sin(t * 1.6f + 3.4f) * 0.18f, -2.4f);
        flash = Mathf.Max(0, flash - Time.deltaTime * 3f);
        // les ennemis flottent
        for (int i = 0; i < enemies.Count; i++) if (enemies[i]) enemies[i].localPosition += new Vector3(Mathf.Sin(t * 0.8f + i) * 0.4f, Mathf.Sin(t * 1.3f + i) * 0.2f, 0) * Time.deltaTime;
    }

    void OnGUI()
    {
        var box = new Rect(10, 10, 170, Screen.height - 20);
        GUILayout.BeginArea(box);
        GUILayout.Label("Route — prototype Unity\n" + status);
        auto = GUILayout.Toggle(auto, "Mode auto");
        GUI.enabled = !busy;
        foreach (var t in new[] { "combat", "elite", "gardien", "recolte", "epave", "repos", "inconnu" })
            if (GUILayout.Button(t) && !busy) { auto = false; StartCoroutine(Play(t)); }
        GUI.enabled = true;
        GUILayout.EndArea();
        if (flash > 0) { GUI.color = new Color(1, 1, 1, flash); GUI.DrawTexture(new Rect(0, 0, Screen.width, Screen.height), Texture2D.whiteTexture); GUI.color = Color.white; }
    }

    // ---------- utilitaires ----------
    Material AdditiveMat(Color c)
    {
        var m = new Material(Shader.Find("Altopia/Additive")) { mainTexture = glow, color = c };
        return m;
    }

    static Texture2D MakeGlow()
    {
        var t = new Texture2D(64, 64, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
        for (int y = 0; y < 64; y++) for (int x = 0; x < 64; x++)
        { float d = Vector2.Distance(new Vector2(x, y), new Vector2(31.5f, 31.5f)) / 32f; float a = Mathf.Clamp01(1f - d); a *= a; t.SetPixel(x, y, new Color(1, 1, 1, a)); }
        t.Apply(); return t;
    }
}

public class Spin : MonoBehaviour { public Vector3 axis; void Update() { transform.Rotate(axis * Time.deltaTime, Space.Self); } }
public class Flicker : MonoBehaviour { Light l; void Start() { l = GetComponent<Light>(); } void Update() { l.intensity = Random.value > 0.8f ? 4.5f : 2f; } }
public class Debris : MonoBehaviour { public Vector3 v; void Update() { transform.position += v * Time.deltaTime; v *= 1f - 0.5f * Time.deltaTime; transform.Rotate(300 * Time.deltaTime, 200 * Time.deltaTime, 0); } }
