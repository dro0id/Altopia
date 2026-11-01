extends SceneTree
## Vérifie que la liste des héros défile au glisser (même en partant d'un bouton) et qu'un glissé n'achète rien.
func _initialize() -> void:
	await process_frame
	var g = root.get_node("Game")
	g.save_path = "user://drag.json"
	g.reset()
	g.intro_seen = true
	g.tutorial_done = true
	g.credits = 5000.0
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	var sc: ScrollContainer = main._scroll
	var levels_before := str(g.levels.values())
	var before := sc.scroll_vertical
	# glissé de bas en haut, en commençant sur le bouton « Améliorer » de la 1re ligne (x≈600, y≈850)
	var start := Vector2(600, 850)
	_send_button(start, true)
	for k in 12:
		await process_frame
		_send_motion(start + Vector2(0, -20 * (k + 1)))
	_send_button(start + Vector2(0, -240), false)
	for i in 10:
		await process_frame
	print("DRAG défilement : %d -> %d, niveaux inchangés : %s" % [before, sc.scroll_vertical, str(str(g.levels.values()) == levels_before)])
	# un simple appui doit toujours acheter
	sc.scroll_vertical = 0
	await process_frame
	_send_button(start, true)
	await process_frame
	_send_button(start, false)
	for i in 5:
		await process_frame
	print("TAP niveaux : %s -> %s" % [levels_before, str(g.levels.values())])
	quit()


func _send_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	if pressed:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


func _send_motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
