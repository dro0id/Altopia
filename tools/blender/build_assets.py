"""Génère les modèles 3D du jeu avec Blender (bpy) : python tools/blender/build_assets.py [--preview DIR] [--out DIR] [nom ...]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import *

OUT = "assets/models"
PREVIEW = None
FBX = None
args = sys.argv[1:]
names = []
i = 0
while i < len(args):
    if args[i] == "--preview": PREVIEW = args[i+1]; i += 2
    elif args[i] == "--out": OUT = args[i+1]; i += 2
    elif args[i] == "--fbx": FBX = args[i+1]; i += 2
    else: names.append(args[i]); i += 1

def player(accent=(0.1, 0.8, 1.0), rng=None):
    rng = rng or random.Random(3)
    hull = mat("hull", (0.74, 0.8, 0.86), 0.75, 0.28)
    dark = mat("dark", (0.07, 0.1, 0.14), 0.85, 0.35)
    panel = mat("panel", (0.5, 0.56, 0.62), 0.8, 0.4)
    neon = mat("accent", accent, 0.2, 0.3, emit=accent, emit_k=6.0)
    glass = mat("canopy", (0.01, 0.05, 0.09), 0.95, 0.03, emit=(0.05, 0.4, 0.8), emit_k=0.5)
    glow = mat("engine", (0.7, 0.95, 1.0), 0.0, 0.2, emit=(0.5, 0.9, 1.0), emit_k=14.0)
    parts = []
    # fuselage : loft nez effilé -> cockpit -> corps -> arrière
    fus = loft("fuselage", [
        (2.7, 0.04, 0.04, 0.0), (2.3, 0.22, 0.14, 0.0), (1.6, 0.46, 0.3, 0.02), (0.6, 0.82, 0.5, 0.05),
        (-0.5, 1.0, 0.56, 0.05), (-1.5, 1.0, 0.5, 0.0), (-2.2, 0.8, 0.44, 0.0), (-2.5, 0.7, 0.38, 0.0)], n=20, exp=2.8, material=hull, subsurf=2)
    parts.append(fus)
    # spine / dorsale
    parts.append(loft("spine", [(1.2, 0.04, 0.02, 0.34), (0.2, 0.16, 0.14, 0.36), (-1.2, 0.3, 0.18, 0.36), (-2.3, 0.12, 0.1, 0.32)], n=12, exp=2.4, material=panel, subsurf=1))
    # verrière
    can = sphere("canopy", 0.5, (0, 0.85, 0.3), (0.5, 1.15, 0.5), glass)
    parts.append(can)
    # ailes (flèche) + volets
    wing_pts = [(0.35, 1.0), (2.85, -1.0), (2.9, -1.55), (2.6, -1.62), (0.4, -1.1)]
    parts.append(plate("wing", wing_pts, 0.1, (0, -0.2, -0.04), dark, bevel=0.02))
    flap = [(0.4, -1.1), (2.6, -1.62), (2.5, -2.0), (0.45, -1.6)]
    parts.append(plate("flap", flap, 0.08, (0, -0.2, -0.04), panel, bevel=0.015))
    for sx in (-1, 1):
        parts.append(box("winglet", (0.06, 0.95, 0.62), (sx*2.88, -1.85, 0.2), (0, sx*0.22, 0), hull, 0.012))
    # liseré lumineux de bord d'attaque
    for sx in (-1, 1):
        dx, dy = sx*2.5, -2.0
        parts.append(box("edge", (0.035, math.hypot(dx, dy), 0.03), (sx*1.6, -0.2, 0.03), (0, 0, math.atan2(-dx, dy)), neon, 0.004))
    # canons
    for sx in (-1, 1):
        parts.append(cyl("cannon", 0.07, 0.05, 1.5, (sx*1.1, 0.5, -0.05), seg=14, material=dark))
        parts.append(cyl("cannon_tip", 0.1, 0.1, 0.12, (sx*1.1, 1.3, -0.05), seg=14, material=neon))
    # nacelles moteurs
    for sx in (-1, 1):
        parts.append(cyl("nacelle", 0.3, 0.38, 1.9, (sx*0.72, -1.55, 0.0), seg=28, material=hull, bevel=0.01))
        parts.append(cyl("collar", 0.43, 0.43, 0.14, (sx*0.72, -0.8, 0.0), seg=28, material=dark))
        parts.append(cyl("nozzle", 0.33, 0.25, 0.3, (sx*0.72, -2.62, 0.0), seg=28, material=dark))
        parts.append(cyl("flame_core", 0.23, 0.23, 0.04, (sx*0.72, -2.74, 0.0), seg=28, material=glow))
        parts.append(box("pylon", (0.22, 1.5, 0.12), (sx*0.52, -1.3, 0.0), material=panel, bevel=0.01))
    # dérive centrale
    parts.append(plate("fin", [(0.0, 0.6), (0.0, 0.0), (0.0, -0.9), (0.0, 0.0)][:0] or [(-0.04, -0.5), (0.04, -0.5), (0.03, -2.2), (-0.03, -2.2)], 0.0001, (0,0,0), dark, mirror=False) if False else box("fin", (0.07, 1.1, 0.75), (0, -1.9, 0.55), (-0.45, 0, 0), dark, 0.01))
    # greeble dorsal
    def ztop(y, x): return 0.38 - abs(x)*0.3
    parts += greeble(rng, -2.0, 0.6, 0.22, lambda y, x: 0.34, 26, panel, size=(0.07, 0.24), height=0.035)
    # bandes et feux de navigation
    parts.append(box("stripe", (0.1, 2.6, 0.02), (0, -0.4, 0.37), material=neon, bevel=0.003))
    parts.append(box("navL", (0.07, 0.07, 0.07), (-2.95, -1.7, 0.02), material=mat("navL", (1, 0.1, 0.1), 0, 0.3, emit=(1, 0.1, 0.1), emit_k=8), bevel=0.01))
    parts.append(box("navR", (0.07, 0.07, 0.07), (2.95, -1.7, 0.02), material=mat("navR", (0.1, 1, 0.3), 0, 0.3, emit=(0.1, 1, 0.3), emit_k=8), bevel=0.01))
    return parts


def enemy(color=(1.0, 0.25, 0.1), elite=False, rng=None):
    rng = rng or random.Random(7)
    hull = mat("ehull", (0.09, 0.07, 0.1), 0.85, 0.32)
    plate_m = mat("eplate", (0.2, 0.15, 0.2), 0.8, 0.4)
    red = mat("eglow", color, 0.0, 0.3, emit=color, emit_k=9.0)
    parts = []
    parts.append(loft("body", [(2.4, 0.05, 0.05, 0), (1.8, 0.5, 0.3, 0), (0.6, 1.0, 0.5, 0), (-0.8, 1.2, 0.55, 0), (-1.8, 0.9, 0.45, 0), (-2.1, 0.6, 0.35, 0)], n=16, exp=2.2, material=hull, subsurf=2))
    # ailes en avant-arrière : faucilles
    parts.append(plate("sickle", [(0.5, 0.8), (2.2, 1.2), (3.0, 0.2), (2.4, -0.3), (1.6, 0.1), (0.5, -1.4)], 0.09, (0, -0.4, 0), plate_m, bevel=0.015))
    for sx in (-1, 1):
        parts.append(cyl("spike", 0.07, 0.01, 1.4, (sx*2.7, 0.7, 0), seg=10, material=hull))
        parts.append(box("fin", (0.06, 1.0, 0.7), (sx*0.65, -1.7, 0.4), (0, sx*0.25, 0), hull, 0.01))
        parts.append(box("vent", (0.5, 0.05, 0.05), (sx*0.35, -0.2, 0.3), material=red, bevel=0.004))
        parts.append(box("edge", (0.03, 2.2, 0.03), (sx*1.7, 0.1, 0.06), (0, 0, math.atan2(-sx*2.2, 0.9)), red, 0.003))
        parts.append(cyl("exhaust", 0.2, 0.15, 0.3, (sx*0.4, -2.2, 0), seg=18, material=plate_m))
        parts.append(cyl("exhaust_glow", 0.14, 0.14, 0.03, (sx*0.4, -2.37, 0), seg=18, material=red))
    parts.append(sphere("eye", 0.28, (0, 1.2, 0.15), (1, 1.4, 0.7), red))
    parts += greeble(rng, -1.6, 1.0, 0.35, lambda y, x: 0.27, 16, plate_m, size=(0.08, 0.26), height=0.04)
    if elite:
        parts.append(box("armor", (1.5, 1.2, 0.2), (0, -0.2, 0.34), material=plate_m, bevel=0.03))
        parts.append(box("armor2", (0.3, 2.0, 0.16), (0, 0.3, 0.46), material=red, bevel=0.01))
    return parts

def boss(color=(1.0, 0.35, 0.8), rng=None):
    rng = rng or random.Random(11)
    hull = mat("bhull", (0.1, 0.06, 0.12), 0.85, 0.3)
    plate_m = mat("bplate", (0.22, 0.13, 0.25), 0.8, 0.4)
    glow = mat("bglow", color, 0.0, 0.3, emit=color, emit_k=10.0)
    parts = []
    core = sphere("core", 3.2, (0, 0, 0), (1, 0.85, 1), hull, seg=48); parts.append(core)
    for k in range(10):
        a = 2*math.pi*k/10
        sp = cyl("spike", 0.55, 0.02, 4.4, (math.cos(a)*4.9, -0.3, math.sin(a)*4.9), seg=8, material=hull)
        sp.rotation_euler = (0, math.pi/2 - a, 0)
        parts.append(sp)
    parts.append(torus("ring1", 5.9, 0.3, rot=(math.pi/2, 0, 0), material=plate_m))
    parts.append(torus("ring2", 4.6, 0.22, rot=(math.pi/2 + 0.9, 0, 0.3), material=plate_m))
    # œil
    parts.append(sphere("eye", 1.2, (0, 3.0, 0), (1, 0.5, 1), glow))
    parts.append(sphere("pupil", 0.45, (0, 3.35, 0), (1, 0.4, 1), mat("pupil", (1, 1, 1), 0, 0.2, emit=(1, 1, 1), emit_k=12)))
    # lames latérales
    for sx in (-1, 1):
        parts.append(plate("blade", [(3.0, 1.5), (9.0, 3.0), (10.0, 0.4), (7.0, -1.4), (3.0, -2.5)], 0.35, (0, 0, 0), plate_m, bevel=0.05, mirror=False))
        parts[-1].scale.x = sx
        parts.append(sphere("turret", 0.5, (sx*9.2, 1.4, 0), material=glow))
        parts.append(box("bedge", (0.08, 6.5, 0.06), (sx*6.4, 0.6, 0.2), (0, 0, math.atan2(-sx*7, 1.5)), glow, 0.005))
    return parts

def asteroid(seed=1, crystals=False):
    rng = random.Random(seed)
    rock = mat("rock", (0.36, 0.3, 0.25), 0.05, 0.92)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=5, radius=1.0)
    ob = bpy.context.active_object
    tex = bpy.data.textures.new("clouds", "CLOUDS"); tex.noise_scale = 0.9 + rng.random()*0.5; tex.noise_depth = 3
    d = ob.modifiers.new("d", "DISPLACE"); d.texture = tex; d.strength = 0.55; d.mid_level = 0.45
    tex2 = bpy.data.textures.new("c2", "VORONOI"); tex2.noise_scale = 0.32; 
    d2 = ob.modifiers.new("d2", "DISPLACE"); d2.texture = tex2; d2.strength = 0.26; d2.mid_level = 0.3
    ob.scale = (1.0+rng.random()*0.3, 0.8+rng.random()*0.3, 0.9+rng.random()*0.3)
    apply_all(ob)
    dec = ob.modifiers.new("dec", "DECIMATE"); dec.ratio = 0.4
    apply_all(ob)
    finish(ob, rock, smooth=True)
    parts = [ob]
    if crystals:
        cm = mat("crystal", (0.05, 0.5, 0.65), 0.1, 0.1, emit=(0.1, 0.8, 1.0), emit_k=2.5)
        for i in range(4):
            a = rng.random()*6.28; z = rng.uniform(-0.3, 0.7)
            bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.12, radius2=0.0, depth=0.7)
            c = new_obj("cr", bm); c.location = (math.cos(a)*0.9, math.sin(a)*0.9, z)
            c.rotation_euler = (math.sin(a)*0.8, -math.cos(a)*0.8, 0)
            finish(c, cm, smooth=False); parts.append(c)
    return parts

def station():
    hull = mat("shull", (0.5, 0.55, 0.6), 0.8, 0.32)
    dark = mat("sdark", (0.1, 0.12, 0.16), 0.85, 0.35)
    win = mat("swin", (0.5, 1.0, 0.7), 0.0, 0.3, emit=(0.4, 1.0, 0.6), emit_k=5.0)
    warn = mat("swarn", (1, 0.25, 0.2), 0.0, 0.3, emit=(1, 0.2, 0.15), emit_k=8.0)
    solar = mat("solar", (0.05, 0.12, 0.3), 0.9, 0.18)
    parts = []
    parts.append(cyl("hub", 1.7, 1.7, 7.5, seg=36, material=hull, bevel=0.03))
    for sy in (-1, 1):
        parts.append(cyl("cap", 1.0, 0.6, 1.2, (0, sy*4.2, 0), seg=28, material=dark))
    parts.append(torus("ring", 7.0, 1.0, rot=(math.pi/2, 0, 0), material=hull))
    for k in range(28):
        a = 2*math.pi*k/28
        w = box("window", (0.7, 0.12, 0.3), (math.cos(a)*7.0, 0.0, math.sin(a)*7.0), material=win, bevel=0.01)
        w.rotation_euler = (0, a + math.pi/2, 0)
        w.location = (math.cos(a)*7.0, 1.02, math.sin(a)*7.0); parts.append(w)
        w2 = box("window2", (0.7, 0.12, 0.3), (0, 0, 0), material=win, bevel=0.01)
        w2.rotation_euler = (0, a + math.pi/2, 0); w2.location = (math.cos(a)*7.0, -1.02, math.sin(a)*7.0); parts.append(w2)
    for k in range(4):
        a = 2*math.pi*k/4 + math.pi/4
        b = box("spoke", (0.4, 0.4, 6.4), (math.cos(a)*3.5, 0, math.sin(a)*3.5), material=hull, bevel=0.02)
        b.rotation_euler = (0, math.pi/2 - a, 0); parts.append(b)
    for sx in (-1, 1):
        parts.append(box("panel", (0.08, 2.8, 9), (sx*3.2, 0, 0), material=solar, bevel=0.01))
        parts.append(box("panelarm", (0.3, 0.3, 4.2), (sx*1.9, 0, 0), material=dark, bevel=0.01))
        parts[-1].rotation_euler = (0, math.pi/2, 0)
    parts.append(sphere("beaconA", 0.3, (0, 4.8, 0), material=win))
    parts.append(sphere("beaconB", 0.25, (0, -4.9, 0), material=warn))
    return parts

def wreck(rng=None):
    rng = rng or random.Random(5)
    hull = mat("whull", (0.16, 0.17, 0.2), 0.8, 0.55)
    rust = mat("wrust", (0.28, 0.16, 0.1), 0.6, 0.7)
    hot = mat("whot", (1, 0.45, 0.1), 0.0, 0.4, emit=(1, 0.4, 0.05), emit_k=7.0)
    parts = []
    f = loft("main", [(-3.8, 1.6, 1.2, 0), (-2.0, 2.4, 1.7, 0), (0.0, 2.6, 1.8, 0), (1.5, 2.0, 1.4, 0), (2.2, 1.2, 0.9, 0)], n=14, exp=3.2, material=hull, subsurf=0)
    parts.append(f)
    # déchirure : on retire des faces au hasard + ossature visible
    bm = bmesh.new(); bm.from_mesh(f.data)
    bm.faces.ensure_lookup_table()
    kill = [fc for fc in bm.faces if fc.calc_center_median().y > 0.2 and fc.calc_center_median().x > 0.2 and fc.calc_center_median().z > -0.2]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(f.data); bm.free()
    md = f.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.08
    for k in range(6):
        y = -3.2 + k*1.0
        bm = bmesh.new(); bmesh.ops.create_circle(bm, segments=16, radius=1.25 + 0.1*math.sin(k))
        rb = new_obj("rib", bm); rb.rotation_euler = (math.pi/2, 0, 0); rb.location = (0, y, 0)
        s2 = rb.modifiers.new("w", "WIREFRAME"); s2.thickness = 0.06; s2.use_replace = True
        rb.scale = (1.0, 1.0, 0.75); finish(rb, rust); parts.append(rb)
    parts.append(box("gash", (0.12, 2.6, 0.1), (1.0, 1.0, 0.7), (0, 0, 0.5), hot, 0.005))
    for i in range(8):
        p = box("scrap", (rng.uniform(0.3, 1.4), rng.uniform(0.1, 0.18), rng.uniform(0.4, 1.2)), (rng.uniform(-4, 4), rng.uniform(-3, 3), rng.uniform(-2, 2)), (rng.uniform(0, 3), rng.uniform(0, 3), rng.uniform(0, 3)), hull, 0.01)
        parts.append(p)
    parts.append(cyl("engine", 0.9, 1.2, 2.2, (0.5, -4.6, -0.4), seg=16, material=rust)); parts[-1].rotation_euler = (math.pi/2 + 0.3, 0.2, 0)
    parts.append(box("wing", (3.2, 1.8, 0.1), (3.6, -1.4, -0.3), (0, 0.4, 0.3), hull, 0.01))
    return parts

BUILD = {"player": lambda: player(), "enemy": lambda: enemy(), "elite": lambda: enemy((1.0, 0.1, 0.2), True), "boss": lambda: boss(),
         "asteroid1": lambda: asteroid(1, True), "asteroid2": lambda: asteroid(2), "asteroid3": lambda: asteroid(3, True),
         "station": lambda: station(), "wreck": lambda: wreck()}
CAMS = {"boss": ((14, 24, 12), (0, 0, 0), 5.0), "station": ((17, -17, 11), (0, 0, 0), 3.0), "wreck": ((15, -15, 8), (0, 0, 0), 3.5),
        "asteroid1": ((3.6, -3.6, 2.2), (0, 0, 0), 0.4), "asteroid2": ((3.6, -3.6, 2.2), (0, 0, 0), 0.4), "asteroid3": ((3.6, -3.6, 2.2), (0, 0, 0), 0.4)}

if __name__ == "__main__":
    todo = names or list(BUILD)
    for n in todo:
        reset()
        BUILD[n]()
        for o in list(bpy.data.objects): 
            pass
        if PREVIEW:
            c = CAMS.get(n)
            if c: setup_render(PREVIEW, n, res=(700, 500), samples=32, cam=c[0], target=c[1], size=c[2])
            else: setup_render(PREVIEW, n, res=(700, 500), samples=32, target=(0, -0.2, 0), views=[(6.5, -7.5, 4.0), (-5, 7.5, 3.0)])
        export(os.path.join(OUT, n + ".glb"))
        if FBX: export_fbx(os.path.join(FBX, n + ".fbx"))
        print("ok", n)
