class_name DefeatScreen
extends Overlay

## Escouade tombée (maquette O) : persévérance, conseils concrets et choix. Jamais de blocage : on peut toujours farmer l'étage d'avant.

signal retry_pressed
signal farm_pressed
signal upgrade_pressed
signal recruit_pressed


func _init(stage_n: int) -> void:
	super._init(720.0)
	var st := use_stage(1.0)
	var eb := Control.new()
	eb.position = Vector2(0, 56)
	eb.size = Vector2(720, 40)
	eb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eb.draw.connect(func():
		var fb := UI.bold_font()
		var txt := "ÉTAGE %d" % stage_n
		var tw := 0.0
		for ch in txt:
			tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		var x := (720.0 - tw) * 0.5
		for ch in txt:
			eb.draw_string(fb, Vector2(x, 30), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.RED)
			x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0)
	st.add_child(eb)
	var t := UI.label(st, "L'escouade est tombée", 48, Color.WHITE, true)
	t.position = Vector2(0, 98)
	t.size = Vector2(720, 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.label(st, "Rien n'est perdu : tu reviens plus fort.", 22, UI.MUTED)
	sub.position = Vector2(0, 158)
	sub.size = Vector2(720, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# persévérance
	var pc := Control.new()
	pc.position = Vector2(32, 224)
	pc.size = Vector2(656, 153)
	pc.draw.connect(func():
		pc.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, pc.size))
		pc.draw_string(UI.bold_font(), Vector2(24, 48), "Persévérance", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		pc.draw_string(UI.bold_font(), Vector2(0, 48), "+%d %% PV / ATQ" % Game.perseverance_pct(), HORIZONTAL_ALIGNMENT_RIGHT, 632.0, 24, UI.GREEN)
		var n: int = Data.PERSEVERANCE_MAX
		var sw := (608.0 - 8.0 * (n - 1)) / float(n)
		for i in n:
			var col := UI.GREEN if i < Game.perseverance else UI.LINE2
			pc.draw_style_box(UI.box(col, Color(0, 0, 0, 0), 10, 0), Rect2(24.0 + i * (sw + 8.0), 70, sw, 20))
		pc.draw_string(ThemeDB.fallback_font, Vector2(24, 126), "%d défaite%s sur %d · bonus conservé jusqu'à la victoire" % [Game.perseverance, "s" if Game.perseverance > 1 else "", n], HORIZONTAL_ALIGNMENT_LEFT, 610.0, 22, UI.MUTED))
	st.add_child(pc)
	# conseils
	var tips: Array = _tips(stage_n)
	var cc := Control.new()
	cc.position = Vector2(32, 400)
	cc.size = Vector2(656, 72.0 + 78.0 * tips.size())
	cc.draw.connect(func():
		cc.draw_style_box(UI.box(UI.PANEL2, Color(0.31, 0.85, 1.0, 0.33), 28, 0), Rect2(Vector2.ZERO, cc.size))
		cc.draw_string(UI.bold_font(), Vector2(24, 50), "Conseils", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE))
	st.add_child(cc)
	for i in tips.size():
		var tp: Dictionary = tips[i]
		var y := 72.0 + 78.0 * i
		var ic := Control.new()
		ic.position = Vector2(24, y + 14)
		ic.size = Vector2(44, 44)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var kind: String = tp.icon
		ic.draw.connect(func():
			if kind == "shield":
				ic.draw_polyline(PackedVector2Array([Vector2(6, 6), Vector2(38, 6), Vector2(38, 24), Vector2(22, 40), Vector2(6, 24), Vector2(6, 6)]), UI.TEXT, 3.0, true)
			else:
				ic.draw_colored_polygon(PackedVector2Array([Vector2(22, 4), Vector2(27, 17), Vector2(40, 22), Vector2(27, 27), Vector2(22, 40), Vector2(17, 27), Vector2(4, 22), Vector2(17, 17)]), UI.TEXT))
		cc.add_child(ic)
		var tl := UI.label(cc, tp.text, 26, Color.WHITE)
		tl.position = Vector2(84, y + 10)
		tl.size = Vector2(450, 60)
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tl.add_theme_constant_override("line_spacing", -6)
		if tp.has("action"):
			var col: Color = UI.GREEN if tp.action == "upgrade" else Color("b388ff")
			var b := Button.new()
			b.position = Vector2(548, y + 8)
			b.size = Vector2(88, 56)
			b.text = "▲" if tp.action == "upgrade" else "▶"
			b.add_theme_font_size_override("font_size", 26)
			for sn in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(sn, UI.box(Color(col.r, col.g, col.b, 0.1), Color(col.r, col.g, col.b, 0.55), 28, 0))
			for k in ["font_color", "font_hover_color", "font_pressed_color"]:
				b.add_theme_color_override(k, col)
			var act: String = tp.action
			b.pressed.connect(func():
				if act == "upgrade":
					upgrade_pressed.emit()
				else:
					recruit_pressed.emit()
				close())
			cc.add_child(b)
	# boutons
	var up := UI.button(st, "Améliorer mes héros", 32, "main")
	up.position = Vector2(32, 1032)
	up.size = Vector2(656, 104)
	up.custom_minimum_size = Vector2(0, 104)
	up.pressed.connect(func():
		upgrade_pressed.emit()
		close())
	var rb := UI.button(st, "Réessayer", 28, "ghost")
	rb.position = Vector2(32, 1152)
	rb.size = Vector2(320, 96)
	rb.pressed.connect(func():
		retry_pressed.emit()
		close())
	if stage_n > 1:
		var fb := UI.button(st, "Farmer l'étage %d" % (stage_n - 1), 28, "ghost")
		fb.position = Vector2(368, 1152)
		fb.size = Vector2(320, 96)
		fb.pressed.connect(func():
			farm_pressed.emit()
			close())
	else:
		rb.size = Vector2(656, 96)
	Sfx.play("lose")


## Conseils concrets : le héros le plus en retard sur le niveau conseillé, un appel de recrutement possible.
func _tips(stage_n: int) -> Array:
	var out: Array = []
	var need: int = Data.recommended_level(stage_n)
	var low := ""
	for id in Game.squad_ids():
		if low == "" or int(Game.levels[id]) < int(Game.levels[low]):
			low = id
	if low != "":
		var gap: int = need - int(Game.levels[low])
		if gap >= 1:
			out.append({"icon": "shield", "text": "%s est %d niveau%s sous la reco" % [String(Data.HEROES[low].name).split(" ")[0], gap, "x" if gap > 1 else ""], "action": "upgrade"})
	if Game.tokens >= Data.RECRUIT_COST:
		out.append({"icon": "star", "text": "%d jetons : un appel pour un nouveau héros" % Game.tokens, "action": "recruit"})
	if out.is_empty():
		out.append({"icon": "shield", "text": "Tu es au bon niveau : retente en lançant les pouvoirs au bon moment."})
	return out
