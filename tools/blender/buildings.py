"""Bâtiments de la Base modélisés sur mesure (bpy) : Atelier, Quartiers, Labo, Mine, Centrale, Soute.
Chaque constructeur crée ses objets autour de l'origine (empreinte ~ 3,6 x 3,6, façade vers -Y, z vers le haut)
et renvoie la liste des objets créés. Réutilisés par hub_scenes.py et exportables en GLB."""
import bpy, bmesh, math, random
from mathutils import Vector
from lib import mat as lmat, box, cyl, sphere

def M(name, col, metal=0.0, rough=0.5): return lmat(name, col, metal, rough)
def E(name, col, k=4.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*col, 1); e.inputs[1].default_value = k
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    return m
def put(ob, m, smooth=True):
    ob.data.materials.clear(); ob.data.materials.append(m)
    if smooth:
        for p in ob.data.polygons: p.use_smooth = True
    return ob

HULL = (0.78, 0.82, 0.88); DARK = (0.06, 0.08, 0.11); STEEL = (0.35, 0.39, 0.45); WIN = (1.0, 0.85, 0.5)

def _new(fn):
    def wrap(*a, **k):
        before = set(bpy.data.objects)
        fn(*a, **k)
        return [o for o in bpy.data.objects if o not in before]
    return wrap

def slab(w, d, col=(0.2, 0.22, 0.26)):
    return box("slab", (w, d, 0.16), (0, 0, 0.08), material=M("slab", col, 0.3, 0.7), bevel=0.03)

def sign(col, y, z, w=1.1):
    box("sign", (w, 0.07, 0.16), (0, y, z), material=E("sign", col, 6.0), bevel=0.0)

def torus(R, r, loc, rot=(0, 0, 0), mat=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=48, minor_segments=10, location=loc, rotation=rot)
    ob = bpy.context.active_object
    if mat: put(ob, mat)
    return ob

def dome(r, loc, sz=0.62, mat=None, seg=36):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    for v in bm.verts:
        v.co.z *= sz
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.001], context="VERTS")
    me = bpy.data.meshes.new("dome"); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("dome", me); bpy.context.collection.objects.link(ob); ob.location = loc
    if mat: put(ob, mat)
    return ob

@_new
def atelier(accent=(1.0, 0.7, 0.42)):
    hull, dark, steel = M("a_hull", HULL, 0.3, 0.45), M("a_dark", DARK, 0.6, 0.4), M("a_steel", STEEL, 0.8, 0.35)
    ac = M("a_acc", accent, 0.2, 0.4)
    slab(3.6, 3.4)
    box("hall", (2.6, 2.1, 1.25), (-0.25, 0.35, 0.8), material=hull, bevel=0.05)
    for k in range(3):   # toit en dents de scie
        y = -0.35 + k * 0.7
        box("saw", (2.7, 0.7, 0.07), (-0.25, y, 1.55 + 0.08 * k), (math.radians(-22), 0, 0), steel, 0.01)
        box("sawglass", (2.5, 0.03, 0.22), (-0.25, y - 0.31, 1.62 + 0.08 * k), material=E("sg", WIN, 3.0), bevel=0.0)
    box("door", (1.2, 0.06, 0.85), (-0.55, -0.72, 0.62), material=dark, bevel=0.02)
    for k in range(4): box("slat", (1.2, 0.02, 0.02), (-0.55, -0.76, 0.35 + k * 0.2), material=steel, bevel=0.0)
    box("frame", (1.34, 0.05, 0.05), (-0.55, -0.74, 1.08), material=ac, bevel=0.0)
    sign(accent, -0.76, 1.3, 0.9)
    cyl("chim", 0.14, 0.12, 1.1, (0.5, 1.0, 1.7), axis="Z", seg=16, material=steel)
    sphere("glow", 0.12, (0.5, 1.0, 2.3), material=E("cg", (1.0, 0.45, 0.1), 8.0))
    # grue
    box("mast", (0.12, 0.12, 1.8), (1.4, -0.2, 0.9), material=ac, bevel=0.0)
    box("jib", (1.5, 0.1, 0.1), (0.85, -0.2, 1.85), material=ac, bevel=0.0)
    box("cable", (0.02, 0.02, 0.8), (0.2, -0.2, 1.4), material=steel, bevel=0.0)
    box("load", (0.3, 0.3, 0.25), (0.2, -0.2, 0.95), material=M("crate", (0.5, 0.35, 0.2), 0.1, 0.8), bevel=0.02)
    for k in range(3): box("crate", (0.4, 0.4, 0.4), (1.2 - k * 0.45, -1.2, 0.36), (0, 0, k * 0.3), M("crate", (0.55, 0.4, 0.22), 0.1, 0.8), 0.02)

@_new
def quartiers(accent=(0.43, 1.0, 0.61)):
    hull, steel = M("q_hull", HULL, 0.3, 0.4), M("q_steel", STEEL, 0.8, 0.35)
    ac = M("q_acc", accent, 0.2, 0.4)
    slab(3.6, 3.4)
    specs = ((0.0, 0.2, 1.0, 0.7), (-1.15, -0.55, 0.72, 0.6), (1.15, -0.55, 0.72, 0.6))
    for x, y, r, h in specs:
        dome(r, (x, y, 0.16), 0.75, hull)
        torus(r * 0.98, 0.04, (x, y, 0.2), mat=ac)
        n = 8
        for a in range(n):
            t = 2 * math.pi * a / n + 0.2
            sphere("win", 0.07, (x + math.cos(t) * r * 0.9, y + math.sin(t) * r * 0.9, 0.16 + h * 0.5), (1, 1, 0.8), E("win", WIN, 5.0), 12)
    for (x1, y1), (x2, y2) in (((0, 0.2), (-1.15, -0.55)), ((0, 0.2), (1.15, -0.55))):
        d = Vector((x2 - x1, y2 - y1, 0)); L = d.length - 1.2
        c = cyl("tube", 0.2, 0.2, max(L, 0.3), (0.5 * (x1 + x2), 0.5 * (y1 + y2), 0.4), axis="Z", seg=16, material=steel)
        c.rotation_euler = (math.radians(90), 0, math.atan2(d.y, d.x) - math.radians(90) + math.radians(90))
        c.rotation_euler = (math.radians(90), 0, math.atan2(d.y, d.x) + math.radians(90))
    box("door", (0.34, 0.05, 0.5), (0.0, -0.78, 0.45), material=M("dk", DARK, 0.5, 0.4), bevel=0.02)
    sign(accent, -0.84, 1.15, 0.7)
    cyl("mast", 0.03, 0.03, 0.8, (0.2, 0.4, 1.4), axis="Z", seg=8, material=steel)
    sphere("tip", 0.07, (0.2, 0.4, 1.8), material=E("tip", (1.0, 0.3, 0.3), 8.0))

@_new
def labo(accent=(0.5, 0.95, 1.0)):
    hull, steel = M("l_hull", HULL, 0.3, 0.4), M("l_steel", STEEL, 0.8, 0.35)
    ac = M("l_acc", accent, 0.2, 0.4)
    slab(3.6, 3.4)
    cyl("drum", 1.25, 1.35, 0.7, (0, 0.1, 0.5), axis="Z", seg=40, material=hull)
    torus(1.3, 0.05, (0, 0.1, 0.84), mat=ac)
    gl = bpy.data.materials.new("glassdome"); gl.use_nodes = True
    b = gl.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (0.4, 0.85, 0.95, 1); b.inputs["Roughness"].default_value = 0.05
    b.inputs["Alpha"].default_value = 0.35; b.inputs["Emission Color"].default_value = (0.3, 0.9, 1.0, 1); b.inputs["Emission Strength"].default_value = 0.8
    dome(1.15, (0, 0.1, 0.85), 0.85, gl)
    for a in range(6):
        t = a * math.pi / 3
        torus(1.15, 0.025, (0, 0.1, 0.85), rot=(math.radians(90), 0, t), mat=steel)
    sphere("orb", 0.3, (0, 0.1, 1.25), material=E("orb", (0.5, 1.0, 1.0), 9.0))
    box("annex", (1.0, 0.9, 0.7), (1.35, -0.7, 0.5), material=hull, bevel=0.04)
    sign(accent, -1.18, 0.55, 0.8)
    # parabole
    cyl("pole", 0.04, 0.04, 0.7, (-1.35, 0.8, 0.5), axis="Z", seg=8, material=steel)
    cyl("dish", 0.5, 0.05, 0.18, (-1.35, 0.8, 0.95), axis="Z", seg=24, material=hull).rotation_euler = (math.radians(50), 0, math.radians(20))

@_new
def mine(accent=(0.88, 0.72, 0.47)):
    hull, steel, dark = M("m_hull", (0.5, 0.45, 0.38), 0.3, 0.7), M("m_steel", STEEL, 0.8, 0.4), M("m_dark", DARK, 0.5, 0.5)
    ac = M("m_acc", accent, 0.2, 0.5)
    slab(3.6, 3.4, (0.3, 0.26, 0.22))
    # chevalement en A
    for sx in (-1, 1):
        for sy in (-1, 1):
            b = box("leg", (0.1, 0.1, 2.2), (sx * 0.45 - 0.9, sy * 0.45 + 0.4, 1.1), (sy * 0.12, -sx * 0.12, 0), steel, 0.01)
    torus(0.32, 0.06, (-0.9, 0.4, 2.15), rot=(0, math.radians(90), 0), mat=ac)
    box("shaft", (0.9, 0.9, 0.35), (-0.9, 0.4, 0.3), material=dark, bevel=0.02)
    # convoyeur
    box("belt", (0.35, 2.4, 0.12), (0.5, 0.0, 0.7), (math.radians(14), 0, 0), dark, 0.01)
    for k in range(5): box("ore", (0.22, 0.22, 0.16), (0.5, -0.9 + k * 0.42, 0.62 + k * 0.1), (0, 0, k), M("ore", (0.35, 0.3, 0.25), 0.1, 0.9), 0.02)
    box("hopper", (0.9, 0.9, 0.7), (1.1, 1.0, 0.5), material=steel, bevel=0.03)
    # cristaux
    rng = random.Random(4)
    cm = E("cr", (1.0, 0.4, 0.9), 3.0)
    for k in range(7):
        h = rng.uniform(0.4, 0.95)
        c = cyl("crys", rng.uniform(0.1, 0.17), 0.0, h, (1.1 + rng.uniform(-0.45, 0.45), -0.8 + rng.uniform(-0.4, 0.5), 0.16 + h / 2), axis="Z", seg=5, material=cm)
        c.rotation_euler = (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0)
    sign(accent, -1.55, 0.35, 0.9)

@_new
def centrale(accent=(0.78, 0.6, 1.0)):
    hull, steel, dark = M("c_hull", HULL, 0.4, 0.4), M("c_steel", STEEL, 0.8, 0.35), M("c_dark", DARK, 0.6, 0.4)
    ac = M("c_acc", accent, 0.2, 0.4)
    slab(3.6, 3.4)
    cyl("reactor", 0.85, 0.85, 1.7, (0, 0.2, 1.0), axis="Z", seg=40, material=hull)
    cyl("band", 0.88, 0.88, 0.25, (0, 0.2, 1.1), axis="Z", seg=40, material=E("band", accent, 4.0))
    dome(0.85, (0, 0.2, 1.85), 0.5, M("c_cap", STEEL, 0.9, 0.3))
    sphere("core", 0.3, (0, 0.2, 2.05), material=E("core", (0.8, 0.6, 1.0), 10.0))
    for sx in (-1, 1):
        t = cyl("tower", 0.6, 0.4, 2.0, (sx * 1.3, 0.9, 1.0), axis="Z", seg=32, material=M("tw", (0.6, 0.62, 0.66), 0.2, 0.6))
        cyl("rim", 0.42, 0.42, 0.06, (sx * 1.3, 0.9, 2.0), axis="Z", seg=32, material=E("rim", accent, 3.0))
    for k, x in enumerate((-1.2, 1.2)):
        box("pylon", (0.08, 0.08, 1.8), (x, -1.0, 0.9), material=steel, bevel=0.0)
        sphere("pt", 0.09, (x, -1.0, 1.85), material=E("pt", accent, 8.0))
    box("cable", (2.4, 0.03, 0.03), (0, -1.0, 1.7), material=dark, bevel=0.0)
    box("trafo", (0.7, 0.6, 0.5), (1.0, -0.6, 0.41), material=dark, bevel=0.03)
    sign(accent, -1.3, 0.35, 0.9)

@_new
def soute(accent=(1.0, 0.82, 0.35)):
    hull, steel, dark = M("s_hull", HULL, 0.3, 0.5), M("s_steel", STEEL, 0.8, 0.35), M("s_dark", DARK, 0.5, 0.4)
    ac = M("s_acc", accent, 0.2, 0.4)
    slab(3.6, 3.4)
    box("hall", (2.4, 2.0, 1.1), (-0.5, 0.5, 0.71), material=hull, bevel=0.05)
    c = cyl("roof", 1.0, 1.0, 2.4, (-0.5, 0.5, 1.26), axis="X", seg=32, material=steel)
    c.scale = (1, 1, 0.38) if False else (1, 1, 1)
    c.scale = (1.0, 1.0, 0.45)
    box("door", (1.3, 0.06, 0.8), (-0.5, -0.52, 0.56), material=dark, bevel=0.02)
    for k in range(5): box("slat", (1.3, 0.02, 0.02), (-0.5, -0.56, 0.28 + k * 0.15), material=steel, bevel=0.0)
    sign(accent, -0.56, 1.05, 0.9)
    cols = [(0.9, 0.35, 0.25), (0.25, 0.55, 0.85), (1.0, 0.75, 0.2), (0.3, 0.7, 0.45)]
    for k in range(4):
        box("cont", (0.9, 0.45, 0.42), (1.15, -0.9 + (k % 2) * 0.1 + k * 0.05, 0.37 + (k // 2) * 0.43), (0, 0, 0.05 * k), M("cont%d" % k, cols[k], 0.2, 0.6), 0.02)
    for x in (0.5, 1.7):
        box("gp", (0.08, 0.08, 1.5), (x, 1.2, 0.9), material=ac, bevel=0.0)
    box("gb", (1.3, 0.1, 0.1), (1.1, 1.2, 1.65), material=ac, bevel=0.0)

BUILDERS = {"atelier": atelier, "quartiers": quartiers, "labo": labo, "mine": mine, "centrale": centrale, "soute": soute}
