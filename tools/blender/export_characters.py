"""Exporte les astronautes en GLB pour Godot : python tools/blender/export_characters.py [--out assets/models] [--base assets/base] [nom ...]
Le Capitaine (assets/base/captain.glb) garde les noms de matières attendus par base_view.gd (suit_steel, accent_cyan), les nœuds
antenna / antenna_tip / pack_panel et les clips Walk, Shoot, Idle. Les autres personnages vont dans assets/models/char_<nom>.glb."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
args = sys.argv[1:]; OUT = os.path.join(ROOT, "assets", "models"); BASE = os.path.join(ROOT, "assets", "base"); names = []
i = 0
while i < len(args):
    if args[i] == "--out": OUT = args[i+1]; i += 2
    elif args[i] == "--base": BASE = args[i+1]; i += 2
    else: names.append(args[i]); i += 1
import bpy
import characters_q as characters
from lib import reset

def merge_by_material(root):
    """Réunit les maillages à une seule matière identique (couleur, métal, rugosité, émission) : moins de surfaces donc moins d'appels
    de dessin dans Godot (~80 -> ~30 par personnage), sans changer l'aspect ni la déformation (mêmes groupes de sommets)."""
    def key(o):
        m = o.material_slots[0].material
        if m is None or not m.use_nodes: return None
        b = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if b is None: return None
        def v(name):
            val = b.inputs[name].default_value
            return tuple(round(x, 3) for x in val) if hasattr(val, "__len__") else round(val, 3)
        return (v("Base Color"), v("Metallic"), v("Roughness"), v("Emission Color"), v("Emission Strength"), v("Alpha"))
    groups = {}
    for o in bpy.data.objects:
        if o.type != "MESH" or len(o.material_slots) != 1 or o.parent_type == "BONE": continue
        k = key(o)
        if k is not None: groups.setdefault((k, o.parent.name if o.parent else ""), []).append(o)
    n = 0
    for objs in groups.values():
        if len(objs) < 2: continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs: o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join(); n += len(objs) - 1
    return n


ALL = ["captain", "rex", "nova", "zara", "bolt", "tess", "gorn", "lumi", "quark", "elara", "vance", "nox", "droid", "jett", "vega", "sira", "tick", "brakk", "maya", "zyl", "sage", "ilan"]
for n in (names or ALL):
    reset()
    god = n == "captain"
    r = characters.make(n, "idle", 0.82 if god else 1.0, godot=god)
    characters.animate(r)
    if not god and not os.environ.get("NOMERGE"): print("fusion", merge_by_material(r))
    characters.PIV[r.name].name = "rig"; r.name = "char"   # mêmes noms de nœuds pour tous : la bibliothèque human_anims.glb s'applique à chacun
    bpy.context.view_layer.update()
    path = os.path.join(BASE, "captain.glb") if god else os.path.join(OUT, "char_%s.glb" % n)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animation_mode="NLA_TRACKS", export_apply=True, use_visible=True, export_texcoords=False)
    import glb_slim
    print("ok", n, path, glb_slim.slim(path))
