extends SceneTree
## Capture de la scène du poste de pilotage (xvfb-run -a godot --path . --resolution 720x1280 -s tools/cockpit_shot.gd -- <png> [id])
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var v := CockpitView.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(v)
	v.show_pilot(a[1] if a.size() > 1 else "rex")
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(a[0])
	quit()
