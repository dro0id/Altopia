extends SceneTree
## Coût processeur des personnages animés (sans rendu) : temps de chargement et de mise à jour d'animation par image.
## godot --headless --path . -s tools/anim_bench.gd
func _initialize() -> void:
	await process_frame
	var ids := ["rex", "zara", "gorn", "elara", "nova", "maya"]
	var holder := Node3D.new()
	root.add_child(holder)
	var t0 := Time.get_ticks_usec()
	var nodes: Array = []
	for id in ids:
		var t1 := Time.get_ticks_usec()
		var n: Node = (load("res://assets/models/char_%s.glb" % id) as PackedScene).instantiate()
		holder.add_child(n)
		CharAnims.attach(n)
		print("BENCH chargement %s : %.1f ms" % [id, (Time.get_ticks_usec() - t1) / 1000.0])
		nodes.append(n)
	var players: Array = []
	var skels: Array = []
	for n in nodes:
		players.append(n.find_children("*", "AnimationPlayer", true, false)[0])
		skels.append(n.find_children("*", "Skeleton3D", true, false)[0])
	for count in [1, 3, 6]:
		for i in players.size():
			if i < count:
				players[i].play("Run")
			else:
				players[i].stop()
		var iters := 600
		var t := Time.get_ticks_usec()
		for k in iters:
			for i in count:
				players[i].advance(1.0 / 60.0)
				skels[i].force_update_all_bone_transforms()
		print("BENCH %d personnage(s) en course : %.3f ms par image (animation + os, CPU, sans rendu)" % [count, (Time.get_ticks_usec() - t) / 1000.0 / iters])
	quit()
