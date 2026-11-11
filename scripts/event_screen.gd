class_name EventScreen
extends Overlay
## Feuille d'un événement à bord (maquette WK) : qui parle, où, le texte, deux ou trois choix.

var _e := {}
var _t := {}
var _st: Control
var _sheet: Control
var _clock := 0.0


func _init(e: Dictionary) -> void:
	super._init(720.0)
	z_index = 0                   # la barre du bas reste visible
	_e = e
	_t = BoardEvents.template(String(e.id))
	_st = use_stage(0.6)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var n: int = _t.choices.size()
	var h := 420.0 + n * 112.0
	var bottom := UI.H - NavBar.total()
	_sheet.size = Vector2(720, h)
	_sheet.position = Vector2(0, bottom - h)
	_sheet.draw.connect(_draw_sheet)
	_st.add_child(_sheet)
	_st.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < _sheet.position.y:
			close())
	for i in n:
		var c: Dictionary = _t.choices[i]
		var b := M3.button(_sheet, BoardEvents.choice_text(c), Rect2(32, 408 + i * 112.0, 656, 96), "main" if i == n - 1 else "secondary", 26)
		var idx := i
		b.pressed.connect(func(): _choose(idx))


func _process(delta: float) -> void:
	_clock += delta
	_sheet.queue_redraw()


func _draw_sheet() -> void:
	var c := _sheet
	M3.sheet(c, Rect2(Vector2.ZERO, c.size))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	var who := String(_t.get("who", "vance"))
	if Data.HEROES.has(who):
		var col: Color = Data.RARITY_COLORS[Data.HEROES[who].rarity]
		Art.draw_portrait(c, Data.HEROES[who], Vector2(104, 132), 56.0, _clock)
		c.draw_arc(Vector2(104, 132), 60, 0, TAU, 40, col, 4.0, true)
	M3.text(c, Vector2(192, 104), "ÉVÉNEMENT · %s" % String(Ship.ROOMS[_e.room].short).to_upper(), 22, UI.GOLD, true, 340)
	M3.text(c, Vector2(192, 150), String(_t.title), 34, UI.TEXT, true, 340)
	var left := maxf(0.0, float(int(_e.expires) - int(Time.get_unix_time_from_system())))
	M3.text(c, Vector2(0, 104), "expire dans %s" % UI.duration(left), 22, UI.MUTED, false, 688, HORIZONTAL_ALIGNMENT_RIGHT)
	M3.para(c, Vector2(40, 250), "« %s »" % String(_t.text), 28, UI.TEXT, 640, 1.35)


func _choose(i: int) -> void:
	var res := Game.board.resolve(_e, i, Game, Game.rng)
	if res == "":
		return
	if res == "Pas assez d’éclats":
		M3.toast(self, res, UI.RED)
		return
	Sfx.play("coin")
	M3.toast(self, res, UI.GREEN if not res.contains("pas de chance") else UI.GOLD)
	Game.save_game()
	Game.changed.emit()
	close()
