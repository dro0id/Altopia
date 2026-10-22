"""Personnages du jeu modélisés de zéro (bpy) : chacun a sa silhouette, sa tenue, son visage.
make(nom, pose) -> empty racine (face vers +Y, pieds à z=0, ~1 m de haut avant mise à l'échelle).
Noms : captain, rex, bolt, lyra, vance, nox.  Poses : idle, point, work, walk, salute, think."""
import bpy, bmesh, math, random
from mathutils import Vector
from lib import mat as lmat

def M(name, col, metal=0.0, rough=0.55): return lmat(name, col, metal, rough)
def E(name, col, k=3.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*col, 1); e.inputs[1].default_value = k
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    return m

def _put(ob, m, parent=None, smooth=True):
    ob.data.materials.clear(); ob.data.materials.append(m)
    if smooth:
        for p in ob.data.polygons: p.use_smooth = True
    if parent is not None:
        ob.parent = parent
    return ob

def sph(name, r, loc, scale=(1, 1, 1), m=None, parent=None, seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=seg // 2, location=loc)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return _put(ob, m, parent)

def cy(name, r1, r2, h, loc, rot=(0, 0, 0), m=None, parent=None, seg=20, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name; ob.scale = scale
    return _put(ob, m, parent)

def bx(name, size, loc, rot=(0, 0, 0), m=None, parent=None, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name; ob.scale = size
    md = ob.modifiers.new("b", "BEVEL"); md.width = bevel; md.segments = 2
    return _put(ob, m, parent, smooth=False)

def tor(name, R, r, loc, rot=(0, 0, 0), m=None, parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=32, minor_segments=10, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = name
    return _put(ob, m, parent)

def pivot(name, loc, parent):
    e = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(e)
    e.location = loc; e.parent = parent
    return e

SPECS = {
 "captain": dict(suit=(0.30, 0.38, 0.52), accent=(0.1, 0.8, 1.0), skin=(0.78, 0.58, 0.45), bulk=1.0, h=1.0, head=1.0),
 "rex":     dict(suit=(0.95, 0.55, 0.12), accent=(0.1, 0.75, 0.95), skin=(0.92, 0.72, 0.58), bulk=0.9, h=0.98, head=1.0),
 "bolt":    dict(suit=(0.85, 0.42, 0.08), accent=(1.0, 0.8, 0.15), skin=(0.55, 0.37, 0.27), bulk=1.3, h=0.86, head=1.05),
 "lyra":    dict(suit=(0.12, 0.55, 0.55), accent=(0.4, 1.0, 0.7), skin=(0.95, 0.8, 0.7), bulk=0.8, h=1.08, head=0.96),
 "vance":   dict(suit=(0.08, 0.12, 0.25), accent=(0.9, 0.2, 0.2), skin=(0.82, 0.62, 0.5), bulk=1.1, h=1.1, head=1.0),
 "nox":     dict(suit=(0.28, 0.3, 0.36), accent=(0.75, 0.45, 1.0), skin=(0.6, 0.64, 0.7), bulk=1.0, h=1.0, head=1.0),
}
POSES = {
 "idle":   dict(aL=(0.05, 0, 0.14), aR=(0.05, 0, -0.14), lL=(0, 0, 0.03), lR=(0, 0, -0.03), head=0.0, lean=0.0),
 "point":  dict(aL=(0.05, 0, 0.14), aR=(1.35, 0, -0.35), lL=(0, 0, 0.05), lR=(0, 0, -0.05), head=-0.2, lean=0.04),
 "work":   dict(aL=(1.0, 0, 0.2), aR=(1.1, 0, -0.2), lL=(0, 0, 0.05), lR=(0, 0, -0.05), head=0.0, lean=0.14),
 "walk":   dict(aL=(0.6, 0, 0.1), aR=(-0.6, 0, -0.1), lL=(-0.5, 0, 0), lR=(0.5, 0, 0), head=0.0, lean=0.04),
 "salute": dict(aL=(0.05, 0, 0.14), aR=(2.5, 0, -0.5), lL=(0, 0, 0.03), lR=(0, 0, -0.03), head=0.0, lean=0.0),
 "think":  dict(aL=(0.9, 0, 0.1), aR=(2.3, 0, -0.1), lL=(0, 0, 0.05), lR=(0.15, 0, -0.05), head=0.25, lean=0.02),
 "cheer":  dict(aL=(2.8, 0, 0.5), aR=(2.8, 0, -0.5), lL=(0, 0, 0.12), lR=(0, 0, -0.12), head=0.0, lean=-0.05),
}

def make(name, pose="idle", s=1.0):
    sp = SPECS[name]; po = POSES[pose]
    bk = sp["bulk"]; H = sp["h"]; hs = sp["head"]
    root = bpy.data.objects.new("char_" + name, None); bpy.context.collection.objects.link(root)
    suit = M(name + "_suit", sp["suit"], 0.1, 0.6); dark = M(name + "_dark", (0.07, 0.08, 0.1), 0.3, 0.6)
    acc = M(name + "_acc", sp["accent"], 0.2, 0.4); skin = M(name + "_skin", sp["skin"], 0.0, 0.7)
    glove = M(name + "_glove", tuple(c * 0.55 for c in sp["suit"]), 0.1, 0.7)
    white = M("white", (0.95, 0.95, 0.97), 0.0, 0.5); black = M("black", (0.02, 0.02, 0.03), 0.0, 0.4)
    lean_p = pivot("hips", (0, 0, 0.36), root)
    # --- jambes
    legs = {}
    for sx, key in ((-1, "lL"), (1, "lR")):
        lp = pivot("leg", (sx * 0.085 * bk, 0, 0.36), lean_p if False else root)
        cy("thigh", 0.075 * bk, 0.062 * bk, 0.34, (0, 0, -0.17), m=suit, parent=lp)
        sph("boot", 0.085 * bk, (0, 0.025, -0.34), (1, 1.35, 0.75), dark, lp)
        legs[key] = lp
        lp.rotation_euler = po[key]
        lp.rotation_euler = (po[key][0], po[key][1], po[key][2])
    # --- torse (basculé par lean)
    tp = pivot("torso", (0, 0, 0.36), root); tp.rotation_euler = (po["lean"], 0, 0)
    cy("torso", 0.17 * bk, 0.2 * bk, 0.34, (0, 0, 0.17), m=suit, parent=tp, seg=28, scale=(1, 0.78, 1))
    sph("shoulderline", 0.2 * bk, (0, 0, 0.33), (1.0, 0.7, 0.35), suit, tp)
    bx("belt", (0.36 * bk, 0.26 * bk, 0.045), (0, 0, 0.03), m=dark, parent=tp)
    bx("buckle", (0.06, 0.02, 0.04), (0, 0.13 * bk, 0.03), m=acc, parent=tp)
    bx("chest", (0.13, 0.015, 0.1), (0, 0.145 * bk, 0.22), m=acc, parent=tp, bevel=0.01)
    # --- tête
    hp = pivot("head", (0, 0, 0.34 + 0.02), tp); hp.rotation_euler = (0, 0, po["head"])
    cy("neck", 0.05, 0.055, 0.06, (0, 0, 0.0), m=skin, parent=hp)
    R = 0.17 * hs
    sph("head", R, (0, 0, 0.17 * hs), (1.0, 0.95, 1.0), skin, hp, 32)
    cz = 0.17 * hs
    # visage
    for sx in (-1, 1):
        sph("eye", 0.032, (sx * 0.06 * hs, R * 0.9, cz + 0.02), (1, 0.5, 1.2), white, hp, 12)
        sph("pupil", 0.018, (sx * 0.06 * hs, R * 0.96, cz + 0.02), (1, 0.4, 1.2), black, hp, 10)
    sph("nose", 0.022, (0, R * 0.98, cz - 0.025), (1, 1, 1), skin, hp, 10)
    sph("mouth", 0.03, (0, R * 0.9, cz - 0.075), (1.3, 0.35, 0.28), M("lip", (0.55, 0.2, 0.2), 0, 0.6), hp, 10)
    brow = black if name != "vance" else white
    for sx in (-1, 1):
        bx("brow", (0.05, 0.015, 0.012), (sx * 0.06 * hs, R * 0.93, cz + 0.065), (0, 0, sx * -0.18), brow, hp, 0.004)
    # --- bras
    arms = {}
    for sx, key in ((-1, "aL"), (1, "aR")):
        ap = pivot("arm", (sx * (0.2 * bk + 0.03), 0, 0.30), tp)
        cy("arm", 0.055 * bk, 0.05 * bk, 0.27, (0, 0, -0.13), m=suit, parent=ap)
        sph("hand", 0.058 * bk, (0, 0, -0.29), (1, 1, 1), glove, ap)
        sph("pad", 0.075 * bk, (0, 0, 0.0), (1, 1, 0.8), acc if name in ("captain", "vance") else suit, ap)
        ap.rotation_euler = po[key]
        arms[key] = ap
    # --- identité
    if name == "captain":
        hairc = M("caphair", (0.08, 0.07, 0.09), 0, 0.8)
        sph("hairbase", R * 1.03, (0, -R * 0.14, cz + R * 0.16), (1.0, 1.0, 0.8), hairc, hp, 24)
        sph("sweep", R * 0.62, (R * 0.3, R * 0.55, cz + R * 0.58), (1.3, 0.6, 0.5), hairc, hp, 14)
        gl = bpy.data.materials.new("capglass"); gl.use_nodes = True
        gb = gl.node_tree.nodes["Principled BSDF"]; gb.inputs["Base Color"].default_value = (0.6, 0.85, 1.0, 1)
        gb.inputs["Roughness"].default_value = 0.04; gb.inputs["Alpha"].default_value = 0.2
        gb.inputs["Emission Color"].default_value = (0.1, 0.8, 1.0, 1); gb.inputs["Emission Strength"].default_value = 0.25
        sph("helmet", R * 1.3, (0, 0, cz), (1, 1, 1), gl, hp, 32)
        tor("helmring", R * 1.12, 0.03, (0, 0, cz - R * 0.5), m=M("helmmet", (0.55, 0.62, 0.72), 0.7, 0.3), parent=hp)
        tor("visorband", R * 1.28, 0.022, (0, 0, cz + R * 0.02), (math.radians(90), 0, 0), E("vband", (0.1, 0.85, 1.0), 6.0), hp)
        sph("cheek", 0.02, (0, R * 0.9, cz - 0.02), m=M("cheek", (0.85, 0.5, 0.45), 0, 0.8), parent=hp, seg=8)
        tor("collar", 0.11, 0.025, (0, 0, 0.0), m=acc, parent=hp)
        for sx in (-1, 1):
            bx("epaulet", (0.09, 0.06, 0.02), (sx * (0.2 * bk + 0.03), 0, 0.37), (0, 0, sx * -0.3), M("gold", (1.0, 0.8, 0.2), 0.7, 0.3), tp)
        bx("bar1", (0.07, 0.01, 0.018), (0, 0.147 * bk, 0.31), m=M("gold", (1.0, 0.8, 0.2), 0.7, 0.3), parent=tp)
        bx("bar2", (0.07, 0.01, 0.018), (0, 0.147 * bk, 0.285), m=M("gold", (1.0, 0.8, 0.2), 0.7, 0.3), parent=tp)
        bx("cape", (0.34, 0.03, 0.34), (0, -0.16 * bk, 0.17), (0.12, 0, 0), M("cape", (0.08, 0.12, 0.2), 0, 0.8), tp)
        bx("pack", (0.2, 0.09, 0.2), (0, -0.19, 0.2), m=dark, parent=tp)
    elif name == "rex":
        hair = M("rexhair", (0.25, 0.13, 0.07), 0, 0.8)
        sph("hairbase", R * 1.04, (0, -R * 0.12, cz + R * 0.18), (1.0, 1.0, 0.8), hair, hp, 24)
        for k in range(7):
            a = math.radians(-60 + k * 20)
            cy("spike", 0.045, 0.0, 0.17, (math.sin(a) * R * 0.75, -R * 0.1 + math.cos(a) * 0.01, cz + R * 0.95), (math.radians(-12), math.sin(a) * 0.5, 0), m=hair, parent=hp, seg=8)
        tor("goggle_band", R * 1.0, 0.016, (0, 0, cz + R * 0.42), m=black, parent=hp)
        for sx in (-1, 1):
            tor("goggle", 0.05, 0.014, (sx * 0.065, R * 0.8, cz + R * 0.46), (math.radians(80), 0, 0), acc, hp)
            sph("lens", 0.045, (sx * 0.065, R * 0.79, cz + R * 0.46), (1, 0.15, 1), E("lens", (0.4, 0.9, 1.0), 1.5), hp, 12)
        tor("scarf", 0.12 * bk, 0.04, (0, 0, 0.33), m=M("scarf", (0.1, 0.75, 0.95), 0, 0.8), parent=tp)
        bx("scarftail", (0.07, 0.02, 0.24), (0.08, 0.12, 0.18), (0.1, 0, 0.2), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), tp)
        bx("wing", (0.12, 0.012, 0.05), (-0.1, 0.147 * bk, 0.16), m=acc, parent=tp)
        bx("pack", (0.16, 0.07, 0.16), (0, -0.16, 0.2), m=dark, parent=tp)
    elif name == "bolt":
        yellow = M("hat", (1.0, 0.78, 0.1), 0.1, 0.4)
        sph("hardhat", R * 1.12, (0, 0, cz + R * 0.18), (1, 1, 0.75), yellow, hp, 28)
        tor("brim", R * 1.08, 0.025, (0, R * 0.05, cz + R * 0.18), m=yellow, parent=hp)
        bx("ridge", (0.05, R * 1.8, 0.035), (0, 0, cz + R * 0.9), m=yellow, parent=hp)
        sph("lamp", 0.045, (0, R * 1.1, cz + R * 0.25), (1, 0.7, 1), E("lamp", (1.0, 0.95, 0.7), 8.0), hp, 12)
        beard = M("beard", (0.12, 0.07, 0.05), 0, 0.9)
        sph("beard", R * 0.7, (0, R * 0.55, cz - R * 0.55), (1.15, 0.7, 0.8), beard, hp, 16)
        bx("must", (0.1, 0.03, 0.025), (0, R * 0.92, cz - 0.04), m=beard, parent=hp, bevel=0.01)
        tor("toolbelt", 0.23 * bk, 0.035, (0, 0, 0.06), m=M("leather", (0.3, 0.18, 0.08), 0, 0.8), parent=tp)
        for sx in (-1, 1):
            bx("tool", (0.04, 0.03, 0.12), (sx * 0.22, 0.04, 0.0), (0, 0, sx * 0.4), M("steel", (0.6, 0.62, 0.66), 0.9, 0.3), tp)
        bx("pocket", (0.1, 0.02, 0.08), (0.08, 0.16 * bk, 0.2), m=dark, parent=tp)
        cy("tank1", 0.06, 0.06, 0.28, (-0.09, -0.16, 0.22), m=acc, parent=tp)
        cy("tank2", 0.06, 0.06, 0.28, (0.09, -0.16, 0.22), m=acc, parent=tp)
        for ar in arms.values():
            sph("glovebig", 0.075, (0, 0, -0.29), (1, 1, 1), M("gl", (0.25, 0.2, 0.15), 0, 0.8), ar, 14)
    elif name == "lyra":
        hair = M("lyrahair", (0.55, 0.18, 0.75), 0, 0.6)
        sph("hairbase", R * 1.07, (0, -R * 0.1, cz + R * 0.1), (1.0, 1.0, 0.95), hair, hp, 28)
        sph("bangs", R * 0.7, (-R * 0.3, R * 0.75, cz + R * 0.45), (1.2, 0.5, 0.5), hair, hp, 14)
        cy("ponytail", 0.07, 0.02, 0.42, (0.0, -R * 1.15, cz - 0.03), (math.radians(160), 0, 0), hair, hp, 12)
        sph("tie", 0.04, (0, -R * 1.0, cz + R * 0.55), m=acc, parent=hp)
        for sx in (-1, 1):
            tor("glass", 0.05, 0.01, (sx * 0.062, R * 0.93, cz + 0.02), (math.radians(90), 0, 0), black, hp)
        bx("bridge", (0.03, 0.01, 0.01), (0, R * 0.93, cz + 0.03), m=black, parent=hp, bevel=0.003)
        coat = M("coat", (0.95, 0.96, 0.98), 0, 0.5)
        bx("coatF", (0.32 * bk, 0.03, 0.44), (0, 0.14 * bk, 0.02), (-0.06, 0, 0), coat, tp)
        bx("coatB", (0.34 * bk, 0.03, 0.46), (0, -0.14 * bk, 0.02), (0.06, 0, 0), coat, tp)
        for sx in (-1, 1): bx("lapel", (0.05, 0.02, 0.26), (sx * 0.08, 0.16 * bk, 0.2), (0, 0, sx * -0.2), coat, tp)
        bx("tablet", (0.16, 0.012, 0.22), (0, 0, -0.29), (0, 0, 0), E("tab", (0.3, 1.0, 0.7), 2.0), arms["aL"])
        sph("sensor", 0.035, (0.17, 0.0, 0.43), m=E("sens", (0.4, 1.0, 0.7), 6.0), parent=tp)
    elif name == "vance":
        white_h = M("vhair", (0.9, 0.9, 0.92), 0, 0.8)
        sph("hairbase", R * 1.03, (0, -R * 0.1, cz + R * 0.08), (1.0, 1.0, 0.85), white_h, hp, 24)
        sph("must", 0.06, (0, R * 0.93, cz - 0.045), (1.6, 0.4, 0.5), white_h, hp, 12)
        cap = M("cap", (0.06, 0.09, 0.2), 0.1, 0.6)
        sph("capdome", R * 1.08, (0, 0, cz + R * 0.35), (1, 1, 0.55), cap, hp, 28)
        bx("capvisor", (R * 1.5, R * 0.8, 0.02), (0, R * 0.95, cz + R * 0.42), (-0.2, 0, 0), dark, hp, 0.006)
        sph("capbadge", 0.035, (0, R * 1.05, cz + R * 0.58), (1, 0.3, 1), M("gold", (1.0, 0.8, 0.2), 0.7, 0.3), hp, 10)
        bx("coat", (0.4 * bk, 0.03, 0.34), (0, 0.15 * bk, 0.06), (-0.08, 0, 0), M("navy", (0.06, 0.1, 0.22), 0, 0.6), tp)
        for sx in (-1, 1):
            bx("lapelred", (0.03, 0.02, 0.3), (sx * 0.1, 0.17 * bk, 0.18), (0, 0, sx * -0.25), acc, tp)
        for k in range(3):
            sph("medal", 0.022, (-0.09 + k * 0.045, 0.16 * bk, 0.27), (1, 0.5, 1), M("gold", (1.0, 0.8, 0.2), 0.7, 0.3) if k != 1 else acc, tp, 10)
        for sx in (-1, 1):
            bx("epaulet", (0.1, 0.06, 0.02), (sx * (0.2 * bk + 0.03), 0, 0.37), (0, 0, sx * -0.3), M("gold", (1.0, 0.8, 0.2), 0.7, 0.3), tp)
    elif name == "nox":
        met = M("nox_met", (0.62, 0.66, 0.72), 0.9, 0.25)
        sph("head", R * 1.1, (0, 0, cz), (1.05, 0.95, 0.95), met, hp, 32)
        bx("face", (0.3 * hs, 0.02, 0.15), (0, R * 0.96, cz), m=M("face", (0.02, 0.03, 0.05), 0.9, 0.1), parent=hp, bevel=0.03)
        for sx in (-1, 1):
            sph("led", 0.034, (sx * 0.07, R * 1.0, cz), (1, 0.3, 1), E("led", (0.75, 0.45, 1.0), 9.0), hp, 12)
        cy("ant", 0.012, 0.012, 0.18, (0.07, 0, cz + R * 1.0), m=met, parent=hp, seg=8)
        sph("anttip", 0.03, (0.07, 0, cz + R * 1.0 + 0.1), m=E("tip", (1.0, 0.4, 0.8), 8.0), parent=hp)
        for sx in (-1, 1): sph("ear", 0.05, (sx * R * 1.08, 0, cz), (0.5, 1, 1), acc, hp, 12)
        bx("core", (0.1, 0.02, 0.1), (0, 0.15 * bk, 0.2), m=E("core", (0.75, 0.45, 1.0), 6.0), parent=tp, bevel=0.02)
        bx("coreplate", (0.15, 0.015, 0.15), (0, 0.145 * bk, 0.2), m=dark, parent=tp, bevel=0.02)
        bx("pack", (0.2, 0.08, 0.2), (0, -0.17, 0.2), m=dark, parent=tp)
    # échelle globale
    root.scale = (s * H, s * H, s * H)
    return root

def all_children(root):
    out = [root]
    for o in bpy.data.objects:
        p = o.parent
        while p is not None:
            if p == root: out.append(o); break
            p = p.parent
    return out
