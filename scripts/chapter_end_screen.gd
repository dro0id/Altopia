class_name ChapterEndScreen
extends Overlay
## Fin de chapitre (maquette CH) : dernière réplique, récompenses, chapitre suivant débloqué.

signal journal_requested

var _n := 1
var _reward: Dictionary
var _t := 0.0
var _body: Control


func _init(n: int, reward: Dictionary) -> void:
	super._init(720.0)
	_n = n
	_reward = reward
	var st := use_stage(1.0)
	_body = Control.new()
	_body.size = Vector2(720, 1000)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	st.add_child(_body)
	var nxt := Story.chapter(n + 1)
	var go := M3.button(st, "Continuer vers le chapitre %d" % (n + 1) if not nxt.is_empty() else "Continuer", Rect2(32, 1280 - 32 - 96 - 16 - 104, 656, 104), "main", 32)
	go.pressed.connect(close)
	var jr := M3.button(st, "Revoir le chapitre dans le journal", Rect2(32, 1280 - 32 - 96, 656, 96), "ghost", 30)
	jr.pressed.connect(func():
		journal_requested.emit()
		close())
	Sfx.play("win")


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _draw_body() -> void:
	var c := _body
	var ch := Story.chapter(_n)
	for k in 12:
		c.draw_circle(Vector2(360, 200), 320.0 - k * 24.0, Color(0.5, 0.86, 1.0, 0.016))
	M3.text(c, Vector2(0, 104), "CHAPITRE %d TERMINÉ" % _n, 24, UI.ACCENT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, 168), String(ch.get("title", "")), 56, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	# dernière réplique du chapitre
	var last: Dictionary = {}
	for s in Story.chapter_scenes(_n):
		if s.has("end"):
			last = s.lines[0]
	var r := Rect2(32, 216, 656, 176)
	M3.card(c, r)
	if not last.is_empty():
		M3.avatar(c, Data.HEROES[last.who], r.position + Vector2(72, 88), 48.0, Story.speaker(String(last.who)).color, _t)
		M3.para(c, r.position + Vector2(144, 64), "« %s »" % String(last.text), 28, UI.TEXT, 480)
	# récompenses
	var x := 32.0
	for it in [["coin", "+" + UI.num(float(_reward.get("credits", 0)))], ["shard", "+%d" % int(_reward.get("shards", 0))], ["token", "+%d" % int(_reward.get("tokens", 0))]]:
		var w := M3.text_w(it[1], 26, true) + 40.0 + 34.0
		c.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 32, 0), Rect2(x, 416, w, 64))
		_icon(c, it[0], Vector2(x + 32, 448))
		M3.text(c, Vector2(x + 54, 448 + M3.fs(26) * 0.36), it[1], 26, UI.TEXT, true)
		x += w + 12.0
	var nxt := Story.chapter(_n + 1)
	if not nxt.is_empty():
		var nr := Rect2(32, 512, 656, 200)
		c.draw_style_box(UI.box(Color("0d1530"), Color(0, 0, 0, 0), 40, 0), nr)
		_dashed(c, nr.grow(-2), UI.ACCENT)
		M3.text(c, nr.position + Vector2(32, 52), "DÉBLOQUÉ", 24, UI.ACCENT, true)
		M3.text(c, nr.position + Vector2(32, 100), "Chapitre %d · %s" % [_n + 1, nxt.title], 36, UI.TEXT, true)
		M3.para(c, nr.position + Vector2(32, 144), "Étages %d à %d · %s" % [int(nxt.from), int(nxt.to), String(nxt.get("teaser", ""))], 26, UI.MUTED, 592)


func _icon(ci: CanvasItem, kind: String, c: Vector2) -> void:
	match kind:
		"coin":
			ci.draw_circle(c, 12, UI.GOLD)
			ci.draw_string(UI.bold_font(), c + Vector2(-12, 8), "¢", HORIZONTAL_ALIGNMENT_CENTER, 24, 20, Color("6b4a00"))
		"shard":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, -2), c + Vector2(8, 13), c + Vector2(-8, 13), c + Vector2(-13, -2)]), Color("7fdcff"))
		_:
			ci.draw_style_box(UI.box(Color("b388ff"), Color(0, 0, 0, 0), 5, 0), Rect2(c + Vector2(-14, -10), Vector2(28, 20)))
			ci.draw_circle(c, 4.5, Color("2a1450"))


func _dashed(ci: CanvasItem, r: Rect2, col: Color) -> void:
	var pts := [r.position + Vector2(40, 0), Vector2(r.end.x - 40, r.position.y), Vector2(r.end.x, r.position.y + 40), Vector2(r.end.x, r.end.y - 40), Vector2(r.end.x - 40, r.end.y), Vector2(r.position.x + 40, r.end.y), Vector2(r.position.x, r.end.y - 40), Vector2(r.position.x, r.position.y + 40), r.position + Vector2(40, 0)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(a.distance_to(b) / 14.0)
		for k in range(0, n, 2):
			ci.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, 2.0)
