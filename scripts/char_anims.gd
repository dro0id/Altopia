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
		if clips.size() > 0 and not a in clips:
			continue
		var anim: Animation = src.get_animation(a).duplicate()
		if lib.has_animation(a):
			lib.remove_animation(a)       # la bibliothèque fait foi (les clips Idle, Walk, Shoot embarqués dans les modèles sont des copies plus anciennes)
		_fix_first_key(anim)
		anim.loop_mode = Animation.LOOP_LINEAR if a in LOOPING else Animation.LOOP_NONE
		lib.add_animation(a, anim)
	src_scene.free()
	return player


## L'export Blender met au début de chaque clip trois images parasites (la pose de la bande précédente, puis un fondu vers la vraie pose) :
## à chaque boucle le personnage repassait par une image « à l'envers » (bras et corps tordus). On coupe donc le début du clip (3 images à 30 i/s)
## et on décale toutes les clés.
const TRIM := 0.1

static func _fix_first_key(anim: Animation) -> void:
	for i in anim.get_track_count():
		var t := anim.track_get_type(i)
		if t != Animation.TYPE_ROTATION_3D and t != Animation.TYPE_POSITION_3D and t != Animation.TYPE_SCALE_3D and t != Animation.TYPE_VALUE:
			continue
		while anim.track_get_key_count(i) > 2 and anim.track_get_key_time(i, 0) < TRIM - 0.002:
			anim.track_remove_key(i, 0)
		for k in anim.track_get_key_count(i):
			anim.track_set_key_time(i, k, maxf(0.0, anim.track_get_key_time(i, k) - TRIM))
	anim.length = maxf(0.1, anim.length - TRIM)
