class_name PrologueScreen
extends Overlay
## Prologue (maquettes CB à CD) : Terre et le signal, Vance sur le pont de l'Aurore, le décollage vers la Ceinture d'Altopia.

signal finished

var _i := 0
var _t := 0.0
var _st: Control
var _art: Control
var _btn: Button
var _replay := false


func _init(replay := false) -> void:
	super._init(720.0)
	_replay = replay
	_st = use_stage(1.0)
	_art = Control.new()
	_art.size = Vector2(720, UI.H)
	_art.draw.connect(_draw_art)
	_art.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			_next())
	_st.add_child(_art)
	_btn = M3.button(_st, "Suivant", Rect2(32, UI.H - 96 - 104, 656, 104), "main", 32)
	_btn.pressed.connect(_next)
	_refresh()


func _refresh() -> void:
	_btn.text = "Monter à bord" if _i == Story.PROLOGUE.size() - 1 else "Suivant"


func _next() -> void:
	Sfx.play("click", -8.0)
	if _i >= Story.PROLOGUE.size() - 1:
		if not _replay:
			Game.see_scene("prologue")
			Game.save_game()
		finished.emit()
		close()
		return
	_i += 1
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	_art.queue_redraw()


func _draw_art() -> void:
	var c := _art
	var p: Dictionary = Story.PROLOGUE[_i]
	c.draw_rect(Rect2(0, 0, 720, UI.H), Color("060b1a"))
	for k in 60:
		var sx := fposmod(sin(k * 12.9898) * 43758.5, 1.0)
		var sy := fposmod(sin(k * 78.233) * 12345.6, 1.0)
		c.draw_circle(Vector2(sx * 720.0, sy * 900.0), 1.5 + (k % 3) * 0.5, Color(1, 1, 1, 0.2 + 0.3 * (0.5 + 0.5 * sin(_t * 1.5 + k))))
	match _i:
		0:
			# la Terre
			for k in 12:
				c.draw_circle(Vector2(360, 400), 320.0 - k * 20.0, Color(0.31, 0.66, 1.0, 0.015))
			c.draw_circle(Vector2(360, 400), 180.0, Color("1f5fa8"))
			c.draw_circle(Vector2(330, 370), 140.0, Color("2f7fc8"))
			c.draw_circle(Vector2(300, 340), 80.0, Color("5fb0e8"))
			c.draw_set_transform(Vector2(372, 360), 0.0, Vector2(1.0, 0.45))
			c.draw_circle(Vector2.ZERO, 120.0, Color(0.49, 1.0, 0.69, 0.35))
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		1:
			M3.text(c, Vector2(0, 136), "PONT DE L'AURORE", 24, UI.ACCENT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
			var r := Rect2(48, 200, 624, 300)
			c.draw_style_box(UI.box(Color(0, 0, 0, 0), M3.OUT, 48, 0), r)
			for x in range(int(r.position.x) + 24, int(r.end.x), 48):
				c.draw_line(Vector2(x, r.position.y + 8), Vector2(x, r.end.y - 8), Color(M3.S3, 0.5), 2.0)
			var code := "7 · 3 · 7 · 1 · 9 · 7"
			var shown := code.substr(0, clampi(int(_t * 8.0) % (code.length() + 12), 0, code.length()))
			M3.text(c, Vector2(0, 366), shown, 36, UI.GREEN, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
		2:
			for k in 12:
				c.draw_circle(Vector2(360, 380), 320.0 - k * 22.0, Color(0.7, 0.53, 1.0, 0.015))
			c.draw_arc(Vector2(360, 380), 220.0, 0, TAU, 96, Color(0.5, 0.86, 1.0, 0.55), 6.0, true)
			c.draw_circle(Vector2(360, 380), 80.0 + 6.0 * sin(_t * 2.0), Color(0.5, 0.86, 1.0, 0.35))
			c.draw_circle(Vector2(360, 380), 44.0, Color("e8fbff"))
			var sy2 := 700.0 - fposmod(_t * 60.0, 120.0)
			c.draw_colored_polygon(PackedVector2Array([Vector2(360, sy2 - 44), Vector2(388, sy2 + 44), Vector2(360, sy2 + 28), Vector2(332, sy2 + 44)]), UI.TEXT)
	if p.has("who"):
		# réplique de Vance dans une feuille du bas
		var y0 := UI.H - 96.0 - 104.0 - 32.0 - 420.0
		var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		c.draw_style_box(sb, Rect2(0, y0, 720, UI.H - y0))
		c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, y0 + 16, 64, 8))
		var sp := Story.speaker(String(p.who))
		M3.avatar(c, Data.HEROES[p.who], Vector2(104, y0 + 136), 72.0, sp.color, _t)
		M3.text(c, Vector2(208, y0 + 124), String(sp.name), 32, sp.color, true)
		M3.text(c, Vector2(208, y0 + 164), String(sp.role), 24, UI.MUTED)
		M3.text(c, Vector2(0, y0 + 124), "Prologue %d/%d" % [_i + 1, Story.PROLOGUE.size()], 24, UI.MUTED, false, 688, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.para(c, Vector2(32, y0 + 260), String(p.text), 32, UI.TEXT, 656)
	else:
		var yb := UI.H - 96.0 - 104.0 - 80.0 - 340.0
		M3.section(c, Vector2(48, yb), String(p.eyebrow))
		var h := M3.para(c, Vector2(48, yb + 64), String(p.title), 44, UI.TEXT, 624, 1.3, true)
		M3.para(c, Vector2(48, yb + 64 + h + 8), String(p.text), 30, UI.MUTED, 624)
		# points d'étape
		var x := 360.0 - (Story.PROLOGUE.size() * 16.0 + 32.0) * 0.5
		for k in Story.PROLOGUE.size():
			var w := 48.0 if k == _i else 16.0
			c.draw_style_box(UI.box(UI.ACCENT if k == _i else M3.OUT, Color(0, 0, 0, 0), 8, 0), Rect2(x, UI.H - 96 - 104 - 48, w, 16))
			x += w + 16.0
		if _i == 0:
			M3.text(c, Vector2(0, UI.H - 40), "Toucher n'importe où pour avancer", 26, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
