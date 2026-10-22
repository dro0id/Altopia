class_name CharAnims
extends RefCounted
## Bibliothèque d'animations humaines (assets/animations/human_anims.glb) : Idle, Look, Walk, Run, Shoot, Talk, Wave, Nod, Shake, Think,
## Point, Work, Salute, Cheer, Surprise, Laugh, Hit. Elle s'applique à tout personnage exporté par tools/blender/export_characters.py
## (mêmes noms de nœuds et d'os). Les robots et extraterrestres n'ont pas les os de visage (Jaw, Blink, Brow) : ces pistes sont ignorées.

const LIB := "res://assets/animations/human_anims.glb"
const LOOPING := ["Idle", "Look", "Walk", "Run", "Talk", "Think", "Work", "Cheer", "Laugh"]

## Ajoute à l'AnimationPlayer du personnage les clips de la bibliothèque qu'il n'a pas déjà (tous si clips est vide). Renvoie le lecteur.
static func attach(character: Node, clips: PackedStringArray = PackedStringArray()) -> AnimationPlayer:
	var player: AnimationPlayer = null
	var found := character.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		player = found[0]
	else:
		player = AnimationPlayer.new()
		character.add_child(player)
	var src_scene: Node = (load(LIB) as PackedScene).instantiate()
	var src: AnimationPlayer = src_scene.find_children("*", "AnimationPlayer", true, false)[0]
	var lib: AnimationLibrary = player.get_animation_library("")
	if lib == null:
		lib = AnimationLibrary.new()
		player.add_animation_library("", lib)
	for a in src.get_animation_list():
		if (clips.size() > 0 and not a in clips) or lib.has_animation(a):
			continue
		var anim: Animation = src.get_animation(a).duplicate()
		anim.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
		lib.add_animation(a, anim)
	src_scene.free()
	return player
