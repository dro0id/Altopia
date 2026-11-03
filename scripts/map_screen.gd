class_name MapScreen
extends Overlay

## Carte du Trou de verre : la montée en tour (étage 1 en bas), le prochain mini-boss, le coffre gratuit et un grand bouton pour monter ou farmer.

signal stage_chosen(stage: int)
signal chest_claimed(chest: Dictionary)

var _free_btn: Button
var _go: Button
var _info: Label
var _tower: TowerView
var _next_label: Label
var _sel := 1
var _timer := 0.0


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1280)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.06, 0.13, 1.0), Color(0, 0, 0, 0), 0, 14))
	box.add_theme_constant_override("separation", 8)
	_sel = Game.stage
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	box.add_child(head)
	var back := UI.button(head, "‹", 34, "ghost")
	back.custom_minimum_size = Vector2(64, 64)
	back.pressed.connect(close)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	UI.label(tv, "Le Trou de verre", 32, UI.ACCENT)
	var total_stars := 0
	for s in Game.stars.values():
		total_stars += int(s)
	UI.label(tv, "Record : étage %d · %d ★" % [Game.best_stage, total_stars], 20, UI.MUTED)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.06, 0.14, 0.9), UI.LINE, 24, 8))
	head.add_child(chip)
	UI.label(chip, "¢ %s" % Data.fmt(Game.credits), 24, UI.GOLD)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 700)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	DragScroll.attach(sc)
	_tower = TowerView.new()
	_tower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tower)
	_tower.setup(Game.best_stage + 2, _sel)
	_tower.selected.connect(func(n: int):
		_sel = n
		_update())
	_scroll_to.call_deferred(sc)
	# bandeau du bas
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 10)
	box.add_child(cards)
	var c1 := PanelContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), UI.LINE, 12, 10))
	cards.add_child(c1)
	var c1v := VBoxContainer.new()
	c1v.add_theme_constant_override("separation", 0)
	c1.add_child(c1v)
	UI.label(c1v, "Prochain boss", 18, UI.MUTED)
	_next_label = UI.label(c1v, "", 22, Color(1.0, 0.69, 0.26))
	_next_label.clip_text = true
	_free_btn = UI.button(cards, "", 20, "gold")
	_free_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_free_btn.pressed.connect(func():
		var c: Dictionary = Game.claim_free_chest()
		if not c.is_empty():
			chest_claimed.emit(c)
		_update_free())
	_info = UI.label(box, "", 20, UI.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go = UI.button(box, "", 30, "main")
	_go.custom_minimum_size = Vector2(0, 84)
	_go.pressed.connect(func():
		stage_chosen.emit(_sel)
		close())
	var nb := Game.best_stage + 1
	while Data.boss_type(nb) == "":
		nb += 1
	_next_label.text = "Étage %d · %s" % [nb, Data.boss_name(nb)]
	_update()
	_update_free()


func _scroll_to(sc: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(_tower):
		var y: float = _tower.center_of(_sel).y
		sc.scroll_vertical = int(maxf(0.0, y - sc.size.y * 0.55))


func _update() -> void:
	var need: int = Data.recommended_level(_sel)
	var avg: float = Game.squad_avg_level()
	if _sel >= Game.best_stage:
		_go.text = "Monter à l'étage %d" % _sel
	else:
		_go.text = "Farmer l'étage %d" % _sel
	_info.text = "Niveau conseillé %d · ton escouade %.0f" % [need, avg]
	_info.add_theme_color_override("font_color", UI.MUTED if avg >= need else Color(1.0, 0.72, 0.4))
	_tower.sel = _sel


func _update_free() -> void:
	if Game.free_chest_ready():
		_free_btn.text = "Coffre gratuit : ouvrir"
		_free_btn.disabled = false
	else:
		_free_btn.text = "Coffre gratuit dans %s" % UI.duration(Game.free_chest_remaining())
		_free_btn.disabled = true


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 1.0:
		_timer = 0.0
		_update_free()
