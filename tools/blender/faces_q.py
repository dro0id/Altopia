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
        mk("Brow." + sd, (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.03), (hc.x + x, hc.y - d * 0.9, hc.z + ez + 0.05))
    mk("Jaw", (hc.x, hc.y + d * 0.1, hc.z - 0.045), (hc.x, hc.y - d * 0.9, hc.z - 0.07))
    mk("HairB", (hc.x, hc.y + d * 0.85, hc.z + 0.04), (hc.x, hc.y + d * 1.4, hc.z - 0.06))
    bpy.ops.object.mode_set(mode="OBJECT")

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
        dv = Vector(dv).normalized(); eu = Vector((0, 0, 1)).rotation_difference(dv).to_euler()
        add(cyl(wd, 0.0, ln, Vector(pos) + dv * ln / 2, (eu.x, eu.y, eu.z), seg), bone, mat)
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
        add(sph(1.0, (hc.x + x, y - 0.0085, hc.z + ez), (0.0095 * es, 0.004, 0.0095 * es), 8), "Blink." + sd, ir)
        add(sph(1.0, (hc.x + x, y - 0.011, hc.z + ez), (0.0045 * es, 0.0025, 0.0045 * es), 6), "Blink." + sd, pu)
        if p["lashes"]:
            add(box((0.036 * es, 0.006, 0.0045), (hc.x + x, y - 0.006, hc.z + ez + 0.0125 * es), (0, math.radians(sg * -6), 0), r=0.3, sub=0), "Blink." + sd, lashm)
            add(box((0.01, 0.006, 0.004), (hc.x + x + sg * 0.018 * es, y - 0.004, hc.z + ez + 0.009 * es), (0, math.radians(sg * 30), 0), r=0.3, sub=0), "Blink." + sd, lashm)
        bt, ang = p["brow"]; bz = ez + 0.026 + 0.004 * es; bt *= p["bush"]
        # sourcil : un bloc incliné ; fournis (bush > 1.3) : deuxième mèche en désordre
        for k_ in range(2 if p["bush"] > 1.3 else 1):
            add(box((0.036, 0.011 + 0.004 * p["bush"], bt * (1.0 if k_ == 0 else 0.7)), (hc.x + x + sg * 0.004 * k_, surf(x, bz) - 0.004, hc.z + bz + 0.004 * k_), (0, math.radians(sg * -(ang + 7 * k_)), 0), r=0.3, sub=0), "Brow." + sd, brm)
    nl, nw = p["nose"]; nz = -0.012; ny = surf(0, nz)
    add(cyl(nw, 0.002, nl, (hc.x, ny - nl / 2 + 0.006, hc.z + nz), (math.radians(90), 0, 0), 4), "Head", sk)
    for sg in (-1, 1): add(sph(1.0, (hc.x + sg * nw * 0.9, ny - 0.002, hc.z + nz - 0.012), (nw * 0.55, 0.008, 0.007), 6), "Head", sk)
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
    # ---- barbe
    bc = M(name + "_beard", p["bc"], 0.0, 0.7); bc2 = M(name + "_beard2", tuple(min(1.0, c * 1.25 + 0.03) for c in p["bc"]), 0.0, 0.5); b = p["beard"]
    if b in ("full", "big", "stubble"):
        mat = bc if b != "stubble" else M(name + "_stubble", tuple(c * 0.78 for c in p["skin"]), 0.0, 0.9)
        k = {"full": 1.1, "big": 1.14, "stubble": 1.03}[b]
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
        for pl in sm.polygons: pl.use_smooth = False
        add(bo, "Head", mat)
        if b in ("full", "big"):
            # mèches de barbe : pointes qui s'étirent sous le menton, favoris, moustache intégrée
            n_ = 5 if b == "big" else 3
            for i_ in range(n_):
                phi = -0.7 + 1.4 * i_ / (n_ - 1); mid = i_ == n_ // 2
                ln = (0.075 if b == "big" else 0.055) * (1.0 if mid else 0.62)
                pt = hc + Vector((math.sin(phi) * w * 0.9, -math.cos(phi) * d * 0.9, -h * 0.88))
                lock(pt, (math.sin(phi) * 0.25, -0.3, -1), ln, 0.03 if mid else 0.024, bc if i_ % 2 == 0 else bc2, "Jaw", 5)
            for sg in (-1, 1):
                lock(hc + Vector((sg * w * 1.02, -d * 0.1, -0.005)), (sg * 0.1, -0.1, -1), 0.06, 0.013, bc, "Head", 4)   # favoris
            if b == "big":
                for sg in (-1, 1):   # tresses de barbe
                    pts = [hc + Vector((sg * 0.03, -d * 0.85, -h * 1.0)), hc + Vector((sg * 0.034, -d * 0.86, -h * 1.0 - 0.05)), hc + Vector((sg * 0.03, -d * 0.84, -h * 1.0 - 0.1))]
                    add(tube(pts, 0.011, 5), "Jaw", bc2); add(sph(0.014, pts[-1] + Vector((0, 0, -0.012)), (1, 1, 1.3), 6), "Jaw", M("tie", (0.75, 0.55, 0.15), 0.6, 0.4))
                add(sph(1.0, (hc.x, hc.y - 0.075, hc.z - 0.135), (0.075, 0.048, 0.08), 9), "Jaw", bc)
    if b == "mustache":
        my2 = surf(0, -0.038)
        add(box((0.05, 0.014, 0.016), (hc.x, my2 - 0.005, hc.z - 0.04), r=0.3, sub=0), "Head", bc)
        for sg in (-1, 1):
            lock((hc.x + sg * 0.02, my2 - 0.004, hc.z - 0.046), (sg * 1.0, -0.15, -0.35), 0.042, 0.012, bc2 if sg > 0 else bc, "Head", 4)
            lock((hc.x + sg * 0.058, my2 - 0.001, hc.z - 0.052), (sg * 0.5, -0.1, 0.9), 0.022, 0.008, bc, "Head", 4)   # pointe relevée
        add(box((0.012, 0.01, 0.014), (hc.x, my2 - 0.002, hc.z - 0.076), r=0.3, sub=0), "Jaw", bc)   # mouche
    # ---- coiffure
    hs = p["hs"]
    if hs != "bald":
        hb = bmesh.new(); bmesh.ops.create_uvsphere(hb, u_segments=16, v_segments=10, radius=1.0)
        kk = 1.34 if hs == "afro" else 1.08
        for v in hb.verts: v.co = Vector((v.co.x * w * kk, v.co.y * d * kk, v.co.z * h * kk)) + hc + (Vector((0, 0.012, 0.01)) if hs == "afro" else Vector())
        fr = {"short": 0.42, "spiky": 0.45, "long": 0.4, "bangs": 0.3, "bob": 0.45, "ponytail": 0.45, "bun": 0.42, "sidepart": 0.4, "receding": 0.72, "braid": 0.42, "afro": 0.2}[hs]
        bk = {"short": -0.05, "spiky": 0.0, "long": -0.5, "bangs": -0.5, "bob": -0.4, "ponytail": -0.1, "bun": -0.1, "sidepart": -0.05, "receding": 0.1, "braid": -0.1, "afro": -0.6}[hs]
        kill = []
        for f in hb.faces:
            c = (f.calc_center_median() - hc); zl = c.z / (h * kk); yl = c.y / (d * kk)
            lim = fr if yl < 0.0 else bk
            if zl < lim: kill.append(f)
            elif yl < -0.55 and zl < fr + 0.15 and hs not in ("bangs", "afro"): kill.append(f)
        bmesh.ops.delete(hb, geom=kill, context="FACES")
        hm = bpy.data.meshes.new("hh"); hb.to_mesh(hm); hb.free()
        ho = bpy.data.objects.new("hh", hm); bpy.context.collection.objects.link(ho)
        for pl in hm.polygons: pl.use_smooth = False
        add(ho, "Head", hair)
        def vary(i, base): return base * (0.8 + 0.4 * abs(math.sin(i * 2.17 + 0.6)))
        def fringe(n, zl, ln, spread=1.15, dirx=0.0, mat=None):
            for i in range(n):
                phi = -spread + 2 * spread * i / (n - 1)
                lock(cap_pt(phi, zl), (math.sin(phi) * 0.3 + dirx, -math.cos(phi) * 0.3, -0.9), vary(i, ln), 0.014, (mat or (hair if i % 2 else hair2)), "Head", 4)
        def sideburns(zl=0.0, ln=0.05):
            for sg in (-1, 1): lock(cap_pt(sg * 1.35, zl), (sg * 0.2, -0.1, -1), ln, 0.016, hair, "Head", 4)
        if hs == "short":
            fringe(9, 0.42, 0.04); sideburns(0.15, 0.04)
        elif hs == "spiky":
            fringe(7, 0.45, 0.028); sideburns(0.1, 0.035)
            for k_, (dx, dy, hh) in enumerate(((-0.06, -0.03, 0.05), (-0.03, 0.0, 0.065), (0.0, -0.045, 0.06), (0.03, 0.0, 0.065), (0.06, -0.03, 0.05), (0.0, 0.04, 0.055), (-0.045, 0.045, 0.045), (0.05, 0.04, 0.048), (-0.015, -0.06, 0.05), (0.02, 0.07, 0.04))):
                lock((hc.x + dx, hc.y + dy, hc.z + h * 0.95), (dx * 6, dy * 6 - 0.1, 1.0), hh, 0.024, hair if k_ % 2 else hair2, "Head", 4)
        elif hs in ("long", "bangs"):
            add(box((w * 2.15, 0.03, 0.2), (hc.x, hc.y + d * 0.92, hc.z - 0.07), r=0.3, sub=0), "HairB", hair)
            for sg in (-1, 1): add(box((0.028, 0.14, 0.17), (hc.x + sg * w * 1.0, hc.y + 0.03, hc.z - 0.05), r=0.3, sub=0), "Head", hair)
            for i in range(8): lock((hc.x - w * 0.95 + i * w * 1.9 / 7, hc.y + d * 0.93, hc.z - 0.165), (0.05 * math.sin(i), 0.15, -1), vary(i, 0.045), 0.016, hair if i % 2 else hair2, "HairB", 4)
            for sg in (-1, 1):
                for i in range(2): lock((hc.x + sg * w * (1.0 + 0.0 * i), hc.y + 0.02 + 0.05 * i, hc.z - 0.125), (sg * 0.2, 0.0, -1), vary(i + 3, 0.04), 0.013, hair2, "Head", 4)
            if hs == "bangs": fringe(11, 0.3, 0.034, 1.0, 0.0)
            else:
                fringe(5, 0.4, 0.034, 0.9); add(box((0.008, 0.06, 0.004), (hc.x + 0.012, hc.y - d * 0.7, hc.z + h * 0.99), r=0.3, sub=0), "Head", M(name + "_part", tuple(c * 0.5 + 0.12 for c in p["skin"]), 0.0, 0.8))
        elif hs == "bob":
            add(box((w * 2.1, 0.03, 0.12), (hc.x, hc.y + d * 0.9, hc.z - 0.03), r=0.3, sub=0), "HairB", hair)
            for sg in (-1, 1):
                add(box((0.03, 0.13, 0.12), (hc.x + sg * w * 1.04, hc.y + 0.02, hc.z - 0.02), r=0.3, sub=0), "Head", hair)
                lock((hc.x + sg * w * 1.05, hc.y - 0.03, hc.z - 0.07), (-sg * 0.5, -0.3, -1), 0.03, 0.02, hair2, "Head", 4)
            for i in range(8): lock((hc.x - w * 0.9 + i * w * 1.8 / 7, hc.y + d * 0.92, hc.z - 0.09), (0, 0.4, -1), vary(i, 0.03), 0.017, hair if i % 2 else hair2, "HairB", 4)
            fringe(9, 0.36, 0.036, 1.05)
        elif hs == "ponytail":
            fringe(7, 0.42, 0.03); sideburns(0.1, 0.03)
            tube_pts = [Vector((hc.x, hc.y + d * 0.95, hc.z + 0.05)), Vector((hc.x, hc.y + d * 1.3, hc.z + 0.02)), Vector((hc.x, hc.y + d * 1.45, hc.z - 0.05)), Vector((hc.x, hc.y + d * 1.5, hc.z - 0.12))]
            add(tube(tube_pts, 0.02, 5), "HairB", hair)
            add(sph(0.019, tube_pts[1], (1.3, 1.3, 1.0), 6), "HairB", M("tie", (0.9, 0.3, 0.3), 0.3, 0.4))
            lock(tube_pts[-1] + Vector((0, 0, 0.02)), (0, 0.15, -1), 0.06, 0.026, hair2, "HairB", 5)
        elif hs == "braid":
            fringe(7, 0.4, 0.03); sideburns(0.1, 0.03)
            for i in range(6): add(sph(0.02 - i * 0.0015, (hc.x + (0.009 if i % 2 else -0.009), hc.y + d * (1.0 + 0.05 * i), hc.z + 0.01 - i * 0.034), (1, 1, 1.25), 6), "HairB", hair if i % 2 else hair2)
            lock((hc.x, hc.y + d * 1.28, hc.z - 0.2), (0, 0.1, -1), 0.04, 0.014, hair, "HairB", 4)
            add(sph(0.014, (hc.x, hc.y + d * 1.25, hc.z - 0.19), (1, 1, 1), 6), "HairB", M("tie2", (0.85, 0.7, 0.2), 0.4, 0.4))
        elif hs == "bun":
            fringe(7, 0.42, 0.03, 1.0); sideburns(0.1, 0.03)
            add(sph(0.046, (hc.x, hc.y + d * 0.5, hc.z + h * 1.06), (1, 1, 0.9), 8), "HairB", hair)
            add(tube([Vector((hc.x + math.cos(a) * 0.05, hc.y + d * 0.5 + math.sin(a) * 0.05, hc.z + h * 1.05)) for a in [2 * math.pi * k / 8 for k in range(8)]], 0.007, 4, True), "HairB", M("tie3", (0.9, 0.8, 0.3), 0.4, 0.4))
        elif hs == "sidepart":
            for i in range(7): lock(cap_pt(-0.2 - 0.18 * i, 0.5 - 0.02 * i), (0.6 + 0.1 * i, -0.8, -0.5), vary(i, 0.045), 0.015, hair if i % 2 else hair2, "Head", 4)
            sideburns(0.1, 0.035)
            add(box((w * 1.0, 0.035, 0.03), (hc.x + 0.03, surf(0.03, 0.082) - 0.004, hc.z + 0.088), (math.radians(-12), math.radians(-14), 0), r=0.3, sub=0), "Head", hair2)
        elif hs == "receding":
            sideburns(0.05, 0.05)
            for sg in (-1, 1):
                for i in range(3): lock(cap_pt(sg * (1.2 + 0.18 * i), 0.38 - 0.1 * i), (sg * 0.6, -0.2, -0.5), vary(i, 0.035), 0.015, hair, "Head", 4)
            for i in range(5): lock((hc.x + (i - 2) * 0.022, hc.y - d * 0.55, hc.z + h * 0.8), (0, -0.5, 0.7), vary(i, 0.03), 0.012, hair2, "Head", 4)
        elif hs == "afro":
            for dx, dz in ((-0.05, 0.1), (0.05, 0.1), (0.0, 0.14), (-0.09, 0.03), (0.09, 0.03), (-0.07, 0.07), (0.07, 0.07), (0.0, 0.09)):
                add(sph(0.045, (hc.x + dx, hc.y + 0.02, hc.z + dz), (1, 1, 1), 8), "Head", hair if (dx > 0) else hair2)
            for i in range(8): lock(cap_pt(-1.1 + 2.2 * i / 7, 0.3, 1.15), (math.sin(-1.1 + 2.2 * i / 7) * 0.6, -0.7, 0.2), vary(i, 0.03), 0.02, hair2, "Head", 4)
