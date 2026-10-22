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
        md = ob.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 1; md.limit_method = "ANGLE"
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
 "captain": _sp((0.86, 0.88, 0.9), (1.0, 0.55, 0.08), (0.1, 0.8, 0.8), (0.82, 0.84, 0.86), (0.72, 0.5, 0.38), (0.15, 0.09, 0.06), 1.0, 1.0, "short", "none", "none", ["epaulet", "antenna"]),
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

def make(name, pose="idle", s=1.0, suit_override=None, godot=False):
    sp_ = dict(SPECS[name])
    if suit_override: sp_.update(suit_override)
    po = POSES[pose]; bk = sp_["bulk"]; H = sp_["h"]; ex = sp_["extras"]
    root = bpy.data.objects.new("char_" + name, None); bpy.context.collection.objects.link(root)
    pivs = {}
    suit = M("suit_steel" if godot else name + "_suit", sp_["suit"], 0.05, 0.7)
    if godot:
        trim = M("accent_cyan", sp_["trim"], 0.1, 0.5)
        b_ = trim.node_tree.nodes["Principled BSDF"]; b_.inputs["Emission Color"].default_value = (*sp_["trim"], 1); b_.inputs["Emission Strength"].default_value = 0.35
    else:
        trim = M(name + "_trim", sp_["trim"], 0.1, 0.5)
    gray = M("gray", (0.45, 0.47, 0.5), 0.3, 0.6); dark = M("dark", (0.1, 0.11, 0.13), 0.3, 0.6)
    boot = M(name + "_boot", sp_["boot"], 0.05, 0.7); skin = M(name + "_skin", sp_["skin"], 0.0, 0.75)
    hair = M(name + "_hair", sp_["hair"], 0.0, 0.8); black = M("black", (0.02, 0.02, 0.03), 0.0, 0.5)
    white = M("white", (0.95, 0.95, 0.97), 0.0, 0.5); vis = E(name + "_vis", sp_["vis"], 1.2)
    gold = M("gold", (1.0, 0.8, 0.2), 0.6, 0.35)
    hip_z = 0.5
    # ---------- jambes
    for sx, key in ((-1, "lL"), (1, "lR")):
        lp = pv("leg", (sx * 0.07 * bk, 0, hip_z), root); lp.rotation_euler = po[key]; pivs[key] = lp
        cy("thigh", 0.082 * bk, 0.068 * bk, 0.24, (0, 0, -0.12), suit, lp, seg=8)
        bx("kneepad", (0.075 * bk, 0.04, 0.085), (0, 0.06 * bk, -0.255), gray, lp, bevel=0.012)
        cy("shin", 0.068 * bk, 0.058 * bk, 0.22, (0, 0, -0.35), suit, lp, seg=8)
        cy("anklering", 0.07 * bk, 0.07 * bk, 0.03, (0, 0, -0.44), trim, lp, seg=8)
        bx("boot", (0.105 * bk, 0.19, 0.085), (0, 0.04, -0.478), boot, lp, bevel=0.03)
        bx("sole", (0.11 * bk, 0.2, 0.02), (0, 0.04, -0.505), dark, lp, bevel=0.006)
    # ---------- torse
    tp = pv("torso", (0, 0, hip_z), root); tp.rotation_euler = (po["lean"], 0, 0); pivs["torso"] = tp
    bx("pelvis", (0.26 * bk, 0.18, 0.1), (0, 0, 0.03), suit, tp, bevel=0.03)
    bx("belt", (0.27 * bk, 0.19, 0.04), (0, 0, 0.1), trim, tp, bevel=0.01)
    bx("buckle", (0.06, 0.02, 0.045), (0, 0.1, 0.1), gray, tp, bevel=0.006)
    cy("chest", 0.14 * bk, 0.18 * bk, 0.24, (0, 0, 0.23), suit, tp, seg=8, scale=(1, 0.74, 1))
    bx("shoulders", (0.35 * bk, 0.16, 0.075), (0, 0, 0.35), suit, tp, bevel=0.03)
    bx("zip", (0.018, 0.012, 0.26), (0, 0.133, 0.22), trim, tp, bevel=0.004)
    bx("panel", (0.1, 0.02, 0.085), (-0.07 * bk, 0.134, 0.2), gray, tp, bevel=0.008)
    bx("screen", (0.07, 0.01, 0.025), (-0.07 * bk, 0.146, 0.22), E("scr", (0.85, 0.95, 0.4) if name != "nox" else sp_["vis"], 1.5), tp, bevel=0.003)
    for k, c in enumerate(((1, 0.3, 0.2), (0.3, 1, 0.5), (0.3, 0.6, 1))):
        bx("btn", (0.014, 0.01, 0.014), (-0.1 * bk + k * 0.03, 0.146, 0.185), E("btn", c, 3.0), tp, bevel=0.002)
    for k, c in enumerate(((0.2, 0.7, 0.3), (1, 1, 1), (1.0, 0.5, 0.1))):
        bx("flag", (0.022, 0.01, 0.014), (0.06 * bk + k * 0.026, 0.135, 0.31), M("flag", c, 0, 0.6), tp, bevel=0.002)
    bx("pack", (0.24 * bk, 0.12, 0.3), (0, -0.14, 0.24), white if name != "nox" else gray, tp, bevel=0.02)
    bx("pack_panel" if godot else "packtrim", (0.2 * bk, 0.01, 0.04), (0, -0.205, 0.3), trim, tp, bevel=0.004)
    for sx in (-1, 1):
        cy("tank", 0.035, 0.035, 0.28, (sx * 0.085 * bk, -0.215, 0.22), gray, tp, seg=8)
    hoop("hose", [(-0.1, -0.18, 0.38), (-0.2, -0.17, 0.5), (-0.17, -0.06, 0.6)], 0.012, dark, tp)
    hoop("hose", [(0.1, -0.18, 0.38), (0.2, -0.17, 0.5), (0.17, -0.06, 0.6)], 0.012, dark, tp)
    if "antenna" in ex:
        cy("antenna", 0.008, 0.008, 0.16, (0.09 * bk, -0.19, 0.52), gray, tp, seg=6)
        sp("antenna_tip", 0.02, (0.09 * bk, -0.19, 0.61), E("atip", (1.0, 0.3, 0.8), 5.0), tp, (1, 1, 1), 6, 4)
    # ---------- bras
    arms = {}
    for sx, key in ((-1, "aL"), (1, "aR")):
        ap = pv("arm", (sx * (0.185 * bk + 0.015), 0, 0.33), tp); ap.rotation_euler = po[key]; arms[key] = ap; pivs[key] = ap
        bx("pad", (0.11 * bk, 0.115, 0.08), (sx * 0.01, 0, 0.015), suit, ap, bevel=0.03)
        cy("upper", 0.066 * bk, 0.058 * bk, 0.17, (0, 0, -0.1), suit, ap, seg=8)
        cy("elbow", 0.06 * bk, 0.06 * bk, 0.03, (0, 0, -0.195), gray, ap, seg=8)
        cy("fore", 0.058 * bk, 0.052 * bk, 0.17, (0, 0, -0.29), suit, ap, seg=8)
        cy("cuff", 0.06 * bk, 0.06 * bk, 0.06, (0, 0, -0.35), trim, ap, seg=8)
        gl = trim if name == "captain" else boot
        bx("glove", (0.08 * bk, 0.085, 0.095), (0, 0.005, -0.43), gl, ap, bevel=0.028)
        bx("thumb", (0.025, 0.04, 0.04), (-sx * 0.04 * bk, 0.03, -0.415), gl, ap, bevel=0.008)
        if "pauldrons" in ex:
            bx("pauldron", (0.14 * bk, 0.14, 0.05), (sx * 0.02, 0, 0.065), trim if name == "gorn" else gold, ap, bevel=0.025)
    # ---------- tête + casque
    hp = pv("head", (0, 0, 0.39), tp); hp.rotation_euler = (0, 0, po["head"]); pivs["head"] = hp
    cy("neck", 0.065, 0.075, 0.06, (0, 0, 0.0), gray, hp, seg=8)
    tr("neckring", 0.09, 0.016, (0, 0, 0.035), dark, hp)
    R = 0.138; hz = 0.17
    hs = sp_["hair_style"]; bd = sp_["beard"]; hat = sp_["hat"]
    if name == "nox":
        sp("head", R * 1.02, (0, 0, hz), M("noxhead", (0.8, 0.83, 0.88), 0.7, 0.35), hp, (1, 0.95, 1), 10, 7)
        bx("face", (0.17, 0.02, 0.085), (0, R * 0.94, hz + 0.005), black, hp, bevel=0.015)
        for sx in (-1, 1): sp("led", 0.017, (sx * 0.04, R * 0.99, hz + 0.005), vis, hp, (1, 0.4, 1), 6, 4)
        cy("ant", 0.008, 0.008, 0.1, (0.05, 0, hz + R), gray, hp, seg=6)
        sp("anttip", 0.02, (0.05, 0, hz + R + 0.06), E("tip", (1.0, 0.4, 0.8), 5.0), hp, (1, 1, 1), 6, 4)
        for sx in (-1, 1): cy("ear", 0.045, 0.045, 0.03, (sx * R * 1.02, 0, hz), trim, hp, rot=(0, math.radians(90), 0), seg=8)
    else:
        ico("head", R * 0.86, (0, 0, hz), skin, hp, (1.0, 0.95, 1.05), 1)
        fy = R * 0.86 * 0.93
        for sx in (-1, 1):
            bx("eye", (0.022, 0.012, 0.026), (sx * 0.042, fy, hz + 0.014), black, hp, bevel=0.002)
            bx("eyew", (0.032, 0.008, 0.03), (sx * 0.042, fy - 0.003, hz + 0.014), white, hp, bevel=0.002)
            bx("brow", (0.038, 0.012, 0.011), (sx * 0.042, fy, hz + 0.045), hair if hs != "none" or bd != "none" else black, hp, (0, 0, sx * -0.2), 0.002)
        cy("nose", 0.016, 0.004, 0.03, (0, fy + 0.012, hz - 0.01), skin, hp, rot=(math.radians(-90), 0, 0), seg=4)
        bx("mouth", (0.04, 0.008, 0.01), (0, fy - 0.002, hz - 0.045), M("lip", (0.5, 0.2, 0.18)), hp, bevel=0.002)
        if sp_["glasses"]:
            for sx in (-1, 1): tr("glass", 0.026, 0.005, (sx * 0.042, fy + 0.008, hz + 0.014), black, hp, rot=(math.radians(90), 0, 0), seg=10)
            bx("bridge", (0.02, 0.006, 0.006), (0, fy + 0.008, hz + 0.02), black, hp, bevel=0.001)
        # cheveux
        if hs in ("short", "spiky", "bob", "pony", "long"):
            sp("hair", R * 0.88, (0, -0.012, hz + 0.018), hair, hp, (1.0, 1.0, 0.92), 8, 5)
        if hs == "spiky":
            for k in range(5):
                a = math.radians(-50 + k * 25)
                cy("spike", 0.03, 0.0, 0.07, (math.sin(a) * 0.065, -0.005, hz + 0.095), hair, hp, rot=(0, math.sin(a) * 0.6, 0), seg=4)
        if hs in ("bob", "pony", "long", "short"):
            bx("fringe", (0.12, 0.03, 0.035), (0.01, fy - 0.005, hz + 0.068), hair, hp, (0, 0, -0.18), 0.006)
        if hs == "bob":
            for sx in (-1, 1): bx("lock", (0.03, 0.07, 0.1), (sx * 0.085, -0.01, hz - 0.03), hair, hp, bevel=0.01)
        if hs == "pony":
            cy("pony", 0.035, 0.012, 0.19, (0, -R * 0.78, hz - 0.045), hair, hp, rot=(math.radians(20), 0, 0), seg=6)
        if hs == "long":
            bx("mane", (0.2, 0.05, 0.32), (0, -0.09, hz - 0.12), hair, hp, bevel=0.012)
            for sx in (-1, 1): bx("lock", (0.03, 0.06, 0.16), (sx * 0.088, -0.02, hz - 0.06), hair, hp, bevel=0.01)
        if hs == "bald_top":
            for sx in (-1, 1): bx("sidehair", (0.03, 0.08, 0.06), (sx * 0.085, -0.02, hz - 0.01), hair, hp, bevel=0.008)
        if bd == "full":
            bx("beard", (0.12, 0.05, 0.065), (0, fy - 0.012, hz - 0.062), hair, hp, bevel=0.012)
            bx("stache", (0.075, 0.02, 0.018), (0, fy + 0.003, hz - 0.028), hair, hp, bevel=0.004)
            for sx in (-1, 1): bx("burn", (0.02, 0.05, 0.07), (sx * 0.075, fy - 0.03, hz - 0.03), hair, hp, bevel=0.005)
        elif bd == "stache":
            bx("stache", (0.075, 0.02, 0.018), (0, fy + 0.003, hz - 0.028), hair, hp, bevel=0.004)
        # casque ouvert devant + verre
        hcol = sp_["suit"] if sp_["helm"] == "suit" else (0.9, 0.91, 0.93)
        shell = M(name + "_helm", hcol, 0.2, 0.45)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.2, segments=12, ring_count=8, location=(0, 0, hz))
        hsph = bpy.context.active_object; hsph.name = "helmet"
        bm = bmesh.new(); bm.from_mesh(hsph.data); bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.calc_center_median().y > R * 0.55 and abs(f.calc_center_median().x) < R * 0.9 and -R * 0.75 < f.calc_center_median().z < R * 0.6]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(hsph.data); bm.free()
        md = hsph.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.012
        _fin(hsph, shell, hp, True)
        sp("visorglass", R * 1.19, (0, 0.004, hz), glass(), hp, (1, 1, 1), 12, 8)
        tr("rim", R * 0.95, 0.012, (0, R * 0.55, hz - 0.002), trim, hp, rot=(math.radians(90), 0, 0), seg=12)
        bx("visortrim", (R * 1.5, 0.016, 0.022), (0, R * 1.04, hz + R * 0.62), M("vt", sp_["vis"], 0.1, 0.4), hp, (-0.35, 0, 0), 0.004)
        for sx in (-1, 1):
            cy("earpod", 0.052, 0.052, 0.04, (sx * R * 1.2, 0, hz), trim, hp, rot=(0, math.radians(90), 0), seg=8)
            cy("earcap", 0.036, 0.036, 0.02, (sx * R * 1.33, 0, hz), gray, hp, rot=(0, math.radians(90), 0), seg=8)
        bx("ridge", (0.03, R * 1.8, 0.02), (0, 0, hz + R * 1.2), trim, hp, bevel=0.004)
        if hat == "lamp":
            sp("lamp", 0.025, (0, R * 1.0, hz + R * 1.05), E("lamp", (1.0, 0.95, 0.7), 8.0), hp, (1, 1.3, 1), 6, 4)
        elif hat == "goggles":
            tr("gband", R * 1.18, 0.012, (0, 0, hz + R * 0.58), black, hp)
            for sx in (-1, 1):
                tr("goggle", 0.04, 0.012, (sx * 0.05, R * 1.08, hz + R * 0.6), black, hp, rot=(math.radians(80), 0, 0), seg=10)
                sp("lens", 0.034, (sx * 0.05, R * 1.07, hz + R * 0.6), E("lens", (1.0, 0.7, 0.2), 1.5), hp, (1, 0.2, 1), 8, 5)
        elif hat == "headband":
            tr("hband", R * 1.2, 0.014, (0, 0, hz + R * 0.55), M("hb", (1.0, 0.95, 0.95), 0.1, 0.5), hp)
        elif hat == "halo":
            tr("halo", 0.11, 0.008, (0, 0, hz + R * 1.55), E("halo", (1.0, 0.85, 0.35), 6.0), hp)
    # ---------- accessoires
    if "epaulet" in ex:
        for sx in (-1, 1): bx("epaulet", (0.075, 0.07, 0.015), (sx * 0.185, 0, 0.395), gold, tp, (0, 0, sx * -0.25), 0.003)
    if "pouches" in ex:
        for k in range(3): bx("pouch", (0.05, 0.035, 0.055), (-0.1 + k * 0.1, 0.1, 0.07), M("pouch", (0.3, 0.22, 0.12), 0, 0.8), tp, bevel=0.008)
    if "tool" in ex:
        bx("tool", (0.025, 0.02, 0.13), (0.17, 0.09, 0.04), M("steel", (0.65, 0.67, 0.7), 0.9, 0.3), tp, (0, 0, 0.5), 0.004)
    if "tablet" in ex:
        bx("tablet", (0.1, 0.012, 0.13), (0, 0.035, -0.43), E("tab", (0.3, 1.0, 0.7), 2.0), arms["aL"], bevel=0.004)
    if "scanner" in ex:
        bx("scanner", (0.05, 0.03, 0.12), (0, 0.04, -0.45), M("scan", (0.2, 0.22, 0.3), 0.6, 0.4), arms["aR"], bevel=0.006)
        sp("scanlight", 0.022, (0, 0.06, -0.5), E("scl", (0.6, 0.4, 1.0), 7.0), arms["aR"], (1, 1, 1), 6, 4)
    if "medals" in ex:
        for k in range(3): bx("medal", (0.02, 0.01, 0.02), (0.045 + k * 0.03, 0.135, 0.27), gold if k != 1 else trim, tp, bevel=0.003)
    if "wings" in ex:
        bx("wing", (0.09 * (1.3 if name == "zara" else 1), 0.012, 0.035), (0.075, 0.135, 0.13), gold if name == "zara" else trim, tp, bevel=0.003)
    if "scarf" in ex:
        tr("scarf", 0.1, 0.035, (0, 0, 0.36), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), tp, seg=10)
        bx("scarftail", (0.06, 0.02, 0.22), (0.07, 0.12, 0.22), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), tp, (0.1, 0, 0.2), 0.004)
    if "glowcore" in ex:
        sp("core", 0.045, (0, 0.14, 0.24), E("core", (1.0, 0.5, 0.15), 8.0), tp, (1, 0.6, 1), 8, 5)
    if "orb" in ex:
        sp("orb", 0.05, (-0.34 * bk, 0.14, 0.12), E("orb", (0.8, 0.6, 1.0), 8.0), tp, (1, 1, 1), 8, 5)
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
