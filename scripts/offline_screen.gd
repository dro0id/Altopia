class_name OfflineScreen
extends Overlay
## Retour hors ligne (maquette BO) : durée d'absence, gains, coffre gratuit prêt.

signal chest_claimed(chest: Dictionary)


func _init(report: Dictionary) -> void:
	super._init(720.0)
	var st := use_stage(1.0)
	var ready := Game.free_chest_ready()
	var body := Control.new()
	body.size = Vector2(720, 700)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(func():
		var fb := UI.bold_font()
		var txt := "PENDANT TON ABSENCE"
		var tw := 0.0
		for ch in txt:
			tw += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24)).x + 3.0
		var x := (720.0 - tw) * 0.5
		for ch in txt:
			body.draw_string(fb, Vector2(x, 136), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24), UI.ACCENT)
			x += fb.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(24)).x + 3.0
		M3.text(body, Vector2(0, 208), _hm(float(report.seconds)), 56, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(body, Vector2(0, 248), "Plafond %d h" % int(Data.OFFLINE_CAP_HOURS), 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
		var rows := [["coin", "Crédits", "Farm automatique", "+" + UI.num(report.credits), UI.GOLD], ["shard", "Éclats de verre", "Collectés", "+%d" % int(report.get("shards", 0)), Color("7fdcff")]]
		for i in 2:
			var r := Rect2(32, 296 + i * 128.0, 656, 112)
			M3.row(body, r)
			_icon(body, rows[i][0], r.position + Vector2(48, 56))
			M3.text(body, r.position + Vector2(88, 48), rows[i][1], 30, UI.TEXT, true)
			M3.text(body, r.position + Vector2(88, 84), rows[i][2], 24, UI.MUTED)
			M3.text(body, r.position + Vector2(0, 68), rows[i][3], 34, rows[i][4], true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		if ready:
			M3.card(body, Rect2(32, 568, 656, 96))
			M3.text(body, Vector2(64, 626), "Un coffre gratuit est prêt à ouvrir.", 26, UI.GREEN))
	st.add_child(body)
	var h := 1280.0
	var ok := M3.button(st, "Tout récupérer", Rect2(32, h - 32 - (96 + 16 if ready else 0) - 104, 656, 104), "main", 32)
	ok.pressed.connect(close)
	if ready:
		var oc := M3.button(st, "Récupérer et ouvrir le coffre", Rect2(32, h - 32 - 96, 656, 96), "ghost", 30)
		oc.pressed.connect(func():
			var c: Dictionary = Game.claim_free_chest()
			if not c.is_empty():
				chest_claimed.emit(c)
			close())
	Sfx.play("coin")


func _icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
	if kind == "coin":
		ci.draw_circle(c, 16, UI.GOLD)
		ci.draw_string(UI.bold_font(), c + Vector2(-16, 10), "¢", HORIZONTAL_ALIGNMENT_CENTER, 32, 26, Color("6b4a00"))
	else:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17), c + Vector2(17, -3), c + Vector2(10, 17), c + Vector2(-10, 17), c + Vector2(-17, -3)]), Color("7fdcff"))


func _hm(sec: float) -> String:
	var s := int(sec)
	if s < 3600:
		return "%d min" % (s / 60)
	return "%d h %02d" % [s / 3600, (s % 3600) / 60]
