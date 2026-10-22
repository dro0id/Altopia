"""Exporte la bibliothèque d'animations humaines (toutes les clips de anims_q) : assets/animations/human_anims.glb
Squelette Humanoid + os de visage, sans maillage. À fusionner dans l'AnimationPlayer d'un personnage (même squelette) avec scripts/char_anims.gd."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import bpy
import characters_q
import anims_q
from lib import reset
import glb_slim

reset()
r = characters_q.make("captain", "idle", 1.0)
characters_q.animate(r, list(anims_q.CLIPS))
arm = characters_q.PIV[r.name]
arm.name = "rig"; r.name = "char"
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True); r.select_set(True); bpy.context.view_layer.objects.active = arm
path = os.path.join(ROOT, "assets", "animations", "human_anims.glb")
os.makedirs(os.path.dirname(path), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_animation_mode="NLA_TRACKS", use_selection=True, export_apply=True, export_optimize_animation_size=True)
print("ok", path, glb_slim.slim(path))
