"""EXPÉRIMENTAL : astronautes organiques riggés (squelette complet, membres balayés le long de courbes, pondérations lissées, visage animé :
sourcils, paupières, mâchoire ; clips Idle / Walk / Run / Shoot et expressions Smile / Angry / Surprised). Non utilisé par le jeu : le jeu
utilise characters.py. Proportions et finition encore loin des références visées."""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion
from lib import mat as lmat

def M(name, col, metal=0.0, rough=0.6): return lmat(name, col, metal, rough)
def E(name, col, k=3.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    e = nt.nodes.new("ShaderNodeEmission"); e.inputs[0].default_value = (*col, 1); e.inputs[1].default_value = k
    o = nt.nodes.new("ShaderNodeOutputMaterial"); nt.links.new(e.outputs[0], o.inputs[0])
    return m
def glass(name="glass", tint=(0.7, 0.85, 1.0), a=0.1):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*tint, 1); b.inputs["Roughness"].default_value = 0.04; b.inputs["Alpha"].default_value = a
    return m

# ------------------------------------------------------------------ géométrie
def _smooth(ob, angle=38):
    me = ob.data
    for p in me.polygons: p.use_smooth = True
    try:
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
        ob.select_set(False)
    except Exception:
        pass

def spline(pts, k):
    """Catmull-Rom : k points lissés passant par les points de contrôle."""
    P = [Vector(p) for p in pts]
    if len(P) < 3: return P
    out = []
    n = len(P) - 1
    for i in range(k):
        t = i / (k - 1) * n
        j = min(int(t), n - 1); u = t - j
        p0 = P[max(j - 1, 0)]; p1 = P[j]; p2 = P[j + 1]; p3 = P[min(j + 2, n)]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    return out

def interp(vals, k):
    n = len(vals) - 1
    out = []
    for i in range(k):
        t = i / (k - 1) * n
        j = min(int(t), n - 1); u = t - j
        u = u * u * (3 - 2 * u)
        out.append(vals[j] * (1 - u) + vals[j + 1] * u)
    return out

def sweep_mesh(pts, rx, ry=None, n=12, k=12, up=(0, 1, 0), cx=None):
    """Tube balayé le long d'une courbe lissée. rx/ry : rayons par point de contrôle. Renvoie (bmesh, ts) avec ts = paramètre 0..1 par anneau."""
    P = spline(pts, k)
    RX = interp(rx, k); RY = interp(ry if ry else rx, k)
    bm = bmesh.new(); rows = []
    for i, p in enumerate(P):
        a_ = P[max(i - 1, 0)]; b_ = P[min(i + 1, len(P) - 1)]
        T = (b_ - a_).normalized()
        ref = Vector(up)
        if abs(ref.dot(T)) > 0.95: ref = Vector((1, 0, 0))
        N = (ref - ref.dot(T) * T).normalized(); B = T.cross(N)
        row = []
        for j in range(n):
            a = 2 * math.pi * (j + 0.5) / n
            row.append(bm.verts.new(p + N * math.cos(a) * RX[i] + B * math.sin(a) * RY[i]))
        rows.append(row)
    for r in range(len(rows) - 1):
        for j in range(n):
            jj = (j + 1) % n
            bm.faces.new((rows[r][j], rows[r][jj], rows[r + 1][jj], rows[r + 1][j]))
    bm.faces.new(rows[0][::-1]); bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm, [i / (k - 1) for i in range(k)], rows

def new_obj(name, bm, m):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m)
    return ob

# ------------------------------------------------------------------ squelette
BONES = {   # nom: (parent, tête, queue)   (A-pose, personnage de face vers +Y, x = droite du personnage)
 "root": (None, (0, 0, 0), (0, 0, 0.08)),
 "hips": ("root", (0, 0, 0.5), (0, 0, 0.56)),
 "spine": ("hips", (0, 0, 0.56), (0, 0, 0.66)),
 "chest": ("spine", (0, 0, 0.66), (0, 0, 0.78)),
 "neck": ("chest", (0, 0, 0.78), (0, 0, 0.84)),
 "head": ("neck", (0, 0, 0.84), (0, 0, 1.08)),
 "jaw": ("head", (0, 0.02, 0.88), (0, 0.1, 0.88)),
 "brow.L": ("head", (-0.045, 0.1, 0.95), (-0.075, 0.1, 0.95)),
 "brow.R": ("head", (0.045, 0.1, 0.95), (0.075, 0.1, 0.95)),
 "lid.L": ("head", (-0.045, 0.1, 0.925), (-0.045, 0.1, 0.945)),
 "lid.R": ("head", (0.045, 0.1, 0.925), (0.045, 0.1, 0.945)),
 "clav.L": ("chest", (0, 0, 0.77), (-0.15, 0, 0.77)),
 "clav.R": ("chest", (0, 0, 0.77), (0.15, 0, 0.77)),
 "arm.L": ("clav.L", (-0.17, 0, 0.77), (-0.26, 0.01, 0.63)),
 "arm.R": ("clav.R", (0.17, 0, 0.77), (0.26, 0.01, 0.63)),
 "fore.L": ("arm.L", (-0.26, 0.01, 0.63), (-0.315, 0.04, 0.5)),
 "fore.R": ("arm.R", (0.26, 0.01, 0.63), (0.315, 0.04, 0.5)),
 "hand.L": ("fore.L", (-0.315, 0.04, 0.5), (-0.34, 0.05, 0.44)),
 "hand.R": ("fore.R", (0.315, 0.04, 0.5), (0.34, 0.05, 0.44)),
 "thigh.L": ("hips", (-0.065, 0, 0.5), (-0.075, 0.012, 0.26)),
 "thigh.R": ("hips", (0.065, 0, 0.5), (0.075, 0.012, 0.26)),
 "shin.L": ("thigh.L", (-0.075, 0.012, 0.26), (-0.08, -0.005, 0.08)),
 "shin.R": ("thigh.R", (0.075, 0.012, 0.26), (0.08, -0.005, 0.08)),
 "foot.L": ("shin.L", (-0.08, -0.005, 0.08), (-0.08, 0.1, 0.03)),
 "foot.R": ("shin.R", (0.08, -0.005, 0.08), (0.08, 0.1, 0.03)),
}
LEFT_RIGHT_SIGN = {"L": -1, "R": 1}

def build_armature(name):
    arm = bpy.data.armatures.new(name); ob = bpy.data.objects.new(name, arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for bn, (par, h, t) in BONES.items():
        b = arm.edit_bones.new(bn); b.head = h; b.tail = t
        if (Vector(t) - Vector(h)).length < 0.004: b.tail = Vector(h) + Vector((0, 0, 0.01))
        eb[bn] = b
    for bn, (par, h, t) in BONES.items():
        if par: eb[bn].parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob

def bone_weights_for_t(path_bones, t):
    """path_bones : [(bone, t_start)] triés ; renvoie {bone: poids} avec fondu autour des articulations."""
    w = {}
    blend = 0.09
    for i, (b, t0) in enumerate(path_bones):
        t1 = path_bones[i + 1][1] if i + 1 < len(path_bones) else 2.0
        # poids de la zone [t0, t1) avec transitions douces
        a = 1.0 if i == 0 else min(1.0, max(0.0, (t - (t0 - blend)) / (2 * blend)))
        c = 1.0 if i + 1 >= len(path_bones) else min(1.0, max(0.0, ((t1 + blend) - t) / (2 * blend)))
        w[b] = max(0.0, a * c)
    s = sum(w.values()) or 1.0
    return {k: v / s for k, v in w.items() if v / s > 0.001}

def skin_object(ob, arm_ob, weights_by_vertex):
    """weights_by_vertex : liste de dict {bone: w} (un par sommet) ou un nom d'os (rigide)."""
    ob.parent = arm_ob
    md = ob.modifiers.new("Armature", "ARMATURE"); md.object = arm_ob
    if isinstance(weights_by_vertex, str):
        vg = ob.vertex_groups.new(name=weights_by_vertex)
        vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    else:
        groups = {}
        for vi, wd in enumerate(weights_by_vertex):
            for b, w in wd.items():
                if b not in groups: groups[b] = ob.vertex_groups.new(name=b)
                groups[b].add([vi], w, "REPLACE")
    return ob

# ------------------------------------------------------------------ personnages
def _sp(suit, trim, vis, boot, skin, hair, bulk=1.0, h=1.0, hair_style="short", beard="none", hat="none", extras=(), helm=None, glasses=False):
    return dict(suit=suit, trim=trim, vis=vis, boot=boot, skin=skin, hair=hair, bulk=bulk, h=h, hair_style=hair_style, beard=beard, hat=hat, extras=list(extras), helm=helm, glasses=glasses)
SPECS = {
 "captain": _sp((0.92, 0.93, 0.95), (0.85, 0.12, 0.14), (0.85, 0.15, 0.15), (0.92, 0.93, 0.95), (0.82, 0.6, 0.47), (0.12, 0.07, 0.05), 1.0, 1.0, "short", "full", "none", ["antenna"]),
 "rex":     _sp((0.95, 0.42, 0.08), (1.0, 0.95, 0.9), (1.0, 0.8, 0.2), (0.15, 0.15, 0.18), (0.9, 0.7, 0.55), (0.35, 0.18, 0.08), 0.94, 0.98, "spiky", "none", "none", ["wings"]),
 "nova":    _sp((0.78, 0.14, 0.22), (1.0, 0.95, 0.95), (1.0, 0.55, 0.7), (0.92, 0.92, 0.95), (0.8, 0.58, 0.45), (0.06, 0.05, 0.08), 0.9, 1.0, "bob", "none", "headband", ["wings", "scarf"]),
 "zara":    _sp((0.1, 0.1, 0.14), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.22, 0.2, 0.15), (0.45, 0.3, 0.22), (0.88, 0.9, 0.95), 0.94, 1.06, "long", "none", "none", ["wings", "epaulet", "pauldrons"]),
 "bolt":    _sp((0.78, 0.18, 0.15), (1.0, 0.85, 0.2), (1.0, 0.7, 0.2), (0.18, 0.15, 0.13), (0.55, 0.37, 0.27), (0.1, 0.06, 0.04), 1.2, 0.92, "bald_top", "full", "lamp", ["pouches", "tool"]),
 "tess":    _sp((0.95, 0.75, 0.12), (0.12, 0.12, 0.15), (1.0, 0.55, 0.1), (0.2, 0.17, 0.13), (0.9, 0.7, 0.58), (0.3, 0.17, 0.08), 0.97, 0.96, "pony", "none", "goggles", ["pouches", "tool"]),
 "gorn":    _sp((0.22, 0.24, 0.28), (1.0, 0.45, 0.1), (1.0, 0.45, 0.1), (0.12, 0.12, 0.14), (0.7, 0.5, 0.4), (0.5, 0.2, 0.1), 1.38, 0.94, "none", "full", "lamp", ["pauldrons", "glowcore", "pouches"]),
 "lumi":    _sp((0.85, 0.93, 0.95), (0.2, 0.8, 0.8), (0.3, 0.9, 0.9), (0.9, 0.93, 0.95), (0.95, 0.8, 0.7), (0.35, 0.6, 0.95), 0.88, 1.02, "short", "none", "none", ["tablet"]),
 "quark":   _sp((0.3, 0.28, 0.66), (0.75, 0.6, 1.0), (0.75, 0.6, 1.0), (0.2, 0.2, 0.3), (0.82, 0.62, 0.5), (0.7, 0.7, 0.75), 1.0, 1.04, "bald_top", "stache", "none", ["scanner"], None, True),
 "elara":   _sp((0.95, 0.95, 0.97), (1.0, 0.8, 0.25), (1.0, 0.8, 0.25), (0.95, 0.85, 0.5), (0.95, 0.82, 0.74), (0.6, 0.25, 0.85), 0.88, 1.08, "long", "none", "halo", ["orb", "epaulet"]),
 "vance":   _sp((0.08, 0.14, 0.38), (0.95, 0.78, 0.25), (0.9, 0.2, 0.2), (0.12, 0.13, 0.18), (0.82, 0.62, 0.5), (0.92, 0.92, 0.95), 1.1, 1.08, "short", "stache", "none", ["epaulet", "medals"], "suit"),
 "nox":     _sp((0.7, 0.74, 0.8), (0.75, 0.45, 1.0), (0.75, 0.45, 1.0), (0.25, 0.27, 0.32), (0.6, 0.64, 0.7), (0, 0, 0), 1.0, 1.0, "none", "none", "none", []),
}

# poses : rotations en repère monde par os (degrés) ; clé = (os, axe) -> angle
POSES = {
 "idle":   {"arm.L": (0, 0), "arm.R": (0, 0)},
 "walk":   {"arm.L": (28, 0), "arm.R": (-28, 0), "fore.L": (22, 0), "fore.R": (-4, 0), "thigh.L": (-26, 0), "thigh.R": (26, 0), "shin.L": (4, 0), "shin.R": (36, 0), "spine": (4, 0)},
 "point":  {"arm.R": (82, 24), "fore.R": (8, 0), "head": (0, -10), "spine": (3, 0)},
 "work":   {"arm.L": (50, 8), "arm.R": (55, -8), "fore.L": (40, 0), "fore.R": (45, 0), "spine": (9, 0), "head": (6, 0)},
 "salute": {"arm.R": (130, 20), "fore.R": (60, 0)},
 "think":  {"arm.R": (118, 0), "fore.R": (70, 0), "arm.L": (35, 0), "fore.L": (45, 0), "head": (0, 12)},
 "cheer":  {"arm.L": (160, 25), "arm.R": (160, -25), "fore.L": (8, 0), "fore.R": (8, 0), "spine": (-4, 0)},
}
PIV = {}

def _rot_world(pb, axis, ang):
    pb.rotation_mode = "QUATERNION"
    rest = pb.bone.matrix_local.to_3x3()
    qw = Quaternion(axis, math.radians(ang)).to_matrix()
    loc = rest.inverted() @ qw @ rest
    q = loc.to_quaternion()
    pb.rotation_quaternion = q @ pb.rotation_quaternion if pb.rotation_quaternion != Quaternion((1, 0, 0, 0)) else q

def pose_bone(arm_ob, bone, fwd=0.0, side=0.0, twist=0.0):
    """fwd : bascule avant/arrière (axe X monde) ; side : écart latéral (axe Y monde, signe selon le côté) ; twist : axe Z."""
    pb = arm_ob.pose.bones[bone]
    pb.rotation_mode = "QUATERNION"; pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
    rest = pb.bone.matrix_local.to_3x3()
    R = Matrix.Identity(3)
    if fwd: R = Quaternion((1, 0, 0), math.radians(fwd)).to_matrix() @ R
    if side:
        sgn = -1 if bone.endswith(".L") else 1
        R = Quaternion((0, 1, 0), math.radians(side * sgn)).to_matrix() @ R
    if twist: R = Quaternion((0, 0, 1), math.radians(twist)).to_matrix() @ R
    pb.rotation_quaternion = (rest.inverted() @ R @ rest).to_quaternion()

def apply_pose(arm_ob, pose):
    for b in arm_ob.pose.bones:
        b.rotation_mode = "QUATERNION"; b.rotation_quaternion = Quaternion((1, 0, 0, 0)); b.location = (0, 0, 0)
    for bn, vals in POSES[pose].items():
        a, sd = vals
        if bn == "head":
            pose_bone(arm_ob, bn, fwd=a, twist=sd)
        else:
            pose_bone(arm_ob, bn, fwd=a, side=sd)
    # A-pose naturelle : bras légèrement écartés au repos (déjà dans le squelette)

def make(name, pose="idle", s=1.0, suit_override=None, godot=False):
    sp_ = dict(SPECS[name])
    if suit_override: sp_.update(suit_override)
    bk = sp_["bulk"]; H = sp_["h"]; ex = sp_["extras"]
    W = bk
    arm_ob = build_armature("char_" + name)
    suit = M("suit_steel" if godot else name + "_suit", sp_["suit"], 0.0, 0.55)
    if godot:
        trim = M("accent_cyan", sp_["trim"], 0.1, 0.45)
        b_ = trim.node_tree.nodes["Principled BSDF"]; b_.inputs["Emission Color"].default_value = (*sp_["trim"], 1); b_.inputs["Emission Strength"].default_value = 0.35
    else:
        trim = M(name + "_trim", sp_["trim"], 0.0, 0.45)
    gray = M("gray", (0.55, 0.57, 0.6), 0.2, 0.5); dark = M("dark", (0.06, 0.08, 0.16), 0.2, 0.5)
    boot = M(name + "_boot", sp_["boot"], 0.0, 0.6); skin = M(name + "_skin", sp_["skin"], 0.0, 0.7)
    hair = M(name + "_hair", sp_["hair"], 0.0, 0.7); black = M("black", (0.02, 0.02, 0.03), 0.0, 0.4)
    white = M("white", (0.95, 0.95, 0.97), 0.0, 0.5); vis = E(name + "_vis", sp_["vis"], 1.2)
    gold = M("gold", (1.0, 0.8, 0.2), 0.6, 0.3); brown = M("kneepad", (0.42, 0.33, 0.26), 0.0, 0.7)
    parts = []   # (objet, os)

    def add(ob, bone, smooth=True):
        if smooth: _smooth(ob)
        parts.append((ob, bone)); return ob

    def rbox(nm, size, loc, mat, bone, rot=(0, 0, 0), r=0.25, sub=1):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        ob = bpy.context.active_object; ob.name = nm; ob.scale = size
        bpy.ops.object.transform_apply(scale=True, rotation=False)
        md = ob.modifiers.new("b", "BEVEL"); md.width = r * min(size); md.segments = 3; md.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="b")
        if sub:
            sm = ob.modifiers.new("s", "SUBSURF"); sm.levels = 1; sm.render_levels = 1
            bpy.ops.object.modifier_apply(modifier="s")
        ob.data.materials.append(mat); return add(ob, bone)

    def rsph(nm, rad, loc, mat, bone, scale=(1, 1, 1), seg=14, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rad, segments=seg, ring_count=max(5, seg // 2), location=loc, rotation=rot)
        ob = bpy.context.active_object; ob.name = nm; ob.scale = scale
        ob.data.materials.append(mat); return add(ob, bone)

    def rcyl(nm, r1, r2, h, loc, mat, bone, rot=(0, 0, 0), seg=14):
        bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
        ob = bpy.context.active_object; ob.name = nm
        ob.data.materials.append(mat); return add(ob, bone)

    def rtor(nm, R_, r_, loc, mat, bone, rot=(0, 0, 0), seg=20):
        bpy.ops.mesh.primitive_torus_add(major_radius=R_, minor_radius=r_, major_segments=seg, minor_segments=8, location=loc, rotation=rot)
        ob = bpy.context.active_object; ob.name = nm
        ob.data.materials.append(mat); return add(ob, bone)

    def hose(nm, pts, rad, mat, bone):
        bm, ts, rows = sweep_mesh(pts, [rad] * len(pts), None, 8, 10)
        ob = new_obj(nm, bm, mat); return add(ob, bone)

    # ---------------------------------------------------------------- corps balayé (pondérations lissées)
    def body_part(nm, pts, rx, ry, mat, path_bones, n=14, k=16, up=(0, 1, 0), mirror=1):
        bm, ts, rows = sweep_mesh(pts, rx, ry, n, k, up)
        # poids par anneau
        wl = []
        for i, t in enumerate(ts):
            wd = bone_weights_for_t(path_bones, t)
            wl.extend([wd] * n)
        # les deux sommets de capuchon : aucun (les faces de bouchon réutilisent les sommets d'anneau)
        ob = new_obj(nm, bm, mat)
        skin_object(ob, arm_ob, wl)
        _smooth(ob)
        return ob
    # torse
    body_part("torso", [(0, 0.004, 0.46), (0, 0.008, 0.56), (0, 0.012, 0.68), (0, 0.004, 0.77), (0, -0.0, 0.83)],
              [0.125 * W, 0.112 * W, 0.152 * W, 0.168 * W, 0.075], [0.088, 0.08, 0.104, 0.097, 0.07], suit,
              [("hips", 0.0), ("spine", 0.26), ("chest", 0.56)], n=16, k=18)
    for sx, sd in ((-1, "L"), (1, "R")):
        # jambes
        body_part("leg" + sd, [(sx * 0.066, 0.0, 0.52), (sx * 0.07, 0.004, 0.4), (sx * 0.075, 0.012, 0.26), (sx * 0.078, 0.0, 0.17), (sx * 0.08, -0.005, 0.09)],
                  [0.092 * W, 0.086 * W, 0.063 * W, 0.066 * W, 0.047 * W], [0.095 * W, 0.088 * W, 0.066 * W, 0.074 * W, 0.047 * W], suit,
                  [("thigh." + sd, 0.0), ("shin." + sd, 0.5), ("foot." + sd, 0.97)], n=14, k=16, up=(0, 1, 0))
        # bras
        body_part("arm" + sd, [(sx * 0.15, 0.0, 0.775), (sx * 0.215, 0.004, 0.7), (sx * 0.26, 0.01, 0.63), (sx * 0.29, 0.03, 0.56), (sx * 0.315, 0.04, 0.5)],
                  [0.07 * W, 0.064 * W, 0.054 * W, 0.052 * W, 0.04 * W], None, suit,
                  [("arm." + sd, 0.0), ("fore." + sd, 0.48)], n=12, k=14, up=(0, 1, 0))
    # ---------------------------------------------------------------- détails rigides
    for sx, sd in ((-1, "L"), (1, "R")):
        # épaulière + liserés
        rbox("pad" + sd, (0.13 * W, 0.125, 0.085), (sx * 0.185, 0.0, 0.795), suit, "arm." + sd, (0, 0, sx * -0.3), 0.35)
        rbox("padline" + sd, (0.136 * W, 0.131, 0.012), (sx * 0.185, 0.0, 0.762), trim, "arm." + sd, (0, 0, sx * -0.3), 0.3)
        rtor("elbow" + sd, 0.062 * W, 0.012, (sx * 0.26, 0.012, 0.63), dark, "fore." + sd, (0, math.radians(sx * 30), 0), 18)
        rcyl("cuff" + sd, 0.05 * W, 0.05 * W, 0.045, (sx * 0.318, 0.042, 0.485), trim, "hand." + sd, (math.radians(-8), math.radians(sx * 27), 0), 16)
        rtor("cuffring" + sd, 0.052 * W, 0.011, (sx * 0.322, 0.044, 0.465), dark, "hand." + sd, (math.radians(-8), math.radians(sx * 27), 0), 16)
        gl = white if name in ("captain", "lumi", "elara", "vance") else boot
        rsph("glove" + sd, 0.058 * W, (sx * 0.333, 0.052, 0.435), gl, "hand." + sd, (1, 1.05, 1.15), 14)
        rsph("thumb" + sd, 0.026, (sx * 0.305, 0.082, 0.45), gl, "hand." + sd, (1, 1.4, 1), 10)
        if "pauldrons" in ex:
            rbox("pauldron" + sd, (0.18 * W, 0.17, 0.06), (sx * 0.19, 0.0, 0.83), trim if name == "gorn" else gold, "arm." + sd, (0, 0, sx * -0.3), 0.3)
        # genouillère, bandes, bottes
        rbox("kneepad" + sd, (0.095 * W, 0.05, 0.105), (sx * 0.076, 0.07 * W, 0.26), brown, "thigh." + sd, (0, 0, 0), 0.3)
        rtor("kneering" + sd, 0.07 * W, 0.012, (sx * 0.075, 0.012, 0.245), dark, "shin." + sd, (0, 0, 0), 18)
        rtor("ankring" + sd, 0.05 * W, 0.013, (sx * 0.08, -0.004, 0.095), dark, "foot." + sd, (0, 0, 0), 16)
        rtor("ankline" + sd, 0.052 * W, 0.008, (sx * 0.08, -0.004, 0.115), trim, "foot." + sd, (0, 0, 0), 16)
        rbox("boot" + sd, (0.11 * W, 0.215, 0.1), (sx * 0.08, 0.028, 0.058), boot, "foot." + sd, (0, 0, 0), 0.4)
        rsph("toe" + sd, 0.058 * W, (sx * 0.08, 0.11, 0.05), boot, "foot." + sd, (1, 1.05, 0.8), 14)
        rbox("sole" + sd, (0.116 * W, 0.235, 0.022), (sx * 0.08, 0.04, 0.012), E("sole", (0.3, 0.8, 1.0), 2.5) if name in ("captain", "vance", "nox") else dark, "foot." + sd, (0, 0, 0), 0.3, 0)
        rbox("bootline" + sd, (0.114 * W, 0.17, 0.012), (sx * 0.08, 0.02, 0.1), trim, "foot." + sd, (0, 0, 0), 0.3, 0)
        # liserés le long des membres
        for (nm_, a, b, bone_) in ((("legline" + sd), (sx * 0.15 * W, 0.0, 0.5), (sx * 0.14 * W, 0.0, 0.12), "thigh." + sd),):
            hose(nm_, [(sx * (0.16 + 0.0) * W * 0.62, 0.0, 0.5), (sx * 0.17 * W * 0.65, 0.004, 0.4), (sx * 0.18 * W * 0.62, 0.012, 0.26), (sx * 0.185 * W * 0.6, 0.0, 0.17), (sx * 0.19 * W * 0.58, -0.005, 0.1)], 0.0, trim, bone_) if False else None
    # ceinture, panneau, sac
    rtor("beltband", 0.118 * W, 0.02, (0, 0.006, 0.55), trim, "spine", (0, 0, 0), 24)
    rbox("buckle", (0.075, 0.025, 0.05), (0, 0.105 * W, 0.55), gray, "spine", (0, 0, 0), 0.3)
    rbox("zip", (0.018, 0.014, 0.22), (0, 0.132, 0.67), trim, "chest", (0, 0, 0), 0.3, 0)
    rbox("panel", (0.15, 0.03, 0.115), (0, 0.14, 0.675), gray, "chest", (0, 0, 0), 0.25)
    rbox("screen", (0.108, 0.014, 0.036), (0, 0.158, 0.7), E("scr", (0.85, 0.95, 0.35) if name != "nox" else sp_["vis"], 1.4), "chest", (0, 0, 0), 0.2, 0)
    for k_, c in enumerate(((1, 0.3, 0.2), (0.95, 0.95, 0.95), (0.3, 0.6, 1))):
        rbox("btn", (0.026, 0.014, 0.022), (-0.04 + k_ * 0.04, 0.158, 0.652), E("btn", c, 2.5), "chest", (0, 0, 0), 0.25, 0)
    rsph("dial", 0.02, (0.062, 0.16, 0.658), white, "chest", (1, 0.4, 1), 10)
    for k_, c in enumerate(((0.2, 0.7, 0.3), (1, 1, 1), (1.0, 0.5, 0.1))):
        rbox("flag", (0.032, 0.012, 0.02), (-0.075 * W + k_ * 0.036, 0.112, 0.78), M("flag", c, 0, 0.6), "chest", (0, 0, 0), 0.2, 0)
    rbox("pack_panel" if godot else "packpanel", (0.25 * W, 0.016, 0.05), (0, -0.2, 0.76), trim, "chest", (0, 0, 0), 0.3, 0)
    rbox("pack", (0.3 * W, 0.15, 0.34), (0, -0.14, 0.66), white if name != "nox" else gray, "chest", (0, 0, 0), 0.3)
    rbox("packlight", (0.07, 0.014, 0.035), (0, -0.218, 0.58), E("pl", (1.0, 0.3, 0.3), 3.0), "chest", (0, 0, 0), 0.25, 0)
    for sx in (-1, 1):
        hose("hose", [(sx * 0.1 * W, -0.16, 0.83), (sx * 0.19 * W, -0.11, 0.9), (sx * 0.14 * W, -0.01, 0.9), (sx * 0.09, 0.05, 0.86)], 0.018, black, "chest")
    if "antenna" in ex:
        rcyl("antenna", 0.01, 0.01, 0.2, (0.11 * W, -0.19, 0.92), gray, "chest", (0, 0, 0), 6)
        rsph("antenna_tip", 0.024, (0.11 * W, -0.19, 1.03), E("atip", (1.0, 0.3, 0.8), 5.0), "chest", (1, 1, 1), 8)
    # ---------------------------------------------------------------- tête, casque, visage
    hz = 0.945; R = 0.17
    rcyl("neck", 0.065, 0.075, 0.07, (0, 0, 0.835), dark, "neck", (0, 0, 0), 14)
    rtor("neckring", 0.085, 0.026, (0, 0, 0.855), dark, "neck", (0, 0, 0), 20)
    rtor("neckseal", 0.088, 0.01, (0, 0, 0.88), trim, "neck", (0, 0, 0), 20)
    hs = sp_["hair_style"]; bd = sp_["beard"]; hat = sp_["hat"]
    if name == "nox":
        rsph("head", R * 1.0, (0, 0, hz), M("noxhead", (0.8, 0.83, 0.88), 0.5, 0.35), "head", (1, 0.95, 1), 20)
        rbox("face", (0.16, 0.024, 0.075), (0, R * 0.95, hz + 0.004), black, "head", (0, 0, 0), 0.4)
        for sx in (-1, 1): rsph("led", 0.017, (sx * 0.038, R * 1.0, hz + 0.004), vis, "head", (1, 0.4, 1), 8)
        rcyl("ant", 0.008, 0.008, 0.1, (0.05, 0, hz + R), gray, "head", (0, 0, 0), 6)
        rsph("anttip", 0.02, (0.05, 0, hz + R + 0.06), E("tip", (1.0, 0.4, 0.8), 5.0), "head", (1, 1, 1), 8)
        for sx in (-1, 1): rcyl("ear", 0.045, 0.045, 0.03, (sx * R * 1.02, 0, hz), trim, "head", (0, math.radians(90), 0), 12)
    else:
        hr = R * 0.76
        rsph("head", hr, (0, 0.006, hz - 0.004), skin, "head", (1.0, 0.97, 1.08), 24)
        fy = hr * 0.97 + 0.006
        for sx in (-1, 1):
            rsph("ear", 0.026, (sx * hr * 0.99, 0.0, hz - 0.012), skin, "head", (0.5, 0.9, 1.3), 10)
            rsph("eyew", 0.021, (sx * 0.04, fy - 0.004, hz + 0.014), white, "head", (1, 0.45, 0.85), 12)
            rsph("eye", 0.012, (sx * 0.04, fy + 0.002, hz + 0.014), black, "head", (1, 0.5, 1), 10)
            rbox("brow" + ("L" if sx < 0 else "R"), (0.044, 0.014, 0.013), (sx * 0.042, fy - 0.001, hz + 0.047), hair if (hs != "none" or bd != "none") else black, "brow." + ("L" if sx < 0 else "R"), (0, 0, sx * -0.2), 0.3, 0)
            rsph("lid" + ("L" if sx < 0 else "R"), 0.0225, (sx * 0.04, fy - 0.001, hz + 0.0195), skin, "lid." + ("L" if sx < 0 else "R"), (1, 0.5, 0.55), 12)
        rbox("nosebridge", (0.016, 0.02, 0.04), (0, fy, hz - 0.006), skin, "head", (0, 0, 0), 0.4)
        rcyl("nose", 0.022, 0.008, 0.036, (0, fy + 0.018, hz - 0.026), skin, "head", (math.radians(-90), 0, 0), 5)
        rbox("mouth", (0.05, 0.01, 0.011), (0, fy - 0.003, hz - 0.062), M("lip", (0.5, 0.2, 0.18)), "jaw", (0, 0, 0), 0.3, 0)
        if sp_["glasses"]:
            for sx in (-1, 1): rtor("glass", 0.026, 0.005, (sx * 0.04, fy + 0.008, hz + 0.014), black, "head", (math.radians(90), 0, 0), 14)
            rbox("bridge", (0.018, 0.006, 0.006), (0, fy + 0.008, hz + 0.02), black, "head", (0, 0, 0), 0.3, 0)
        if hs in ("short", "spiky", "bob", "pony", "long"):
            rsph("hair", hr * 1.05, (0, -0.012, hz + 0.014), hair, "head", (1.0, 1.0, 0.92), 16)
        if hs == "spiky":
            for k_ in range(5):
                a = math.radians(-50 + k_ * 25)
                rcyl("spike", 0.03, 0.0, 0.07, (math.sin(a) * 0.058, -0.005, hz + 0.085), hair, "head", (0, math.sin(a) * 0.6, 0), 5)
        if hs in ("bob", "pony", "long", "short"):
            rbox("fringe", (0.1, 0.025, 0.03), (0.01, fy - 0.004, hz + 0.058), hair, "head", (0, 0, -0.18), 0.3, 0)
        if hs == "bob":
            for sx in (-1, 1): rbox("lock", (0.028, 0.06, 0.09), (sx * 0.076, -0.01, hz - 0.03), hair, "head", (0, 0, 0), 0.4, 0)
        if hs == "pony": rcyl("pony", 0.03, 0.01, 0.17, (0, -hr * 0.85, hz - 0.04), hair, "head", (math.radians(20), 0, 0), 8)
        if hs == "long":
            rbox("mane", (0.18, 0.05, 0.28), (0, -0.08, hz - 0.1), hair, "head", (0, 0, 0), 0.3)
            for sx in (-1, 1): rbox("lock", (0.028, 0.05, 0.14), (sx * 0.078, -0.02, hz - 0.05), hair, "head", (0, 0, 0), 0.4, 0)
        if hs == "bald_top":
            for sx in (-1, 1): rbox("sidehair", (0.028, 0.07, 0.05), (sx * 0.076, -0.02, hz - 0.01), hair, "head", (0, 0, 0), 0.4, 0)
        if bd == "full":
            rbox("beard", (0.105, 0.052, 0.062), (0, fy - 0.014, hz - 0.058), hair, "jaw", (0, 0, 0), 0.4)
            rbox("beardchin", (0.072, 0.042, 0.04), (0, fy - 0.012, hz - 0.088), hair, "jaw", (0, 0, 0), 0.4)
            rbox("stache", (0.074, 0.024, 0.02), (0, fy + 0.004, hz - 0.03), hair, "head", (0, 0, 0), 0.4, 0)
            for sx in (-1, 1): rbox("burn", (0.022, 0.05, 0.068), (sx * 0.068, fy - 0.03, hz - 0.025), hair, "head", (0, 0, 0), 0.4, 0)
        elif bd == "stache":
            rbox("stache", (0.074, 0.024, 0.02), (0, fy + 0.004, hz - 0.03), hair, "head", (0, 0, 0), 0.4, 0)
        # casque
        hcol = sp_["suit"] if sp_["helm"] == "suit" else (0.94, 0.95, 0.97)
        shell = M(name + "_helm", hcol, 0.0, 0.4)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=R * 1.2, segments=28, ring_count=18, location=(0, 0, hz))
        hsph = bpy.context.active_object; hsph.name = "helmet"
        bm = bmesh.new(); bm.from_mesh(hsph.data); bm.faces.ensure_lookup_table()
        kill = [f for f in bm.faces if f.calc_center_median().y > R * 0.5 and abs(f.calc_center_median().x) < R * 0.95 and -R * 0.8 < f.calc_center_median().z < R * 0.7]
        bmesh.ops.delete(bm, geom=kill, context="FACES")
        bm.to_mesh(hsph.data); bm.free()
        md = hsph.modifiers.new("sol", "SOLIDIFY"); md.thickness = 0.016
        bpy.ops.object.modifier_apply(modifier="sol")
        hsph.data.materials.append(shell); add(hsph, "head")
        rsph("visorglass", R * 1.19, (0, 0.003, hz), glass("visor", (0.7, 0.85, 1.0), 0.08), "head", (1, 1, 1), 28)
        rtor("rim", R * 0.99, 0.015, (0, R * 0.52, hz - 0.002), trim, "head", (math.radians(90), 0, 0), 22)
        for sx in (-1, 1):
            rcyl("earpod", 0.05, 0.05, 0.04, (sx * R * 1.2, 0, hz), trim, "head", (0, math.radians(90), 0), 14)
            rcyl("earcap", 0.034, 0.034, 0.02, (sx * R * 1.33, 0, hz), gray, "head", (0, math.radians(90), 0), 14)
        rbox("ridge", (0.03, R * 1.6, 0.02), (0, -0.012, hz + R * 1.19), trim, "head", (0, 0, 0), 0.3, 0)
        rbox("backlight", (0.05, 0.014, 0.03), (0, -R * 1.2, hz + 0.01), E("bl", (1.0, 0.3, 0.3), 2.5), "head", (0, 0, 0), 0.25, 0)
        if hat == "lamp":
            rsph("lamp", 0.026, (0, R * 1.0, hz + R * 1.05), E("lamp", (1.0, 0.95, 0.7), 8.0), "head", (1, 1.3, 1), 8)
        elif hat == "goggles":
            rtor("gband", R * 1.19, 0.012, (0, 0, hz + R * 0.58), black, "head", (0, 0, 0), 24)
            for sx in (-1, 1):
                rtor("goggle", 0.04, 0.012, (sx * 0.05, R * 1.08, hz + R * 0.6), black, "head", (math.radians(80), 0, 0), 14)
                rsph("lens", 0.033, (sx * 0.05, R * 1.07, hz + R * 0.6), E("lens", (1.0, 0.7, 0.2), 1.5), "head", (1, 0.2, 1), 10)
        elif hat == "headband":
            rtor("hband", R * 1.21, 0.014, (0, 0, hz + R * 0.55), M("hb", (1.0, 0.95, 0.95), 0.0, 0.5), "head", (0, 0, 0), 24)
        elif hat == "halo":
            rtor("halo", 0.11, 0.008, (0, 0, hz + R * 1.55), E("halo", (1.0, 0.85, 0.35), 6.0), "head", (0, 0, 0), 24)
    # ---------------------------------------------------------------- accessoires
    if "epaulet" in ex:
        for sx in (-1, 1): rbox("epaulet", (0.075, 0.07, 0.014), (sx * 0.19, 0, 0.84), gold, "arm." + ("L" if sx < 0 else "R"), (0, 0, sx * -0.3), 0.3, 0)
    if "pouches" in ex:
        for k_ in range(3): rbox("pouch", (0.05, 0.034, 0.055), (-0.09 + k_ * 0.09, 0.1, 0.5), M("pouch", (0.3, 0.22, 0.12), 0, 0.8), "hips", (0, 0, 0), 0.3)
    if "tool" in ex:
        rbox("tool", (0.024, 0.02, 0.13), (0.16 * W, 0.07, 0.49), M("steel", (0.65, 0.67, 0.7), 0.9, 0.3), "hips", (0, 0.2, 0.3), 0.3, 0)
    if "tablet" in ex:
        rbox("tablet", (0.1, 0.012, 0.13), (-0.335, 0.085, 0.41), E("tab", (0.3, 1.0, 0.7), 2.0), "hand.L", (0, 0, 0), 0.2, 0)
    if "scanner" in ex:
        rbox("scanner", (0.05, 0.03, 0.12), (0.335, 0.08, 0.4), M("scan", (0.2, 0.22, 0.3), 0.6, 0.4), "hand.R", (0, 0, 0), 0.3)
        rsph("scanlight", 0.022, (0.335, 0.1, 0.34), E("scl", (0.6, 0.4, 1.0), 7.0), "hand.R", (1, 1, 1), 8)
    if "medals" in ex:
        for k_ in range(3): rbox("medal", (0.02, 0.01, 0.02), (0.03 + k_ * 0.028, 0.12, 0.74), gold if k_ != 1 else trim, "chest", (0, 0, 0), 0.3, 0)
    if "wings" in ex:
        rbox("wing", (0.08 * (1.3 if name == "zara" else 1), 0.012, 0.03), (0.065, 0.12, 0.62), gold if name == "zara" else trim, "chest", (0, 0, 0), 0.3, 0)
    if "scarf" in ex:
        rtor("scarf", 0.09, 0.03, (0, 0, 0.82), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), "chest", (0, 0, 0), 16)
        rbox("scarftail", (0.055, 0.02, 0.2), (0.07, 0.085, 0.7), M("scarf", (0.1, 0.75, 0.95), 0, 0.8), "chest", (0.1, 0, 0.2), 0.3, 0)
    if "glowcore" in ex:
        rsph("core", 0.04, (0, 0.118, 0.6), E("core", (1.0, 0.5, 0.15), 8.0), "chest", (1, 0.6, 1), 10)
    if "orb" in ex:
        rsph("orb", 0.045, (-0.4 * W, 0.1, 0.62), E("orb", (0.8, 0.6, 1.0), 8.0), "chest", (1, 1, 1), 10)
    # ---------------------------------------------------------------- fusion par (os, matière) puis peau
    groups = {}
    for ob, bone in parts:
        key = (bone, ob.data.materials[0].name if ob.data.materials else "")
        groups.setdefault(key, []).append(ob)
    for (bone, mn), obs in groups.items():
        for o in obs:
            if o.modifiers: pass
        bpy.ops.object.select_all(action="DESELECT")
        for o in obs: o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1: bpy.ops.object.join()
        j = bpy.context.active_object; j.name = "%s_%s" % (bone, mn)
        skin_object(j, arm_ob, bone)
    arm_ob.scale = (s * H * 0.9,) * 3
    apply_pose(arm_ob, pose)
    PIV[arm_ob.name] = arm_ob
    return arm_ob

# ------------------------------------------------------------------ animation
def _key(arm_ob, frame):
    for pb in arm_ob.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)

def _setpose(arm_ob, d, face=None):
    for b in arm_ob.pose.bones:
        b.rotation_mode = "QUATERNION"; b.rotation_quaternion = Quaternion((1, 0, 0, 0)); b.location = (0, 0, 0)
    for bn, (a, sd) in d.items():
        if bn == "head": pose_bone(arm_ob, bn, fwd=a, twist=sd)
        else: pose_bone(arm_ob, bn, fwd=a, side=sd)
    if face:
        for bn, (dz, dy) in face.items():   # décalages locaux (visage)
            arm_ob.pose.bones[bn].location = (0, dy, dz)

def animate(root):
    """Clips Idle, Walk, Run, Shoot, Smile, Angry, Surprised (NLA)."""
    arm_ob = root
    bpy.context.scene.render.fps = 24
    arm_ob.animation_data_create()
    def clip(nm, frames):
        act = bpy.data.actions.new(nm); arm_ob.animation_data.action = act
        for f, d, face in frames:
            _setpose(arm_ob, d, face); _key(arm_ob, f)
        arm_ob.animation_data.action = None
        tr_ = arm_ob.animation_data.nla_tracks.new(); tr_.name = nm; tr_.strips.new(nm, 1, act)
    breathe = lambda a: {"spine": (a, 0), "chest": (a * 0.6, 0), "head": (-a * 0.5, 0), "arm.L": (1, 0), "arm.R": (1, 0)}
    clip("Idle", [(1, breathe(0), None), (30, breathe(2.2), None), (60, breathe(0), None)])
    w = lambda s_: {"arm.L": (28 * s_, 0), "arm.R": (-28 * s_, 0), "fore.L": (22 if s_ > 0 else 4, 0), "fore.R": (4 if s_ > 0 else 22, 0),
                    "thigh.L": (-26 * s_, 0), "thigh.R": (26 * s_, 0), "shin.L": (4 if s_ > 0 else 36, 0), "shin.R": (36 if s_ > 0 else 4, 0), "spine": (4, 0), "hips": (0, 0)}
    clip("Walk", [(1, w(1), None), (13, w(-1), None), (25, w(1), None)])
    r = lambda s_: {"arm.L": (60 * s_, 0), "arm.R": (-60 * s_, 0), "fore.L": (75 if s_ > 0 else 20, 0), "fore.R": (20 if s_ > 0 else 75, 0),
                    "thigh.L": (-50 * s_, 0), "thigh.R": (50 * s_, 0), "shin.L": (8 if s_ > 0 else 80, 0), "shin.R": (80 if s_ > 0 else 8, 0), "spine": (14, 0)}
    clip("Run", [(1, r(1), None), (9, r(-1), None), (17, r(1), None)])
    sh0 = {"arm.R": (5, 0), "arm.L": (5, 0)}
    sh1 = {"arm.R": (88, -6), "arm.L": (82, 14), "fore.R": (6, 0), "fore.L": (14, 0), "spine": (-3, 0)}
    clip("Shoot", [(1, sh0, None), (6, sh1, None), (10, sh1, None), (16, sh0, None)])
    face0 = {}
    clip("Smile", [(1, {}, {"jaw": (0, 0)}), (8, {"head": (0, 0)}, {"jaw": (-0.01, 0), "brow.L": (0.004, 0), "brow.R": (0.004, 0)}), (24, {}, {"jaw": (0, 0)})])
    clip("Angry", [(1, {}, {}), (8, {}, {"brow.L": (-0.012, 0), "brow.R": (-0.012, 0), "jaw": (-0.006, 0)}), (24, {}, {})])
    clip("Surprised", [(1, {}, {}), (8, {}, {"brow.L": (0.016, 0), "brow.R": (0.016, 0), "jaw": (-0.026, 0), "lid.L": (0.008, 0), "lid.R": (0.008, 0)}), (24, {}, {})])
    for b in arm_ob.pose.bones:
        b.rotation_quaternion = Quaternion((1, 0, 0, 0)); b.location = (0, 0, 0)
    apply_pose(arm_ob, "idle")

def all_children(root):
    return [root] + list(root.children)
