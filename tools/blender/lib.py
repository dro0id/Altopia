"""Utilitaires Blender (bpy) pour générer les modèles du jeu : lofts, matériaux, rendu d'aperçu, export glTF.
Usage : python tools/blender/build_assets.py [nom ...] — produit assets/models/<nom>.glb et un aperçu PNG dans le dossier donné par --preview.
Convention : nez du vaisseau vers +Y dans Blender (devient -Z en glTF/three.js, avant en Godot)."""
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color, metal=0.0, rough=0.5, emit=None, emit_k=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = emit_k
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m

def finish(ob, material, smooth=True, bevel=0.0, subsurf=0, weighted=True):
    ob.data.materials.clear()
    ob.data.materials.append(material)
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    if bevel > 0:
        md = ob.modifiers.new("bev", "BEVEL"); md.width = bevel; md.segments = 2; md.limit_method = "ANGLE"
    if subsurf:
        md = ob.modifiers.new("sub", "SUBSURF"); md.levels = subsurf; md.render_levels = subsurf
    return ob

def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob

def box(name, size, loc=(0,0,0), rot=(0,0,0), material=None, bevel=0.01):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
    ob = new_obj(name, bm)
    ob.location = loc; ob.rotation_euler = rot
    if material: finish(ob, material, smooth=False, bevel=bevel)
    return ob

def cyl(name, r1, r2, length, loc=(0,0,0), axis="Y", seg=24, material=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=length)
    ob = new_obj(name, bm)
    if axis == "Y": ob.rotation_euler = (math.pi/2, 0, 0)
    elif axis == "X": ob.rotation_euler = (0, math.pi/2, 0)
    ob.location = loc
    if material: finish(ob, material, bevel=bevel)
    return ob

def sphere(name, r, loc=(0,0,0), scale=(1,1,1), material=None, seg=32):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg//2, radius=r)
    ob = new_obj(name, bm)
    ob.location = loc; ob.scale = scale
    if material: finish(ob, material)
    return ob

def loft(name, rings, n=16, exp=2.6, material=None, subsurf=1):
    """rings : liste de (y, largeur, hauteur, décalage_z). Profil super-ellipse (exp>2 : coins arrondis)."""
    bm = bmesh.new()
    prev = None
    rows = []
    for (y, w, h, dz) in rings:
        row = []
        for i in range(n):
            a = 2*math.pi*i/n
            c, s = math.cos(a), math.sin(a)
            x = w*0.5*math.copysign(abs(c)**(2/exp), c)
            z = h*0.5*math.copysign(abs(s)**(2/exp), s) + dz
            row.append(bm.verts.new((x, y, z)))
        rows.append(row)
    for r in range(len(rows)-1):
        for i in range(n):
            j = (i+1) % n
            bm.faces.new((rows[r][i], rows[r][j], rows[r+1][j], rows[r+1][i]))
    bm.faces.new(rows[0][::-1]); bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm)
    if material: finish(ob, material, subsurf=subsurf)
    return ob

def plate(name, pts, thick, loc=(0,0,0), material=None, bevel=0.015, mirror=True):
    """Plaque extrudée à partir d'un polygone 2D (x,y) dans le plan XY, épaisseur en Z. mirror : symétrie X."""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, -thick/2)) for x, y in pts]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    vv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    for v in vv: v.co.z += thick
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm)
    ob.location = loc
    if material: finish(ob, material, smooth=False, bevel=bevel)
    if mirror:
        md = ob.modifiers.new("mir", "MIRROR"); md.use_axis[0] = True; md.use_mirror_merge = False
    return ob

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob

def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    for md in list(ob.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=md.name)
        except RuntimeError: pass

def greeble(rng, target_y0, target_y1, width, z_top_fn, count, material, size=(0.12, 0.3), height=0.04):
    out = []
    for i in range(count):
        y = rng.uniform(target_y0, target_y1)
        x = rng.uniform(-width, width)
        sx, sy = rng.uniform(*size), rng.uniform(*size)
        out.append(box("g%d" % i, (sx, sy, height), (x, y, z_top_fn(y, x) + height/2), material=material, bevel=0.006))
    return out

def setup_render(preview_dir, name, res=(900, 640), cam=(6, -7, 3.5), target=(0, 0, 0), samples=48, size=1.0, views=None):
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.samples = samples
    scn.cycles.device = "CPU"
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.012, 0.016, 0.04, 1); bg.inputs[1].default_value = 1.0
    def area(loc, energy, color):
        l = bpy.data.lights.new("a", "AREA"); l.energy = energy; l.color = color; l.size = 6
        o = bpy.data.objects.new("a", l); bpy.context.collection.objects.link(o); o.location = loc
        d = (Vector(target) - Vector(loc)); o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    area((6, -4, 7), 900*size**2, (1, 0.95, 0.88)); area((-7, 2, 3), 500*size**2, (0.45, 0.6, 1.0)); area((0, 8, -2), 380*size**2, (1, 0.5, 0.35))
    c = bpy.data.cameras.new("c"); c.lens = 50
    co = bpy.data.objects.new("c", c); bpy.context.collection.objects.link(co); co.location = cam
    co.rotation_euler = (Vector(target) - Vector(cam)).to_track_quat("-Z", "Y").to_euler()
    scn.camera = co
    scn.view_settings.view_transform = "AgX"
    os.makedirs(preview_dir, exist_ok=True)
    for k, vc in enumerate(views or [cam]):
        co.location = vc
        co.rotation_euler = (Vector(target) - Vector(vc)).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = os.path.join(preview_dir, "%s%s.png" % (name, "" if not views else "_%d" % k))
        bpy.ops.render.render(write_still=True)

def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, use_selection=False, export_materials="EXPORT", export_lights=False, export_cameras=False)


def torus(name, R, r, rot=(0, 0, 0), loc=(0, 0, 0), material=None, seg=72, minor=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=minor)
    ob = bpy.context.active_object
    ob.name = name; ob.rotation_euler = rot; ob.location = loc
    if material: finish(ob, material)
    return ob
