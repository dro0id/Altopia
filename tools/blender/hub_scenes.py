"""Rendus Blender (Cycles) des décors du hub : introduction, vaisseau en croisière, arrivée, Base, icônes de bâtiments, équipage.
Usage : python tools/blender/hub_scenes.py OUT_DIR [--scale 0.4] [--samples 48] [scène ...]
Utilise les modèles du dépôt (assets/altopack_r2 : Kenney CC0, assets/models : vaisseau Blender maison)."""
import sys, os, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
A = os.path.join(ROOT, "assets", "altopack_r2") + os.sep
args = sys.argv[1:]
OUT = args[0] if args and not args[0].startswith("--") else "/tmp/hub_renders"
SCALE = 1.0; SAMPLES = 48; NAMES = []
i = 1 if args and not args[0].startswith("--") else 0
while i < len(args):
    if args[i] == "--scale": SCALE = float(args[i+1]); i += 2
    elif args[i] == "--samples": SAMPLES = int(args[i+1]); i += 2
    else: NAMES.append(args[i]); i += 1
sys.path.insert(0, HERE); sys.argv = ["x"]
import bpy
from mathutils import Vector, Euler
import build_assets as BA
from lib import mat as lmat, loft, box, cyl, sphere

# ---------------------------------------------------------------- outils
def reset():
    BA.reset()

def bbox(objs):
    mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
    for o in objs:
        if o.type == "MESH":
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx

def group(objs, name, loc=(0, 0, 0), rz=0.0, s=1.0, center=True):
    roots = [o for o in objs if o.parent is None]
    bpy.context.view_layer.update()
    if center:
        mn, mx = bbox(objs)
        off = Vector((-(mn.x+mx.x)/2, -(mn.y+mx.y)/2, -mn.z))
        for r in roots: r.location += off
    e = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(e)
    bpy.context.view_layer.update()
    for r in roots:
        r.parent = e
    e.location = loc; e.rotation_euler = (0, 0, rz); e.scale = (s, s, s)
    return e

MODELS = os.path.join(ROOT, "assets", "models") + os.sep
def imp(name, loc=(0, 0, 0), rz=0.0, s=1.0, center=True, models=False):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=(MODELS if models else A) + name + ".glb")
    new = [o for o in bpy.data.objects if o not in before]
    return group(new, name, loc, rz, s, center)

def ship(loc=(0, 0, 0), rz=0.0, s=1.0, pitch=0.0, accent=(0.1, 0.8, 1.0), flame_len=0.0, flame_col=(0.04, 0.45, 1.0)):
    before = set(bpy.data.objects)
    BA.player(accent)
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type == "MESH":
            bpy.context.view_layer.objects.active = o
            for md in list(o.modifiers):
                try: bpy.ops.object.modifier_apply(modifier=md.name)
                except RuntimeError: pass
    e = group(new, "ship", loc, rz, s, center=False)
    e.rotation_euler = (pitch, 0, rz)
    if flame_len > 0:
        for sx in (-0.72, 0.72):
            for r, k, L in ((0.2*max(1.0, flame_len/3.0), 5.0 + flame_len, flame_len*0.9),):
                c = flame((0, 0, 0), (math.radians(90), 0, 0), L, r, flame_col, k)
                c.parent = e; c.location = (sx, -2.78 - L/2, 0)
    return e

def solid(name, color, rough=0.6, metal=0.0, emit=None, k=0.0):
    return lmat(name, color, metal, rough, emit=emit, emit_k=k)

def emissive(name, color, k=5.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*color, 1); e.inputs[1].default_value = k
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    return m

def put(ob, m):
    ob.data.materials.clear(); ob.data.materials.append(m)
    for p in ob.data.polygons: p.use_smooth = True
    return ob

def sun(rot, energy=3.0, color=(1, 0.95, 0.85), angle=0.02):
    l = bpy.data.lights.new("sun", "SUN"); l.energy = energy; l.color = color; l.angle = angle
    o = bpy.data.objects.new("sun", l); bpy.context.collection.objects.link(o); o.rotation_euler = rot
    return o

def area(loc, target, energy, color=(1, 1, 1), size=4.0):
    l = bpy.data.lights.new("a", "AREA"); l.energy = energy; l.color = color; l.size = size
    o = bpy.data.objects.new("a", l); bpy.context.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return o

def point(loc, energy, color=(1, 1, 1), r=0.2):
    l = bpy.data.lights.new("p", "POINT"); l.energy = energy; l.color = color; l.shadow_soft_size = r
    o = bpy.data.objects.new("p", l); bpy.context.collection.objects.link(o); o.location = loc
    return o

def world_space(neb=((0.35, 0.12, 0.7), (0.05, 0.25, 0.55)), neb_k=0.28, stars=1.0, base=(0.004, 0.006, 0.02)):
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    nt = w.node_tree; nt.nodes.clear()
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    nt.links.new(tc.outputs["Generated"], mp.inputs[0])
    vor = nt.nodes.new("ShaderNodeTexVoronoi"); vor.feature = "F1"; vor.inputs["Scale"].default_value = 260.0
    nt.links.new(mp.outputs[0], vor.inputs[0])
    sr = nt.nodes.new("ShaderNodeValToRGB"); sr.color_ramp.elements[0].position = 0.0; sr.color_ramp.elements[1].position = 0.075
    sr.color_ramp.elements[0].color = (1, 1, 1, 1); sr.color_ramp.elements[1].color = (0, 0, 0, 1)
    nt.links.new(vor.outputs["Distance"], sr.inputs[0])
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 1.6; nz.inputs["Detail"].default_value = 8; nz.inputs["Roughness"].default_value = 0.6
    nt.links.new(mp.outputs[0], nz.inputs[0])
    nr = nt.nodes.new("ShaderNodeValToRGB")
    nr.color_ramp.elements[0].position = 0.5; nr.color_ramp.elements[0].color = (0, 0, 0, 1)
    nr.color_ramp.elements[1].position = 0.85; nr.color_ramp.elements[1].color = (*neb[0], 1)
    e = nr.color_ramp.elements.new(0.66); e.color = (*neb[1], 1)
    nt.links.new(nz.outputs["Fac"], nr.inputs[0])
    mul = nt.nodes.new("ShaderNodeMix"); mul.data_type = "RGBA"; mul.blend_type = "MULTIPLY"; mul.inputs[0].default_value = 1.0
    mul.inputs[6].default_value = (neb_k,)*3 + (1,)
    nt.links.new(nr.outputs[0], mul.inputs[7])
    add = nt.nodes.new("ShaderNodeMix"); add.data_type = "RGBA"; add.blend_type = "ADD"; add.inputs[0].default_value = 1.0
    st = nt.nodes.new("ShaderNodeMix"); st.data_type = "RGBA"; st.blend_type = "MULTIPLY"; st.inputs[0].default_value = 1.0
    st.inputs[6].default_value = (stars*2.2,)*3 + (1,)
    nt.links.new(sr.outputs[0], st.inputs[7])
    nt.links.new(mul.outputs[2], add.inputs[6]); nt.links.new(st.outputs[2], add.inputs[7])
    bg = nt.nodes.new("ShaderNodeBackground"); nt.links.new(add.outputs[2], bg.inputs[0])
    out = nt.nodes.new("ShaderNodeOutputWorld"); nt.links.new(bg.outputs[0], out.inputs[0])
    return w

def world_sky(elev=5.0, rot=0.0, dust=3.0, strength=1.0):
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    nt = w.node_tree; nt.nodes.clear()
    sk = nt.nodes.new("ShaderNodeTexSky"); sk.sky_type = "MULTIPLE_SCATTERING"
    sk.sun_elevation = math.radians(elev); sk.sun_rotation = rot; sk.aerosol_density = dust; sk.air_density = 1.0
    bg = nt.nodes.new("ShaderNodeBackground"); bg.inputs[1].default_value = strength
    nt.links.new(sk.outputs[0], bg.inputs[0])
    out = nt.nodes.new("ShaderNodeOutputWorld"); nt.links.new(bg.outputs[0], out.inputs[0])

def planet(loc, r, ramp, scale=2.2, atmo=(0.4, 0.7, 1.0), atmo_k=3.0, clouds=False, rough=0.8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=96, ring_count=48, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.name = "planet"
    for p in ob.data.polygons: p.use_smooth = True
    m = bpy.data.materials.new("planet"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise")
    nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 12; nz.inputs["Roughness"].default_value = 0.55
    nt.links.new(tc.outputs["Generated"], nz.inputs[0])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    els = cr.color_ramp.elements
    els[0].position = ramp[0][0]; els[0].color = (*ramp[0][1], 1)
    els[1].position = ramp[-1][0]; els[1].color = (*ramp[-1][1], 1)
    for pos, col in ramp[1:-1]:
        e = els.new(pos); e.color = (*col, 1)
    nt.links.new(nz.outputs["Fac"], cr.inputs[0]); nt.links.new(cr.outputs[0], b.inputs["Base Color"])
    ob.data.materials.append(m)
    if clouds:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r*1.012, segments=96, ring_count=48, location=loc)
        c = bpy.context.active_object; c.name = "clouds"
        for p in c.data.polygons: p.use_smooth = True
        cm = bpy.data.materials.new("clouds"); cm.use_nodes = True
        cnt = cm.node_tree; cb = cnt.nodes["Principled BSDF"]
        ctc = cnt.nodes.new("ShaderNodeTexCoord"); cn = cnt.nodes.new("ShaderNodeTexNoise")
        cn.inputs["Scale"].default_value = scale*1.3; cn.inputs["Detail"].default_value = 10
        cnt.links.new(ctc.outputs["Generated"], cn.inputs[0])
        cc = cnt.nodes.new("ShaderNodeValToRGB"); cc.color_ramp.elements[0].position = 0.5; cc.color_ramp.elements[1].position = 0.68
        cc.color_ramp.elements[0].color = (0, 0, 0, 1); cc.color_ramp.elements[1].color = (1, 1, 1, 1)
        cnt.links.new(cn.outputs["Fac"], cc.inputs[0]); cnt.links.new(cc.outputs[0], cb.inputs["Alpha"])
        cb.inputs["Base Color"].default_value = (1, 1, 1, 1); cb.inputs["Roughness"].default_value = 1.0
        c.data.materials.append(cm)
    # atmosphère : halo fresnel
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r*1.045, segments=96, ring_count=48, location=loc)
    a = bpy.context.active_object; a.name = "atmo"
    for p in a.data.polygons: p.use_smooth = True
    am = bpy.data.materials.new("atmo"); am.use_nodes = True
    ant = am.node_tree; ant.nodes.clear()
    lw = ant.nodes.new("ShaderNodeLayerWeight"); lw.inputs[0].default_value = 0.3
    pw = ant.nodes.new("ShaderNodeMath"); pw.operation = "POWER"; pw.inputs[1].default_value = 4.0
    ant.links.new(lw.outputs["Fresnel"], pw.inputs[0])
    inv = pw
    em = ant.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (*atmo, 1); em.inputs[1].default_value = atmo_k
    tr = ant.nodes.new("ShaderNodeBsdfTransparent")
    mx = ant.nodes.new("ShaderNodeMixShader")
    ant.links.new(inv.outputs[0], mx.inputs[0]); ant.links.new(tr.outputs[0], mx.inputs[1]); ant.links.new(em.outputs[0], mx.inputs[2])
    o = ant.nodes.new("ShaderNodeOutputMaterial"); ant.links.new(mx.outputs[0], o.inputs[0])
    am.blend_method = "BLEND" if hasattr(am, "blend_method") else None
    a.data.materials.append(am)
    return ob

def ground(size=200, color=(0.16, 0.15, 0.14), rough=0.95, bump=0.15, scale=6.0, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z))
    g = bpy.context.active_object; g.name = "ground"
    m = bpy.data.materials.new("ground"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]; b.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord"); nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = scale; nz.inputs["Detail"].default_value = 10
    nt.links.new(tc.outputs["Object"], nz.inputs[0])
    cr = nt.nodes.new("ShaderNodeValToRGB")
    cr.color_ramp.elements[0].color = (*[c*0.6 for c in color], 1); cr.color_ramp.elements[1].color = (*color, 1)
    nt.links.new(nz.outputs["Fac"], cr.inputs[0]); nt.links.new(cr.outputs[0], b.inputs["Base Color"])
    bm = nt.nodes.new("ShaderNodeBump"); bm.inputs["Strength"].default_value = bump
    nt.links.new(nz.outputs["Fac"], bm.inputs["Height"]); nt.links.new(bm.outputs[0], b.inputs["Normal"])
    g.data.materials.append(m)
    return g

def camera(loc, target, lens=28, roll=0.0):
    c = bpy.data.cameras.new("c"); c.sensor_fit = "HORIZONTAL"; c.sensor_width = 36; c.lens = lens
    co = bpy.data.objects.new("c", c); bpy.context.collection.objects.link(co); co.location = loc
    co.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    if roll: co.rotation_euler.rotate_axis("Z", roll)
    bpy.context.scene.camera = co
    return co

def render(name, res=(624, 1352), transparent=False, samples=None, view="AgX", look="None", exposure=0.0):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"; scn.cycles.device = "CPU"
    scn.cycles.samples = samples or SAMPLES
    scn.cycles.use_denoising = True
    scn.cycles.max_bounces = 6
    scn.render.resolution_x = int(res[0]*SCALE); scn.render.resolution_y = int(res[1]*SCALE)
    scn.render.film_transparent = transparent
    scn.view_settings.view_transform = view; scn.view_settings.exposure = exposure
    try: scn.view_settings.look = "AgX - Medium High Contrast" if look == "None" else look
    except TypeError: pass
    os.makedirs(OUT, exist_ok=True)
    scn.render.image_settings.file_format = "PNG" if transparent else "JPEG"
    if not transparent: scn.render.image_settings.quality = 88
    scn.render.filepath = os.path.join(OUT, name + (".png" if transparent else ".jpg"))
    bpy.ops.render.render(write_still=True)
    print("rendu", scn.render.filepath)

import characters
CHAR = {"captain": "captain", "crew_pilot": "rex", "crew_engineer": "bolt", "crew_scientist": "lyra", "rex": "rex", "bolt": "bolt", "lyra": "lyra", "vance": "vance", "nox": "nox"}
def person(kind, loc, rz, s=2.0, pose="idle"):
    """Personnage modélisé sur mesure (characters.py), hauteur ~1,7 m pour s=2."""
    r = characters.make(CHAR[kind], pose, s * 0.8)
    r.location = (loc[0], loc[1], loc[2] if len(loc) > 2 else 0.0); r.rotation_euler = (0, 0, rz)
    return r

def flame(loc, rz_rot, length, r, color=(0.5, 0.85, 1.0), k=14.0, soft=True):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=r, radius2=0.0, depth=length, location=loc)
    c = bpy.context.active_object
    c.rotation_euler = rz_rot
    m = bpy.data.materials.new("flame"); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs[0].default_value = (*color, 1); em.inputs[1].default_value = k
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs[0].default_value = 0.5
    inv = nt.nodes.new("ShaderNodeMath"); inv.operation = "SUBTRACT"; inv.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs["Facing"] if False else lw.outputs["Fresnel"], inv.inputs[1])
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(inv.outputs[0], mx.inputs[0]); nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2])
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(mx.outputs[0], o.inputs[0])
    c.data.materials.append(m)
    return c

def smoke_puffs(center, n, spread, rmin, rmax, seed=1, col=(0.8, 0.8, 0.82)):
    rng = random.Random(seed)
    m = bpy.data.materials.new("smoke"); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Roughness"].default_value = 1.0
    for i in range(n):
        r = rng.uniform(rmin, rmax)
        loc = (center[0]+rng.uniform(-spread, spread), center[1]+rng.uniform(-spread, spread), center[2]+rng.uniform(0, spread*0.6))
        bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=3, location=loc)
        o = bpy.context.active_object
        for p in o.data.polygons: p.use_smooth = True
        d = o.modifiers.new("d", "DISPLACE"); t = bpy.data.textures.new("t", "CLOUDS"); t.noise_scale = 0.8; d.texture = t; d.strength = r*0.5
        o.data.materials.append(m)

SCENES = {}
def scene(f): SCENES[f.__name__] = f; return f

# ---------------------------------------------------------------- scènes de l'espace
@scene
def cruise():
    reset(); world_space()
    s = ship((0, 0, 0), 0, 1.0, flame_len=2.0)
    planet((-60, 160, -40), 36, [(0.0, (0.05, 0.1, 0.35)), (0.5, (0.12, 0.35, 0.7)), (1.0, (0.7, 0.85, 0.95))], scale=5.0, atmo=(0.35, 0.6, 1.0), atmo_k=1.0)
    sun((math.radians(55), math.radians(10), math.radians(140)), 4.0, (1, 0.93, 0.85))
    area((-7, -6, 3), (0, 0, 0), 600, (0.4, 0.6, 1.0), 5)
    point((0, -4.2, 0), 500, (0.5, 0.9, 1.0), 0.6)
    camera((0.9, -8.6, 2.3), (0, 0.5, -0.2), 30)
    render("cruise")

@scene
def orbit():
    reset(); world_space(neb_k=0.3)
    planet((0, 0, -118), 100, [(0.0, (0.02, 0.1, 0.35)), (0.42, (0.05, 0.28, 0.6)), (0.5, (0.1, 0.35, 0.18)), (0.6, (0.3, 0.42, 0.2)), (0.72, (0.8, 0.78, 0.6)), (1.0, (0.95, 0.97, 1.0))], scale=5.0, atmo=(0.4, 0.7, 1.0), atmo_k=1.6, clouds=True)
    s = ship((2.0, 8, 3), 0.0, 1.0, flame_len=1.6)
    s.rotation_euler = (math.radians(8), 0, math.radians(-28))
    sun((math.radians(60), math.radians(-30), math.radians(35)), 3.0, (1, 0.95, 0.88))
    area((-6, -4, 10), (2.0, 8, 3), 500, (0.4, 0.6, 1.0), 5)
    camera((6.5, -6, 8), (1.0, 7, -0.5), 32)
    render("orbit")

@scene
def arrive():
    reset(); world_space(neb=((0.7, 0.35, 0.15), (0.25, 0.1, 0.4)), neb_k=0.5)
    planet((0, 40, -130), 120, [(0.0, (0.1, 0.12, 0.3)), (0.4, (0.15, 0.4, 0.55)), (0.55, (0.78, 0.6, 0.3)), (0.75, (0.9, 0.75, 0.5)), (1.0, (0.98, 0.9, 0.75))], scale=6.0, atmo=(1.0, 0.7, 0.4), atmo_k=1.5)
    s = ship((2.2, 2, 6.5), 0.0, 1.0, flame_len=1.2, flame_col=(1.0, 0.35, 0.05))
    s.rotation_euler = (math.radians(-12), math.radians(3), math.radians(-14))
    pass
    sun((math.radians(70), math.radians(10), math.radians(220)), 3.0, (1, 0.88, 0.7))
    area((-6, -4, 10), (2, 2, 6.5), 500, (0.4, 0.6, 1.0), 5)
    camera((5.5, -6, 8.5), (1.5, 2, 4.5), 30)
    render("arrive")


# ---------------------------------------------------------------- scènes au sol
ACCENTS = {"atelier": (1.0, 0.7, 0.42), "quartiers": (0.43, 1.0, 0.61), "labo": (0.5, 0.95, 1.0), "mine": (0.88, 0.72, 0.47), "centrale": (0.78, 0.6, 1.0), "soute": (1.0, 0.82, 0.35), "pad": (1.0, 0.55, 0.5)}

def launch_site(sun_elev=3.0, sun_az=3.4, dust=5.0, ship_pos=(0, 0, 1.9), ship_rz=math.radians(-90), pitch=0.0, flame_len=0.0, s=1.4, flame_col=(0.04, 0.45, 1.0)):
    world_sky(sun_elev, sun_az, dust, 0.5)
    ground(200, (0.16, 0.15, 0.15), 0.9, 0.12, 5.0)
    box("slab", (18, 13, 0.5), (0, 0, 0.25), material=solid("slab", (0.2, 0.21, 0.23), 0.8), bevel=0.0)
    for sy in (-6.3, 6.3):
        box("edge", (17.4, 0.12, 0.06), (0, sy, 0.53), material=emissive("edge", (1.0, 0.65, 0.2), 5.0), bevel=0.0)
    for sx, sy in ((-1, -1), (1, -1), (0, 1.3)):
        cyl("leg", 0.12, 0.2, 0.9, (ship_pos[0] + sx*2.0, ship_pos[1] + sy*1.4, 0.95), axis="Z", seg=10, material=solid("leg", (0.3, 0.32, 0.36), 0.6, 0.5))
    sh = ship(ship_pos, ship_rz, s, pitch, flame_len=flame_len, flame_col=flame_col)
    for hx in (-24, 4, 30):
        imp("hangar_largeA", (hx, 34, 0), math.radians(180), 5.5)
    imp("structure_detailed", (-9, 18, 0), 0, 9)
    imp("structure_diagonal", (-9, 18, 9), 0, 9)
    imp("satelliteDish_large", (22, 20, 0), math.radians(200), 5.0)
    imp("machine_generatorLarge", (13, 16, 0), 0.5, 5.0)
    for k in range(5):
        imp("barrels", (-14 + k*2.2, 10, 0), k, 2.5)
    for hx in (-60, -35, 50, 70):
        imp("rock_largeB", (hx, 70, 0), hx*0.1, 14)
    return sh

@scene
def pad():
    reset(); launch_site(2.0, math.radians(215), 6.0, ship_rz=math.radians(-60), s=1.9)
    person("captain", (-5.8, -8.0, 0.5), math.radians(40), 2.1)
    area((-7, -9, 5), (0, 0, 1.8), 900, (1.0, 0.75, 0.55), 5)
    area((8, -6, 3), (0, 0, 1.8), 400, (0.5, 0.7, 1.0), 5)
    camera((-10.5, -14.0, 3.0), (1.5, 0.0, 2.4), 27)
    render("pad", exposure=-0.5)

@scene
def launch():
    reset(); launch_site(10.0, math.radians(215), 3.0, ship_pos=(0, 2, 8.5), ship_rz=math.radians(-90), pitch=0.0, flame_len=7.0, flame_col=(1.0, 0.2, 0.02), s=1.8)
    sh = [o for o in bpy.data.objects if o.name == "ship"][0]
    sh.rotation_euler = (math.radians(35), 0, math.radians(-90))
    smoke_puffs((-1, 2, 0.8), 18, 4.0, 0.8, 1.7, 4, col=(0.2, 0.18, 0.17))
    point((-3, 2, 5.0), 3500, (1.0, 0.5, 0.15), 1.5)
    area((-5, -7, 6), (0, 2, 7), 1000, (1.0, 0.7, 0.45), 6)
    camera((-7, -11, 3.0), (2.0, 2, 6.0), 26)
    render("launch", exposure=-0.8)

def lab_room(color=(0.05, 0.07, 0.1)):
    w = solid("wall", color, 0.5, 0.6)
    box("floor", (14, 14, 0.2), (0, 0, -0.1), material=solid("floor", (0.05, 0.06, 0.08), 0.4, 0.5), bevel=0.0)
    box("wallL", (0.3, 14, 5), (-6, 0, 2.5), material=w, bevel=0.0)
    box("wallR", (0.3, 14, 5), (6, 0, 2.5), material=w, bevel=0.0)
    box("ceil", (14, 14, 0.2), (0, 0, 5), material=w, bevel=0.0)

@scene
def briefing():
    reset()
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.015, 0.03, 1)
    lab_room()
    box("wallB", (14, 0.3, 5), (0, 7, 2.5), material=solid("wallB", (0.05, 0.07, 0.1), 0.5, 0.6), bevel=0.0)
    # baie vitrée côté fond avec la Terre au loin
    box("bay", (9, 0.1, 3.0), (0, 6.8, 2.7), material=emissive("bay", (0.05, 0.12, 0.28), 1.2), bevel=0.0)
    for k in range(5): box("rib%d" % k, (0.15, 0.25, 3.2), (-4 + k*2.0, 6.7, 2.7), material=solid("rib", (0.1, 0.12, 0.16), 0.7, 0.4), bevel=0.0)
    # table holographique
    cyl("tbase", 1.5, 1.3, 0.9, (0, 0, 0.45), axis="Z", seg=48, material=solid("tbase", (0.07, 0.1, 0.14), 0.8, 0.3))
    cyl("tring", 1.55, 1.55, 0.06, (0, 0, 0.93), axis="Z", seg=48, material=emissive("tring", (0.3, 0.9, 1.0), 6.0))
    planet((0, 0, 1.9), 0.62, [(0.0, (0.02, 0.2, 0.55)), (0.5, (0.1, 0.5, 0.9)), (0.56, (0.2, 0.6, 0.35)), (0.75, (0.5, 0.9, 1.0)), (1.0, (0.8, 1.0, 1.0))], scale=4.0, atmo=(0.4, 0.9, 1.0), atmo_k=2.0)
    for ob in [o for o in bpy.data.objects if o.name.startswith("planet")]:
        ob.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = (0.1, 0.5, 0.9, 1)
        ob.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = 1.2
    for r_, z_, k_ in ((1.05, 1.9, 4.0), (1.35, 1.9, 2.0)):
        t = bpy.ops.mesh.primitive_torus_add(major_radius=r_, minor_radius=0.012, major_segments=96, minor_segments=8, location=(0, 0, z_), rotation=(math.radians(70), 0, math.radians(20)))
        bpy.context.active_object.data.materials.append(emissive("orb", (0.5, 0.95, 1.0), 6.0))
    sphere("marker", 0.07, (1.35, 0.1, 2.25), material=emissive("mk", (1.0, 0.82, 0.35), 12.0))
    person("captain", (0.0, -2.3, 0), 0, 2.1)
    person("rex", (2.2, -0.5, 0), math.radians(90), 2.0)
    person("bolt", (-2.2, -0.5, 0), math.radians(-90), 2.0, "idle")
    person("lyra", (-1.3, 1.9, 0), math.radians(-150), 2.0, "think")
    person("vance", (1.2, 1.9, 0), math.radians(160), 2.1, "point")
    point((0, 0, 2.0), 700, (0.3, 0.8, 1.0), 0.5)
    area((0, -6.0, 4.6), (0, 0, 1.2), 350, (1.0, 0.85, 0.7), 4)
    area((0, 6.0, 3.5), (0, 0, 1.2), 220, (0.4, 0.6, 1.0), 6)
    camera((0.9, -6.4, 2.6), (0, 0.4, 1.35), 26)
    render("briefing")

@scene
def cockpit():
    reset(); world_sky(3.0, math.radians(215), 6.0, 0.6)
    ground(200, (0.22, 0.2, 0.19), 0.9, 0.12, 5.0, z=-3.0)
    imp("platform_large", (0, 14, -2.9), 0, 6)
    for hx in (-18, 6, 28):
        imp("hangar_largeA", (hx, 38, -3.0), math.radians(180), 5.5)
    imp("structure_detailed", (-6, 24, -3.0), 0, 9)
    imp("satelliteDish_large", (14, 26, -3.0), math.radians(200), 5.0)
    dark = solid("cabin", (0.04, 0.05, 0.07), 0.5, 0.45)
    box("floor", (6, 6, 0.2), (0, -0.5, -0.1), material=dark, bevel=0.0)
    box("ceil", (6, 6, 0.2), (0, -0.5, 3.1), material=dark, bevel=0.0)
    box("wallL", (0.3, 6, 3.2), (-3, -0.5, 1.5), material=dark, bevel=0.0)
    box("wallR", (0.3, 6, 3.2), (3, -0.5, 1.5), material=dark, bevel=0.0)
    box("pillarL", (0.35, 0.35, 3.2), (-2.4, 2.4, 1.5), (0, 0, 0), dark, 0.0)
    box("pillarR", (0.35, 0.35, 3.2), (2.4, 2.4, 1.5), (0, 0, 0), dark, 0.0)
    box("header", (5.2, 0.4, 0.5), (0, 2.4, 2.8), material=dark, bevel=0.0)
    box("dash", (5.4, 1.1, 0.9), (0, 2.1, 0.45), material=dark, bevel=0.02)
    for sx in (-1.5, 0.0, 1.5):
        box("scr", (1.1, 0.04, 0.5), (sx, 1.55, 0.95), (math.radians(-22), 0, 0), emissive("scr", (0.2, 0.8, 1.0) if sx != 0 else (1.0, 0.6, 0.2), 3.0), 0.0)
    for sx in (-1.1, 1.1):
        imp("desk_chairArms", (sx, 0.1, 0), math.radians(0), 1.5)
    person("rex", (-1.1, 0.25, 0.05), 0, 1.8, "work")
    person("bolt", (1.1, 0.25, 0.05), 0, 1.8, "work")
    point((0, 1.2, 1.8), 120, (0.5, 0.8, 1.0), 0.4)
    camera((0.0, -3.0, 1.7), (0.0, 3.0, 1.3), 22)
    render("cockpit")

# ---------------------------------------------------------------- la Base
def tent(loc, rz=0.0, col=(0.85, 0.55, 0.25)):
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=1.4, radius2=0.1, depth=1.9, location=(loc[0], loc[1], 0.95), rotation=(0, 0, rz))
    t = bpy.context.active_object; put(t, solid("tent", col, 0.9)); t.data.polygons[0].use_smooth = False
    box("door", (0.5, 0.05, 0.8), (loc[0], loc[1] - 1.18, 0.4), (0, 0, rz), solid("door", (0.04, 0.05, 0.06), 0.9), 0.0)

def scaffold(loc, col, h=2.2, w=3.0):
    m = solid("scaf", (1.0, 0.55, 0.15), 0.6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("post", (0.12, 0.12, h), (loc[0] + sx*w/2, loc[1] + sy*w/2, h/2), material=m, bevel=0.0)
    for z in (h*0.5, h):
        for sx in (-1, 1):
            box("beamy", (0.1, w, 0.1), (loc[0] + sx*w/2, loc[1], z), material=m, bevel=0.0)
            box("beamx", (w, 0.1, 0.1), (loc[0], loc[1] + sx*w/2, z), material=m, bevel=0.0)
    box("slab", (w*0.9, w*0.9, 0.16), (loc[0], loc[1], 0.08), material=solid("slab", (0.3, 0.3, 0.32), 0.8), bevel=0.0)
    cyl("crane", 0.07, 0.07, 3.6, (loc[0] + w/2, loc[1], h + 0.9), axis="Z", seg=8, material=m)
    box("jib", (2.4, 0.1, 0.1), (loc[0] + w/2 - 0.9, loc[1], h + 2.6), material=m, bevel=0.0)

def plot_marker(loc, col):
    m = emissive("pm", col, 3.0)
    w = 3.4
    box("pmfill", (w, w, 0.03), (loc[0], loc[1], 0.015), material=solid("pf", (0.12, 0.14, 0.16), 0.9), bevel=0.0)
    for sx in (-1, 1):
        box("pmy", (0.07, w, 0.05), (loc[0] + sx*w/2, loc[1], 0.04), material=m, bevel=0.0)
        box("pmx", (w, 0.07, 0.05), (loc[0], loc[1] + sx*w/2, 0.04), material=m, bevel=0.0)

def building(kind, loc, rz=0.0, level=1):
    import buildings
    objs = buildings.build(kind, level, ACCENTS[kind])
    group(objs, kind, (loc[0], loc[1], 0.0), rz, 0.92 * buildings.level_scale(level), center=False)

def building_kenney(kind, loc, rz=0.0):
    x, y = loc[0], loc[1]
    tag = ACCENTS[kind]
    if kind == "atelier":
        imp("hangar_smallA", (x, y, 0), rz, 2.1)
        imp("machine_wireless", (x + 1.7, y - 0.8, 0), 0.4, 1.8)
        imp("barrels", (x - 1.6, y - 1.5, 0), 0.2, 1.6)
        box("lamp", (0.9, 0.06, 0.18), (x, y - 1.42, 1.95), material=emissive("t", tag, 5.0), bevel=0.0)
    elif kind == "quartiers":
        imp("hangar_roundA", (x, y, 0), rz, 1.6)
        imp("corridor_window", (x + 2.0, y + 0.2, 0), math.radians(90), 1.5)
        imp("corridor_windowClosed", (x - 2.0, y + 0.2, 0), math.radians(90), 1.5)
        box("lamp", (1.0, 0.06, 0.18), (x, y - 1.9, 2.1), material=emissive("t", tag, 5.0), bevel=0.0)
    elif kind == "labo":
        imp("hangar_roundGlass", (x, y, 0), rz, 1.6)
        imp("satelliteDish_large", (x + 1.7, y + 1.2, 0), 0.6, 2.6)
        imp("desk_computer", (x - 1.7, y - 1.2, 0), 0.3, 2.2)
        box("lamp", (1.0, 0.06, 0.18), (x, y - 1.9, 2.0), material=emissive("t", tag, 5.0), bevel=0.0)
    elif kind == "mine":
        imp("platform_large", (x, y, 0), 0, 2.0)
        imp("rock_crystalsLargeA", (x - 0.9, y + 0.6, 0.1), 0.3, 3.3)
        imp("rock_crystals", (x + 1.0, y + 0.8, 0.1), 1.3, 3.0)
        imp("machine_barrelLarge", (x + 1.0, y - 0.7, 0.1), 0.0, 2.6)
        imp("monorail_trackStraight", (x - 1.0, y - 1.0, 0.0), math.radians(90), 2.5)
        box("lamp", (0.9, 0.06, 0.18), (x, y - 1.55, 0.5), material=emissive("t", tag, 5.0), bevel=0.0)
    elif kind == "centrale":
        imp("machine_generatorLarge", (x, y, 0), rz, 3.6)
        imp("chimney_detailed", (x + 1.4, y + 1.2, 0), 0, 2.4)
        imp("pipe_straight", (x - 1.7, y, 0), math.radians(90), 2.0)
        box("lamp", (0.9, 0.06, 0.18), (x, y - 1.5, 1.9), material=emissive("t", tag, 5.0), bevel=0.0)
    elif kind == "soute":
        imp("hangar_largeA", (x, y, 0), rz, 1.85)
        for k in range(3): imp("barrels", (x - 1.5 + k*1.3, y - 2.0, 0), k, 1.5)
        box("lamp", (1.0, 0.06, 0.18), (x, y - 1.55, 2.0), material=emissive("t", tag, 5.0), bevel=0.0)

SPOTS = [(-4.5, -6.4), (4.5, -6.4), (-4.5, -2.1), (4.5, -2.1), (-4.5, 2.2), (4.5, 2.2), (-4.5, 6.5), (4.5, 6.5)]
LEVELS = {"atelier": 12, "quartiers": 4, "labo": 20, "mine": 7, "centrale": 10, "soute": 3, "pad": 1}
KINDS = ["atelier", "quartiers", "labo", "mine", "centrale", "soute", "pad"]

def base_env(elev=14.0):
    world_sky(elev, math.radians(205), 2.5, 0.35)
    ground(3000, (0.42, 0.29, 0.19), 0.95, 0.35, 3.0)
    for hx, hy, hs in ((-40, 60, 18), (-10, 70, 20), (30, 64, 17), (60, 70, 22), (-70, 55, 15)):
        imp("rock_largeA", (hx, hy, 0), hx, hs)
    imp("craterLarge", (-22, 24, 0), 0, 6)
    rng = random.Random(7)
    for k in range(46):
        x, y = rng.uniform(-30, 30), rng.uniform(-14, 40)
        if (abs(x) < 9.5 and -9 < y < 11) or y < -7: continue
        imp(rng.choice(["rocks_smallA", "rocks_smallB", "rock"]), (x, y, 0), rng.uniform(0, 6), rng.uniform(1.2, 3.2))
    sh = ship((0, 16.5, 1.0), math.radians(180), 1.5)
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        cyl("leg", 0.08, 0.08, 1.0, (sx*1.6, 16.5 + sy*1.4, 0.5), axis="Z", seg=8, material=solid("leg", (0.4, 0.42, 0.46), 0.6, 0.5))
    # lunes
    sphere("moon1", 11, (-70, 260, 90), material=emissive("moon", (0.8, 0.88, 1.0), 6.0))
    sphere("moon2", 5, (-135, 230, 40), material=emissive("moon2", (0.75, 0.8, 0.95), 5.0))

def base_cam():
    camera((0, -15.0, 13.5), (0, 2.6, 0.3), 28)

def stage_people(positions, kinds=("captain", "crew_pilot", "crew_engineer", "crew_scientist", "crew_pilot", "crew_engineer")):
    for (x, y, rz), k in zip(positions, kinds):
        person(k, (x, y, 0), rz, 2.0)

@scene
def base_0():
    reset(); base_env()
    for (x, y), k in zip(SPOTS, KINDS): plot_marker((x, y), ACCENTS[k])
    plot_marker(SPOTS[7], (0.6, 0.65, 0.7))
    tent((-2.0, 9.5), 0.2); tent((0.8, 10.4), 0.0, (0.7, 0.5, 0.3)); tent((3.5, 9.5), -0.3)
    for k in range(3): imp("barrels", (-5.5 + k*1.2, 8.0, 0), k, 1.8)
    point((0.8, 8.4, 0.8), 140, (1.0, 0.6, 0.25), 0.4)
    sphere("fire", 0.22, (0.8, 8.4, 0.25), material=emissive("fire", (1.0, 0.5, 0.15), 12.0))
    stage_people([(-0.6, 7.2, math.radians(-30)), (1.3, 7.4, math.radians(25)), (0.4, 6.1, 0.0)], ("captain", "crew_pilot", "crew_engineer"))
    sun((math.radians(55), 0, math.radians(30)), 1.6, (1, 0.8, 0.6))
    base_cam(); render("base_0", exposure=-0.9)

@scene
def base_1():
    reset(); base_env()
    building("atelier", (*SPOTS[0], 0)[:2], 0)
    scaffold(SPOTS[6], ACCENTS["pad"])
    for (x, y), k in list(zip(SPOTS, KINDS))[1:6]: plot_marker((x, y), ACCENTS[k])
    plot_marker(SPOTS[7], (0.6, 0.65, 0.7))
    tent((-2.0, 9.5), 0.2); tent((0.8, 10.4), 0.0, (0.7, 0.5, 0.3))
    stage_people([(-1.0, 7.0, math.radians(-30)), (3.2, -1.8, math.radians(90)), (-2.8, -2.6, 0.0), (4.2, -3.0, math.radians(-90))], ("captain", "crew_engineer", "crew_pilot", "crew_scientist"))
    sun((math.radians(55), 0, math.radians(30)), 1.6, (1, 0.8, 0.6))
    base_cam(); render("base_1", exposure=-0.9)

@scene
def base_2():
    reset(); base_env()
    for (x, y), k in zip(SPOTS, KINDS): building(k, (x, y), 0, LEVELS[k])
    plot_marker(SPOTS[7], (0.6, 0.65, 0.7))
    scaffold((0, 8.0), ACCENTS["soute"], h=1.8, w=2.4) if False else None
    stage_people([(0.0, 3.0, 0.0), (2.0, 7.0, math.radians(90)), (-2.0, 7.2, math.radians(-90)), (0.0, -1.2, math.radians(180)), (1.4, -4.8, math.radians(30)), (-1.6, 5.0, 0.0)])
    sun((math.radians(55), 0, math.radians(30)), 1.6, (1, 0.8, 0.6))
    base_cam(); render("base_2", exposure=-0.9)

@scene
def base_proj():
    """Écrit base_plots.json : position écran (0..1) du centre et des 4 coins de chaque emplacement, pour caler les surcouches de la maquette."""
    import json
    from bpy_extras.object_utils import world_to_camera_view
    reset(); base_cam()
    scn = bpy.context.scene; scn.render.resolution_x = 624; scn.render.resolution_y = 1352
    bpy.context.view_layer.update(); cam = scn.camera; res = []
    for (x, y) in SPOTS:
        pts = []
        for dx, dy in ((0, 0), (-1.7, 0), (0, -1.7), (1.7, 0), (0, 1.7)):
            v = world_to_camera_view(scn, cam, Vector((x + dx, y + dy, 0.0)))
            pts.append([round(v.x, 4), round(1 - v.y, 4)])
        res.append(pts)
    os.makedirs(OUT, exist_ok=True)
    json.dump(res, open(os.path.join(OUT, "base_plots.json"), "w"))
    print("rendu", os.path.join(OUT, "base_plots.json"))

# ---------------------------------------------------------------- décors du tutoriel
def dark_world(col=(0.01, 0.015, 0.03)):
    w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*col, 1)

def room(w=10, d=12, h=4.0, col=(0.05, 0.07, 0.1)):
    m = solid("wall", col, 0.5, 0.55)
    box("floor", (w, d, 0.2), (0, 0, -0.1), material=solid("floor", (0.05, 0.06, 0.08), 0.35, 0.5), bevel=0.0)
    box("wallL", (0.3, d, h), (-w/2, 0, h/2), material=m, bevel=0.0)
    box("wallR", (0.3, d, h), (w/2, 0, h/2), material=m, bevel=0.0)
    box("wallB", (w, 0.3, h), (0, d/2, h/2), material=m, bevel=0.0)
    box("ceil", (w, d, 0.2), (0, 0, h), material=m, bevel=0.0)
    for k in range(5):
        box("trim", (0.12, 0.12, h), (-w/2 + 0.2, -d/2 + 1 + k*(d-2)/4, h/2), material=emissive("trim", (0.2, 0.8, 1.0), 2.5), bevel=0.0)

def holo_panel(loc, size, rot, col=(0.3, 0.9, 1.0), k=3.0):
    return box("holo", (size[0], 0.02, size[1]), loc, rot, emissive("holo", col, k), 0.0)

@scene
def engine_room():
    reset(); dark_world(); room(11, 12, 4.4)
    cyl("core", 0.8, 0.8, 3.6, (0, 1.5, 1.8), axis="Z", seg=48, material=emissive("core", (0.2, 0.75, 1.0), 4.0))
    for z_ in (0.4, 1.4, 2.4, 3.4):
        bpy.ops.mesh.primitive_torus_add(major_radius=1.15, minor_radius=0.09, major_segments=48, minor_segments=12, location=(0, 1.5, z_))
        bpy.context.active_object.data.materials.append(solid("ring", (0.15, 0.18, 0.22), 0.9, 0.3))
    cyl("base", 1.6, 1.8, 0.3, (0, 1.5, 0.15), axis="Z", seg=48, material=solid("base", (0.1, 0.12, 0.15), 0.8, 0.35))
    imp("machine_generatorLarge", (-3.6, 2.5, 0), math.radians(90), 3.0)
    imp("machine_generatorLarge", (3.6, 2.5, 0), math.radians(-90), 3.0)
    for k in range(3):
        imp("pipe_straight", (-4.6, -2 + k*2.2, 2.6), math.radians(90), 2.2)
    imp("desk_computer", (2.6, -1.2, 0), math.radians(-30), 3.0)
    person("rex", (1.4, -1.8, 0), math.radians(-150), 2.0, "idle")
    person("bolt", (-1.6, -0.6, 0), math.radians(110), 2.0, "work")
    point((0, 1.5, 1.8), 900, (0.3, 0.8, 1.0), 0.6)
    area((0, -5.5, 3.8), (0, 1, 1.2), 300, (1.0, 0.8, 0.6), 4)
    camera((1.7, -3.4, 1.7), (-0.2, 1.4, 1.5), 21)
    render("engine_room")

@scene
def combat():
    reset(); world_space(neb=((0.5, 0.2, 0.25), (0.1, 0.2, 0.5)), neb_k=0.22)
    s = ship((0, 0, 0), 0, 1.0, flame_len=2.0)
    rng = random.Random(11)
    for k in range(9):
        a = rng.choice(["asteroid1", "asteroid2", "asteroid3"])
        imp(a, (rng.uniform(-14, 14), rng.uniform(10, 40), rng.uniform(-6, 6)), rng.uniform(0, 6), rng.uniform(1.6, 3.4), models=True)
    for ex, ey, ez in ((-5, 24, 1), (4, 28, -1), (0, 20, 3)):
        e = imp("enemy", (ex, ey, ez), math.radians(180), 1.3, models=True)
        point((ex, ey - 1.2, ez), 120, (1.0, 0.2, 0.1), 0.3)
        sphere("halo", 0.35, (ex, ey - 1.0, ez), material=emissive("eh", (1.0, 0.25, 0.1), 6.0))
    for tx, ty, tz in ((-5, 24, 1), (0, 20, 3)):
        d = Vector((tx, ty, tz)) - Vector((0, 2.5, 0)); L = d.length
        bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=L, location=Vector((0, 2.5, 0)) + d/2)
        c = bpy.context.active_object; c.rotation_euler = d.to_track_quat("Z", "Y").to_euler(); c.data.materials.append(emissive("laser", (0.3, 1.0, 1.0), 14.0))
    sphere("boom", 1.0, (4, 28, -1), material=emissive("boom", (1.0, 0.6, 0.15), 12.0))
    sun((math.radians(55), math.radians(10), math.radians(140)), 3.5, (1, 0.93, 0.85))
    area((-7, -6, 3), (0, 0, 0), 600, (0.4, 0.6, 1.0), 5)
    point((0, -4.2, 0), 500, (0.5, 0.9, 1.0), 0.6)
    camera((0.7, -6.4, 2.4), (0, 7.0, 0.8), 28)
    render("combat")

@scene
def armory():
    reset(); dark_world(); room(9, 9, 3.8, (0.06, 0.07, 0.1))
    for k in range(4):
        box("locker", (1.0, 0.6, 2.6), (-3.6 + k*1.15, 4.0, 1.3), material=solid("lk", (0.12, 0.15, 0.2), 0.6, 0.4), bevel=0.02)
        box("lkl", (0.8, 0.02, 0.08), (-3.6 + k*1.15, 3.68, 2.2), material=emissive("lkl", (1.0, 0.8, 0.3) if k == 1 else (0.2, 0.8, 1.0), 4.0), bevel=0.0)
    cyl("ped", 0.55, 0.65, 0.9, (2.0, 1.2, 0.45), axis="Z", seg=32, material=solid("ped", (0.1, 0.12, 0.16), 0.8, 0.3))
    cyl("pring", 0.7, 0.7, 0.04, (2.0, 1.2, 0.92), axis="Z", seg=32, material=emissive("pring", (1.0, 0.82, 0.3), 6.0))
    sphere("visor", 0.28, (2.0, 1.2, 1.5), (1.0, 1.0, 0.8), emissive("visor", (1.0, 0.8, 0.3), 3.0))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.34, minor_radius=0.03, major_segments=40, minor_segments=8, location=(2.0, 1.2, 1.5), rotation=(math.radians(80), 0, 0))
    bpy.context.active_object.data.materials.append(emissive("vr", (1.0, 0.9, 0.5), 8.0))
    imp("barrels", (-3.5, -1.0, 0), 0.5, 2.6)
    person("captain", (-0.2, -0.2, 0), math.radians(200), 2.4, "salute")
    point((2.0, 1.2, 1.6), 600, (1.0, 0.8, 0.4), 0.4)
    area((0, -4.0, 3.3), (0, 1, 1.2), 300, (0.8, 0.9, 1.0), 4)
    camera((0.3, -3.3, 1.4), (0.5, 0.6, 1.2), 30)
    render("armory")

@scene
def lab():
    reset(); dark_world(); room(10, 10, 4.0, (0.05, 0.07, 0.1))
    box("bench", (4.6, 1.2, 0.9), (0, 2.0, 0.45), material=solid("bench", (0.1, 0.12, 0.16), 0.7, 0.35), bevel=0.02)
    for k, c in enumerate(((0.3, 0.9, 1.0), (0.4, 1.0, 0.6), (1.0, 0.8, 0.3))):
        holo_panel((-1.5 + k*1.5, 1.2, 1.9 + (k % 2)*0.2), (1.2, 0.9), (math.radians(80), 0, math.radians(-14 + k*14)), c, 2.6)
    imp("desk_computer", (-1.6, 1.8, 0.9), math.radians(180), 2.4)
    imp("satelliteDish_large", (3.8, 3.2, 0), math.radians(200), 2.8)
    planet((1.3, 2.0, 1.6), 0.38, [(0.0, (0.1, 0.4, 0.6)), (0.6, (0.3, 0.9, 0.8)), (1.0, (0.8, 1.0, 1.0))], scale=4.0, atmo=(0.4, 0.9, 1.0), atmo_k=1.5)
    person("lyra", (-0.2, 0.3, 0), math.radians(10), 2.1, "work")
    person("captain", (1.8, -0.8, 0), math.radians(20), 2.1, "think")
    point((0, 1.5, 2.0), 500, (0.4, 0.9, 1.0), 0.5)
    area((0, -4.5, 3.6), (0, 1, 1.2), 300, (1.0, 0.85, 0.7), 4)
    camera((0.5, -3.7, 1.6), (0.1, 1.6, 1.3), 29)
    render("lab")

DRIFT_REV = {1, 2, 3, 6, 7, 8, 11, 12, 13, 17, 18, 19}
DRIFT_RES = {3, 12, 18}
DRIFT_SCALE = 5.6
DRIFT_CAM_Y = 0.12

@scene
def drift():
    reset(); world_space(neb_k=0.2)
    rng = random.Random(5)
    for k in range(6):
        imp(rng.choice(["asteroid1", "asteroid2", "asteroid3"]), (rng.choice([-5.5, 5.5]) + rng.uniform(-1, 1), rng.uniform(-5, 4), -3 - rng.uniform(0, 2)), rng.uniform(0, 6), rng.uniform(1.4, 2.4), models=True)
    box("deck", (5.7, 5.7, 0.1), (0, 0, -0.06), material=solid("deck", (0.02, 0.05, 0.1), 0.2, 0.3), bevel=0.0)
    for j in range(5):
        for c in range(5):
            i = j*5 + c; X = c - 2; Y = 2 - j
            if i in DRIFT_RES: col, k_ = (0.2, 1.0, 0.5), 2.4
            elif i in DRIFT_REV: col, k_ = (0.12, 0.45, 0.65), 0.7
            else: col, k_ = (0.05, 0.14, 0.24), 0.18
            box("cell", (0.9, 0.9, 0.12), (X, Y, 0.02), material=emissive("cell", col, k_), bevel=0.0)
            if i in DRIFT_RES: imp("rock_crystals", (X, Y, 0.08), rng.uniform(0, 6), 1.1)
    point((0, 0, 3.0), 400, (0.5, 0.8, 1.0), 1.0)
    sun((math.radians(30), 0, math.radians(30)), 2.0, (0.8, 0.9, 1.0))
    c = camera((0, DRIFT_CAM_Y, 12.0), (0, DRIFT_CAM_Y, 0), 40)
    c.data.type = "ORTHO"; c.data.ortho_scale = DRIFT_SCALE
    c.rotation_euler = (0, 0, 0)
    render("drift")

@scene
def rift():
    reset(); world_space(neb=((0.45, 0.15, 0.8), (0.1, 0.5, 0.7)), neb_k=0.5)
    n = 16
    for k in range(n):
        r = 7.0 - k*0.42
        y = 14 + k*2.4
        t = k / (n - 1)
        col = (0.25 + 0.5*t, 0.2 + 0.3*(1 - t), 1.0 - 0.2*t)
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.12 + 0.02*k, major_segments=64, minor_segments=10, location=(0, y, 0.5), rotation=(math.radians(90), 0, k*0.2))
        bpy.context.active_object.data.materials.append(emissive("rift", col, 2.0 + 0.5*k))
    sphere("core", 1.6, (0, 14 + n*2.4, 0.5), (1, 1, 1), emissive("core", (1.0, 1.0, 1.0), 20.0))
    ship((0, 0, -1.6), 0, 0.8, flame_len=1.6)
    area((-5, -5, 3), (0, 0, 0), 500, (0.5, 0.5, 1.0), 5)
    point((0, 11, 0.5), 3000, (0.6, 0.4, 1.0), 1.5)
    camera((0.4, -6.2, 0.6), (0, 14, 0.6), 30)
    render("rift")

ROUTE = [(-2.6, -3.6), (-0.8, -2.2), (1.8, -2.9), (2.6, -0.4), (0.9, 1.2), (-1.7, 1.6), (-0.4, 3.7)]
@scene
def route():
    reset(); dark_world((0.008, 0.012, 0.03))
    cyl("table", 4.6, 4.8, 0.3, (0, 0, -0.15), axis="Z", seg=64, material=solid("table", (0.05, 0.07, 0.1), 0.8, 0.3))
    bpy.ops.mesh.primitive_torus_add(major_radius=4.7, minor_radius=0.05, major_segments=96, minor_segments=8, location=(0, 0, 0.03))
    bpy.context.active_object.data.materials.append(emissive("tring", (0.3, 0.9, 1.0), 4.0))
    rng = random.Random(3)
    for k in range(40):
        sphere("star", 0.025, (rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(0.2, 1.6)), material=emissive("st", (0.7, 0.9, 1.0), 6.0))
    pts = [Vector((x, y, 0.35)) for x, y in ROUTE]
    for a, b in zip(pts, pts[1:]):
        d = b - a
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=d.length, location=a + d/2)
        c = bpy.context.active_object; c.rotation_euler = d.to_track_quat("Z", "Y").to_euler(); c.data.materials.append(emissive("rl", (0.3, 0.9, 1.0), 5.0))
    for idx, p in enumerate(pts):
        if idx < 3: col, r_ = (0.3, 1.0, 0.55), 0.2
        elif idx == 3: col, r_ = (1.0, 0.8, 0.25), 0.3
        elif idx < 6: col, r_ = (0.4, 0.9, 1.0), 0.2
        else: col, r_ = (1.0, 0.25, 0.2), 0.42
        sphere("node", r_, p, material=emissive("nd", col, 6.0))
        if idx == 3:
            bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.03, major_segments=40, minor_segments=8, location=p)
            bpy.context.active_object.data.materials.append(emissive("sel", (1.0, 0.85, 0.3), 8.0))
    ship(pts[3] + Vector((0, 0, 0.5)), 0, 0.14)
    point((0, 0, 3.0), 400, (0.4, 0.9, 1.0), 1.0)
    camera((0, -6.0, 5.4), (0, 0.5, 0.2), 27)
    render("route")

# ---------------------------------------------------------------- icônes et portraits (fond transparent)
def catcher():
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    g = bpy.context.active_object; g.is_shadow_catcher = True

def icon_rig(target, dist=1.0):
    world = bpy.data.worlds.new("w"); bpy.context.scene.world = world; world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.3, 0.4, 0.6, 1); world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    sun((math.radians(50), math.radians(0), math.radians(-35)), 3.5, (1, 0.93, 0.82))
    area((-6, 4, 5), target, 250, (0.5, 0.7, 1.0), 6)

def make_icon(kind, level):
    def f():
        reset(); catcher(); icon_rig((0, 0, 1.0))
        building(kind, (0, 0), 0, level)
        camera((5.3, -6.3, 4.6), (0, 0, 1.25), 38)
        render("i_%s_%d" % (kind, level) if level != 1 else "i_" + kind, res=(480, 480), transparent=True)
    return f
for _k in KINDS + ["pad"]:
    SCENES["icon_" + _k] = make_icon(_k, 1)
    for _l in (10, 20): SCENES["icon_%s_%d" % (_k, _l)] = make_icon(_k, _l)

def make_portrait(kind):
    def f():
        reset(); catcher()
        w = bpy.data.worlds.new("w"); bpy.context.scene.world = w; w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.3, 0.45, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.5
        person(kind, (0, 0, 0), math.radians(18), 2.0, "idle")
        sun((math.radians(55), 0, math.radians(-30)), 3.2, (1, 0.95, 0.9))
        area((-3, 2.5, 2.0), (0, 0, 1.2), 160, (0.4, 0.8, 1.0), 3)
        camera((-0.55, 2.3, 1.35), (0, 0, 1.2), 58)
        render("i_" + kind, res=(480, 600), transparent=True)
    return f
for _k in ("captain", "rex", "bolt", "lyra", "vance", "nox"): SCENES["portrait_" + _k] = make_portrait(_k)

if __name__ == "__main__":
    for n in (NAMES or list(SCENES)):
        SCENES[n]()
