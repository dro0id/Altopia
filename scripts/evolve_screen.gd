class_name EvolveScreen
extends Overlay
## Palier d'évolution (maquette N) : feuille du bas, le héros avant et après, ce que le palier apporte, un bouton pour évoluer.

signal evolved

var _t := 0.0
var _hero: Dictionary


func _init(id: String) -> void:
	super._init(720.0)
	_hero = Data.HEROES[id]
	var tier: int = Game.tier(id)
	var lv: int = Game.levels[id]
	var st := use_stage(0.62)
	var sheet := Control.new()
	sheet.position = Vector2(0, 649)
	sheet.size = Vector2(720, 631)
	sheet.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.PANEL2
		sb.corner_radius_top_left = 44
		sb.corner_radius_top_right = 44
		sb.border_width_top = 2
		sb.border_color = UI.ACCENT
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		sheet.draw_style_box(UI.box(UI.LINE, Color(0, 0, 0, 0), 4, 0), Rect2(320, 28, 80, 8)))
	st.add_child(sheet)
	var t := UI.label(st, "Palier d'évolution", 36, Color.WHITE, true)
	t.position = Vector2(32, 696)
	var s := UI.label(st, "%s atteint le niveau %d" % [String(_hero.name).split(" ")[0], lv], 22, UI.MUTED)
	s.position = Vector2(32, 748)
	# avant → après
	var row := Control.new()
	row.position = Vector2(0, 790)
	row.size = Vector2(720, 240)
	row.draw.connect(func():
		UI.portrait(row, _hero, Vector2(198, 120), 90.0, _t)
		row.draw_string(UI.bold_font(), Vector2(0, 134), "→", HORIZONTAL_ALIGNMENT_CENTER, 720.0 - 6.0, 52, UI.ACCENT)
		var k := 0.5 + 0.5 * sin(_t * 2.4)
		row.draw_circle(Vector2(502, 120), 120.0 + 6.0 * k, Color(1.0, 0.69, 0.26, 0.10 + 0.08 * k))
		UI.portrait(row, _hero, Vector2(502, 120 - 5.0 * k), 110.0, _t))
	st.add_child(row)
	var stat_gain := int(round((Data.EVO_STAT_MULT[tier + 1] / Data.EVO_STAT_MULT[tier] - 1.0) * 100.0))
	var cost: Dictionary = Game.evolve_cost(id)
	var chips := [["Niveau max %d" % Data.level_cap(tier + 1), UI.TEXT], ["PV +%d %%" % stat_gain, UI.GREEN], ["¢ %s" % Data.fmt(cost.credits), UI.GOLD]]
	var widths: Array = []
	var total := 0.0
	for c in chips:
		var w := UI.bold_font().get_string_size(c[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 48.0
		widths.append(w)
		total += w + 12.0
	var x := (720.0 - total + 12.0) * 0.5
	for i in chips.size():
		var h := HudButton.new()
		h.font_size = 24
		h.bold = true
		h.radius = 30.0
		h.tappable = false
		h.text_color = chips[i][1]
		h.set_texts(chips[i][0])
		h.size = Vector2(widths[i], 60)
		h.position = Vector2(x, 1052)
		x += widths[i] + 12.0
		st.add_child(h)
	var ok_c: bool = Game.credits >= cost.credits
	var ok_s: bool = Game.shards >= cost.shards
	var go := UI.button(st, "", 32, "gold")
	go.position = Vector2(32, 1132)
	go.size = Vector2(656, 104)
	go.custom_minimum_size = Vector2(0, 104)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.add_child(hb)
	var l1 := UI.label(hb, "Évoluer ·", 32, Color("1a1004"), true)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UI.icon("shard")
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)
	var l2 := UI.label(hb, str(int(cost.shards)), 32, Color("1a1004") if ok_s else Color("8a2a2a"), true)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go.disabled = not (ok_c and ok_s)
	go.pressed.connect(func():
		if Game.evolve(id):
			Sfx.play("chest")
			evolved.emit()
			close())
	# toucher en dehors de la feuille = plus tard
	var out := Control.new()
	out.position = Vector2(0, 0)
	out.size = Vector2(720, 649)
	out.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			close())
	st.add_child(out)
	st.move_child(out, 0)


func _process(delta: float) -> void:
	_t += delta
	if stage != null:
		for c in stage.get_children():
			if c is Control and c.size.y == 240.0:
				c.queue_redraw()
