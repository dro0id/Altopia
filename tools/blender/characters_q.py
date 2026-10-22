"""Astronautes à partir des bases Quaternius (CC0, squelette Humanoid Rig à 49 os, visages et cheveux low poly facettés).
Chaque personnage : base Quaternius (tête, cheveux, barbe, anatomie) + combinaison gonflée qui épouse le corps et suit le squelette
+ casque à visière claire, sac, tuyaux, panneau de commandes, genouillères, épaulières, liserés. Vrai squelette, clips Idle / Walk / Run / Shoot.
make(nom, pose, s) -> empty racine (face vers +Y, pieds à z=0). animate(root) crée les clips (NLA)."""
import bpy, bmesh, math, os
import faces_q
from mathutils import Vector, Matrix, Quaternion

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
QDIR = os.path.join(ROOT, "art_src", "quaternius")

def M(name, col, metal=0.0, rough=0.55, emit=None, k=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*col, 1); b.inputs["Metallic"].default_value = metal; b.inputs["Roughness"].default_value = rough
    if emit is not None:
        b.inputs["Emission Color"].default_value = (*emit, 1); b.inputs["Emission Strength"].default_value = k
    return m
def E(name, col, k=3.0): return M(name, col, 0.0, 0.5, emit=col, k=k)
def glass(name="glass", tint=(0.75, 0.88, 1.0), a=0.1):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*tint, 1); b.inputs["Roughness"].default_value = 0.03; b.inputs["Alpha"].default_value = a
    return m

# base Quaternius, tête à garder, personnalisation ---------------------------------------------------------
def _sp(suit, trim, vis, boot, skin, hair, base, bulk=1.0, h=1.0, hat="none", extras=(), beard=None, glasses=False, helm=None, hair_keep=True, head=None):
    return dict(head=head, suit=suit, trim=trim, vis=vis, boot=boot, skin=skin, hair=hair, base=base, bulk=bulk, h=h, hat=hat, extras=list(extras), beard=beard, glasses=glasses, helm=helm, hair_keep=hair_keep)
SPECS = {
 "captain": _sp((0.92, 0.93, 0.95), (0.85, 0.12, 0.14), (0.85, 0.15, 0.15), (0.92, 0.93, 0.95), None, None, ("umc", "Adventurer"), 1.0, 1.0, "none", ["antenna"]),
 "rex":     _sp((0.95, 0.42, 0.08), (1.0, 0.95, 0.9), (1.0, 0.8, 0.2), (0.15, 0.15, 0.18), None, None, ("umc", "Beach"), 0.98, 0.97, "none", ["wings"]),
 "nova":    _sp((0.78, 0.14, 0.22), (1.0, 0.95, 0.95), (1.0, 0.55, 0.7), (0.92, 0.92, 0.95), None, None, ("uw", "Soldier"), 0.92, 0.96, "headband", ["wings", "scarf"]),
 "zara":    _sp((0.1, 0.1, 0.14), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.22, 0.2, 0.15), (0.45, 0.3, 0.22), (0.88, 0.9, 0.95), ("uw", "SciFi"), 0.96, 1.0, "none", ["wings", "epaulet", "pauldrons"]),
 "bolt":    _sp((0.78, 0.18, 0.15), (1.0, 0.85, 0.2), (1.0, 0.7, 0.2), (0.18, 0.15, 0.13), (0.55, 0.37, 0.27), None, ("umc", "Worker"), 1.12, 0.94, "lamp", ["pouches", "tool"]),
 "tess":    _sp((0.95, 0.75, 0.12), (0.12, 0.12, 0.15), (1.0, 0.55, 0.1), (0.2, 0.17, 0.13), None, None, ("uw", "Worker"), 0.96, 0.94, "goggles", ["pouches", "tool"]),
 "gorn":    _sp((0.22, 0.24, 0.28), (1.0, 0.45, 0.1), (1.0, 0.45, 0.1), (0.12, 0.12, 0.14), (0.7, 0.5, 0.4), (0.5, 0.2, 0.1), ("umc", "Adventurer"), 1.3, 0.96, "lamp", ["pauldrons", "glowcore", "pouches"]),
 "lumi":    _sp((0.45, 0.82, 0.88), (0.95, 0.97, 1.0), (0.3, 0.9, 0.9), (0.9, 0.93, 0.95), None, (0.35, 0.6, 0.95), ("uw", "Casual"), 0.9, 0.95, "none", ["tablet"]),
 "quark":   _sp((0.3, 0.28, 0.66), (0.75, 0.6, 1.0), (0.75, 0.6, 1.0), (0.2, 0.2, 0.3), None, (0.7, 0.7, 0.75), ("umc", "Suit"), 1.0, 1.0, "none", ["scanner"], None, True),
 "elara":   _sp((0.95, 0.95, 0.97), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.95, 0.85, 0.5), None, (0.6, 0.25, 0.85), ("uw", "Formal"), 0.9, 1.0, "halo", ["orb", "epaulet"]),
 "vance":   _sp((0.08, 0.14, 0.38), (0.95, 0.78, 0.25), (0.9, 0.2, 0.2), (0.12, 0.13, 0.18), None, None, ("umc", "King"), 1.08, 1.02, "none", ["epaulet", "medals"], None, False, "suit"),
 "droid":   _sp((0.78, 0.52, 0.16), (0.12, 0.12, 0.15), (1.0, 0.6, 0.15), (0.25, 0.27, 0.32), (0.6, 0.64, 0.7), None, ("umc", "Worker"), 1.08, 0.95, "none", ["tool"], head="robot_visor"),
 "jett":    _sp((0.62, 0.72, 0.82), (0.95, 0.2, 0.15), (1.0, 0.3, 0.1), (0.3, 0.3, 0.35), (0.8, 0.82, 0.86), None, ("umc", "Suit"), 1.0, 1.0, "none", ["wings"], head="robot_cyclops"),
 "vega":    _sp((0.92, 0.96, 0.97), (0.95, 0.25, 0.85), (0.95, 0.25, 0.85), (0.2, 0.2, 0.3), (0.35, 0.6, 0.95), None, ("uw", "SciFi"), 0.9, 1.02, "none", ["wings"], head="alien_blue"),
 "sira":    _sp((0.1, 0.5, 0.38), (1.0, 0.85, 0.3), (1.0, 0.85, 0.3), (0.12, 0.2, 0.16), (0.62, 0.42, 0.32), (0.65, 0.25, 0.1), ("uw", "Medieval"), 0.95, 0.99, "none", ["wings", "epaulet"]),
 "tick":    _sp((0.85, 0.75, 0.2), (0.3, 1.0, 0.6), (0.3, 1.0, 0.6), (0.3, 0.3, 0.35), (0.78, 0.8, 0.84), None, ("umc", "Worker"), 1.1, 0.8, "none", ["pouches", "tool"], head="robot_screen"),
 "brakk":   _sp((0.45, 0.4, 0.35), (1.0, 0.55, 0.1), (1.0, 0.55, 0.1), (0.2, 0.18, 0.15), (0.35, 0.6, 0.25), None, ("umc", "Adventurer"), 1.35, 1.05, "none", ["pauldrons", "pouches"], head="alien_lizard"),
 "maya":    _sp((0.65, 0.3, 0.12), (0.2, 0.85, 0.95), (0.3, 0.9, 0.9), (0.2, 0.12, 0.08), (0.36, 0.22, 0.16), (0.07, 0.07, 0.1), ("uw", "Casual"), 0.93, 0.95, "lamp", ["tool", "pouches"]),
 "zyl":     _sp((0.55, 0.8, 0.55), (0.95, 0.9, 0.35), (0.95, 0.9, 0.35), (0.25, 0.3, 0.25), (0.62, 0.7, 0.66), None, ("uw", "Formal"), 0.8, 0.96, "none", ["tablet"], head="alien_grey"),
 "sage":    _sp((0.9, 0.9, 0.95), (0.3, 0.8, 1.0), (0.3, 0.8, 1.0), (0.3, 0.3, 0.38), (0.78, 0.8, 0.84), None, ("umc", "Suit"), 0.95, 1.0, "none", ["scanner"], head="robot_dome"),
 "ilan":    _sp((0.75, 0.6, 0.85), (1.0, 0.9, 0.4), (1.0, 0.9, 0.4), (0.3, 0.25, 0.35), (0.5, 0.33, 0.24), (0.15, 0.15, 0.18), ("umc", "Beach"), 1.0, 0.99, "none", ["tablet"], glasses=True),
 "nox":     _sp((0.7, 0.74, 0.8), (0.75, 0.45, 1.0), (0.75, 0.45, 1.0), (0.25, 0.27, 0.32), (0.6, 0.64, 0.7), None, ("umc", "Suit"), 1.0, 1.0, "none", [], head="robot_visor"),
}
HEAD_DROP_MATS = {"Gold", "Worker_Yellow", "Worker_Vest", "Metal", "Swat", "Earrings", "Grey", "Orange", "LimeGreen", "Red_Dark"}   # couvre-chefs, bijoux, vêtements
HAIR_MATS = ("Hair", "Hair_White", "Hair_Brown", "Hair_Blond", "Moustache", "Eyebrows")

def _base_path(base):
    pack, name = base
    return os.path.join(QDIR, name + ".blend") if pack == "umc" else os.path.join(QDIR, "femmes", name + ".blend")

def load_base(base):
    path = _base_path(base)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n == "CharacterArmature" or n.endswith(("_Head", "_Body", "_Legs", "_Feet"))]
    objs = [o for o in dst.objects if o is not None]
    for o in objs: bpy.context.collection.objects.link(o)
    arm = next(o for o in objs if o.type == "ARMATURE")
    parts = {k: next((o for o in objs if o.name.split(".")[0].endswith("_" + k)), None) for k in ("Head", "Body", "Legs", "Feet")}
    return arm, parts

def evaluated_copy(ob, name):
    dg = bpy.context.evaluated_depsgraph_get()
    e = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(e)
    new = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(new)
    for vg in ob.vertex_groups: new.vertex_groups.new(name=vg.name)
    return new

def dominant_groups(ob):
    names = [vg.name for vg in ob.vertex_groups]
    out = []
    for v in ob.data.vertices:
        best, bw = None, 0.0
        for g in v.groups:
            if g.weight > bw: best, bw = names[g.group], g.weight
        out.append(best)
    return out

HAND = ("Hand", "Index", "Middle", "Ring", "Pinky", "Thumb")
FOOT = ("Foot", "Toes", "Toe")

def build_suit_shell(src_objs, arm, mats, inflate=0.026):
    """Duplique corps / jambes / pieds, gonfle le long des normales, répartit les matières par os dominant. Les poids du squelette sont conservés."""
    shells = []
    for so in src_objs:
        if so is None: continue
        # on travaille sur le maillage évalué (modificateurs appliqués : Mirror, Nodes), puis on regonfle
        sh = evaluated_copy(so, so.name + "_suit")
        if LOD and SHELL_RATIO < 1.0:
            dm = sh.modifiers.new("dec", "DECIMATE"); dm.ratio = SHELL_RATIO
            bpy.context.view_layer.objects.active = sh
            bpy.ops.object.modifier_apply(modifier="dec")
        bm = bmesh.new(); bm.from_mesh(sh.data)
        bm.verts.ensure_lookup_table()
        dom = dominant_groups(sh)
        bm.normal_update()
        for v in bm.verts:
            g = dom[v.index] or ""
            k = inflate
            if g.startswith(HAND): k = inflate * 0.9
            elif g.startswith(FOOT): k = inflate * 1.5
            elif g in ("Neck",): k = inflate * 1.0
            v.co += v.normal * k
        onames = [(m.name.split(".")[0] if m else "") for m in sh.data.materials]
        bad = [f for f in bm.faces if onames[f.material_index].startswith(("Hair", "Moustache", "Beard"))
               and not (max(set(dom[v.index] or "" for v in f.verts), key=[dom[v.index] or "" for v in f.verts].count)).startswith(HAND)]
        if bad: bmesh.ops.delete(bm, geom=bad, context="FACES")
        bm.faces.ensure_lookup_table()
        sh.data.materials.clear()
        for m in mats: sh.data.materials.append(m)   # 0 suit, 1 glove, 2 boot, 3 dark
        for f in bm.faces:
            gs = [dom[v.index] or "" for v in f.verts]
            g = max(set(gs), key=gs.count)
            f.material_index = 1 if g.startswith(HAND) else (2 if g.startswith(FOOT) else (3 if g in ("Neck", "Head") else 0))
            f.smooth = False
        bm.to_mesh(sh.data); bm.free()
        sh.parent = arm
        md = sh.modifiers.new("Armature", "ARMATURE"); md.object = arm
        shells.append(sh)
    return shells

# ------------------------------------------------------------------ outils géométrie / squelette
def bone_h(arm, n): return arm.data.bones[n].head_local.copy()
def bone_t(arm, n): return arm.data.bones[n].tail_local.copy()

def skin_rigid(ob, arm, bone):
    ob.parent = arm
    md = ob.modifiers.new("Armature", "ARMATURE"); md.object = arm
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    return ob

def _flat(ob, smooth=False):
    for p in ob.data.polygons: p.use_smooth = smooth

def prim_box(size, loc, rot=(0, 0, 0), r=0.25, sub=1):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = bpy.context.active_object; ob.scale = size
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    md = ob.modifiers.new("b", "BEVEL"); md.width = r * min(size); md.segments = 1 if LOD else 2; md.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier="b")
    if sub and not LOD:
        sm = ob.modifiers.new("s", "SUBSURF"); sm.levels = 1; sm.render_levels = 1
        bpy.ops.object.modifier_apply(modifier="s")
    _flat(ob, False); return ob

def prim_sph(r, loc, scale=(1, 1, 1), seg=14):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=max(5, seg // 2), location=loc)
    ob = bpy.context.active_object; ob.scale = scale; _flat(ob, False); return ob

def prim_cyl(r1, r2, h, loc, rot=(0, 0, 0), seg=12):
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    ob = bpy.context.active_object; _flat(ob, False); return ob

LOD = True   # allège les maillages (anneaux, casque, combinaison) : ~25 000 -> ~10 000 triangles par personnage
SHELL_RATIO = 0.8
HEAD_RATIO = 0.65

def tube(pts, r, n=8, closed=False):
    """Tuyau de rayon r le long de points (liste Vector) ; closed : boucle fermée."""
    pts = [Vector(p) for p in pts]
    if LOD:
        n = min(n, 5)
        if closed and len(pts) > 12 and len(pts) <= 24 and len(pts) % 2 == 0 and len(pts) != 18: pts = pts[::2]
    bm = bmesh.new(); rows = []
    N = len(pts)
    for i, p in enumerate(pts):
        a_ = pts[(i - 1) % N] if closed else pts[max(i - 1, 0)]
        b_ = pts[(i + 1) % N] if closed else pts[min(i + 1, N - 1)]
        T = (b_ - a_).normalized()
        ref = Vector((0, 0, 1)) if abs(T.z) < 0.9 else Vector((1, 0, 0))
        Nn = (ref - ref.dot(T) * T).normalized(); B = T.cross(Nn)
        row = []
        for j in range(n):
            a = 2 * math.pi * j / n
            row.append(bm.verts.new(p + Nn * math.cos(a) * r + B * math.sin(a) * r))
        rows.append(row)
    rng = N if closed else N - 1
    for i in range(rng):
        i2 = (i + 1) % N
        for j in range(n):
            jj = (j + 1) % n
            bm.faces.new((rows[i][j], rows[i][jj], rows[i2][jj], rows[i2][j]))
    if not closed:
        bm.faces.new(rows[0][::-1]); bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tube"); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new("tube", me); bpy.context.collection.objects.link(ob)
    _flat(ob, False); return ob

def section(mesh_obj, center, axis, half=0.025):
    """Sommets du maillage proches du plan perpendiculaire à l'axe en 'center' ; renvoie la liste des positions."""
    ax = axis.normalized(); out = []
    for v in mesh_obj.data.vertices:
        p = mesh_obj.matrix_world @ v.co
        if abs((p - center).dot(ax)) < half: out.append(p)
    return out

def ring_around(shell_objs, arm, bone, t, thick, mat, extra=0.012, name="ring", rmax_ring=None):
    """Anneau qui entoure le membre/torse à la position t (0..1) de l'os, au rayon mesuré sur la combinaison."""
    h, tl = bone_h(arm, bone), bone_t(arm, bone)
    ax = tl - h; c = h + ax * t
    pts = []
    for so in shell_objs: pts += section(so, c, ax)
    if not pts: return None
    # projection dans le plan : rayon max (percentile) par secteur => anneau elliptique suivant la section
    up = Vector((0, 0, 1)) if abs(ax.normalized().z) < 0.9 else Vector((0, 1, 0))
    u = (up - up.dot(ax.normalized()) * ax.normalized()).normalized(); w = ax.normalized().cross(u)
    ring = []
    K = 18
    for k in range(K):
        a = 2 * math.pi * k / K
        d = u * math.cos(a) + w * math.sin(a)
        best = 0.0
        for p in pts:
            q = p - c; q -= ax.normalized() * q.dot(ax.normalized())
            if rmax_ring is not None and q.length > rmax_ring: continue
            if q.length > 1e-5 and q.normalized().dot(d) > 0.92: best = max(best, q.length)
        if best == 0.0: best = 0.04
        ring.append(c + d * (best + extra + (0.005 if LOD else 0.0)))
    ob = tube(ring, thick, 6, closed=True); ob.name = name
    ob.data.materials.append(mat); return ob

def limb_extent(shell_objs, arm, bone, t, direction, rmax=0.16):
    """Distance maximale, dans 'direction', entre l'axe de l'os (à t) et la combinaison, sur les sommets proches de cet axe."""
    h, tl = bone_h(arm, bone), bone_t(arm, bone)
    ax = (tl - h); c = h + ax * t; axn = ax.normalized(); d = Vector(direction).normalized()
    best = 0.0
    for so in shell_objs:
        for v in so.data.vertices:
            p = so.matrix_world @ v.co
            if abs((p - c).dot(axn)) > 0.03: continue
            q = p - c; q -= axn * q.dot(axn)
            if q.length > rmax: continue
            best = max(best, q.dot(d))
    return best if best > 0 else 0.05

def front_y(shell_objs, z, xr=0.09, front=True):
    ys = []
    for so in shell_objs:
        for v in so.data.vertices:
            p = so.matrix_world @ v.co
            if abs(p.z - z) < 0.03 and abs(p.x) < xr: ys.append(p.y)
    return (min(ys) if front else max(ys)) if ys else 0.0

def half_width(shell_objs, z):
    xs = []
    for so in shell_objs:
        for v in so.data.vertices:
            p = so.matrix_world @ v.co
            if abs(p.z - z) < 0.03 and abs(p.x) < 0.3: xs.append(abs(p.x))
    return max(xs) if xs else 0.15

# ------------------------------------------------------------------ pose en repère monde
def _bone_order(arm):
    order = []
    def rec(b):
        order.append(b.name)
        for c in b.children: rec(c)
    for b in arm.data.bones:
        if b.parent is None: rec(b)
    return order

def apply_pose(arm, spec, keyframe=None, fx=None):
    """spec : {os: [(axe, degrés), ...]} rotations en repère monde, appliquées de la racine vers les extrémités."""
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = Quaternion((1, 0, 0, 0)); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    for bn in _bone_order(arm):
        if bn in spec:
            pb = arm.pose.bones[bn]
            h = pb.head.copy()
            R = Matrix.Identity(4)
            for axis, deg in spec[bn]:
                R = Matrix.Rotation(math.radians(deg), 4, Vector(axis)) @ R
            M_ = Matrix.Translation(h) @ R @ Matrix.Translation(-h) @ pb.matrix
            pb.matrix = M_
            bpy.context.view_layer.update()
    for bn, tr in spec.get("_t", {}).items():
        pb = arm.pose.bones.get(bn)
        if pb is not None:
            m = pb.matrix.copy(); m.translation = m.translation + Vector(tr); pb.matrix = m
            bpy.context.view_layer.update()
    for bn, fx in (fx or {}).items():
        pb = arm.pose.bones.get(bn)
        if pb is None: continue
        if "s" in fx: pb.scale = fx["s"]
        if "l" in fx: pb.location = fx["l"]
    if keyframe is not None:
        for pb in arm.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=keyframe)
            pb.keyframe_insert("location", frame=keyframe)
            pb.keyframe_insert("scale", frame=keyframe)

X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)
def apose(dl=68, bend=14):
    """Bras le long du corps (A-pose) : la base est en T-pose."""
    return {"UpperArm.L": [(Y, dl)], "UpperArm.R": [(Y, -dl)], "LowerArm.L": [(Z, 0)], "LowerArm.R": [(Z, 0)],
            "UpperLeg.L": [(Y, 2.5)], "UpperLeg.R": [(Y, -2.5)]}
def pose_spec(name):
    s = apose()
    if name == "idle": return s
    d = dict(s)
    def add(b, *rot): d[b] = d.get(b, []) + list(rot)
    if name == "walk":
        add("UpperArm.L", (X, 26)); add("UpperArm.R", (X, -26)); add("LowerArm.L", (X, 20)); add("UpperLeg.L", (X, -24)); add("UpperLeg.R", (X, 24)); add("LowerLeg.R", (X, 30))
    elif name == "point":
        d["UpperArm.R"] = [(Y, -15), (X, 80)]; add("LowerArm.R", (X, 6))
    elif name == "work":
        d["UpperArm.L"] = [(Y, 40), (X, 48)]; d["UpperArm.R"] = [(Y, -40), (X, 52)]; add("LowerArm.L", (X, 42)); add("LowerArm.R", (X, 44)); add("Abdomen", (X, 9)); add("Head", (X, 8))
    elif name == "salute":
        d["UpperArm.R"] = [(Y, -40), (X, 70)]; add("LowerArm.R", (X, 85), (Z, 0))
    elif name == "think":
        d["UpperArm.R"] = [(Y, -30), (X, 60)]; add("LowerArm.R", (X, 110)); add("Head", (Z, 10))
    elif name == "cheer":
        d["UpperArm.L"] = [(Y, 150)]; d["UpperArm.R"] = [(Y, -150)]
    return d

PIV = {}

def _recolor_head(head, sp_):
    # retire couvre-chefs et ornements
    bm = bmesh.new(); bm.from_mesh(head.data)
    names = [m.name.split(".")[0] if m else "" for m in head.data.materials]
    kill = [f for f in bm.faces if names[f.material_index] in HEAD_DROP_MATS]
    if kill: bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(head.data); bm.free()
    for m in head.data.materials:
        if m is None: continue
        n = m.name.split(".")[0]
        b = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
        if b is None: continue
        if n == "Skin" and sp_["skin"] is not None:
            b.inputs["Base Color"].default_value = (*sp_["skin"], 1)
        if n in HAIR_MATS or n in ("Brown", "DarkBrown") and sp_["hair"] is not None:
            if sp_["hair"] is not None and n.startswith("Hair") or (sp_["hair"] is not None and n in ("Moustache", "Brown", "DarkBrown", "White", "Black")):
                b.inputs["Base Color"].default_value = (*sp_["hair"], 1)

def make(name, pose="idle", s=1.0, suit_override=None, godot=False):
    sp_ = dict(SPECS[name])
    if suit_override: sp_.update(suit_override)
    H = sp_["h"]; bk = sp_["bulk"]; ex = sp_["extras"]
    arm, parts = load_base(sp_["base"])
    head = parts["Head"]
    HK = sp_.get("head"); ANDROID = HK is not None; FACE = name in faces_q.FACES
    if ANDROID or FACE:
        bpy.data.objects.remove(head); head = None
    else:
        _recolor_head(head, sp_)
        cc = Vector((0.0, -0.043, 1.69))
        hc0 = Vector((0.0, -0.043, 1.705)); Rin = Vector((0.188 * 0.9, 0.205 * 0.9, 0.205 * 0.9))
        for v in head.data.vertices:
            v.co = cc + (v.co - cc) * 1.18
            d_ = v.co - hc0; e_ = math.sqrt((d_.x / Rin.x) ** 2 + (d_.y / Rin.y) ** 2 + (d_.z / Rin.z) ** 2)
            if e_ > 1.0 and d_.z > -0.05: v.co = hc0 + d_ / e_   # cheveux : rester sous le casque
        if LOD and HEAD_RATIO < 1.0:
            dm = head.modifiers.new("dec", "DECIMATE"); dm.ratio = HEAD_RATIO
            bpy.context.view_layer.objects.active = head
            bpy.ops.object.modifier_apply(modifier="dec")
    # matières de la combinaison
    suit = M("suit_steel" if godot else name + "_suit", sp_["suit"], 0.0, 0.5)
    sc_ = sp_["suit"]
    glove = M(name + "_glove", tuple(min(1.0, c * 1.04) for c in sc_), 0.0, 0.5)
    boot = M(name + "_boot", tuple(c * 0.9 for c in sc_), 0.0, 0.5)
    dark = M("dark", (0.05, 0.07, 0.15), 0.1, 0.5)
    if (sp_.get("head") or "").startswith("robot"):
        glove = M(name + "_glove", (0.7, 0.72, 0.78), 0.85, 0.3); boot = M(name + "_boot", (0.5, 0.52, 0.58), 0.85, 0.35)
    if godot:
        trim = M("accent_cyan", sp_["trim"], 0.1, 0.4, emit=sp_["trim"], k=0.35)
    else:
        trim = M(name + "_trim", sp_["trim"], 0.0, 0.4)
    gray = M("gray", (0.55, 0.57, 0.6), 0.2, 0.5); white = M("white", (0.95, 0.95, 0.97), 0.0, 0.5)
    black = M("black", (0.02, 0.02, 0.03), 0.0, 0.4); gold = M("gold", (1.0, 0.8, 0.2), 0.6, 0.3); brown = M("kneepad", (0.42, 0.33, 0.26), 0.0, 0.7)
    # combinaison : gonflée autour du corps (épaisseur selon corpulence)
    shells = build_suit_shell([parts["Body"], parts["Legs"], parts["Feet"]], arm, [suit, glove, boot, dark], inflate=0.026 * bk)
    for o in (parts["Body"], parts["Legs"], parts["Feet"]):
        if o is not None: bpy.data.objects.remove(o)
    rigid = []   # (objet, os)
    def add(ob, bone, mat, keep=None):
        ob.data.materials.append(mat); rigid.append((ob, bone))
        if keep: ob["keep"] = keep
        return ob
    hb = lambda n: bone_h(arm, n); tb = lambda n: bone_t(arm, n)
    # --- casque
    hc = Vector((0.0, -0.043, 1.705)); R = Vector((0.188, 0.205, 0.205))
    shell_m = M(name + "_helm", sp_["suit"] if sp_["helm"] == "suit" else (0.94, 0.95, 0.97), 0.0, 0.4)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=20, ring_count=12, location=hc)
    hs = bpy.context.active_object; hs.scale = R * 1.02; bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new(); bm.from_mesh(hs.data); bm.faces.ensure_lookup_table()
    ys = lambda f: f.calc_center_median()
    kill = [f for f in bm.faces if (ys(f).y - hc.y) < -0.075 and abs(ys(f).x - hc.x) < 0.17 and -0.13 < (ys(f).z - hc.z) < 0.115]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.verts.ensure_lookup_table(); bm.edges.ensure_lookup_table()
    bedges = [e for e in bm.edges if e.is_boundary]
    loop_pts = []
    if bedges:
        nxt = {}
        for e in bedges:
            a, b = e.verts; nxt.setdefault(a.index, []).append(b.index); nxt.setdefault(b.index, []).append(a.index)
        start = bedges[0].verts[0].index; cur = start; prev = None
        for _ in range(len(bedges) + 2):
            loop_pts.append(bm.verts[cur].co.copy())
            cand = [n for n in nxt.get(cur, []) if n != prev]
            if not cand: break
            prev, cur = cur, cand[0]
            if cur == start: break
    bm.to_mesh(hs.data); bm.free()
    md = hs.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.012; bpy.ops.object.modifier_apply(modifier="sol")
    _flat(hs, False); add(hs, "Head", shell_m)
    gs = prim_sph(1.0, hc, tuple(R * 1.0), 14 if LOD else 26); add(gs, "Head", glass("visor", (0.75, 0.88, 1.0), 0.07))
    if len(loop_pts) > 6:
        cen = sum(loop_pts, Vector()) / len(loop_pts)
        rm = tube([p + (p - cen).normalized() * 0.004 for p in loop_pts], 0.016, 6, closed=True); add(rm, "Head", trim)
        rm2 = tube([p + (p - cen).normalized() * 0.012 + Vector((0, -0.01, 0)) for p in loop_pts], 0.008, 6, closed=True); add(rm2, "Head", dark)
    for sx in (-1, 1):
        ep = prim_cyl(0.058, 0.058, 0.05, (hc.x + sx * 0.205, hc.y, hc.z), (0, math.radians(90), 0), 14); add(ep, "Head", trim)
        ec = prim_cyl(0.04, 0.04, 0.025, (hc.x + sx * 0.235, hc.y, hc.z), (0, math.radians(90), 0), 14); add(ec, "Head", gray)
    rg = prim_box((0.04, 0.3, 0.025), (hc.x, hc.y + 0.01, hc.z + 0.205), r=0.3, sub=0); add(rg, "Head", trim)
    bl = prim_box((0.07, 0.02, 0.04), (hc.x, hc.y + 0.205, hc.z + 0.01), r=0.2, sub=0); add(bl, "Head", E("bl", (1.0, 0.3, 0.3), 2.5))
    if ANDROID:
        metal = M(name + "_metal", (0.78, 0.8, 0.84), 0.85, 0.3); face = M(name + "_face", (0.03, 0.035, 0.05), 0.2, 0.2)
        eye = E(name + "_eye", sp_["trim"], 9.0); V3 = Vector
        kind, _, style = HK.partition("_")
        def eyes_pair(x, y, z, sx, sy, sz, mat):
            for sg in (-1, 1): add(prim_sph(1.0, (hc.x + sg * x, y, z), (sx, sy, sz), 10), "Head", mat)
        if kind == "robot" and style == "visor":
            add(prim_sph(1.0, hc + V3((0, 0.01, -0.015)), (0.125, 0.135, 0.15), 18), "Head", metal)
            add(prim_sph(1.0, hc + V3((0, -0.075, 0.0)), (0.1, 0.06, 0.11), 16), "Head", face)
            for sx in (-1, 1):
                add(prim_box((0.034, 0.012, 0.016), (hc.x + sx * 0.042, hc.y - 0.128, hc.z + 0.012), r=0.3, sub=0), "Head", eye)
                add(prim_cyl(0.034, 0.034, 0.03, (hc.x + sx * 0.128, hc.y + 0.01, hc.z - 0.01), (0, math.radians(90), 0), 12), "Head", eye)
            add(prim_box((0.06, 0.01, 0.008), (hc.x, hc.y - 0.133, hc.z - 0.055), r=0.3, sub=0), "Head", eye)
            add(prim_cyl(0.008, 0.008, 0.07, (hc.x + 0.05, hc.y + 0.02, hc.z + 0.16), seg=6), "Head", metal)
            add(prim_sph(0.016, (hc.x + 0.05, hc.y + 0.02, hc.z + 0.2), (1, 1, 1), 8), "Head", eye)
        elif kind == "robot" and style == "cyclops":
            add(prim_sph(1.0, hc + V3((0, 0.01, -0.02)), (0.125, 0.13, 0.14), 14), "Head", metal)
            add(prim_cyl(0.075, 0.075, 0.05, (hc.x, hc.y - 0.1, hc.z + 0.01), (math.radians(90), 0, 0), 12), "Head", face)
            add(prim_sph(1.0, (hc.x, hc.y - 0.128, hc.z + 0.01), (0.052, 0.025, 0.052), 10), "Head", eye)
            for k_ in range(3): add(prim_box((0.07, 0.01, 0.008), (hc.x, hc.y - 0.125, hc.z - 0.08 - k_ * 0.018), r=0.3, sub=0), "Head", face)
            for sg in (-1, 1): add(prim_cyl(0.012, 0.012, 0.09, (hc.x + sg * 0.1, hc.y + 0.02, hc.z + 0.14), seg=6), "Head", metal)
        elif kind == "robot" and style == "screen":
            add(prim_box((0.25, 0.22, 0.25), hc + V3((0, 0.0, -0.01)), r=0.3, sub=0), "Head", metal)
            add(prim_box((0.2, 0.02, 0.16), (hc.x, hc.y - 0.113, hc.z + 0.0), r=0.2, sub=0), "Head", face)
            eyes_pair(0.05, hc.y - 0.126, hc.z + 0.03, 0.026, 0.008, 0.026, eye)
            for k_, dz in enumerate((-0.04, -0.055, -0.04)): add(prim_box((0.025, 0.008, 0.012), (hc.x + (k_ - 1) * 0.04, hc.y - 0.126, hc.z + dz - 0.005), r=0.3, sub=0), "Head", eye)
            add(prim_cyl(0.01, 0.01, 0.1, (hc.x, hc.y, hc.z + 0.17), seg=6), "Head", metal)
            add(prim_sph(0.022, (hc.x, hc.y, hc.z + 0.225), (1, 1, 1), 8), "Head", eye)
        elif kind == "robot" and style == "dome":
            add(prim_box((0.21, 0.19, 0.11), hc + V3((0, 0.0, -0.07)), r=0.3, sub=0), "Head", metal)
            add(prim_box((0.17, 0.02, 0.035), (hc.x, hc.y - 0.1, hc.z - 0.065), r=0.2, sub=0), "Head", face)
            add(prim_box((0.12, 0.012, 0.012), (hc.x, hc.y - 0.11, hc.z - 0.065), r=0.3, sub=0), "Head", eye)
            add(prim_sph(1.0, hc + V3((0, 0.0, 0.03)), (0.1, 0.1, 0.1), 14), "Head", glass(name + "_dome", (0.8, 0.95, 1.0), 0.18))
            add(prim_sph(1.0, hc + V3((0, 0.0, 0.03)), (0.045, 0.045, 0.045), 10), "Head", eye)
        elif kind == "alien" and style == "grey":
            sk = M(name + "_skin", sp_["skin"], 0.0, 0.6); blk = M(name + "_eyeblack", (0.01, 0.01, 0.02), 0.0, 0.15)
            add(prim_sph(1.0, hc + V3((0, 0.0, 0.01)), (0.135, 0.13, 0.165), 14), "Head", sk)
            eyes_pair(0.052, hc.y - 0.115, hc.z + 0.0, 0.046, 0.018, 0.07, blk)
            for sg in (-1, 1): add(prim_sph(1.0, (hc.x + sg * 0.04, hc.y - 0.128, hc.z + 0.02), (0.012, 0.006, 0.02), 6), "Head", E(name + "_glint", (1, 1, 1), 3.0))
            add(prim_box((0.04, 0.01, 0.006), (hc.x, hc.y - 0.128, hc.z - 0.09), r=0.3, sub=0), "Head", blk)
        elif kind == "alien" and style == "blue":
            sk = M(name + "_skin", sp_["skin"], 0.0, 0.6); blk = M(name + "_pupil", (0.02, 0.02, 0.03), 0.0, 0.15); yl = M(name + "_iris", (1.0, 0.85, 0.2), 0.0, 0.3)
            add(prim_sph(1.0, hc + V3((0, 0.0, -0.005)), (0.125, 0.125, 0.15), 14), "Head", sk)
            eyes_pair(0.05, hc.y - 0.108, hc.z + 0.01, 0.036, 0.016, 0.036, yl)
            eyes_pair(0.05, hc.y - 0.12, hc.z + 0.01, 0.013, 0.008, 0.026, blk)
            add(prim_cyl(0.014, 0.0, 0.05, (hc.x, hc.y - 0.125, hc.z - 0.03), (math.radians(90), 0, 0), 6), "Head", sk)
            add(prim_box((0.05, 0.01, 0.006), (hc.x, hc.y - 0.115, hc.z - 0.07), r=0.3, sub=0), "Head", blk)
            for sg in (-1, 1):
                add(tube([V3((hc.x + sg * 0.05, hc.y - 0.02, hc.z + 0.13)), V3((hc.x + sg * 0.09, hc.y - 0.04, hc.z + 0.2)), V3((hc.x + sg * 0.1, hc.y - 0.07, hc.z + 0.25))], 0.007, 4), "Head", sk)
                add(prim_sph(0.02, (hc.x + sg * 0.1, hc.y - 0.07, hc.z + 0.255), (1, 1, 1), 8), "Head", eye)
        elif kind == "alien" and style == "lizard":
            sk = M(name + "_skin", sp_["skin"], 0.0, 0.6); dk = M(name + "_dark", tuple(c * 0.45 for c in sp_["skin"]), 0.0, 0.6); yl = M(name + "_iris", (1.0, 0.8, 0.1), 0.0, 0.3)
            add(prim_sph(1.0, hc + V3((0, 0.0, 0.0)), (0.115, 0.14, 0.13), 14), "Head", sk)
            add(prim_box((0.1, 0.09, 0.075), (hc.x, hc.y - 0.12, hc.z - 0.035), r=0.3, sub=0), "Head", sk)
            for sg in (-1, 1):
                add(prim_sph(0.03, (hc.x + sg * 0.075, hc.y - 0.095, hc.z + 0.05), (1, 0.7, 1), 8), "Head", yl)
                add(prim_box((0.008, 0.01, 0.034), (hc.x + sg * 0.075, hc.y - 0.12, hc.z + 0.05), r=0.2, sub=0), "Head", dk)
                add(prim_sph(0.008, (hc.x + sg * 0.025, hc.y - 0.168, hc.z - 0.01), (1, 1, 1), 6), "Head", dk)
            add(prim_box((0.09, 0.012, 0.008), (hc.x, hc.y - 0.166, hc.z - 0.06), r=0.3, sub=0), "Head", dk)
            for k_ in range(3): add(prim_cyl(0.022 - k_ * 0.004, 0.0, 0.07 - k_ * 0.012, (hc.x, hc.y + 0.01 + k_ * 0.045, hc.z + 0.115 - k_ * 0.018), seg=5), "Head", dk)
        add(prim_cyl(0.05, 0.05, 0.05, (hc.x, hc.y, hc.z - 0.14), seg=10), "Head", metal if kind == "robot" else M(name + "_neck", sp_["skin"], 0.0, 0.6))
    if FACE:
        faces_q.add_face_bones(arm, name, hc)
        faces_q.human_head(name, hc, add, dict(M=M, E=E, box=prim_box, sph=prim_sph, cyl=prim_cyl, tube=tube))
    # --- col, sac, tuyaux
    nz = hb("Neck").z
    nr = tube([Vector((math.cos(a) * 0.115, -0.043 + math.sin(a) * 0.11, nz + 0.01)) for a in [2 * math.pi * k / 20 for k in range(20)]], 0.028, 8, True); add(nr, "Neck", dark)
    ns = tube([Vector((math.cos(a) * 0.12, -0.043 + math.sin(a) * 0.115, nz + 0.05)) for a in [2 * math.pi * k / 20 for k in range(20)]], 0.012, 6, True); add(ns, "Neck", trim)
    cz = hb("Torso").z + 0.1
    back_y = front_y(shells, cz, 0.12, front=False)
    pk = prim_box((0.36 * bk, 0.17, 0.46), (0, back_y + 0.1, cz + 0.02), r=0.22); add(pk, "Chest", white if name != "nox" else gray)
    pt = prim_box((0.28 * bk, 0.02, 0.05), (0, back_y + 0.2, cz + 0.12), r=0.3, sub=0); add(pt, "Chest", trim)
    pl = prim_box((0.07, 0.02, 0.04), (0, back_y + 0.2, cz - 0.1), r=0.2, sub=0); add(pl, "Chest", E("pl", (1.0, 0.3, 0.3), 3.0))
    for sx in (-1, 1):
        add(prim_cyl(0.05, 0.05, 0.36, (sx * 0.2 * bk, back_y + 0.09, cz - 0.02), seg=12), "Chest", gray)          # bouteilles latérales
        add(prim_cyl(0.054, 0.054, 0.03, (sx * 0.2 * bk, back_y + 0.09, cz + 0.13), seg=12), "Chest", trim)
        add(prim_box((0.035, 0.012, 0.3), (sx * 0.12 * bk, back_y + 0.2, cz - 0.02), r=0.3, sub=0), "Chest", trim)     # sangles
        for k_ in range(3): add(prim_box((0.08 * bk, 0.012, 0.012), (sx * 0.08 * bk, back_y + 0.2, cz - 0.1 - k_ * 0.03), r=0.3, sub=0), "Chest", dark)   # prises d'air
    add(prim_box((0.12 * bk, 0.02, 0.07), (0, back_y + 0.2, cz + 0.02), r=0.25, sub=0), "Chest", E("bk_scr", sp_["trim"], 2.0), keep="pack_panel")
    for sx in (-1, 1):
        hs_ = tube([Vector((sx * 0.1, back_y + 0.06, cz + 0.27)), Vector((sx * 0.2, back_y - 0.02, cz + 0.34)), Vector((sx * 0.17, -0.06, cz + 0.36)), Vector((sx * 0.1, -0.075, cz + 0.28))], 0.02, 8); add(hs_, "Chest", black)
    # --- panneau de commandes
    fy = front_y(shells, cz + 0.02, 0.1)
    pn = prim_box((0.21, 0.03, 0.15), (0, fy - 0.004, cz + 0.02), r=0.25); add(pn, "Chest", gray)
    sc = prim_box((0.15, 0.015, 0.04), (0, fy - 0.022, cz + 0.06), r=0.2, sub=0); add(sc, "Chest", E("scr", (0.85, 0.95, 0.35), 1.4))
    for k_, c in enumerate(((1, 0.3, 0.2), (0.95, 0.95, 0.95), (0.3, 0.6, 1))):
        b_ = prim_box((0.035, 0.016, 0.03), (-0.055 + k_ * 0.055, fy - 0.022, cz - 0.005), r=0.25, sub=0); add(b_, "Chest", E("btn", c, 2.5))
    dl = prim_sph(0.028, (0.078, fy - 0.022, cz - 0.045), (1, 0.4, 1), 10); add(dl, "Chest", white)
    zb_, zt_ = cz - 0.03, hc.z - 0.14; zp = prim_box((0.022, 0.016, zt_ - zb_), (0, front_y(shells, (zb_ + zt_) / 2, 0.05) - 0.003, (zb_ + zt_) / 2), r=0.3, sub=0); add(zp, "Chest", trim)
    for k_, c in enumerate(((0.2, 0.7, 0.3), (1, 1, 1), (1.0, 0.5, 0.1))):
        fg = prim_box((0.04, 0.014, 0.026), (-0.1 + k_ * 0.046, front_y(shells, cz + 0.2, 0.12) - 0.004, cz + 0.2), r=0.2, sub=0); add(fg, "Chest", M("flag", c, 0, 0.6))
    # --- ceinture, anneaux, liserés
    for (bone, t, th, mt, ex_) in (("Abdomen", 0.45, 0.026, trim, 0.012), ("Abdomen", 0.62, 0.014, dark, 0.012), ("Abdomen", 0.3, 0.014, dark, 0.012), ("UpperArm.L", 0.92, 0.014, dark, 0.012), ("UpperArm.R", 0.92, 0.014, dark, 0.012),
                                   ("LowerArm.L", 0.06, 0.016, dark, 0.014), ("LowerArm.R", 0.06, 0.016, dark, 0.014), ("LowerArm.L", 0.86, 0.02, trim, 0.012), ("LowerArm.R", 0.86, 0.02, trim, 0.012),
                                   ("UpperLeg.L", 0.2, 0.016, dark, 0.014), ("UpperLeg.R", 0.2, 0.016, dark, 0.014), ("LowerLeg.L", 0.08, 0.018, dark, 0.014), ("LowerLeg.R", 0.08, 0.018, dark, 0.014),
                                   ("LowerLeg.L", 0.88, 0.02, trim, 0.012), ("LowerLeg.R", 0.88, 0.02, trim, 0.012),
                                   ("Abdomen", 0.82, 0.02, trim, 0.012), ("Hips", 0.5, 0.02, dark, 0.012),
                                   ("LowerArm.L", 0.45, 0.012, dark, 0.012), ("LowerArm.R", 0.45, 0.012, dark, 0.012),
                                   ("UpperLeg.L", 0.55, 0.014, trim, 0.012), ("UpperLeg.R", 0.55, 0.014, trim, 0.012), ("UpperLeg.L", 0.9, 0.016, dark, 0.012), ("UpperLeg.R", 0.9, 0.016, dark, 0.012),
                                   ("LowerLeg.L", 0.5, 0.012, dark, 0.012), ("LowerLeg.R", 0.5, 0.012, dark, 0.012)):
        r_ = ring_around(shells, arm, bone, t, th, mt, ex_, rmax_ring=(0.2 if bone in ("Abdomen", "Hips", "Chest") else 0.13))
        if r_ is not None: rigid.append((r_, bone))
    bh_ = prim_box((0.06, 0.03, 0.05), (0, front_y(shells, hb("Abdomen").z + 0.07, 0.04) - 0.006, hb("Abdomen").z + 0.07), r=0.3, sub=0); add(bh_, "Abdomen", gray)
    for bone, side in (("UpperArm.L", 1), ("UpperArm.R", -1), ("UpperLeg.L", 1), ("UpperLeg.R", -1), ("LowerArm.L", 1), ("LowerArm.R", -1), ("LowerLeg.L", 1), ("LowerLeg.R", -1)):
        h_, t_ = hb(bone), tb(bone); ax = (t_ - h_)
        arm_limb = bone.startswith("UpperArm") or bone.startswith("LowerArm")
        d_ = (0, 0, 1) if arm_limb else (side, 0, 0)
        t0, t1 = (0.16, 0.9) if bone.startswith("Lower") else (0.14, 0.88)
        pts_a = []; pts_b = []
        for tt in [t0 + (t1 - t0) * k_ / 5 for k_ in range(6)]:
            r_ = limb_extent(shells, arm, bone, tt, d_)
            c_ = h_ + ax * tt
            pts_a.append(c_ + Vector(d_) * (r_ + 0.008)); pts_b.append(c_ + Vector(d_) * (r_ + 0.008) + (Vector((0, -0.016, 0)) if arm_limb else Vector((0, -0.016, 0))))
        add(tube(pts_a, 0.007, 4), bone, trim); add(tube(pts_b, 0.006, 4), bone, dark)
    # --- genouillères, épaulières
    for bone, side in (("LowerLeg.L", 1), ("LowerLeg.R", -1)):
        h_ = hb(bone); fyk = front_y(shells, h_.z, 0.12)
        kp = prim_box((0.13 * bk, 0.06, 0.15), (side * 0.121, fyk - 0.012, h_.z + 0.01), r=0.3); add(kp, bone, brown)
        kr = prim_box((0.15 * bk, 0.065, 0.02), (side * 0.121, fyk - 0.012, h_.z + 0.09), r=0.3, sub=0); add(kr, bone, dark)
    for bone, side in (("UpperArm.L", 1), ("UpperArm.R", -1)):
        h_ = hb(bone)
        sp_pad = prim_box((0.19 * bk, 0.2, 0.11), (h_.x + side * 0.045, h_.y, h_.z + 0.045), (0, 0, 0), r=0.35); add(sp_pad, bone, suit)
        sl = prim_box((0.2 * bk, 0.21, 0.016), (h_.x + side * 0.045, h_.y, h_.z + 0.0), r=0.3, sub=0); add(sl, bone, trim)
    # --- semelle lumineuse
    for bone, side in (("Foot.L", 1), ("Foot.R", -1)):
        h_, t_ = hb(bone), tb(bone)
        so = prim_box((0.115, 0.3, 0.018), (side * 0.121, (h_.y + t_.y) / 2 - 0.02, 0.006), r=0.3, sub=0)
        add(so, bone, E("sole", (0.3, 0.8, 1.0), 2.5) if name in ("captain", "vance", "nox") else dark)
    # --- identité
    fy0 = front_y(shells, cz + 0.02, 0.1)
    hz = hc.z
    if sp_["hat"] == "lamp": add(prim_sph(0.032, (hc.x, hc.y - 0.2, hc.z + 0.13), (1, 0.7, 1), 8), "Head", E("lamp", (1.0, 0.95, 0.7), 8.0))
    elif sp_["hat"] == "goggles":
        add(tube([Vector((math.cos(a) * 0.152, hc.y + math.sin(a) * 0.165, hc.z + 0.13)) for a in [2 * math.pi * k / 24 for k in range(24)]], 0.012, 6, True), "Head", black)
        for sx in (-1, 1):
            add(tube([Vector((hc.x + sx * 0.065 + math.cos(a) * 0.05, hc.y - 0.2, hc.z + 0.115 + math.sin(a) * 0.05)) for a in [2 * math.pi * k / 14 for k in range(14)]], 0.012, 6, True), "Head", black)
            add(prim_sph(0.042, (hc.x + sx * 0.065, hc.y - 0.2, hc.z + 0.115), (1, 0.2, 1), 10), "Head", E("lens", (1.0, 0.7, 0.2), 1.5))
    elif sp_["hat"] == "headband":
        add(tube([Vector((math.cos(a) * 0.15, hc.y + math.sin(a) * 0.163, hc.z + 0.13)) for a in [2 * math.pi * k / 24 for k in range(24)]], 0.014, 6, True), "Head", M("hb", (1.0, 0.95, 0.95), 0, 0.5))
    elif sp_["hat"] == "halo":
        add(tube([Vector((math.cos(a) * 0.14, hc.y + math.sin(a) * 0.14, hc.z + 0.3)) for a in [2 * math.pi * k / 24 for k in range(24)]], 0.008, 6, True), "Head", E("halo", (1.0, 0.85, 0.35), 6.0))
    if sp_["glasses"] and not FACE:
        for sx in (-1, 1):
            add(tube([Vector((hc.x + sx * 0.05 + math.cos(a) * 0.032, hc.y - 0.13, hc.z - 0.0 + math.sin(a) * 0.032)) for a in [2 * math.pi * k / 12 for k in range(12)]], 0.005, 4, True), "Head", black)
    if "antenna" in ex:
        add(prim_cyl(0.01, 0.01, 0.2, (0.16 * bk, back_y + 0.1, cz + 0.2), seg=6), "Chest", gray, keep="antenna")
        add(prim_sph(0.026, (0.16 * bk, back_y + 0.1, cz + 0.31), (1, 1, 1), 8), "Chest", E("atip", (1.0, 0.3, 0.8), 5.0), keep="antenna_tip")
    if "epaulet" in ex:
        for bone, side in (("UpperArm.L", 1), ("UpperArm.R", -1)):
            h_ = hb(bone); add(prim_box((0.12, 0.1, 0.02), (h_.x + side * 0.045, h_.y, h_.z + 0.11), r=0.3, sub=0), bone, gold)
    if "pauldrons" in ex:
        for bone, side in (("UpperArm.L", 1), ("UpperArm.R", -1)):
            h_ = hb(bone); add(prim_box((0.17 * bk, 0.18, 0.05), (h_.x + side * 0.05, h_.y, h_.z + 0.1), r=0.35), bone, trim if name == "gorn" else gold)
    if "pouches" in ex:
        hz2 = hb("Hips").z + 0.06
        for k_ in range(3): add(prim_box((0.075, 0.05, 0.08), (-0.13 + k_ * 0.13, front_y(shells, hz2, 0.14) - 0.02, hz2), r=0.3), "Hips", M("pouch", (0.3, 0.22, 0.12), 0, 0.8))
    if "tool" in ex:
        add(prim_box((0.03, 0.03, 0.2), (0.23 * bk, front_y(shells, hb("Hips").z + 0.05, 0.22) - 0.02, hb("Hips").z + 0.02), (0, 0.2, 0.4), r=0.3, sub=0), "Hips", M("steel", (0.65, 0.67, 0.7), 0.9, 0.3))
    if "tablet" in ex:
        h_ = hb("LowerArm.L"); t_ = tb("LowerArm.L"); c_ = h_ + (t_ - h_) * 0.5
        add(prim_box((0.15, 0.03, 0.08), (c_.x, c_.y - 0.062, c_.z), r=0.25, sub=0), "LowerArm.L", gray)
        add(prim_box((0.11, 0.016, 0.05), (c_.x, c_.y - 0.08, c_.z), r=0.2, sub=0), "LowerArm.L", E("tab", (0.3, 1.0, 0.8), 2.5))
    if "scanner" in ex:
        h_ = hb("Hand.R"); add(prim_box((0.08, 0.045, 0.16), (h_.x - 0.06, h_.y - 0.06, h_.z), r=0.3), "Hand.R", M("scan", (0.2, 0.22, 0.3), 0.6, 0.4))
        add(prim_sph(0.03, (h_.x - 0.06, h_.y - 0.09, h_.z + 0.09), (1, 1, 1), 8), "Hand.R", E("scl", (0.6, 0.4, 1.0), 7.0))
    if "medals" in ex:
        for k_ in range(3): add(prim_box((0.03, 0.014, 0.03), (0.04 + k_ * 0.04, fy0 - 0.016, cz + 0.12), r=0.3, sub=0), "Chest", gold if k_ != 1 else trim)
    if "wings" in ex:
        add(prim_box((0.12 * (1.3 if name == "zara" else 1), 0.014, 0.04), (0.07, fy0 - 0.012, cz - 0.1), r=0.3, sub=0), "Chest", gold if name == "zara" else trim)
    if "scarf" in ex:
        add(tube([Vector((math.cos(a) * 0.14, -0.043 + math.sin(a) * 0.12, nz - 0.05)) for a in [2 * math.pi * k / 20 for k in range(20)]], 0.04, 8, True), "Chest", M("scarf", (0.1, 0.75, 0.95), 0, 0.8))
    if "glowcore" in ex:
        add(prim_sph(0.032, (0, fy0 - 0.02, cz - 0.17), (1, 0.5, 1), 10), "Chest", E("core", (1.0, 0.5, 0.15), 8.0))
    if "orb" in ex:
        add(prim_sph(0.06, (0.34, hb("UpperArm.L").y - 0.05, hb("UpperArm.L").z - 0.4), (1, 1, 1), 10), "Chest", E("orb", (0.8, 0.6, 1.0), 8.0))
    # --- fusion par (os, matière), peau
    groups = {}
    for ob, bone in rigid:
        if ob.get("keep"):
            ob.name = ob["keep"]; skin_rigid(ob, arm, bone); continue
        key = (bone, ob.data.materials[0].name if ob.data.materials else "")
        groups.setdefault(key, []).append(ob)
    for (bone, mn), obs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in obs: o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1: bpy.ops.object.join()
        j = bpy.context.active_object; j.name = "%s_%s" % (bone, mn)
        skin_rigid(j, arm, bone)
    # racine : faisceau orienté face +Y, pieds à z = 0
    root = bpy.data.objects.new("char_" + name, None); bpy.context.collection.objects.link(root)
    arm.parent = root
    arm.rotation_euler = (0, 0, math.pi)
    k = s * H * 0.5
    root.scale = (k, k, k)
    arm.name = "rig_" + name
    PIV[root.name] = arm
    apply_pose(arm, pose_spec(pose))
    return root


def animate(root, clips=None):
    """Clips (NLA) de anims_q sur le squelette Humanoid + os de visage. clips : noms (par défaut Idle, Walk, Shoot). Le squelette reste en A-pose à la fin."""
    import anims_q
    arm = PIV[root.name]
    bpy.context.scene.render.fps = 24
    arm.animation_data_create()
    for nm in (clips or anims_q.CORE):
        frames = anims_q.CLIPS[nm]()
        act = bpy.data.actions.new(nm); arm.animation_data.action = act
        for f, sp_, fx in frames: apply_pose(arm, sp_, keyframe=f, fx=fx)
        arm.animation_data.action = None
        tr = arm.animation_data.nla_tracks.new(); tr.name = nm; st = tr.strips.new(nm, 1, act); st.name = nm
    apply_pose(arm, apose())
