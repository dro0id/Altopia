class_name BoostScreen
extends Overlay
## Choix d'un renfort (maquette M) : feuille du bas, trois propositions, un bouton pour confirmer.

signal picked(id: String)

var offer: Array = []
var _sel := 0
var _cards: Array = []


func _init(p_offer: Array, next_boss: int) -> void:
	super._init(720.0)
	offer = p_offer
	var st := use_stage(0.62)
	var sheet := Control.new()
	sheet.position = Vector2(0, 543)
	sheet.size = Vector2(720, 737)
	sheet.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.bg_color = UI.PANEL2
		sb.set_corner_radius_all(0)
		sb.corner_radius_top_left = 44
		sb.corner_radius_top_right = 44
		sb.border_width_top = 2
		sb.border_color = UI.ACCENT
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		sheet.draw_style_box(UI.box(UI.LINE, Color(0, 0, 0, 0), 4, 0), Rect2(320, 28, 80, 8)))
	st.add_child(sheet)
	var t := UI.label(st, "Choisis un renfort", 36, Color.WHITE, true)
	t.position = Vector2(32, 592)
	var s := UI.label(st, "Actif jusqu'au prochain boss", 22, UI.MUTED)
	s.position = Vector2(32, 644)
	for i in offer.size():
		var id: String = offer[i]
		var b: Dictionary = Data.BOOSTS[id]
		var c := Control.new()
		c.position = Vector2(32, 693 + i * 144)
		c.size = Vector2(656, 126)
		var idx := i
		c.draw.connect(func():
			var on := idx == _sel
			c.draw_style_box(UI.box(Color("1a2a55") if on else UI.PANEL, UI.ACCENT if on else UI.LINE2, 24, 0), Rect2(Vector2.ZERO, c.size))
			c.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 20, 0), Rect2(20, 21, 84, 84))
			_glyph(c, id, Vector2(62, 63), Color.WHITE)
			c.draw_string(UI.bold_font(), Vector2(128, 58), b.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
			c.draw_string(ThemeDB.fallback_font, Vector2(128, 92), String(b.short), HORIZONTAL_ALIGNMENT_LEFT, 500, 22, UI.MUTED))
		c.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
				_sel = idx
				Sfx.play("click", -8.0)
				for k in _cards:
					k.queue_redraw())
		st.add_child(c)
		_cards.append(c)
	var go := UI.button(st, "Prendre ce renfort", 32, "main")
	go.position = Vector2(32, 1132)
	go.size = Vector2(656, 104)
	go.custom_minimum_size = Vector2(0, 104)
	go.pressed.connect(func():
		picked.emit(offer[_sel])
		close())


func _glyph(ci: Control, id: String, c: Vector2, col: Color) -> void:
	match id:
		"tir":    # épées croisées
			ci.draw_line(c + Vector2(-16, 18), c + Vector2(16, -18), col, 4.0, true)
			ci.draw_line(c + Vector2(-16, -18), c + Vector2(16, 18), col, 4.0, true)
		"bouclier":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-18, -18), c + Vector2(18, -18), c + Vector2(18, 2), c + Vector2(0, 22), c + Vector2(-18, 2), c + Vector2(-18, -18)]), col, 4.0, true)
		"pouvoirs":
			SkillButton.draw_glyph(ci, 0, c, col, 0.9)
		"vitalite":
			SkillButton.draw_glyph(ci, 1, c, col, 0.9)
		_:
			ci.draw_circle(c, 18, UI.GOLD)
			ci.draw_arc(c, 18, 0, TAU, 32, Color("6b4a00"), 3.0, true)
