extends SceneTree
## Planche des boutons actuels : godot --path . -s tools/button_sheet.gd -- <fichier.png>
func _initialize() -> void:
	await process_frame
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/buttons.png"
	var m3 = load("res://scripts/m3.gd")
	var bg := ColorRect.new()
	bg.color = Color("0b1226")
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var kinds := ["main", "ghost", "tonal", "outline", "gold", "danger", "text"]
	var names := ["Principal", "Secondaire", "Tonal", "Contour", "Premium", "Danger", "Texte"]
	for i in kinds.size():
		var y := 24.0 + i * 120.0
		var b = m3.button(bg, names[i], Rect2(24, y, 330, 96), kinds[i], 30)
		var d = m3.button(bg, names[i] + " (inactif)", Rect2(366, y, 330, 96), kinds[i], 26)
		d.disabled = true
	var ib = m3.icon_button(bg, "⚙", 34)
	ib.position = Vector2(24, 880)
	var ib2 = m3.icon_button(bg, "←", 44)
	ib2.position = Vector2(140, 880)
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
