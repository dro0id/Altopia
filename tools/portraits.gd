extends SceneTree
## Exporte un portrait PNG par héros (xvfb-run -a godot --path . --resolution 720x1280 -s tools/portraits.gd -- <dossier>)
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	for id in ["mara", "kai", "zyra", "t9", "oru"]:
		var ic := HeroIcon.new()
		ic.hero = (load("res://scripts/data.gd") as GDScript).HEROES[id]
		ic.custom_minimum_size = Vector2(160, 160)
		ic.size = Vector2(160, 160)
		ic.position = Vector2(100, 100)
		root.add_child(ic)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image().get_region(Rect2i(100, 100, 160, 160))
		img.save_png("%s/%s.png" % [out, id])
		ic.queue_free()
	quit()
