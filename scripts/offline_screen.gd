class_name OfflineScreen
extends Overlay

## Retour hors ligne (maquette Q) : durée d'absence, gains, jauge d'absence.

signal chest_claimed(chest: Dictionary)


func _init(report: Dictionary) -> void:
	super._init(720.0)
	var st := use_stage(1.0)
	# halo bleu discret en haut
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.31, 0.85, 1.0, 0.11), Color(0.31, 0.85, 1.0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var halo := TextureRect.new()
	halo.texture = gt
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.position = Vector2(-80, 40)
	halo.size = Vector2(880, 760)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(halo)
	var eb := Control.new()
	eb.position = Vector2(0, 308)
	eb.size = Vector2(720, 40)
	eb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eb.draw.connect(func():
		var fb := UI.bold_font()
		var tw := 0.0
		for ch in "DE RETOUR":
			tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		var x := (720.0 - tw) * 0.5
		for ch in "DE RETOUR":
			eb.draw_string(fb, Vector2(x, 28), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.ACCENT)
			x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0)
	st.add_child(eb)
	var t := UI.label(st, "Ton escouade a farmé", 48, Color.WHITE, true)
	t.position = Vector2(0, 350)
	t.size = Vector2(720, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.label(st, "%s d'absence · plafond %d h" % [_hm(float(report.seconds)), int(Data.OFFLINE_CAP_HOURS)], 22, UI.MUTED)
	sub.position = Vector2(0, 414)
	sub.size = Vector2(720, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cards := [["Crédits", "+%s" % UI.num(report.credits), UI.GOLD], ["Éclats", "+%d" % int(report.get("shards", 0)), Color("7fdcff")]]
	for i in 2:
		var c := Control.new()
		c.position = Vector2(32.0 + i * 336.0, 473)
		c.size = Vector2(320, 124)
		var info: Array = cards[i]
		c.draw.connect(func():
			c.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, c.size))
			c.draw_string(ThemeDB.fallback_font, Vector2(0, 42), info[0], HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 22, UI.MUTED)
			c.draw_string(UI.bold_font(), Vector2(0, 94), info[1], HORIZONTAL_ALIGNMENT_CENTER, c.size.x, 44, info[2]))
		st.add_child(c)
	var gauge := Control.new()
	gauge.position = Vector2(32, 622)
	gauge.size = Vector2(656, 96)
	var frac := clampf(float(report.seconds) / (Data.OFFLINE_CAP_HOURS * 3600.0), 0.0, 1.0)
	gauge.draw.connect(func():
		gauge.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 24, 0), Rect2(Vector2.ZERO, gauge.size))
		gauge.draw_string(UI.bold_font(), Vector2(24, 40), "Jauge d'absence", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		gauge.draw_string(ThemeDB.fallback_font, Vector2(0, 38), "%d %%" % int(round(frac * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 632.0, 22, UI.MUTED)
		gauge.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 8, 0), Rect2(24, 58, 608, 16))
		gauge.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 8, 0), Rect2(24, 58, maxf(16.0, 608.0 * frac), 16)))
	st.add_child(gauge)
	var ok := UI.button(st, "Récupérer", 32, "main")
	ok.position = Vector2(32, 1032)
	ok.size = Vector2(656, 104)
	ok.custom_minimum_size = Vector2(0, 104)
	ok.pressed.connect(close)
	var dbl := UI.button(st, "Doubler pour ◆ 2 (bientôt : vidéo)", 28, "gold")
	dbl.position = Vector2(32, 1152)
	dbl.size = Vector2(656, 96)
	dbl.pressed.connect(func(): Sfx.play("click", -4.0))
	Sfx.play("coin")


func _hm(sec: float) -> String:
	var s := int(sec)
	if s < 3600:
		return "%d min" % (s / 60)
	return "%d h %02d" % [s / 3600, (s % 3600) / 60]
