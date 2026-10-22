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
import characters
from lib import reset

ALL = ["captain", "rex", "nova", "zara", "bolt", "tess", "gorn", "lumi", "quark", "elara", "vance", "nox"]
for n in (names or ALL):
    reset()
    god = n == "captain"
    r = characters.make(n, "idle", 0.82 if god else 1.0, godot=god)
    characters.animate(r)
    bpy.context.view_layer.update()
    path = os.path.join(BASE, "captain.glb") if god else os.path.join(OUT, "char_%s.glb" % n)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animation_mode="NLA_TRACKS", export_apply=True, use_visible=True)
    print("ok", n, path)
