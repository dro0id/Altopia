"""Astronautes low poly facettés (bpy), d'après les références du projet : combinaison segmentée, casque à visière claire
laissant voir le visage, sac de survie à tuyaux, panneau de commandes, genouillères, ceinture et manchettes colorées.
make(nom, pose, s) -> empty racine (face vers +Y, pieds à z=0, ~1 m de haut avant mise à l'échelle).
Noms : captain, rex, bolt, lyra, vance, nox.  Poses : idle, point, work, walk, salute, think, cheer.
Tout est en polygones plats (flat shading) : peu de segments, biseaux courts."""
import bpy, bmesh, math
from mathutils import Vector
from lib import mat as lmat

def M(name, col, metal=0.0, rough=0.65): return lmat(name, col, metal, rough)
def E(name, col, k=3.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*col, 1); e.inputs[1].default_value = k
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    return m
def glass(name="glass", tint=(0.8, 0.95, 1.0), a=0.07):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*tint, 1); b.inputs["Roughness"].default_value = 0.05; b.inputs["Alpha"].default_value = a
    b.inputs["Specular IOR Level"].default_value = 0.8
    return m

def _fin(ob, m, parent, flat=True, bevel=0.0):
    ob.data.materials.clear(); ob.data.materials.append(m)
    for p in ob.data.polygons: p.use_smooth = not flat
    if bevel > 0:
        md = ob.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2; md.limit_method = "ANGLE"
    if parent is not None: ob.parent = parent
    return ob

def bx(name, size, loc, m, parent, rot=(0, 0, 0), bevel=0.008):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name; ob.scale = size
    return _fin(ob, m, parent, True, bevel)

def cy(name, r1, r2, h, loc, m, parent, rot=(0, 0, 0), seg=8, scale=(1, 1, 1), bevel=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return _fin(ob, m, parent, True, bevel)

def sp(name, r, loc, m, parent, scale=(1, 1, 1), seg=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=rings, location=loc)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return _fin(ob, m, parent, True)

def ico(name, r, loc, m, parent, scale=(1, 1, 1), sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=sub, location=loc)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return _fin(ob, m, parent, True)

def tr(name, R, r, loc, m, parent, rot=(0, 0, 0), seg=14):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=5, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name
    return _fin(ob, m, parent, True)

def pv(name, loc, parent):
    e = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(e)
    e.location = loc; e.parent = parent
    return e

def hoop(name, pts, r, m, parent):
    """Tuyau : suite de segments cylindriques entre points (coordonnées du parent)."""
    for a, b in zip(pts, pts[1:]):
        a, b = Vector(a), Vector(b); d = b - a
        c = cy(name, r, r, d.length, a + d / 2, m, parent, seg=6)
        c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()

# --- distribution : suit = combinaison, trim = liserés/manchettes/ceinture, vis = bandeau de visière, boot = bottes/gants
def _sp(suit, trim, vis, boot, skin, hair, bulk=1.0, h=1.0, hair_style="short", beard="none", hat="none", extras=(), helm=None, glasses=False):
    return dict(suit=suit, trim=trim, vis=vis, boot=boot, skin=skin, hair=hair, bulk=bulk, h=h, hair_style=hair_style, beard=beard, hat=hat, extras=list(extras), helm=helm, glasses=glasses)
SPECS = {
 "captain": _sp((0.92, 0.93, 0.95), (0.85, 0.12, 0.14), (0.85, 0.15, 0.15), (0.92, 0.93, 0.95), (0.82, 0.6, 0.47), (0.12, 0.07, 0.05), 1.0, 1.0, "short", "full", "none", ["antenna"]),
 "rex":     _sp((0.95, 0.42, 0.08), (1.0, 0.95, 0.9), (1.0, 0.8, 0.2), (0.15, 0.15, 0.18), (0.9, 0.7, 0.55), (0.35, 0.18, 0.08), 0.92, 0.98, "spiky", "none", "none", ["wings"]),
 "nova":    _sp((0.78, 0.14, 0.22), (1.0, 0.95, 0.95), (1.0, 0.55, 0.7), (0.92, 0.92, 0.95), (0.8, 0.58, 0.45), (0.06, 0.05, 0.08), 0.86, 1.0, "bob", "none", "headband", ["wings", "scarf"]),
 "zara":    _sp((0.1, 0.1, 0.14), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.22, 0.2, 0.15), (0.45, 0.3, 0.22), (0.88, 0.9, 0.95), 0.9, 1.08, "long", "none", "none", ["wings", "epaulet", "pauldrons"]),
 "bolt":    _sp((0.78, 0.18, 0.15), (1.0, 0.85, 0.2), (1.0, 0.7, 0.2), (0.18, 0.15, 0.13), (0.55, 0.37, 0.27), (0.1, 0.06, 0.04), 1.22, 0.9, "bald_top", "full", "lamp", ["pouches", "tool"]),
 "tess":    _sp((0.95, 0.75, 0.12), (0.12, 0.12, 0.15), (1.0, 0.55, 0.1), (0.2, 0.17, 0.13), (0.9, 0.7, 0.58), (0.3, 0.17, 0.08), 0.95, 0.96, "pony", "none", "goggles", ["pouches", "tool"]),
 "gorn":    _sp((0.22, 0.24, 0.28), (1.0, 0.45, 0.1), (1.0, 0.45, 0.1), (0.12, 0.12, 0.14), (0.7, 0.5, 0.4), (0.5, 0.2, 0.1), 1.5, 0.92, "none", "full", "lamp", ["pauldrons", "glowcore", "pouches"]),
 "lumi":    _sp((0.85, 0.93, 0.95), (0.2, 0.8, 0.8), (0.3, 0.9, 0.9), (0.9, 0.93, 0.95), (0.95, 0.8, 0.7), (0.35, 0.6, 0.95), 0.84, 1.02, "short", "none", "none", ["tablet"]),
 "quark":   _sp((0.3, 0.28, 0.66), (0.75, 0.6, 1.0), (0.75, 0.6, 1.0), (0.2, 0.2, 0.3), (0.82, 0.62, 0.5), (0.7, 0.7, 0.75), 1.0, 1.04, "bald_top", "stache", "none", ["scanner"], None, True),
 "elara":   _sp((0.95, 0.95, 0.97), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.95, 0.85, 0.5), (0.95, 0.82, 0.74), (0.6, 0.25, 0.85), 0.84, 1.1, "long", "none", "halo", ["orb", "epaulet"]),
 "vance":   _sp((0.08, 0.14, 0.38), (0.95, 0.78, 0.25), (0.9, 0.2, 0.2), (0.12, 0.13, 0.18), (0.82, 0.62, 0.5), (0.92, 0.92, 0.95), 1.1, 1.08, "short", "stache", "none", ["epaulet", "medals"], "suit"),
 "nox":     _sp((0.7, 0.74, 0.8), (0.75, 0.45, 1.0), (0.75, 0.45, 1.0), (0.25, 0.27, 0.32), (0.6, 0.64, 0.7), (0, 0, 0), 1.0, 1.0, "none", "none", "none", []),
}
POSES = {
 "idle":   dict(aL=(0.05, 0, 0.12), aR=(0.05, 0, -0.12), lL=(0, 0, 0.02), lR=(0, 0, -0.02), head=0.0, lean=0.0),
 "point":  dict(aL=(0.05, 0, 0.12), aR=(1.35, 0, -0.3), lL=(0, 0, 0.04), lR=(0, 0, -0.04), head=-0.2, lean=0.04),
 "work":   dict(aL=(1.0, 0, 0.18), aR=(1.1, 0, -0.18), lL=(0, 0, 0.04), lR=(0, 0, -0.04), head=0.0, lean=0.12),
 "walk":   dict(aL=(0.6, 0, 0.1), aR=(-0.6, 0, -0.1), lL=(-0.5, 0, 0), lR=(0.5, 0, 0), head=0.0, lean=0.04),
 "salute": dict(aL=(0.05, 0, 0.12), aR=(2.5, 0, -0.45), lL=(0, 0, 0.03), lR=(0, 0, -0.03), head=0.0, lean=0.0),
 "think":  dict(aL=(0.9, 0, 0.1), aR=(2.3, 0, -0.1), lL=(0, 0, 0.04), lR=(0.15, 0, -0.04), head=0.25, lean=0.02),
 "cheer":  dict(aL=(2.8, 0, 0.5), aR=(2.8, 0, -0.5), lL=(0, 0, 0.1), lR=(0, 0, -0.1), head=0.0, lean=-0.05),
}
PIV = {}   # racine.name -> pivots (pour l'animation)


def zloft(name, rings, m, parent, n=10, loc=(0, 0, 0), k=1.0):
    """Tube effilé le long de Z : rings = [(z, rx, ry, cx, cy)], section à n côtés, flat shading."""
    bm = bmesh.new(); rows = []
    for (z, rx, ry, cx, cy_) in rings:
        row = []
        for i in range(n):
            a = 2 * math.pi * (i + 0.5) / n
            row.append(bm.verts.new((cx + math.cos(a) * rx * k, cy_ + math.sin(a) * ry * k, z)))
        rows.append(row)
    for r in range(len(rows) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((rows[r][i], rows[r][j], rows[r + 1][j], rows[r + 1][i]))
    bm.faces.new(rows[0][::-1]); bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob); ob.location = loc
    return _fin(ob, m, parent, True)

def stripe(name, p0, p1, w, d, m, parent):
    """Liseré : boîte fine allant du point p0 au point p1 (coordonnées du parent)."""
    a, b = Vector(p0), Vector(p1); v = b - a
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=a + v / 2)
    ob = bpy.context.active_object; ob.name = name; ob.scale = (w, d, v.length)
    ob.rotation_euler = v.to_track_quat("Z", "Y").to_euler()
    return _fin(ob, m, parent, True)

def make(name, pose="idle", s=1.0, suit_override=None, godot=False):
    sp_ = dict(SPECS[name])
    if suit_override: sp_.update(suit_override)
    po = POSES[pose]; bk = sp_["bulk"]; H = sp_["h"]; ex = sp_["extras"]
    root = bpy.data.objects.new("char_" + name, None); bpy.context.collection.objects.link(root)
    pivs = {}
    suit = M("suit_steel" if godot else name + "_suit", sp_["suit"], 0.0, 0.8)
    if godot:
        trim = M("accent_cyan", sp_["trim"], 0.1, 0.5)
        b_ = trim.node_tree.nodes["Principled BSDF"]; b_.inputs["Emission Color"].default_value = (*sp_["trim"], 1); b_.inputs["Emission Strength"].default_value = 0.35
    else:
        trim = M(name + "_trim", sp_["trim"], 0.0, 0.55)
    gray = M("gray", (0.55, 0.57, 0.6), 0.2, 0.6); dark = M("dark", (0.07, 0.09, 0.16), 0.2, 0.6)
    boot = M(name + "_boot", sp_["boot"], 0.0, 0.7); skin = M(name + "_skin", sp_["skin"], 0.0, 0.75)
    hair = M(name + "_hair", sp_["hair"], 0.0, 0.8); black = M("black", (0.02, 0.02, 0.03), 0.0, 0.5)
    white = M("white", (0.95, 0.95, 0.97), 0.0, 0.55); vis = E(name + "_vis", sp_["vis"], 1.2)
    gold = M("gold", (1.0, 0.8, 0.2), 0.6, 0.35); brown = M("kneepad", (0.42, 0.33, 0.26), 0.0, 0.8)
    hipz = 0.49; W = bk
    # ---------- jambes (pivot à la hanche)
    for sx, key in ((-1, "lL"), (1, "lR")):
        lp = pv("leg", (sx * 0.058 * W, 0, hipz), root); lp.rotation_euler = po[key]; pivs[key] = lp
        zloft("thigh", [(0.0, 0.056 * W, 0.058 * W, 0, 0), (-0.1, 0.05 * W, 0.052 * W, 0, 0), (-0.21, 0.04 * W, 0.042 * W, 0, 0.002)], suit, lp, 12, k=1.18)
        bx("kneepad", (0.064 * W, 0.036, 0.078), (0, 0.046 * W, -0.235), brown, lp, bevel=0.016)
        bx("kneeband", (0.07 * W, 0.04, 0.012), (0, 0.04 * W, -0.2), dark, lp, bevel=0.004)
        zloft("shin", [(-0.225, 0.04 * W, 0.042 * W, 0, 0.002), (-0.3, 0.036 * W, 0.04 * W, 0, 0), (-0.395, 0.033 * W, 0.036 * W, 0, -0.004)], suit, lp, 12, k=1.18)
        stripe("legline", (sx * 0.052 * W, 0.0, -0.01), (sx * 0.04 * W, 0.0, -0.4), 0.009, 0.009, trim, lp)
        stripe("legline2", (sx * 0.052 * W, 0.012, -0.01), (sx * 0.04 * W, 0.012, -0.4), 0.007, 0.007, dark, lp)
        cy("ankle", 0.04 * W, 0.04 * W, 0.022, (0, -0.002, -0.42), dark, lp, seg=10)
        cy("ankleline", 0.042 * W, 0.042 * W, 0.008, (0, -0.002, -0.405), trim, lp, seg=10)
        bx("boot", (0.072 * W, 0.155, 0.066), (0, 0.032, -0.46), boot, lp, bevel=0.03)
        bx("toe", (0.062 * W, 0.05, 0.05), (0, 0.095, -0.465), boot, lp, bevel=0.018)
        bx("bootline", (0.072 * W, 0.12, 0.01), (0, 0.025, -0.445), trim, lp, bevel=0.003)
        bx("sole", (0.074 * W, 0.16, 0.014), (0, 0.04, -0.495), E("sole", (0.3, 0.8, 1.0), 2.0) if name in ("captain", "vance", "nox") else dark, lp, bevel=0.003)
    # ---------- torse
    tp = pv("torso", (0, 0, hipz), root); tp.rotation_euler = (po["lean"], 0, 0); pivs["torso"] = tp
    zloft("pelvis", [(-0.02, 0.092 * W, 0.064, 0, 0), (0.03, 0.098 * W, 0.066, 0, 0), (0.06, 0.09 * W, 0.062, 0, 0)], suit, tp, 10)
    zloft("chest", [(0.05, 0.09 * W, 0.062, 0, 0), (0.12, 0.108 * W, 0.07, 0, 0.003), (0.21, 0.126 * W, 0.076, 0, 0.004), (0.27, 0.134 * W, 0.074, 0, 0.002), (0.295, 0.1 * W, 0.062, 0, 0)], suit, tp, 10)
    zloft("beltband", [(0.045, 0.098 * W, 0.066, 0, 0), (0.075, 0.1 * W, 0.068, 0, 0)], trim, tp, 10)
    bx("buckle", (0.05, 0.014, 0.034), (0, 0.068, 0.06), gray, tp, bevel=0.005)
    bx("zip", (0.012, 0.01, 0.2), (0, 0.075, 0.2), trim, tp, bevel=0.003)
    bx("panel", (0.1, 0.016, 0.075), (0, 0.078, 0.185), gray, tp, bevel=0.008)
    bx("screen", (0.07, 0.01, 0.022), (0, 0.088, 0.208), E("scr", (0.85, 0.95, 0.35) if name != "nox" else sp_["vis"], 1.3), tp, bevel=0.003)
    for k, c in enumerate(((1, 0.3, 0.2), (0.95, 0.95, 0.95), (0.3, 0.6, 1))):
        bx("btn", (0.016, 0.01, 0.014), (-0.025 + k * 0.025, 0.088, 0.17), E("btn", c, 2.5), tp, bevel=0.002)
    sp("dial", 0.014, (0.04, 0.09, 0.178), M("dial", (0.9, 0.9, 0.95), 0.2, 0.5), tp, (1, 0.4, 1), 8, 5)
    for k, c in enumerate(((0.2, 0.7, 0.3), (1, 1, 1), (1.0, 0.5, 0.1))):
        bx("flag", (0.022, 0.008, 0.014), (-0.06 * W + k * 0.025, 0.074, 0.26), M("flag", c, 0, 0.6), tp, bevel=0.002)
    # sac de survie + tuyaux
    bx("pack", (0.2 * W, 0.1, 0.25), (0, -0.088, 0.17), white if name != "nox" else gray, tp, bevel=0.03)
    bx("pack_panel" if godot else "packtrim", (0.17 * W, 0.01, 0.035), (0, -0.14, 0.24), trim, tp, bevel=0.004)
    bx("packlight", (0.05, 0.01, 0.025), (0, -0.142, 0.14), E("pl", (1.0, 0.3, 0.3), 3.0), tp, bevel=0.003)
    for sx in (-1, 1):
        hoop("hose", [(sx * 0.07 * W, -0.1, 0.285), (sx * 0.15 * W, -0.06, 0.34), (sx * 0.11 * W, 0.0, 0.325), (sx * 0.075, 0.04, 0.31)], 0.012, black, tp)
    if "antenna" in ex:
        cy("antenna", 0.007, 0.007, 0.16, (0.08 * W, -0.12, 0.35), gray, tp, seg=6)
        sp("antenna_tip", 0.018, (0.08 * W, -0.12, 0.44), E("atip", (1.0, 0.3, 0.8), 5.0), tp, (1, 1, 1), 6, 4)
    # ---------- bras
    arms = {}
    for sx, key in ((-1, "aL"), (1, "aR")):
        ap = pv("arm", (sx * (0.15 * W + 0.012), 0, 0.745), root if False else tp); ap.location = (sx * (0.15 * W + 0.012), 0, 0.255); ap.rotation_euler = po[key]; arms[key] = ap; pivs[key] = ap
        bx("pad", (0.082 * W, 0.082, 0.055), (sx * 0.012, 0, 0.022), suit, ap, bevel=0.028)
        bx("padline", (0.078 * W, 0.078, 0.008), (sx * 0.012, 0, 0.012), trim, ap, bevel=0.003)
        zloft("upper", [(0.0, 0.036 * W, 0.036 * W, 0, 0), (-0.09, 0.034 * W, 0.034 * W, 0, 0), (-0.18, 0.03 * W, 0.03 * W, 0, 0)], suit, ap, 12, k=1.18)
        zloft("fore", [(-0.19, 0.03 * W, 0.03 * W, 0, 0), (-0.27, 0.031 * W, 0.031 * W, 0, 0.002), (-0.335, 0.027 * W, 0.027 * W, 0, 0)], suit, ap, 12, k=1.18)
        cy("elbow", 0.034 * W, 0.034 * W, 0.016, (0, -0.0, -0.185), dark, ap, seg=10)
        stripe("armline", (sx * 0.037 * W, 0, 0.0), (sx * 0.031 * W, 0, -0.33), 0.009, 0.009, trim, ap)
        stripe("armline2", (sx * 0.037 * W, 0.012, 0.0), (sx * 0.031 * W, 0.012, -0.33), 0.007, 0.007, dark, ap)
        cy("cuff", 0.036 * W, 0.036 * W, 0.034, (0, 0, -0.335), trim, ap, seg=10)
        cy("cuffring", 0.038 * W, 0.038 * W, 0.008, (0, 0, -0.352), dark, ap, seg=10)
        gl = white if name in ("captain", "lumi", "elara", "vance") else boot
        bx("glove", (0.052 * W, 0.058, 0.066), (0, 0.003, -0.395), gl, ap, bevel=0.024)
        bx("fingers", (0.048 * W, 0.04, 0.036), (0, 0.006, -0.44), gl, ap, bevel=0.012)
        bx("thumb", (0.018, 0.034, 0.03), (-sx * 0.03 * W, 0.03, -0.395), gl, ap, bevel=0.007)
        if "pauldrons" in ex:
            bx("pauldron", (0.1 * W, 0.1, 0.04), (sx * 0.015, 0, 0.045), trim if name == "gorn" else gold, ap, bevel=0.02)
    # ---------- tête + casque
    hp = pv("head", (0, 0, 0.8), root); hp.location = (0, 0, 0.31); hp.parent = tp; hp.rotation_euler = (0, 0, po["head"]); pivs["head"] = hp
    cy("neck", 0.042, 0.048, 0.04, (0, 0, 0.0), dark, hp, seg=10)
    tr("neckring", 0.066, 0.02, (0, 0, 0.018), dark, hp)
    tr("neckseal", 0.066, 0.008, (0, 0, 0.035), trim, hp)
    R = 0.134; hz = 0.124
    hs = sp_["hair_style"]; bd = sp_["beard"]; hat = sp_["hat"]
    if name == "nox":
        sp("head", R * 1.0, (0, 0, hz), M("noxhead", (0.8, 0.83, 0.88), 0.5, 0.4), hp, (1, 0.95, 1), 12, 8)
        bx("face", (0.15, 0.02, 0.07), (0, R * 0.92, hz + 0.004), black, hp, bevel=0.012)
        for sx in (-1, 1): sp("led", 0.016, (sx * 0.036, R * 0.97, hz + 0.004), vis, hp, (1, 0.4, 1), 6, 4)
        cy("ant", 0.007, 0.007, 0.09, (0.045, 0, hz + R), gray, hp, seg=6)
        sp("anttip", 0.018, (0.045, 0, hz + R + 0.055), E("tip", (1.0, 0.4, 0.8), 5.0), hp, (1, 1, 1), 6, 4)
        for sx in (-1, 1): cy("ear", 0.04, 0.04, 0.028, (sx * R * 1.0, 0, hz), trim, hp, rot=(0, math.radians(90), 0), seg=10)
    else:
        hr = R * 0.76
        ico("head", hr, (0, 0, hz - 0.004), skin, hp, (1.0, 0.96, 1.08), 2)
        fy = hr * 0.95
        for sx in (-1, 1):
            bx("ear", (0.012, 0.022, 0.035), (sx * hr * 0.98, -0.005, hz - 0.01), skin, hp, bevel=0.004)
            bx("eyew", (0.027, 0.008, 0.02), (sx * 0.033, fy - 0.004, hz + 0.012), white, hp, bevel=0.002)
            bx("eye", (0.016, 0.01, 0.018), (sx * 0.033, fy - 0.001, hz + 0.011), black, hp, bevel=0.002)
            bx("brow", (0.036, 0.012, 0.01), (sx * 0.034, fy - 0.001, hz + 0.036), hair if (hs != "none" or bd != "none") else black, hp, (0, 0, sx * -0.22), 0.002)
        bx("nosebridge", (0.014, 0.018, 0.04), (0, fy, hz - 0.005), skin, hp, bevel=0.005)
        cy("nose", 0.017, 0.006, 0.03, (0, fy + 0.016, hz - 0.022), skin, hp, rot=(math.radians(-90), 0, 0), seg=4)
        bx("mouth", (0.04, 0.008, 0.009), (0, fy - 0.002, hz - 0.052), M("lip", (0.5, 0.2, 0.18)), hp, bevel=0.002)
        if sp_["glasses"]:
            for sx in (-1, 1): tr("glass", 0.024, 0.0045, (sx * 0.033, fy + 0.006, hz + 0.012), black, hp, rot=(math.radians(90), 0, 0), seg=10)
            bx("bridge", (0.016, 0.006, 0.006), (0, fy + 0.006, hz + 0.016), black, hp, bevel=0.001)
        if hs in ("short", "spiky", "bob", "pony", "long"):
            sp("hair", hr * 1.04, (0, -0.012, hz + 0.014), hair, hp, (1.0, 1.0, 0.92), 10, 6)
        if hs == "spiky":
            for k in range(5):
                a = math.radians(-50 + k * 25)
                cy("spike", 0.026, 0.0, 0.065, (math.sin(a) * 0.055, -0.005, hz + 0.08), hair, hp, rot=(0, math.sin(a) * 0.6, 0), seg=4)
        if hs in ("bob", "pony", "long", "short"):
            bx("fringe", (0.1, 0.025, 0.03), (0.01, fy - 0.004, hz + 0.055), hair, hp, (0, 0, -0.18), 0.006)
        if hs == "bob":
            for sx in (-1, 1): bx("lock", (0.026, 0.06, 0.09), (sx * 0.074, -0.01, hz - 0.03), hair, hp, bevel=0.01)
        if hs == "pony": cy("pony", 0.03, 0.01, 0.17, (0, -hr * 0.85, hz - 0.04), hair, hp, rot=(math.radians(20), 0, 0), seg=6)
        if hs == "long":
            bx("mane", (0.17, 0.045, 0.28), (0, -0.075, hz - 0.1), hair, hp, bevel=0.012)
            for sx in (-1, 1): bx("lock", (0.026, 0.05, 0.14), (sx * 0.076, -0.02, hz - 0.05), hair, hp, bevel=0.01)
        if hs == "bald_top":
            for sx in (-1, 1): bx("sidehair", (0.026, 0.07, 0.05), (sx * 0.074, -0.02, hz - 0.01), hair, hp, bevel=0.008)
        if bd == "full":
            bx("beard", (0.1, 0.05, 0.06), (0, fy - 0.014, hz - 0.055), hair, hp, bevel=0.012)
            bx("beardchin", (0.07, 0.04, 0.04), (0, fy - 0.012, hz - 0.085), hair, hp, bevel=0.012)
            bx("stache", (0.07, 0.022, 0.018), (0, fy + 0.004, hz - 0.03), hair, hp, bevel=0.004)
            for sx in (-1, 1): bx("burn", (0.02, 0.05, 0.065), (sx * 0.066, fy - 0.03, hz - 0.025), hair, hp, bevel=0.005)
        elif bd == "stache":
            bx("stache", (0.07, 0.022, 0.018), (0, fy + 0.004, hz - 0.03), hair, hp, bevel=0.004)
        # casque : coque blanche ouverte devant, grand verre teinté
        hcol = sp_["suit"] if sp_["helm"] == "suit" else (0.94, 0.95, 0.97)
        shell = M(name + "_helm", hcol, 0.0, 0.5)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.2, segments=20, ring_count=12, location=(0, 0, hz))
        hsph = bpy.context.active_object; hsph.name = "helmet"
        bm = bmesh.new(); bm.from_mesh(hsph.data); bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.calc_center_median().y > R * 0.5 and abs(f.calc_center_median().x) < R * 0.95 and -R * 0.8 < f.calc_center_median().z < R * 0.7]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(hsph.data); bm.free()
        md = hsph.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.014
        _fin(hsph, shell, hp, True)
        sp("visorglass", R * 1.19, (0, 0.003, hz), glass("visor", (0.7, 0.85, 1.0), 0.06), hp, (1, 1, 1), 20, 12)
        tr("rim", R * 0.98, 0.014, (0, R * 0.52, hz - 0.002), trim, hp, rot=(math.radians(90), 0, 0), seg=14)
        bx("visortrim", (R * 1.2, 0.012, 0.014), (0, R * 1.03, hz + R * 0.66), M("vt", sp_["vis"], 0.0, 0.4), hp, (-0.38, 0, 0), 0.003)
        for sx in (-1, 1):
            cy("earpod", 0.046, 0.046, 0.036, (sx * R * 1.2, 0, hz), trim, hp, rot=(0, math.radians(90), 0), seg=10)
            cy("earcap", 0.03, 0.03, 0.018, (sx * R * 1.32, 0, hz), gray, hp, rot=(0, math.radians(90), 0), seg=10)
        bx("ridge", (0.026, R * 1.7, 0.014), (0, -0.01, hz + R * 1.18), trim, hp, bevel=0.003)
        bx("backlight", (0.05, 0.012, 0.03), (0, -R * 1.2, hz + 0.01), E("bl", (1.0, 0.3, 0.3), 2.5), hp, bevel=0.003)
        if hat == "lamp":
            sp("lamp", 0.024, (0, R * 1.0, hz + R * 1.05), E("lamp", (1.0, 0.95, 0.7), 8.0), hp, (1, 1.3, 1), 6, 4)
        elif hat == "goggles":
            tr("gband", R * 1.18, 0.011, (0, 0, hz + R * 0.58), black, hp)
            for sx in (-1, 1):
                tr("goggle", 0.036, 0.011, (sx * 0.046, R * 1.08, hz + R * 0.6), black, hp, rot=(math.radians(80), 0, 0), seg=10)
                sp("lens", 0.03, (sx * 0.046, R * 1.07, hz + R * 0.6), E("lens", (1.0, 0.7, 0.2), 1.5), hp, (1, 0.2, 1), 8, 5)
        elif hat == "headband":
            tr("hband", R * 1.2, 0.013, (0, 0, hz + R * 0.55), M("hb", (1.0, 0.95, 0.95), 0.0, 0.5), hp)
        elif hat == "halo":
            tr("halo", 0.1, 0.007, (0, 0, hz + R * 1.55), E("halo", (1.0, 0.85, 0.35), 6.0), hp)
    # ---------- accessoires
    if "epaulet" in ex:
        for sx in (-1, 1): bx("epaulet", (0.06, 0.06, 0.012), (sx * 0.145 * W, 0, 0.3), gold, tp, (0, 0, sx * -0.25), 0.003)
    if "pouches" in ex:
        for k in range(3): bx("pouch", (0.046, 0.032, 0.05), (-0.085 + k * 0.085, 0.07, 0.04), M("pouch", (0.3, 0.22, 0.12), 0, 0.8), tp, bevel=0.008)
    if "tool" in ex:
        bx("tool", (0.022, 0.018, 0.12), (0.14, 0.06, 0.02), M("steel", (0.65, 0.67, 0.7), 0.9, 0.3), tp, (0, 0, 0.5), 0.004)
    if "tablet" in ex:
        bx("tablet", (0.09, 0.01, 0.12), (0, 0.03, -0.4), E("tab", (0.3, 1.0, 0.7), 2.0), arms["aL"], bevel=0.004)
    if "scanner" in ex:
        bx("scanner", (0.045, 0.028, 0.11), (0, 0.035, -0.42), M("scan", (0.2, 0.22, 0.3), 0.6, 0.4), arms["aR"], bevel=0.006)
        sp("scanlight", 0.02, (0, 0.055, -0.47), E("scl", (0.6, 0.4, 1.0), 7.0), arms["aR"], (1, 1, 1), 6, 4)
    if "medals" in ex:
        for k in range(3): bx("medal", (0.018, 0.008, 0.018), (0.03 + k * 0.026, 0.078, 0.255), gold if k != 1 else trim, tp, bevel=0.003)
    if "wings" in ex:
        bx("wing", (0.08 * (1.3 if name == "zara" else 1), 0.01, 0.03), (0.06, 0.078, 0.12), gold if name == "zara" else trim, tp, bevel=0.003)
    if "scarf" in ex:
        tr("scarf", 0.075, 0.03, (0, 0, 0.3), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), tp, seg=10)
        bx("scarftail", (0.055, 0.018, 0.2), (0.06, 0.07, 0.2), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), tp, (0.1, 0, 0.2), 0.004)
    if "glowcore" in ex:
        sp("core", 0.04, (0, 0.08, 0.1), E("core", (1.0, 0.5, 0.15), 8.0), tp, (1, 0.6, 1), 8, 5)
    if "orb" in ex:
        sp("orb", 0.045, (-0.3 * W, 0.12, 0.12), E("orb", (0.8, 0.6, 1.0), 8.0), tp, (1, 1, 1), 8, 5)
    root.scale = (s * H, s * H, s * H)
    PIV[root.name] = pivs
    return root

def animate(root):
    """Clips Walk / Shoot / Idle (NLA) sur les pivots : bras, jambes, torse, tête. Renvoie la liste des pivots animés."""
    pv_ = PIV[root.name]
    bpy.context.scene.render.fps = 24
    def key(o, f, rx=None, loc=None):
        o.rotation_mode = "XYZ"
        if rx is not None:
            e = list(o.rotation_euler); e[0] = rx; o.rotation_euler = e; o.keyframe_insert("rotation_euler", frame=f)
        if loc is not None:
            o.location = loc; o.keyframe_insert("location", frame=f)
    base = {k: (v.rotation_euler[0], v.location.copy()) for k, v in pv_.items()}
    def clip(nm, fn):
        for k, o in pv_.items():
            if o.animation_data is None: o.animation_data_create()
            act = bpy.data.actions.new("%s_%s_%s" % (nm, root.name, k)); o.animation_data.action = act
            o.rotation_euler[0] = base[k][0]; o.location = base[k][1].copy()
            fn(k, o)
            o.animation_data.action = None
            fc = [fc for l in act.layers for st in l.strips for cb in st.channelbags for fc in cb.fcurves]
            if not fc:
                bpy.data.actions.remove(act); continue
            tr_ = o.animation_data.nla_tracks.new(); tr_.name = nm; tr_.strips.new(nm, 1, act)
            o.rotation_euler[0] = base[k][0]; o.location = base[k][1].copy()
    def walk(k, o):
        a = 0.7; b0 = base[k][0]; L = {"aL": a, "aR": -a, "lL": -a, "lR": a}
        if k in L: key(o, 1, rx=b0 + L[k]); key(o, 13, rx=b0 - L[k]); key(o, 25, rx=b0 + L[k])
        if k == "torso":
            b = base[k][1]
            for f, dz in ((1, 0), (7, 0.012), (13, 0), (19, 0.012), (25, 0)): key(o, f, loc=(b.x, b.y, b.z + dz))
    def idle(k, o):
        if k == "torso":
            b = base[k][1]
            for f, dz in ((1, 0), (30, 0.008), (60, 0)): key(o, f, loc=(b.x, b.y, b.z + dz))
        if k == "head":
            b0 = base[k][0]
            for f, d in ((1, 0), (30, 0.04), (60, 0)): key(o, f, rx=b0 + d)
    def shoot(k, o):
        b0 = base[k][0]
        if k == "aR": key(o, 1, rx=b0); key(o, 6, rx=1.55); key(o, 10, rx=1.45); key(o, 16, rx=b0)
        if k == "aL": key(o, 1, rx=b0); key(o, 6, rx=1.35); key(o, 10, rx=1.3); key(o, 16, rx=b0)
        if k == "torso":
            b = base[k][1]; key(o, 1, loc=tuple(b)); key(o, 7, loc=(b.x, b.y + 0.015, b.z)); key(o, 16, loc=tuple(b))
    for nm, fn in (("Walk", walk), ("Idle", idle), ("Shoot", shoot)): clip(nm, fn)

def all_children(root):
    out = [root]
    for o in bpy.data.objects:
        p = o.parent
        while p is not None:
            if p == root: out.append(o); break
            p = p.parent
    return out
