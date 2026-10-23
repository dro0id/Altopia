extends SceneTree
## Gros plans de visages animés : 12 images par équipier (repos à plusieurs instants pour attraper le clignement, parler, rire, surprise, coup, réflexion).
## xvfb-run -a godot --path . --resolution 720x1280 -s tools/face_shot.gd -- <dossier> <id> [<id> ...]   -> <dossier>/<id>_<0..11>.png
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0]
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://face_shot.json"
	gs.reset()
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 4:
		await process_frame
	main._open_sheet("rex")
	main._sheet_gen += 1
	var shots := [["Idle", 0.0], ["Idle", 0.5], ["Idle", 1.0], ["Idle", 1.5], ["Idle", 2.0], ["Idle", 2.5], ["Talk", 0.4], ["Talk", 0.8], ["Laugh", 0.4], ["Surprise", 0.4], ["Hit", 0.3], ["Think", 0.5]]
	for id in a.slice(1):
		main._sheet_view.show_hero(id)
		main._sheet_view._auto = false
		main._sheet_view._yaw = 0.0
		var cam: Camera3D = main._sheet_view._cam
		var h: float = cam.position.y / 0.52
		var skel: Skeleton3D = main._sheet_view._model.find_children("*", "Skeleton3D", true, false)[0]
		var hb := skel.find_bone("Head")
		var an: AnimationPlayer = main._sheet_view._anim
		var k := 0
		for s in shots:
			an.play(s[0], 0.0)
			an.seek(minf(s[1], an.get_animation(s[0]).length * 0.95), true)
			an.pause()
			for i in 2:
				await process_frame
			var hp: Vector3 = main._sheet_view._holder.global_transform * (skel.global_transform * skel.get_bone_global_pose(hb).origin)
			hp.y += h * 0.075
			cam.position = hp + Vector3(0, 0.0, h * 0.5)
			cam.look_at(hp)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().get_region(Rect2i(170, 440, 420, 420)).save_png("%s/%s_%d.png" % [out, id, k])
			k += 1
	quit()
