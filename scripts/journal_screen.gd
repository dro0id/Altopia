class_name JournalScreen
extends Overlay
## Journal de bord (maquette CI) : puces de chapitre, progression, liste des scènes ; une scène vue se revoit d'un appui.

var _st: Control
var _chips: M3Chips
var _list: Control
var _ch := 1
var _rows: Array = []        # {kind: "prologue"/"scene", scene, seen}


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	M3.top_bar(_st, "Journal de bord", close)
	var labels: Array = []
	var fmt := "Ch. %d" if Story.written().size() > 2 else "Chapitre %d"
	for c in Story.written():
		var open := int(c.n) == 1 or Game.chapters_done.has(int(c.n) - 1)
		labels.append(("" if open else "🔒 ") + fmt % int(c.n))
	_chips = M3Chips.new(labels, 0)
	_chips.position = Vector2(32, 96)
	_chips.changed.connect(func(i: int):
		var n := int(Story.written()[i].n)
		if n > 1 and not Game.chapters_done.has(n - 1):
			_chips.sel = _ch - 1
			_chips.queue_redraw()
			Sfx.play("click", -10.0)
			return
		_ch = n
		_rebuild())
	_st.add_child(_chips)
	var sc := ScrollContainer.new()
	sc.position = Vector2(0, 192)
	sc.size = Vector2(720, 1280 - 192 - NavBar.total())
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_st.add_child(sc)
	DragScroll.attach(sc)
	_list = Control.new()
	_list.draw.connect(_draw_list)
	_list.gui_input.connect(_list_input)
	sc.add_child(_list)
	_rebuild()


func _rebuild() -> void:
	_rows = []
	if _ch == 1:
		_rows.append({"kind": "prologue", "seen": Game.seen_scenes.has("prologue")})
	for s in Story.chapter_scenes(_ch):
		_rows.append({"kind": "scene", "scene": s, "seen": Game.seen_scenes.has(String(s.id))})
	_list.custom_minimum_size = Vector2(720, 216 + _rows.size() * 144.0 + 16.0)
	_list.queue_redraw()


func _row_rect(i: int) -> Rect2:
	return Rect2(32, 216 + i * 144.0, 656, 128)


func _draw_list() -> void:
	var c := _list
	var ch := Story.chapter(_ch)
	var seen := 0
	for r in _rows:
		seen += 1 if r.seen else 0
	var head := Rect2(32, 0, 656, 200)
	var col: Color = ch.get("color", UI.ACCENT)
	UI.draw_gradient_box(c, head, 32.0, ch.get("head", Color("16305e")), M3.S2, Color(0, 0, 0, 0), 0.0)
	M3.text(c, Vector2(64, 52), "CHAPITRE %d · ÉTAGES %d À %d" % [_ch, int(ch.from), int(ch.to)], 24, col, true)
	M3.text(c, Vector2(64, 100), String(ch.title), 36, UI.TEXT, true)
	M3.bar(c, Rect2(64, 124, 592, 12), float(seen) / float(maxi(1, _rows.size())), col)
	M3.text(c, Vector2(64, 172), "%d scène%s sur %d vue%s" % [seen, "s" if seen > 1 else "", _rows.size(), "s" if seen > 1 else ""], 24, UI.MUTED)
	for i in _rows.size():
		var r := _row_rect(i)
		var row: Dictionary = _rows[i]
		M3.card(c, r)
		var n := 0 if row.kind == "prologue" else int(row.scene.stage)
		var title := "Prologue" if row.kind == "prologue" else String(row.scene.title)
		var sub := "Terre, le signal, le décollage" if row.kind == "prologue" else String(row.scene.sub)
		c.draw_circle(r.position + Vector2(64, 64), 40, M3.S3)
		M3.text(c, r.position + Vector2(24, 64 + M3.fs(28) * 0.36), str(n), 28, col if row.seen else UI.MUTED, true, 80, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, r.position + Vector2(128, 56), title, 30, UI.TEXT if row.seen else UI.MUTED, true, 440)
		M3.text(c, r.position + Vector2(128, 94), sub if row.seen else "À découvrir en jouant", 24, UI.MUTED, false, 440)
		if row.seen:
			c.draw_colored_polygon(PackedVector2Array([r.position + Vector2(604, 50), r.position + Vector2(628, 64), r.position + Vector2(604, 78)]), UI.TEXT)
		else:
			M3.lock(c, r.position + Vector2(612, 64), UI.MUTED, 1.2)


var _press := Vector2.ZERO


func _list_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		return
	if not M3.is_release(ev) or ev.position.distance_to(_press) > 14.0:
		return
	for i in _rows.size():
		if _row_rect(i).has_point(ev.position):
			var row: Dictionary = _rows[i]
			if not row.seen:
				Sfx.play("click", -10.0)
				return
			Sfx.play("click", -6.0)
			if row.kind == "prologue":
				add_child(PrologueScreen.new(true))
			else:
				add_child(DialogueScreen.new(row.scene, true))
			return
