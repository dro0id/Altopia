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
	var h := UI.H
	var sh := 152.0 + offer.size() * 144.0 + 104.0 + 48.0
	var y0 := h - sh
	var sheet := Control.new()
	sheet.position = Vector2(0, y0)
	sheet.size = Vector2(720, sh)
	sheet.draw.connect(func():
		var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		sheet.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
		M3.text(sheet, Vector2(32, 88), "Choisis un renfort", 40, UI.TEXT, true)
		M3.text(sheet, Vector2(32, 128), "Actif jusqu'au prochain boss", 26, UI.MUTED))
	st.add_child(sheet)
	for i in offer.size():
		var id: String = offer[i]
		var b: Dictionary = Data.BOOSTS[id]
		var c := Control.new()
		c.position = Vector2(32, y0 + 152 + i * 144)
		c.size = Vector2(656, 128)
		var idx := i
		c.draw.connect(func():
			var on := idx == _sel
			M3.row(c, Rect2(Vector2.ZERO, c.size), on)
			c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 28, 0), Rect2(16, 16, 96, 96))
			_glyph(c, id, Vector2(64, 64), Color.WHITE)
			M3.text(c, Vector2(136, 56), String(b.name), 30, UI.TEXT, true)
			M3.text(c, Vector2(136, 92), String(b.short), 24, UI.MUTED, false, 420)
			c.draw_arc(Vector2(608, 64), 16, 0, TAU, 32, UI.ACCENT, 3.0, true)
			if on:
				c.draw_circle(Vector2(608, 64), 9, UI.ACCENT))
		c.gui_input.connect(func(ev: InputEvent):
			if M3.is_tap(ev):
				_sel = idx
				Sfx.play("click", -8.0)
				for k in _cards:
					k.queue_redraw())
		st.add_child(c)
		_cards.append(c)
	var go := M3.button(st, "Choisir ce renfort", Rect2(32, h - 32 - 104, 656, 104), "main", 32)
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
