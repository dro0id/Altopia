class_name MapScreen
extends Overlay

## Carte des étages : une montée du bas (étage 1) vers le haut, avec mini-boss et gros boss, puissance recommandée et farm.

signal stage_chosen(stage: int)
signal chest_claimed(chest: Dictionary)

var _free_btn: Button
var _timer := 0.0


func _init() -> void:
	super._init(680.0)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := UI.label(head, "Le Trou de verre", 34, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := UI.button(head, "Fermer", 22, "ghost")
	x.pressed.connect(close)
	_free_btn = UI.button(box, "", 22, "gold")
	_free_btn.custom_minimum_size = Vector2(0, 58)
	_free_btn.pressed.connect(func():
		var c: Dictionary = Game.claim_free_chest()
		if not c.is_empty():
			chest_claimed.emit(c)
		_update_free())
	_update_free()
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 820)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)
	var avg := 0.0
	for id in Data.HERO_ORDER:
		avg += float(Game.levels[id])
	avg /= Data.HERO_ORDER.size()
	var top := Game.best_stage + 2
	var current_row: Control = null
	for n in range(top, 0, -1):
		var row := _row(n, avg)
		col.add_child(row)
		if n == Game.stage:
			current_row = row
	if current_row != null:
		_scroll_to.call_deferred(sc, current_row)


func _scroll_to(sc: ScrollContainer, row: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(row):
		sc.scroll_vertical = int(maxf(0.0, row.position.y - 300.0))


func _row(n: int, avg_level: float) -> Control:
	var locked := n > Game.best_stage
	var cur := n == Game.stage
	var bt: String = Data.boss_type(n)
	var line := Color(0.3, 0.45, 0.6, 0.6)
	var fill := Color(0.07, 0.13, 0.24, 0.95)
	var badge := Color(0.17, 0.23, 0.42)
	if bt == "mini":
		line = Color(1.0, 0.69, 0.26)
		fill = Color(0.16, 0.12, 0.07, 0.95)
		badge = Color(1.0, 0.69, 0.26)
	elif bt == "big":
		line = Color(1.0, 0.42, 0.42)
		fill = Color(0.17, 0.08, 0.11, 0.95)
		badge = Color(1.0, 0.42, 0.42)
	if cur:
		line = UI.ACCENT
		fill = Color(0.1, 0.2, 0.34, 0.98)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 84)
	var sb := UI.box(fill, line, 12, 10)
	sb.set_border_width_all(2 if (cur or bt != "") else 1)
	panel.add_theme_stylebox_override("panel", sb)
	if locked:
		panel.modulate.a = 0.55
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	panel.add_child(h)
	var b := UI.label(h, "%d" % n, 26, Color(0.03, 0.05, 0.1) if (n < Game.best_stage or bt != "" or cur) else Color.WHITE)
	b.custom_minimum_size = Vector2(54, 54)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bs := UI.box(UI.ACCENT if cur else (UI.GREEN if n < Game.best_stage and bt == "" else badge), Color(0, 0, 0, 0), 27, 0)
	b.add_theme_stylebox_override("normal", bs)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := "Étage %d" % n
	if bt == "mini":
		title += " · MINI-BOSS"
	elif bt == "big":
		title += " · GROS BOSS"
	UI.label(v, title, 24, Color.WHITE)
	var s := int(Game.stars.get(n, 0))
	var need: int = Data.recommended_level(n)
	var sub := ""
	if locked:
		sub = "Verrouillé"
	else:
		sub = "%s  ·  niveau conseillé %d  ·  toi %.0f" % ["★".repeat(s) + "☆".repeat(3 - s) if s > 0 else "☆☆☆", need, avg_level]
	var subl := UI.label(v, sub, 17, UI.MUTED if avg_level >= need or locked else Color(1.0, 0.72, 0.4))
	subl.clip_text = true
	if not locked:
		var txt := "Combattre"
		if n < Game.best_stage:
			txt = "Farmer"
		elif n == Game.stage and n == Game.best_stage:
			txt = "Monter"
		var go := UI.button(h, txt, 20, "main" if n >= Game.best_stage else "ghost")
		go.custom_minimum_size = Vector2(150, 56)
		go.pressed.connect(func():
			stage_chosen.emit(n)
			close())
	return panel


func _update_free() -> void:
	if Game.free_chest_ready():
		_free_btn.text = "Coffre gratuit prêt : ouvrir"
		_free_btn.disabled = false
	else:
		_free_btn.text = "Prochain coffre gratuit dans %s" % UI.duration(Game.free_chest_remaining())
		_free_btn.disabled = true


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 1.0:
		_timer = 0.0
		_update_free()
