class_name MapScreen
extends Overlay

## Carte du Trou de verre (maquette D) : bandeau d'en-tête, montée en tour, prochain boss, coffre gratuit et grand bouton Monter ou Farmer.

signal stage_chosen(stage: int)
signal chest_claimed(chest: Dictionary)

var _free_card: PanelContainer
var _free_val: Label
var _go: Button
var _tower: TowerView
var _next_label: Label
var _sel := 1
var _timer := 0.0


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, 1280)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_sel = Game.stage
	# bandeau : retour, titre, record, crédits
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 24))
	hp.custom_minimum_size = Vector2(0, 128)
	box.add_child(hp)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	hp.add_child(head)
	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(96, 96)
	back.add_theme_font_size_override("font_size", 36)
	for st in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(st, UI.box(Color(0, 0, 0, 0) if st == "normal" else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 48, 0))
	back.pressed.connect(close)
	head.add_child(back)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	head.add_child(tv)
	UI.label(tv, "Le Trou de verre", 32, Color.WHITE, true)
	var total_stars := 0
	for s in Game.stars.values():
		total_stars += int(s)
	UI.label(tv, "Record : étage %d · %d ★" % [Game.best_stage, total_stars], 22, UI.MUTED)
	var chip := HudButton.new()
	chip.icon = "coin"
	chip.font_size = 26
	chip.tappable = false
	chip.set_texts(UI.num(Game.credits))
	chip.fit_chip()
	chip.custom_minimum_size = Vector2(chip.size.x, 80)
	head.add_child(chip)
	# montée
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(area)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([UI.BG, UI.PANEL2])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var bgr := TextureRect.new()
	bgr.texture = gt
	bgr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgr.stretch_mode = TextureRect.STRETCH_SCALE
	bgr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(bgr)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	area.add_child(sc)
	DragScroll.attach(sc)
	_tower = TowerView.new()
	_tower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_tower)
	_tower.setup(Game.best_stage + 1, _sel)
	_tower.selected.connect(func(n: int):
		_sel = n
		_update())
	_scroll_to.call_deferred(sc)
	# bandeau du bas
	var bp := PanelContainer.new()
	var bsb := UI.box(UI.BAR, UI.LINE2, 0, 0)
	bsb.set_border_width_all(0)
	bsb.border_width_top = 2
	bsb.content_margin_left = 32
	bsb.content_margin_right = 32
	bsb.content_margin_top = 20
	bsb.content_margin_bottom = 28
	bp.add_theme_stylebox_override("panel", bsb)
	box.add_child(bp)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 16)
	bp.add_child(bv)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	bv.add_child(cards)
	var c1 := _info_card(cards, "Prochain mini-boss", Color("ffb142"))
	_next_label = c1
	_free_card = PanelContainer.new()
	_free_val = _info_card(cards, "Coffre gratuit", UI.GOLD, true)
	_go = UI.button(bv, "", 32, "main")
	_go.custom_minimum_size = Vector2(0, 104)
	_go.pressed.connect(func():
		stage_chosen.emit(_sel)
		close())
	var nb := Game.best_stage + 1
	while Data.boss_type(nb) != "mini":
		nb += 1
	_next_label.text = "Étage %d · %s" % [nb, Data.boss_name(nb).replace(" éclaté", "")]
	_update()
	_update_free()


## Carte d'information : légende + valeur en gras colorée.
func _info_card(parent: Node, title: String, col: Color, tappable := false) -> Label:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, Color(0, 0, 0, 0), 20, 12))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	UI.label(v, title, 22, UI.MUTED)
	var val := UI.label(v, "", 26, col, true)
	if tappable:
		_free_card = p
		p.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				if Game.free_chest_ready():
					var c: Dictionary = Game.claim_free_chest()
					if not c.is_empty():
						chest_claimed.emit(c)
					_update_free())
	return val


func _scroll_to(sc: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(sc) and is_instance_valid(_tower):
		var y: float = _tower.center_of(_sel).y
		sc.scroll_vertical = int(maxf(0.0, y - sc.size.y * 0.4))


func _update() -> void:
	if _sel >= Game.best_stage:
		_go.text = "Monter à l'étage %d" % _sel
	else:
		_go.text = "Farmer l'étage %d" % _sel
	_tower.sel = _sel


func _update_free() -> void:
	if Game.free_chest_ready():
		_free_val.text = "Prêt : toucher pour ouvrir"
	else:
		_free_val.text = "dans %s" % UI.duration(Game.free_chest_remaining())


func _process(delta: float) -> void:
	_timer += delta
	if _timer > 1.0:
		_timer = 0.0
		_update_free()
