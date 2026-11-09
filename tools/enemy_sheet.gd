extends SceneTree
## Planche des ennemis actuels : godot --path . -s tools/enemy_sheet.gd -- <fichier.png>
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/enemies.png"
	var kinds := ["mite", "drone", "gunner", "foreur", "titan", "sentinelle", "reine"]
	# arguments : <fichier> [étage de la teinte] [phase2] [gold]
	var art = load("res://scripts/art.gd")
	var bg := ColorRect.new()
	bg.color = Color("0b1226")
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	for i in kinds.size():
		# chaque ennemi dans son propre nœud : l'art règle lui-même la transformation de dessin
		var n := Node2D.new()
		n.position = Vector2(120.0 + (i % 3) * 240.0, 330.0 + (i / 3) * 400.0)
		n.scale = Vector2(1.5, 1.5)
		var k: String = kinds[i]
		var pal = load("res://scripts/enemy_art.gd").palette_for(int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 5)
		var ph2 := OS.get_cmdline_user_args().size() > 2 and OS.get_cmdline_user_args()[2] == "phase2"
		var gold := OS.get_cmdline_user_args().size() > 3 and OS.get_cmdline_user_args()[3] == "gold"
		n.draw.connect(func(): art.draw_enemy_front(n, k, {"t": 0.4, "pal": pal, "phase2": ph2, "gold": gold}))
		root.add_child(n)
		var l := Label.new()
		l.text = k
		l.position = Vector2(50.0 + (i % 3) * 240.0, 370.0 + (i / 3) * 400.0)
		root.add_child(l)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
