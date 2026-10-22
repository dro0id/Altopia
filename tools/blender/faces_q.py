"""Visages humains low poly paramétriques : un visage unique par personnage (forme de tête, yeux, sourcils, nez, bouche, oreilles, coiffure, barbe, lunettes, taches, cicatrice).
human_head(name, hc, add, T) construit la tête en pièces rigides (os Head) autour du centre hc, face vers -Y. T = outils de characters_q (M, E, prim_box, prim_sph, prim_cyl, tube)."""
import bpy, bmesh, math
from mathutils import Vector
from mathutils.bvhtree import BVHTree

def F(skin, hair, hs="short", beard=None, bc=None, w=0.1, d=0.108, h=0.122, jaw=0.9, chin=0.0, eye=(0.28, 0.2, 0.12), eyes=1.0, eyex=0.045, brow=(0.012, 8.0), brow_col=None,
      nose=(0.03, 0.014), mouth=(0.045, 0.5), lip=(0.55, 0.25, 0.25), ear=1.0, glasses=None, freckles=False, scar=False, tilt=0.0):
    return dict(skin=skin, hair=hair, hs=hs, beard=beard, bc=bc or hair, w=w, d=d, h=h, jaw=jaw, chin=chin, eye=eye, eyes=eyes, eyex=eyex, brow=brow, brow_col=brow_col or tuple(c * 0.6 for c in hair),
                nose=nose, mouth=mouth, lip=lip, ear=ear, glasses=glasses, freckles=freckles, scar=scar, tilt=tilt)

FACES = {
 "captain": F((0.78, 0.58, 0.45), (0.28, 0.17, 0.1), "long", "full", w=0.104, jaw=1.0, eye=(0.2, 0.3, 0.4), brow=(0.016, -10.0), nose=(0.036, 0.017), mouth=(0.05, -0.2)),
 "rex":     F((0.86, 0.66, 0.5), (0.08, 0.07, 0.07), "spiky", "stubble", w=0.1, jaw=1.05, eye=(0.15, 0.1, 0.06), brow=(0.015, 4.0), mouth=(0.058, 1.0), nose=(0.032, 0.015)),
 "nova":    F((0.95, 0.8, 0.7), (0.07, 0.06, 0.1), "bangs", None, w=0.092, jaw=0.78, eyes=1.25, eyex=0.042, eye=(0.2, 0.1, 0.12), brow=(0.008, 12.0), nose=(0.022, 0.01), mouth=(0.038, 0.4), lip=(0.8, 0.3, 0.4)),
 "zara":    F((0.4, 0.26, 0.2), (0.88, 0.9, 0.95), "long", None, w=0.095, jaw=0.82, eyes=1.1, eye=(0.9, 0.7, 0.2), brow=(0.008, 16.0), nose=(0.028, 0.012), mouth=(0.042, 0.1), lip=(0.35, 0.12, 0.12), tilt=0.0),
 "bolt":    F((0.8, 0.55, 0.42), (0.32, 0.2, 0.1), "receding", "mustache", w=0.108, d=0.112, jaw=1.1, eyes=0.9, eye=(0.35, 0.25, 0.15), brow=(0.02, -6.0), nose=(0.04, 0.022), mouth=(0.05, -0.3)),
 "tess":    F((0.72, 0.52, 0.4), (0.22, 0.12, 0.07), "ponytail", None, w=0.098, jaw=0.88, eyes=1.1, eye=(0.2, 0.35, 0.2), brow=(0.01, 6.0), mouth=(0.055, 1.0), freckles=True, nose=(0.024, 0.011)),
 "gorn":    F((0.86, 0.62, 0.52), (0.7, 0.3, 0.1), "bald", "big", w=0.112, d=0.114, h=0.124, jaw=1.15, eyes=0.85, eye=(0.2, 0.25, 0.2), brow=(0.022, -14.0), nose=(0.042, 0.022), mouth=(0.05, -0.4), scar=True),
 "lumi":    F((0.92, 0.77, 0.67), (0.88, 0.7, 0.3), "bob", None, w=0.098, jaw=0.85, eyes=1.3, eyex=0.046, eye=(0.2, 0.5, 0.6), brow=(0.008, 8.0), nose=(0.02, 0.01), mouth=(0.05, 1.0), lip=(0.85, 0.4, 0.45)),
 "quark":   F((0.88, 0.7, 0.58), (0.3, 0.2, 0.14), "sidepart", None, w=0.096, d=0.108, jaw=0.92, eyes=0.95, eye=(0.2, 0.15, 0.1), brow=(0.012, 2.0), nose=(0.04, 0.014), mouth=(0.036, -0.1), glasses="round"),
 "elara":   F((0.96, 0.84, 0.76), (0.65, 0.14, 0.1), "bun", None, w=0.09, jaw=0.8, eyes=1.15, eyex=0.041, eye=(0.35, 0.6, 0.3), brow=(0.007, 14.0), nose=(0.022, 0.01), mouth=(0.04, 0.35), lip=(0.7, 0.2, 0.25)),
 "vance":   F((0.82, 0.65, 0.55), (0.92, 0.92, 0.94), "sidepart", "mustache", w=0.1, jaw=0.95, eyes=0.9, eye=(0.45, 0.5, 0.55), brow=(0.018, -12.0), nose=(0.036, 0.016), mouth=(0.044, -0.5)),
 "sira":    F((0.7, 0.5, 0.4), (0.65, 0.25, 0.1), "braid", None, w=0.096, jaw=1.0, eyes=1.0, eye=(0.15, 0.4, 0.3), brow=(0.009, 10.0), nose=(0.03, 0.012), mouth=(0.05, 0.8), freckles=True, chin=0.006),
 "maya":    F((0.36, 0.22, 0.16), (0.05, 0.04, 0.05), "afro", None, w=0.1, jaw=0.9, eyes=1.15, eye=(0.12, 0.07, 0.05), brow=(0.01, 10.0), nose=(0.03, 0.016), mouth=(0.06, 1.0), lip=(0.45, 0.15, 0.15)),
 "ilan":    F((0.5, 0.33, 0.24), (0.1, 0.1, 0.12), "short", "stubble", w=0.098, jaw=0.95, eyes=1.0, eye=(0.12, 0.08, 0.06), brow=(0.012, 3.0), nose=(0.032, 0.014), mouth=(0.042, 0.4), glasses="square"),
}

def human_head(name, hc, add, T):
    p = FACES[name]; M, E, box, sph, cyl, tube = T["M"], T["E"], T["box"], T["sph"], T["cyl"], T["tube"]
    sk = M(name + "_skin", p["skin"], 0.0, 0.7); hair = M(name + "_hair", p["hair"], 0.0, 0.6)
    w, d, h = p["w"], p["d"], p["h"]
    # tête : sphère facettée, mâchoire resserrée et menton avancé
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
    # oreilles
    for sg in (-1, 1): add(sph(1.0, (hc.x + sg * w * 0.97, hc.y + 0.006, hc.z - 0.004), (0.012 * p["ear"], 0.016 * p["ear"], 0.028 * p["ear"]), 8), "Head", sk)
    # yeux
    wh = M(name + "_sclera", (0.95, 0.95, 0.97), 0.0, 0.3); ir = M(name + "_iris", p["eye"], 0.0, 0.3); pu = M("pupil", (0.02, 0.02, 0.03), 0.0, 0.2)
    ez = 0.016; es = p["eyes"]
    for sg in (-1, 1):
        x = sg * p["eyex"]; y = surf(x, ez)
        add(sph(1.0, (hc.x + x, y - 0.003, hc.z + ez), (0.017 * es, 0.007, 0.012 * es), 8), "Head", wh)
        add(sph(1.0, (hc.x + x, y - 0.0085, hc.z + ez), (0.0095 * es, 0.004, 0.0095 * es), 8), "Head", ir)
        add(sph(1.0, (hc.x + x, y - 0.011, hc.z + ez), (0.0045 * es, 0.0025, 0.0045 * es), 6), "Head", pu)
        # sourcils
        bt, ang = p["brow"]; bz = ez + 0.026 + 0.004 * es
        add(box((0.032, 0.01, bt), (hc.x + x, surf(x, bz) - 0.004, hc.z + bz), (0, math.radians(sg * -ang), 0), r=0.3, sub=0), "Head", M(name + "_brow", p["brow_col"], 0.0, 0.7))
    # nez
    nl, nw = p["nose"]; nz = -0.012; ny = surf(0, nz)
    add(cyl(nw, 0.002, nl, (hc.x, ny - nl / 2 + 0.006, hc.z + nz), (math.radians(90), 0, 0), 4), "Head", sk)
    # bouche
    mw, cv = p["mouth"]; mz = -0.058; my = surf(0, mz) - (0.012 if p["beard"] in ("full", "big") else 0.003)
    lipm = M(name + "_lip", p["lip"], 0.0, 0.5)
    add(box((mw, 0.008, 0.008), (hc.x, my, hc.z + mz), r=0.3, sub=0), "Head", lipm)
    for sg in (-1, 1): add(box((mw * 0.32, 0.008, 0.007), (hc.x + sg * mw * 0.46, my, hc.z + mz + cv * 0.006), (0, math.radians(sg * cv * 28), 0), r=0.3, sub=0), "Head", lipm)
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
    # taches de rousseur, cicatrice
    if p["freckles"]:
        fm = M("freck", tuple(c * 0.7 for c in p["skin"]), 0.0, 0.8)
        for sg in (-1, 1):
            for dx, dz in ((0.035, -0.012), (0.05, -0.02), (0.028, -0.026), (0.058, -0.008)):
                x = sg * dx; add(sph(0.004, (hc.x + x, surf(x, dz) - 0.001, hc.z + dz), (1, 0.5, 1), 5), "Head", fm)
    if p["scar"]:
        x = -0.05; add(box((0.007, 0.006, 0.07), (hc.x + x, surf(x, 0.0) - 0.003, hc.z + 0.0), (0, math.radians(25), 0), r=0.3, sub=0), "Head", M("scar", (0.62, 0.25, 0.25), 0.0, 0.7))
    # barbe
    bc = M(name + "_beard", p["bc"], 0.0, 0.7); b = p["beard"]
    if b in ("full", "big", "stubble"):
        mat = bc if b != "stubble" else M(name + "_stubble", tuple(c * 0.78 for c in p["skin"]), 0.0, 0.9)
        k = {"full": 1.1, "big": 1.14, "stubble": 1.03}[b]
        sb = bmesh.new(); bmesh.ops.create_uvsphere(sb, u_segments=14, v_segments=9, radius=1.0)
        for v in sb.verts:
            x, y, z = v.co; t = max(0.0, (-z - 0.15) / 0.85)
            x *= 1 - (1 - p["jaw"]) * t * 1.2; y -= p["chin"] * 6 * t * max(0.0, -y)
            v.co = Vector((x * w * k, y * d * k, z * h * k)) + hc
        keep = [f for f in sb.faces if (f.calc_center_median() - hc).z < -0.012 * 1.0 - 0.02 and (f.calc_center_median() - hc).y < 0.025]
        if b == "stubble": keep = [f for f in keep if (f.calc_center_median() - hc).z < -0.04]
        rest = [f for f in sb.faces if f not in keep]; bmesh.ops.delete(sb, geom=rest, context="FACES")
        # ouverture de la bouche : retire les faces juste autour de la bouche
        if b != "stubble":
            for f in list(sb.faces):
                c = f.calc_center_median() - hc
                if abs(c.x) < 0.03 and -0.07 < c.z < -0.045 and c.y < -0.03: sb.faces.remove(f) if f.is_valid else None
        sm = bpy.data.meshes.new("bd"); sb.to_mesh(sm); sb.free()
        bo = bpy.data.objects.new("bd", sm); bpy.context.collection.objects.link(bo)
        for pl in sm.polygons: pl.use_smooth = False
        add(bo, "Head", mat)
        if b == "big": add(sph(1.0, (hc.x, hc.y - 0.075, hc.z - 0.14), (0.07, 0.045, 0.075), 8), "Head", bc)
    if b == "mustache":
        my2 = surf(0, -0.038)
        add(box((0.062, 0.014, 0.017), (hc.x, my2 - 0.005, hc.z - 0.04), r=0.3, sub=0), "Head", bc)
        for sg in (-1, 1): add(box((0.024, 0.012, 0.012), (hc.x + sg * 0.034, my2 - 0.002, hc.z - 0.05), (0, math.radians(sg * 25), 0), r=0.3, sub=0), "Head", bc)
    # coiffure
    hs = p["hs"]
    if hs != "bald":
        hb = bmesh.new(); bmesh.ops.create_uvsphere(hb, u_segments=14, v_segments=9, radius=1.0)
        kk = 1.34 if hs == "afro" else 1.08
        for v in hb.verts: v.co = Vector((v.co.x * w * kk, v.co.y * d * kk, v.co.z * h * kk)) + hc + (Vector((0, 0.012, 0.01)) if hs == "afro" else Vector())
        fr = {"short": 0.42, "spiky": 0.45, "long": 0.4, "bangs": 0.3, "bob": 0.45, "ponytail": 0.45, "bun": 0.42, "sidepart": 0.4, "receding": 0.72, "braid": 0.42, "afro": 0.2}[hs]
        bk = {"short": -0.05, "spiky": 0.0, "long": -0.5, "bangs": -0.5, "bob": -0.4, "ponytail": -0.1, "bun": -0.1, "sidepart": -0.05, "receding": 0.1, "braid": -0.1, "afro": -0.6}[hs]
        kill = []
        for f in hb.faces:
            c = (f.calc_center_median() - hc); zl = c.z / (h * kk); yl = c.y / (d * kk)
            lim = fr if yl < 0.0 else bk
            if zl < lim + (0.0 if yl > 0.0 else 0.0): kill.append(f)
            elif yl < -0.55 and zl < fr + 0.15 and hs not in ("bangs", "afro"): kill.append(f)
        bmesh.ops.delete(hb, geom=kill, context="FACES")
        hm = bpy.data.meshes.new("hh"); hb.to_mesh(hm); hb.free()
        ho = bpy.data.objects.new("hh", hm); bpy.context.collection.objects.link(ho)
        for pl in hm.polygons: pl.use_smooth = False
        add(ho, "Head", hair)
        if hs == "spiky":
            for k_, (dx, dy, hh) in enumerate(((-0.06, -0.03, 0.05), (-0.03, 0.0, 0.065), (0.0, -0.045, 0.06), (0.03, 0.0, 0.065), (0.06, -0.03, 0.05), (0.0, 0.04, 0.055), (-0.045, 0.045, 0.045))):
                add(cyl(0.022, 0.0, hh, (hc.x + dx, hc.y + dy, hc.z + h * 0.98 + hh * 0.35), seg=4), "Head", hair)
        if hs in ("long", "bangs"):
            add(box((w * 2.15, 0.03, 0.2), (hc.x, hc.y + d * 0.92, hc.z - 0.07), r=0.3, sub=0), "Head", hair)
            for sg in (-1, 1): add(box((0.028, 0.14, 0.17), (hc.x + sg * w * 1.0, hc.y + 0.03, hc.z - 0.05), r=0.3, sub=0), "Head", hair)
        if hs == "bangs":
            add(box((w * 1.9, 0.03, 0.038), (hc.x, surf(0, 0.075) - 0.003, hc.z + 0.073), r=0.3, sub=0), "Head", hair)
        if hs == "bob":
            add(box((w * 2.1, 0.03, 0.12), (hc.x, hc.y + d * 0.9, hc.z - 0.03), r=0.3, sub=0), "Head", hair)
            for sg in (-1, 1): add(box((0.03, 0.13, 0.12), (hc.x + sg * w * 1.04, hc.y + 0.02, hc.z - 0.02), r=0.3, sub=0), "Head", hair)
            add(box((w * 1.8, 0.03, 0.03), (hc.x, surf(0, 0.07) - 0.002, hc.z + 0.07), (math.radians(-10), 0, 0), r=0.3, sub=0), "Head", hair)
        if hs == "ponytail":
            add(tube([Vector((hc.x, hc.y + d * 0.95, hc.z + 0.03)), Vector((hc.x, hc.y + d * 1.35, hc.z + 0.0)), Vector((hc.x, hc.y + d * 1.4, hc.z - 0.06))], 0.017, 5), "Head", hair)
            add(sph(0.024, (hc.x, hc.y + d * 1.42, hc.z - 0.075), (1, 1, 1.5), 7), "Head", hair)
        if hs == "braid":
            for k_ in range(4): add(sph(0.02 - k_ * 0.002, (hc.x + (0.008 if k_ % 2 else -0.008), hc.y + d * 1.0, hc.z - 0.02 - k_ * 0.04), (1, 1, 1.2), 6), "Head", hair)
        if hs == "bun":
            add(sph(0.045, (hc.x, hc.y + d * 0.55, hc.z + h * 1.05), (1, 1, 0.9), 8), "Head", hair)
        if hs == "sidepart":
            add(box((w * 1.0, 0.035, 0.03), (hc.x + 0.03, surf(0.03, 0.082) - 0.004, hc.z + 0.088), (math.radians(-12), math.radians(-14), 0), r=0.3, sub=0), "Head", hair)
        if hs == "afro":
            for dx, dz in ((-0.05, 0.1), (0.05, 0.1), (0.0, 0.14), (-0.09, 0.03), (0.09, 0.03)):
                add(sph(0.045, (hc.x + dx, hc.y + 0.02, hc.z + dz), (1, 1, 1), 8), "Head", hair)
