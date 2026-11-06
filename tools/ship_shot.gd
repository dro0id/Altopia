extends SceneTree
## Capture de la vue 3D du vaisseau : godot --path . -s tools/ship_shot.gd -- <dossier> <niveau> [coque]
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp"
	var lv := int(args[1]) if args.size() > 1 else 10
	var bg := ColorRect.new()
	bg.color = Color("070b1a")
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var v = load("res://scripts/ship_view.gd").new()
	v.size = Vector2(720, 1280)
	root.add_child(v)
	var t0 = Time.get_ticks_msec()
	v.setup(lv)
	print("setup ms ", Time.get_ticks_msec() - t0)
	if args.size() > 2 and args[2] == "coque":
		v.set_cut(false)
		v.yaw = 0.6
	for i in 6:
		await process_frame
		print("frame ", i, " ", Time.get_ticks_msec() - t0)
	var img := root.get_texture().get_image()
	img.save_png(out + "/ship_%d%s.png" % [lv, "_c" if args.size() > 2 else ""])
	quit()
