"""Visages humains low poly paramétriques : un visage unique par personnage (forme de tête, yeux, sourcils, nez, bouche, oreilles, coiffure, barbe, lunettes, taches, cicatrice).
human_head(name, hc, add, T) construit la tête en pièces rigides (os Head) autour du centre hc, face vers -Y. T = outils de characters_q (M, E, prim_box, prim_sph, prim_cyl, tube)."""
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def F(skin, hair, hs="short", beard=None, bc=None, w=0.1, d=0.108, h=0.122, jaw=0.9, chin=0.0, eye=(0.28, 0.2, 0.12), eyes=1.0, eyex=0.045, brow=(0.012, 8.0), brow_col=None,
      nose=(0.03, 0.014), mouth=(0.045, 0.5), lip=(0.55, 0.25, 0.25), ear=1.0, glasses=None, freckles=False, scar=False, tilt=0.0, lashes=False, bush=1.0):
    return dict(skin=skin, hair=hair, hs=hs, beard=beard, bc=bc or hair, w=w, d=d, h=h, jaw=jaw, chin=chin, eye=eye, eyes=eyes, eyex=eyex, brow=brow, brow_col=brow_col or tuple(c * 0.6 for c in hair),
                nose=nose, mouth=mouth, lip=lip, ear=ear, glasses=glasses, freckles=freckles, scar=scar, tilt=tilt, lashes=lashes, bush=bush)

FACES = {
 "captain": F((0.78, 0.58, 0.45), (0.28, 0.17, 0.1), "long", "full", w=0.104, jaw=1.0, eye=(0.2, 0.3, 0.4), brow=(0.016, -10.0), nose=(0.036, 0.017), mouth=(0.05, -0.2), bush=1.4),
 "rex":     F((0.86, 0.66, 0.5), (0.08, 0.07, 0.07), "spiky", "stubble", w=0.1, jaw=1.05, eye=(0.15, 0.1, 0.06), brow=(0.015, 4.0), mouth=(0.058, 1.0), nose=(0.032, 0.015)),
 "nova":    F((0.95, 0.8, 0.7), (0.07, 0.06, 0.1), "bangs", None, w=0.092, jaw=0.78, eyes=1.25, eyex=0.042, eye=(0.2, 0.1, 0.12), brow=(0.008, 12.0), nose=(0.022, 0.01), mouth=(0.038, 0.4), lip=(0.8, 0.3, 0.4), lashes=True),
 "zara":    F((0.4, 0.26, 0.2), (0.88, 0.9, 0.95), "long", None, w=0.095, jaw=0.82, eyes=1.1, eye=(0.9, 0.7, 0.2), brow=(0.008, 16.0), nose=(0.028, 0.012), mouth=(0.042, 0.1), lip=(0.35, 0.12, 0.12), tilt=0.0, lashes=True),
 "bolt":    F((0.8, 0.55, 0.42), (0.32, 0.2, 0.1), "receding", "mustache", w=0.108, d=0.112, jaw=1.1, eyes=0.9, eye=(0.35, 0.25, 0.15), brow=(0.02, -6.0), nose=(0.04, 0.022), mouth=(0.05, -0.3), bush=1.5),
 "tess":    F((0.72, 0.52, 0.4), (0.22, 0.12, 0.07), "ponytail", None, w=0.098, jaw=0.88, eyes=1.1, eye=(0.2, 0.35, 0.2), brow=(0.01, 6.0), mouth=(0.055, 1.0), freckles=True, nose=(0.024, 0.011), lashes=True),
 "gorn":    F((0.86, 0.62, 0.52), (0.7, 0.3, 0.1), "bald", "big", w=0.112, d=0.114, h=0.124, jaw=1.15, eyes=0.85, eye=(0.2, 0.25, 0.2), brow=(0.022, -14.0), nose=(0.042, 0.022), mouth=(0.05, -0.4), scar=True, bush=2.0),
 "lumi":    F((0.92, 0.77, 0.67), (0.88, 0.7, 0.3), "bob", None, w=0.098, jaw=0.85, eyes=1.3, eyex=0.046, eye=(0.2, 0.5, 0.6), brow=(0.008, 8.0), nose=(0.02, 0.01), mouth=(0.05, 1.0), lip=(0.85, 0.4, 0.45), lashes=True),
 "quark":   F((0.88, 0.7, 0.58), (0.3, 0.2, 0.14), "sidepart", None, w=0.096, d=0.108, jaw=0.92, eyes=0.95, eye=(0.2, 0.15, 0.1), brow=(0.012, 2.0), nose=(0.04, 0.014), mouth=(0.036, -0.1), glasses="round"),
 "elara":   F((0.96, 0.84, 0.76), (0.65, 0.14, 0.1), "bun", None, w=0.09, jaw=0.8, eyes=1.15, eyex=0.041, eye=(0.35, 0.6, 0.3), brow=(0.007, 14.0), nose=(0.022, 0.01), mouth=(0.04, 0.35), lip=(0.7, 0.2, 0.25), lashes=True),
 "vance":   F((0.82, 0.65, 0.55), (0.92, 0.92, 0.94), "sidepart", "mustache", w=0.1, jaw=0.95, eyes=0.9, eye=(0.45, 0.5, 0.55), brow=(0.018, -12.0), nose=(0.036, 0.016), mouth=(0.044, -0.5), bush=1.8),
 "sira":    F((0.7, 0.5, 0.4), (0.65, 0.25, 0.1), "braid", None, w=0.096, jaw=1.0, eyes=1.0, eye=(0.15, 0.4, 0.3), brow=(0.009, 10.0), nose=(0.03, 0.012), mouth=(0.05, 0.8), freckles=True, chin=0.006, lashes=True),
 "maya":    F((0.36, 0.22, 0.16), (0.05, 0.04, 0.05), "afro", None, w=0.1, jaw=0.9, eyes=1.15, eye=(0.12, 0.07, 0.05), brow=(0.01, 10.0), nose=(0.03, 0.016), mouth=(0.06, 1.0), lip=(0.45, 0.15, 0.15), lashes=True),
 "ilan":    F((0.5, 0.33, 0.24), (0.1, 0.1, 0.12), "short", "stubble", w=0.098, jaw=0.95, eyes=1.0, eye=(0.12, 0.08, 0.06), brow=(0.012, 3.0), nose=(0.032, 0.014), mouth=(0.042, 0.4), glasses="square"),
}


def face_geom(p, hc):
    return hc + Vector((0, 0, 0)), p["w"], p["d"], p["h"]

def add_face_bones(arm, name, hc):
    """Os de visage : Jaw (bouche, menton), Blink.L/R (paupières), Brow.L/R (sourcils), HairB (cheveux arrière : queue, tresse, mèches)."""
    p = FACES[name]; w, d, h = p["w"], p["d"], p["h"]
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones; par = eb["Head"]
    def mk(n, head, tail):
        b = eb.new(n); b.head = Vector(head); b.tail = Vector(tail); b.parent = par; b.use_connect = False; return b
    ez = 0.016
    for sg, sd in ((-1, "L"), (1, "R")):
        x = sg * p["eyex"]
        mk("Blink." + sd, (hc.x + x, hc.y - d * 0.9, hc.z + ez), (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.02))
        e_ = mk("Eye." + sd, (hc.x + x, hc.y - d * 0.9, hc.z + ez), (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.012)); e_.parent = eb["Blink." + sd]
        mk("Brow." + sd, (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.03), (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.05))
    mk("Jaw", (hc.x, hc.y + d * 0.1, hc.z - 0.045), (hc.x, hc.y - d * 0.9, hc.z - 0.07))
    h1 = mk("HairB", (hc.x, hc.y + d * 0.85, hc.z + 0.03), (hc.x, hc.y + d * 1.1, hc.z - 0.05))
    h2 = mk("HairB2", (hc.x, hc.y + d * 1.1, hc.z - 0.05), (hc.x, hc.y + d * 1.2, hc.z - 0.13)); h2.parent = h1
    h3 = mk("HairB3", (hc.x, hc.y + d * 1.2, hc.z - 0.13), (hc.x, hc.y + d * 1.3, hc.z - 0.24)); h3.parent = h2
    bpy.ops.object.mode_set(mode="OBJECT")

TAU = 2 * math.pi

def human_head(name, hc, add, T):
    p = FACES[name]; M, E, box, sph, cyl, tube = T["M"], T["E"], T["box"], T["sph"], T["cyl"], T["tube"]
    sk = M(name + "_skin", p["skin"], 0.0, 0.7); hair = M(name + "_hair", p["hair"], 0.0, 0.6)
    hair2 = M(name + "_hair2", tuple(min(1.0, c * 1.25 + 0.03) for c in p["hair"]), 0.0, 0.5)   # reflets
    w, d, h = p["w"], p["d"], p["h"]
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=9, radius=1.0)
    for v in bm.verts:
        x, y, z = v.co
        t = max(0.0, (-z - 0.15) / 0.85)
        x *= 1 - (1 - p["jaw"]) * t * 1.2; y -= p["chin"] * 6 * t * max(0.0, -y)
        v.co = Vector((x * w, y * d, z * h)) + hc
    bvh = BVHTree.FromBMesh(bm)
    me = bpy.data.meshes.new("hd"); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("hd", me); bpy.context.collection.objects.link(ob)
    for pl in me.polygons: pl.use_smooth = False
    add(ob, "Head", sk)
    def surf(x, z):
        r = bvh.ray_cast(Vector((hc.x + x, hc.y - 0.5, hc.z + z)), Vector((0, 1, 0)))
        return r[0].y if r[0] is not None else hc.y - d
    def lock(pos, dv, ln, wd, mat, bone="Head", seg=4):
        """Mèche : plaque fine posée sur la surface (à plat contre la tête), bout biseauté : pas de pointe tournée vers l'avant."""
        pos = Vector(pos); n = (pos - hc); n = Vector((n.x / w, n.y / d, n.z / h)).normalized() if n.length > 1e-6 else Vector((0, -1, 0))
        z = Vector(dv).normalized(); z = (z - n * z.dot(n))
        if z.length < 1e-4: z = Vector((0, 0, -1)) - n * (-n.z)
        z.normalize(); x = n.cross(z).normalized(); n2 = z.cross(x).normalized()
        from mathutils import Matrix
        m = Matrix(((x.x, n2.x, z.x), (x.y, n2.y, z.y), (x.z, n2.z, z.z))); eu = m.to_euler()
        add(box((wd * 1.7, 0.009, ln), pos + z * ln / 2 + n2 * 0.004, (eu.x, eu.y, eu.z), r=0.35, sub=0), bone, mat)
    HC = ("HairB", "HairB2", "HairB3")
    def lerp(a_, b_, u_): return a_ + (b_ - a_) * u_
    def tube_r(pts, radii, n=4):
        """Tube effilé (rayon par point), bout fermé en pointe, ombrage lissé"""
        bm_ = bmesh.new(); rows = []; N = len(pts)
        for i_, p_ in enumerate(pts):
            T = (pts[min(i_ + 1, N - 1)] - pts[max(i_ - 1, 0)]).normalized()
            ref = Vector((0, 0, 1)) if abs(T.z) < 0.9 else Vector((1, 0, 0))
            Nn = (ref - ref.dot(T) * T).normalized(); B = T.cross(Nn)
            rows.append([bm_.verts.new(p_ + Nn * math.cos(2 * math.pi * j / n) * radii[i_] + B * math.sin(2 * math.pi * j / n) * radii[i_]) for j in range(n)])
        for i_ in range(N - 1):
            for j in range(n): bm_.faces.new((rows[i_][j], rows[i_][(j + 1) % n], rows[i_ + 1][(j + 1) % n], rows[i_ + 1][j]))
        bm_.faces.new(rows[0][::-1]); bm_.faces.new(rows[-1])
        bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces)
        me_ = bpy.data.meshes.new("tr"); bm_.to_mesh(me_); bm_.free()
        for pl in me_.polygons: pl.use_smooth = True
        o_ = bpy.data.objects.new("tr", me_); bpy.context.collection.objects.link(o_); return o_
    def clump(root, d0, length, r0, mat, bone, grav=0.7, lift=0.0, curl=0.0, seg=4):
        """Mèche : courbe qui retombe (gravité), s'écarte du crâne, se recourbe un peu ; rayon effilé"""
        p_ = Vector(root); dv = Vector(d0).normalized(); pts = [p_.copy()]; step = length / seg
        for i_ in range(seg):
            side = dv.cross(Vector((0, 0, 1)))
            dv = (dv + Vector((0, 0, -1)) * grav * 0.5 + Vector((0, 0, 1)) * lift * (i_ / seg) * 0.6 + (side.normalized() * curl * 0.4 if side.length > 1e-4 else Vector())).normalized()
            p_ = p_ + dv * step
            q = p_ - hc; e_ = math.sqrt((q.x / (w * 1.04)) ** 2 + (q.y / (d * 1.04)) ** 2 + (q.z / (h * 1.04)) ** 2)
            if e_ < 1.0 and q.z > -h * 0.55: p_ = hc + q / max(e_, 1e-3)
            pts.append(p_.copy())
        add(tube_r(pts, [r0 * (1 - i_ / seg) ** 0.8 + 0.0008 for i_ in range(seg + 1)], 4), bone, mat)
    def cap_pt(phi, zl, k=1.07):
        """point sur la calotte (phi : 0 = face, +/- côtés ; zl : hauteur relative)"""
        r = math.sqrt(max(0.0, 1 - zl * zl))
        return hc + Vector((r * math.sin(phi) * w * k, -r * math.cos(phi) * d * k, zl * h * k))
    # oreilles
    for sg in (-1, 1): add(sph(1.0, (hc.x + sg * w * 0.97, hc.y + 0.006, hc.z - 0.004), (0.012 * p["ear"], 0.016 * p["ear"], 0.028 * p["ear"]), 8), "Head", sk)
    # yeux (os Blink), sourcils (os Brow), cils
    wh = M(name + "_sclera", (0.95, 0.95, 0.97), 0.0, 0.3); ir = M(name + "_iris", p["eye"], 0.0, 0.3); pu = M("pupil", (0.02, 0.02, 0.03), 0.0, 0.2)
    brm = M(name + "_brow", p["brow_col"], 0.0, 0.7); lashm = M("lash", (0.04, 0.03, 0.03), 0.0, 0.6)
    ez = 0.016; es = p["eyes"]
    for sg in (-1, 1):
        sd = "L" if sg < 0 else "R"; x = sg * p["eyex"]; y = surf(x, ez)
        add(sph(1.0, (hc.x + x, y - 0.003, hc.z + ez), (0.017 * es, 0.007, 0.012 * es), 8), "Blink." + sd, wh)
        add(sph(1.0, (hc.x + x, y - 0.0085, hc.z + ez), (0.0095 * es, 0.004, 0.0095 * es), 8), "Eye." + sd, ir)
        add(sph(1.0, (hc.x + x, y - 0.011, hc.z + ez), (0.0045 * es, 0.0025, 0.0045 * es), 6), "Eye." + sd, pu)
        if p["lashes"]:
            add(box((0.036 * es, 0.006, 0.0045), (hc.x + x, y - 0.006, hc.z + ez + 0.0125 * es), (0, math.radians(sg * -6), 0), r=0.3, sub=0), "Blink." + sd, lashm)
            add(box((0.01, 0.006, 0.004), (hc.x + x + sg * 0.018 * es, y - 0.004, hc.z + ez + 0.009 * es), (0, math.radians(sg * 30), 0), r=0.3, sub=0), "Blink." + sd, lashm)
        bt, ang = p["brow"]; bz = ez + 0.026 + 0.004 * es; bt *= p["bush"]
        # sourcil : arc effilé (plus épais et plus long si fourni), incliné selon l'humeur
        bw = 0.02 + 0.004 * (p["bush"] - 1); tl = math.radians(sg * -ang) * 0.5
        pts = [Vector((hc.x + x - sg * bw * 1.0, surf(x - sg * bw, bz) - 0.004, hc.z + bz - bw * tl * -0.6)), Vector((hc.x + x, surf(x, bz + 0.003) - 0.005, hc.z + bz + 0.003 + 0.0)), Vector((hc.x + x + sg * bw * 1.15, surf(x + sg * bw * 1.2, bz - 0.004 + bw * tl * 0.9) - 0.004, hc.z + bz - 0.004 + bw * tl * 0.9))]
        add(tube_r(pts, [bt * 0.28 + 0.0015, bt * 0.5 + 0.002, 0.0012], 4), "Brow." + sd, brm)
    nl, nw = p["nose"]; nz = -0.012; ny = surf(0, nz)
    add(cyl(nw, 0.002, nl, (hc.x, ny - nl / 2 + 0.006, hc.z + nz), (math.radians(90), 0, 0), 4), "Head", sk)
    # bouche (os Jaw)
    mw, cv = p["mouth"]; mz = -0.058; my = surf(0, mz) - (0.012 if p["beard"] in ("full", "big") else 0.003)
    lipm = M(name + "_lip", p["lip"], 0.0, 0.5); lip2 = M(name + "_lip2", tuple(c * 0.75 for c in p["lip"]), 0.0, 0.5)
    add(box((mw, 0.008, 0.0065), (hc.x, my, hc.z + mz + 0.003), r=0.3, sub=0), "Jaw", lipm)
    add(box((mw * 0.9, 0.008, 0.0075), (hc.x, my, hc.z + mz - 0.004), r=0.3, sub=0), "Jaw", lip2)
    for sg in (-1, 1): add(box((mw * 0.32, 0.008, 0.007), (hc.x + sg * mw * 0.46, my, hc.z + mz + cv * 0.006), (0, math.radians(sg * cv * 28), 0), r=0.3, sub=0), "Jaw", lipm)
    # lunettes
    if p["glasses"]:
        bl = M("frames", (0.08, 0.08, 0.1), 0.3, 0.4)
        for sg in (-1, 1):
            x = sg * p["eyex"]; y = surf(x, ez) - 0.012
            if p["glasses"] == "round":
                add(tube([Vector((hc.x + x + math.cos(a) * 0.027, y, hc.z + ez + math.sin(a) * 0.027)) for a in [2 * math.pi * k / 10 for k in range(10)]], 0.0035, 4, True), "Head", bl)
            else:
                add(box((0.056, 0.006, 0.042), (hc.x + x, y, hc.z + ez), r=0.2, sub=0), "Head", M("frames2", (0.1, 0.1, 0.13), 0.3, 0.4)); add(box((0.044, 0.008, 0.03), (hc.x + x, y - 0.001, hc.z + ez), r=0.2, sub=0), "Head", sk)
            add(box((0.006, 0.12, 0.006), (hc.x + sg * (w * 0.98), hc.y - 0.0, hc.z + ez), r=0.3, sub=0), "Head", bl)
        add(box((0.02, 0.006, 0.006), (hc.x, surf(0, ez) - 0.012, hc.z + ez + 0.004), r=0.3, sub=0), "Head", bl)
    if p["freckles"]:
        fm = M("freck", tuple(c * 0.7 for c in p["skin"]), 0.0, 0.8)
        for sg in (-1, 1):
            for dx, dz in ((0.035, -0.012), (0.05, -0.02), (0.028, -0.026), (0.058, -0.008), (0.042, -0.03)):
                x = sg * dx; add(sph(0.004, (hc.x + x, surf(x, dz) - 0.001, hc.z + dz), (1, 0.5, 1), 5), "Head", fm)
        for dx in (-0.01, 0.0, 0.01): add(sph(0.0035, (hc.x + dx, surf(dx, -0.004) - 0.001, hc.z - 0.004), (1, 0.5, 1), 5), "Head", fm)
    if p["scar"]:
        x = -0.05; add(box((0.007, 0.006, 0.07), (hc.x + x, surf(x, 0.0) - 0.003, hc.z + 0.0), (0, math.radians(25), 0), r=0.3, sub=0), "Head", M("scar", (0.62, 0.25, 0.25), 0.0, 0.7))
    # ---- barbe (mèches souples : tubes effilés, ombrage lissé) -------------------------------------------------
    bc = M(name + "_beard", p["bc"], 0.0, 0.55); bc2 = M(name + "_beard2", tuple(min(1.0, c * 1.25 + 0.03) for c in p["bc"]), 0.0, 0.45); b = p["beard"]
    def jit(i, k=1.0): return 0.5 + 0.5 * math.sin(i * 2.399 + k)       # variation déterministe 0..1
    def ring(n, phi0, phi1, zl0, zl1, dirf, length, r0, mats, bone, grav=0.8, lift=0.0, curl=0.0, k=1.06, seg=4):
        for i in range(n):
            u = i / max(1, n - 1); phi = lerp(phi0, phi1, u) + 0.07 * (jit(i, 1.3) - 0.5); zl = lerp(zl0, zl1, jit(i, 0.4)) 
            clump(cap_pt(phi, zl, k), dirf(phi, zl), length * (0.75 + 0.5 * jit(i, 2.1)), r0 * (0.8 + 0.4 * jit(i, 3.3)), mats[i % len(mats)], bone, grav, lift, curl * (jit(i, 5.0) - 0.5) * 2, seg)
    if b in ("full", "big", "stubble"):
        mat = bc if b != "stubble" else M(name + "_stubble", tuple(c * 0.78 for c in p["skin"]), 0.0, 0.9)
        k = {"full": 1.07, "big": 1.09, "stubble": 1.03}[b]
        sb = bmesh.new(); bmesh.ops.create_uvsphere(sb, u_segments=18, v_segments=11, radius=1.0)
        for v in sb.verts:
            x, y, z = v.co; t = max(0.0, (-z - 0.15) / 0.85)
            x *= 1 - (1 - p["jaw"]) * t * 1.2; y -= p["chin"] * 6 * t * max(0.0, -y)
            v.co = Vector((x * w * k, y * d * k, z * h * k)) + hc
        keep = [f for f in sb.faces if (f.calc_center_median() - hc).z < -0.032 and (f.calc_center_median() - hc).y < 0.025]
        if b == "stubble": keep = [f for f in keep if (f.calc_center_median() - hc).z < -0.04]
        rest = [f for f in sb.faces if f not in keep]; bmesh.ops.delete(sb, geom=rest, context="FACES")
        if b != "stubble":
            for f in list(sb.faces):
                c = f.calc_center_median() - hc
                if abs(c.x) < 0.03 and -0.07 < c.z < -0.045 and c.y < -0.03 and f.is_valid: sb.faces.remove(f)
        sm = bpy.data.meshes.new("bd"); sb.to_mesh(sm); sb.free()
        bo = bpy.data.objects.new("bd", sm); bpy.context.collection.objects.link(bo)
        for pl in sm.polygons: pl.use_smooth = True
        add(bo, "Head", mat)
        if b in ("full", "big"):
            L_ = 1.0 if b == "full" else 1.7
            for row, (zl0, zl1, ln) in enumerate(((-0.62, -0.5, 0.05), (-0.78, -0.62, 0.065), (-0.9, -0.78, 0.08))):
                n_ = 15 if row < 2 else 11
                for i in range(n_):
                    u = i / (n_ - 1); phi = lerp(-1.45, 1.45, u) + 0.16 * (jit(i, row + 3.1) - 0.5)
                    if abs(phi) < 0.42 and row == 0: continue      # ouverture de la bouche
                    zl = lerp(zl0, zl1, jit(i, 0.7 + row))
                    dv = (math.sin(phi) * 0.25 + 0.3 * (jit(i, 7.0 + row) - 0.5), -math.cos(phi) * (0.25 + 0.2 * row), -1.0)
                    clump(cap_pt(phi, zl, 1.08), dv, ln * L_ * (0.6 + 0.85 * jit(i, 2.0 + row)) * (1.25 if abs(phi) < 0.5 and row == 2 else 1.0), 0.016 * (0.85 + 0.3 * jit(i, 4.0)), bc if (i + row) % 2 else bc2, "Jaw", 0.5, 0.0, 0.5 * (jit(i, 6.0) - 0.5), 4)
            for sg in (-1, 1):   # favoris reliant les cheveux à la barbe
                for j in range(3): clump(cap_pt(sg * (1.2 + 0.12 * j), 0.0 - 0.15 * j, 1.07), (sg * 0.1, -0.2, -1), 0.05, 0.014, bc, "Head", 0.5, 0.0, 0.0, 3)
            if b == "big":
                for sg in (-1, 1):   # tresses de barbe
                    pts = [hc + Vector((sg * 0.03, -d * 0.85, -h * 1.0)), hc + Vector((sg * 0.036, -d * 0.87, -h * 1.0 - 0.05)), hc + Vector((sg * 0.028, -d * 0.86, -h * 1.0 - 0.1)), hc + Vector((sg * 0.034, -d * 0.84, -h * 1.0 - 0.15))]
                    add(tube_r(pts, [0.012, 0.012, 0.011, 0.004], 4), "Jaw", bc2); add(sph(0.012, pts[-1] + Vector((0, 0, -0.006)), (1, 1, 1.2), 6), "Jaw", M("tie", (0.75, 0.55, 0.15), 0.6, 0.4))
    if b == "mustache":
        my2 = surf(0, -0.038)
        add(sph(1.0, (hc.x, my2 - 0.003, hc.z - 0.043), (0.026, 0.012, 0.012), 8), "Head", bc)
        for sg in (-1, 1):
            clump((hc.x + sg * 0.012, my2 - 0.004, hc.z - 0.044), (sg * 1.0, -0.22, -0.35), 0.05, 0.011, bc2, "Head", 0.4, 0.9, 0.0, 4)
            clump((hc.x + sg * 0.012, my2 - 0.004, hc.z - 0.05), (sg * 1.0, -0.22, -0.5), 0.045, 0.01, bc, "Head", 0.4, 0.5, 0.0, 4)
        add(sph(1.0, (hc.x, my2 - 0.002, hc.z - 0.076), (0.007, 0.006, 0.008), 6), "Jaw", bc)
    # ---- coiffure : calotte lissée + mèches effilées (les longues suivent le squelette HairB..HairB3 : elles ploient)
    hs = p["hs"]
    if hs != "bald":
        hb = bmesh.new(); bmesh.ops.create_uvsphere(hb, u_segments=16, v_segments=10, radius=1.0)
        kk = 1.34 if hs == "afro" else 1.10
        for v in hb.verts: v.co = Vector((v.co.x * w * kk, v.co.y * d * kk, v.co.z * h * kk)) + hc + (Vector((0, 0.012, 0.01)) if hs == "afro" else Vector())
        fr = {"short": 0.34, "spiky": 0.36, "long": 0.32, "bangs": 0.22, "bob": 0.34, "ponytail": 0.36, "bun": 0.34, "sidepart": 0.32, "receding": 0.62, "braid": 0.34, "afro": 0.2}[hs]
        bk = {"short": -0.05, "spiky": 0.0, "long": -0.5, "bangs": -0.5, "bob": -0.4, "ponytail": -0.1, "bun": -0.1, "sidepart": -0.05, "receding": 0.1, "braid": -0.1, "afro": -0.6}[hs]
        kill = []
        for f in hb.faces:
            c = (f.calc_center_median() - hc); zl = c.z / (h * kk); yl = c.y / (d * kk)
            phi = math.atan2(c.x / (w * kk), -c.y / (d * kk))
            hl = {"sidepart": (0.22 if phi < 0 else 0.55) + 0.04 * math.sin(6 * phi), "receding": fr - 0.14 * abs(math.sin(2.4 * phi)) * (1 if abs(phi) < 1.2 else 0),
                  "bangs": fr + 0.035 * math.sin(9 * phi), "bob": fr + 0.04 * math.sin(8 * phi), "spiky": fr + 0.1 * abs(math.sin(5 * phi)), "afro": fr}.get(hs, fr + 0.06 * math.sin(5 * phi + 0.5))
            lim = hl if yl < 0.0 else bk
            if zl < lim: kill.append(f)
        bmesh.ops.delete(hb, geom=kill, context="FACES")
        hm = bpy.data.meshes.new("hh"); hb.to_mesh(hm); hb.free()
        ho = bpy.data.objects.new("hh", hm); bpy.context.collection.objects.link(ho)
        for pl in hm.polygons: pl.use_smooth = True
        add(ho, "Head", hair)
        Hm = [hair, hair2]
        out = lambda phi, zl: (math.sin(phi), -math.cos(phi), 0.0)
        def sideburns(zl=0.0, ln=0.05):
            for sg in (-1, 1):
                for j in range(2): clump(cap_pt(sg * (1.3 + 0.1 * j), zl - 0.12 * j, 1.07), (sg * 0.15, -0.15, -1), ln * (1 - 0.2 * j), 0.014, hair, "Head", 0.5, 0.0, 0.0, 3)
        def dirf(a, b_, c): return lambda phi, zl: (math.sin(phi) * a, -math.cos(phi) * b_, c)
        if hs == "short":
            ring(16, -1.5, 1.5, 0.45, 0.62, dirf(0.7, 0.8, -0.3), 0.04, 0.013, Hm, "Head", 0.6, 0.0, 0.8)
            ring(10, 1.6, 4.7, 0.2, 0.7, dirf(1.0, 1.0, -0.5), 0.05, 0.014, Hm, "Head", 0.7, 0.0, 0.8)
            sideburns(0.12, 0.04)
        elif hs == "spiky":
            ring(14, -1.5, 1.5, 0.5, 0.7, lambda phi, zl: (math.sin(phi) * 0.5, -math.cos(phi) * 0.35, 1.0), 0.07, 0.02, Hm, "Head", 0.0, 0.0, 0.9)
            ring(8, 1.6, 4.6, 0.5, 0.8, lambda phi, zl: (math.sin(phi) * 0.5, -math.cos(phi) * 0.35, 1.0), 0.06, 0.02, Hm, "Head", 0.0, 0.0, 0.9)
            sideburns(0.1, 0.035)
        elif hs in ("long", "bangs"):
            ring(22, 1.2, 5.1, 0.45, -0.2, lambda phi, zl: (math.sin(phi) * 0.15, -math.cos(phi) * 0.3, -1.0), 0.2, 0.019, Hm, HC, 0.7, 0.0, 0.8, 1.07, 5)
            ring(8, -1.9, -1.35, 0.4, -0.1, lambda phi, zl: (math.sin(phi) * 0.2, 0.05, -1.0), 0.14, 0.016, Hm, HC, 0.7, 0.0, 0.4, 1.07, 5)
            ring(8, 1.35, 1.9, 0.4, -0.1, lambda phi, zl: (math.sin(phi) * 0.2, 0.05, -1.0), 0.14, 0.016, Hm, HC, 0.7, 0.0, 0.4, 1.07, 5)
            if hs == "bangs": ring(13, -1.1, 1.1, 0.62, 0.55, lambda phi, zl: (math.sin(phi) * 0.25 + 0.1, -math.cos(phi) * 0.5, -0.9), 0.07, 0.014, Hm, "Head", 0.5, 0.0, 0.9, 1.07, 4)
            else: ring(9, -1.0, 1.0, 0.6, 0.5, lambda phi, zl: (math.sin(phi) * 0.7 + 0.5 * (1 if phi > 0 else -1), -math.cos(phi) * 0.4, -0.7), 0.06, 0.013, Hm, "Head", 0.6, 0.0, 0.8, 1.07, 4)
        elif hs == "bob":
            ring(16, 1.2, 5.1, 0.4, -0.1, lambda phi, zl: (math.sin(phi) * 0.15, -math.cos(phi) * 0.3, -1.0), 0.1, 0.018, Hm, HC, 0.4, -0.6, 0.6, 1.07, 4)
            ring(6, -1.9, -1.35, 0.35, 0.0, lambda phi, zl: (math.sin(phi) * 0.2, -0.2, -1.0), 0.09, 0.016, Hm, HC, 0.4, -0.5, 0.3, 1.07, 4)
            ring(6, 1.35, 1.9, 0.35, 0.0, lambda phi, zl: (math.sin(phi) * 0.2, -0.2, -1.0), 0.09, 0.016, Hm, HC, 0.4, -0.5, 0.3, 1.07, 4)
            ring(13, -1.1, 1.1, 0.58, 0.5, lambda phi, zl: (math.sin(phi) * 0.3, -math.cos(phi) * 0.6, -0.8), 0.06, 0.013, Hm, "Head", 0.5, 0.0, 0.8, 1.07, 4)
        elif hs == "ponytail":
            sideburns(0.1, 0.03)
            ring(9, -1.4, 1.4, 0.45, 0.6, dirf(0.5, 0.6, -0.4), 0.04, 0.013, Hm, "Head", 0.6, 0.0, 0.8)
            tie = Vector((hc.x, hc.y + d * 1.28, hc.z + 0.02))
            for i in range(7):
                a_ = (i - 3) * 0.1
                pts = [cap_pt(math.pi + a_ * 1.5, 0.5, 1.05), Vector((hc.x + a_ * 0.05, hc.y + d * 1.12, hc.z + 0.06)), tie + Vector((a_ * 0.04, 0, 0)), tie + Vector((a_ * 0.18, 0.05, -0.08)), tie + Vector((a_ * 0.3, 0.07, -0.17)), tie + Vector((a_ * 0.35, 0.06, -0.24))]
                add(tube_r(pts, [0.011, 0.012, 0.01, 0.014, 0.012, 0.003], 4), HC, Hm[i % 2])
            add(tube([tie + Vector((math.cos(a) * 0.026, 0.0, math.sin(a) * 0.026)) for a in [TAU * k / 8 for k in range(8)]] if False else [Vector((tie.x + math.cos(a) * 0.024, tie.y, tie.z + math.sin(a) * 0.024)) for a in [2 * math.pi * k / 8 for k in range(8)]], 0.006, 4, True), "HairB", M("tie", (0.9, 0.3, 0.3), 0.3, 0.4))
        elif hs == "braid":
            sideburns(0.1, 0.03)
            ring(9, -1.4, 1.4, 0.45, 0.6, dirf(0.5, 0.6, -0.4), 0.04, 0.013, Hm, "Head", 0.6, 0.0, 0.8)
            for s_ in range(3):
                ph = s_ * 2.1
                pts = [Vector((hc.x + 0.012 * math.sin(ph + i * 1.5), hc.y + d * (0.95 + 0.08 * i), hc.z + 0.04 - i * 0.045)) for i in range(7)]
                add(tube_r(pts, [0.012, 0.014, 0.014, 0.013, 0.012, 0.01, 0.003], 4), HC, Hm[s_ % 2])
            add(sph(0.014, (hc.x, hc.y + d * 1.5, hc.z - 0.26), (1, 1, 1), 6), HC, M("tie2", (0.85, 0.7, 0.2), 0.4, 0.4))
        elif hs == "bun":
            sideburns(0.1, 0.03)
            ring(14, -1.5, 1.5, 0.45, 0.62, dirf(0.6, 0.7, -0.3), 0.04, 0.013, Hm, "Head", 0.6, 0.0, 0.8)
            add(sph(0.046, (hc.x, hc.y + d * 0.5, hc.z + h * 1.06), (1, 1, 0.9), 10), HC, hair)
            for i in range(6):
                a_ = TAU * i / 6; pts = [Vector((hc.x + math.cos(a_) * 0.03, hc.y + d * 0.5 + math.sin(a_) * 0.03, hc.z + h * 1.04 + 0.03)), Vector((hc.x + math.cos(a_) * 0.052, hc.y + d * 0.5 + math.sin(a_) * 0.052, hc.z + h * 1.06)), Vector((hc.x + math.cos(a_ + 0.6) * 0.04, hc.y + d * 0.5 + math.sin(a_ + 0.6) * 0.04, hc.z + h * 1.1))]
                add(tube_r(pts, [0.007, 0.007, 0.003], 4), HC, Hm[i % 2])
            add(tube([Vector((hc.x + math.cos(a) * 0.05, hc.y + d * 0.5 + math.sin(a) * 0.05, hc.z + h * 1.05)) for a in [2 * math.pi * k / 8 for k in range(8)]], 0.006, 4, True), HC, M("tie3", (0.9, 0.8, 0.3), 0.4, 0.4))
        elif hs == "sidepart":
            ring(14, -1.5, 0.2, 0.7, 0.45, lambda phi, zl: (-0.9, -0.5, -0.4), 0.06, 0.014, Hm, "Head", 0.5, 0.0, 0.7, 1.07, 4)
            ring(7, 0.2, 1.5, 0.5, 0.6, lambda phi, zl: (math.sin(phi) * 0.4 - 0.5, -math.cos(phi) * 0.5, -0.5), 0.045, 0.013, Hm, "Head", 0.6, 0.0, 0.7, 1.07, 4)
            ring(8, 1.6, 4.6, 0.2, 0.7, dirf(1.0, 1.0, -0.5), 0.05, 0.014, Hm, "Head", 0.7, 0.0, 0.8)
            sideburns(0.1, 0.035)
        elif hs == "receding":
            sideburns(0.05, 0.05)
            for sg in (-1, 1): ring(6, sg * 1.25, sg * 1.9, 0.35, 0.0, dirf(0.9, 0.3, -0.7), 0.05, 0.014, Hm, "Head", 0.7, 0.0, 0.6)
            ring(10, 1.9, 4.4, 0.1, 0.55, dirf(1.0, 1.0, -0.6), 0.05, 0.014, Hm, "Head", 0.7, 0.0, 0.8)
        elif hs == "afro":
            for i in range(22):
                a_ = -1.7 + 3.4 * (i % 11) / 10 if i < 11 else 1.5 + 3.0 * ((i - 11) / 10)
                zl_ = 0.35 + 0.5 * jit(i, 1.9)
                c_ = cap_pt(a_, zl_, 1.28); add(sph(0.032 + 0.012 * jit(i, 2.2), c_, (1, 1, 0.95), 7), "Head", Hm[i % 2])
            for dx, dz in ((-0.05, 0.1), (0.05, 0.1), (0.0, 0.14), (-0.09, 0.03), (0.09, 0.03), (-0.07, 0.07), (0.07, 0.07), (0.0, 0.09)):
                add(sph(0.045, (hc.x + dx, hc.y + 0.02, hc.z + dz), (1, 1, 1), 8), "Head", Hm[0 if dx > 0 else 1])
