class_name MapScreen
extends Overlay
## Carte des étages (maquette BI), plein écran : barre du haut, puces de secteur, liste des étages (boss, étoiles), bouton Monter ou Farmer.

signal stage_chosen(stage: int)
signal chest_claimed(chest: Dictionary)
signal journal_requested

const PER_SECTOR := 10

var _st: Control
var _chips: M3Chips
var _scroll: ScrollContainer
var _list: Control
var _go: Button
var _sel := 1
var _sector := 0
var _press := Vector2.ZERO
var _down := false


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	_sel = Game.stage
	_sector = (_sel - 1) / PER_SECTOR
	M3.top_bar(_st, "Secteurs", close, [["⋮", func(): M3.menu(_st, Vector2(704, 96), [["Journal de bord", func():
		journal_requested.emit()
		close()], ["Aller à mon record (secteur %d)" % Game.best_stage, func():
		_sel = Game.best_stage
		_sector = (_sel - 1) / PER_SECTOR
		_chips.sel = _sector
		_chips.queue_redraw()
		_refresh()]])]])
	var labels: Array = []
	var top_sector := (Game.best_stage - 1) / PER_SECTOR
	for k in top_sector + 2:
		# secteurs de l'histoire nommés par leur chapitre (le chapitre 1 est le voyage, sans étages)
		var lab := ("Ch. %d" % (k + 2)) if k < Story.CHAPTERS.size() - 1 else ("Secteur %d" % (k + 1))
		labels.append(("🔒 " if k > top_sector else "") + lab)
	_chips = M3Chips.new(labels, _sector)
	_chips.position = Vector2(32, 96)
	_chips.changed.connect(func(i: int):
		if i > top_sector:
			_chips.sel = _sector
			_chips.queue_redraw()
			Sfx.play("click", -10.0)
			return
		_sector = i
		_refresh())
	_st.add_child(_chips)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 192)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_st.add_child(_scroll)
	DragScroll.attach(_scroll)
	_list = Control.new()
	_list.draw.connect(_draw_list)
	_list.gui_input.connect(_list_input)
	_scroll.add_child(_list)
	_go = M3.button(_st, "", Rect2(32, 0, 656, 104), "main")
	_go.pressed.connect(func():
		stage_chosen.emit(_sel)
		close())
	_st.resized.connect(_layout)
	_layout()
	_refresh()


func _layout() -> void:
	var h := _st.size.y if _st.size.y > 0.0 else 1280.0
	_go.position.y = h - 32.0 - 104.0
	_scroll.size = Vector2(720, h - 192.0 - 152.0)


func _stages() -> Array:
	var out: Array = []
	var hi := mini((_sector + 1) * PER_SECTOR, Game.best_stage + PER_SECTOR)
	for n in range(hi, _sector * PER_SECTOR, -1):
		out.append(n)
	return out


func _refresh() -> void:
	var n := _stages().size()
	_list.custom_minimum_size = Vector2(720, n * 128.0 + 16.0)
	_go.text = ("Descendre au secteur %d" if _sel >= Game.best_stage else "Farmer le secteur %d") % _sel
	_list.queue_redraw()


func _row(i: int) -> Rect2:
	return Rect2(32, 8.0 + i * 128.0, 656, 112)


func _draw_list() -> void:
	var ss := _stages()
	for i in ss.size():
		var n: int = ss[i]
		var r := _row(i)
		var locked: bool = n > Game.best_stage
		var sel: bool = n == _sel
		M3.card(_list, r, M3.TONAL if sel else M3.S2, 32)
		var bt := Data.boss_type(n)
		var cc := r.position + Vector2(64, 56)
		var st: int = int(Game.stars.get(n, 0))
		# repère à gauche (maquette I5) : vert si déjà vaincu, cyan pour le prochain
		var nxt: bool = n == Game.best_stage and st == 0
		_list.draw_circle(cc, 40, Color("3a1620") if bt == "big" else (Color("1d4a3a") if st > 0 else (Color("16405a") if nxt else M3.S3)))
		if nxt:
			_list.draw_arc(cc, 40, 0, TAU, 48, UI.ACCENT, 3.0, true)
		var glyph := "☠" if bt == "big" else str(n)
		M3.text(_list, cc + Vector2(-40, M3.fs(28) * 0.36), glyph, 28, Color("ff9b9b") if bt == "big" else UI.TEXT, true, 80, HORIZONTAL_ALIGNMENT_CENTER)
		var title := "Secteur %d" % n
		if bt == "big":
			title += " · Gros boss"
		elif bt == "mini":
			title += " · Mini-boss"
		# on ne répète pas l'état par défaut : seulement ce qui diffère (maquette I5)
		var sub := "Verrouillé" if locked else ("À vaincre" if nxt else ("★".repeat(st) + "☆".repeat(3 - st) if st > 0 else ""))
		var ty := 50.0 if sub != "" else 68.0
		M3.text(_list, r.position + Vector2(128, ty), title, 30, UI.MUTED if locked else UI.TEXT, true, 440)
		if sub != "":
			M3.text(_list, r.position + Vector2(128, 88), sub, 24, UI.MUTED if locked else (UI.ACCENT if nxt else UI.GOLD), nxt)
		if locked:
			M3.lock(_list, r.position + Vector2(612, 56), UI.MUTED, 1.2)
		else:
			M3.text(_list, r.position + Vector2(0, 66), "▶" if sel else "›", 30, UI.ACCENT if sel else UI.MUTED, false, 624, HORIZONTAL_ALIGNMENT_RIGHT)


func _list_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		_down = true
	elif M3.is_release(ev) and _down:
		_down = false
		if ev.position.distance_to(_press) > 14.0:
			return
		var ss := _stages()
		for i in ss.size():
			if _row(i).has_point(ev.position):
				if int(ss[i]) > Game.best_stage:
					Sfx.play("click", -10.0)
					return
				_sel = ss[i]
				Sfx.play("click", -6.0)
				_refresh()
				return
