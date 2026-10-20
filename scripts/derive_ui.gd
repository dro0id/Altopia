extends Control
## Écran de la dérive, par-dessus le jeu : minuterie, énergie et coque, grille 6 x 7, conseil en direct, boutons d'action de la case choisie,
## sonde, objectifs et résultat. À la fin il règle le butin avec GameState.finish_live().
## Commandes : un premier toucher sur une case voisine inconnue la sélectionne, un second la scanne ; une case déjà scannée : un toucher pour y aller ;
## arriver sur une ressource lance l'extraction toute seule.

const Data = preload("res://scripts/game_data.gd")
const Sim = preload("res://scripts/derive_sim.gd")
const Cell = preload("res://scripts/derive_cell.gd")
const LiveUI = preload("res://scripts/live_ui.gd")
const Sfx = preload("res://scripts/live_sfx.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

signal closed(replay: bool)

const COL_MIN := Color("ccb39e")
const COL_DAT := Color("80f2ff")
const COL_ENE := Color("c79bff")
const COL_HAZ := Color("ffb26b")
const COL_GOLD := Color("ffd159")
const GLYPH := {"min": "◆", "dat": "●", "ene": "✦"}

var sim: Sim
var slot_i := 0
var dest := ""
var random := false
var mult := 1.0
var sel: Array = []                 # case choisie [ligne, colonne] ou []
var running := true
var speed := 1

var _timer: Label
var _energy_bar: ProgressBar
var _energy_label: Label
var _hull_bar: ProgressBar
var _hull_label: Label
var _cells: Array = []
var _coach: Label
var _selbar: HBoxContainer
var _probe_btn: Button
var _leave_btn: Button
var _speed_btn: Button
var _assist_btn: Button
var _sound_btn: Button
var _pause_btn: Button
var _obj_labels: Array = []
var _info: Label
var _guide: PanelContainer
var _result: PanelContainer
var _res_title: Label
var _res_stars: Label
var _res_body: Label
var _res_info: Label
var _again_btn: Button
var _players: Array = []
var _settled := false
var _relaunch_t := -1.0
var _sel_sig := ""
var _cell_sigs: Array = []


## `cfg` vient de GameState.derive_config ; `mult` est le multiplicateur de gains annoncé.
func begin(p_slot: int, p_dest: String, cfg: Dictionary, p_random: bool, p_mult: float) -> void:
	slot_i = p_slot
	dest = p_dest
	random = p_random
	mult = p_mult
	cfg["assist"] = LiveUI.assist_on
	sim = Sim.new()
	sim.setup(cfg)
	_build()
	_refresh()


func _style(bg: Color, line: Color, width: int = 1, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = line
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	return sb


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.035, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	margin.add_child(col)

	# en-tête
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	top.add_child(titles)
	var dl := Label.new()
	dl.text = "DÉRIVE · " + Data.DEST[dest].name.to_upper()
	dl.add_theme_font_size_override("font_size", 17)
	dl.add_theme_color_override("font_color", UiTheme.DIM)
	titles.add_child(dl)
	_timer = Label.new()
	_timer.add_theme_font_size_override("font_size", 32)
	_timer.add_theme_color_override("font_color", COL_GOLD)
	titles.add_child(_timer)
	_speed_btn = _chip("x1", 72)
	_speed_btn.pressed.connect(func():
		speed = 2 if speed == 1 else 1
		_speed_btn.text = "x%d" % speed)
	top.add_child(_speed_btn)
	_assist_btn = _chip("Auto", 92)
	_assist_btn.toggle_mode = true
	_assist_btn.button_pressed = LiveUI.assist_on
	_assist_btn.toggled.connect(func(v: bool):
		LiveUI.assist_on = v
		sim.assist = v)
	top.add_child(_assist_btn)
	_sound_btn = _chip("Son", 82)
	_sound_btn.toggle_mode = true
	_sound_btn.button_pressed = LiveUI.sound_on
	_sound_btn.toggled.connect(func(v: bool): LiveUI.sound_on = v)
	top.add_child(_sound_btn)
	_pause_btn = _chip("II", 66)
	_pause_btn.pressed.connect(func():
		running = not running
		_pause_btn.text = "II" if running else "▶")
	top.add_child(_pause_btn)
	var help := _chip("?", 60)
	help.pressed.connect(func(): _guide.visible = not _guide.visible)
	top.add_child(help)

	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", UiTheme.DIM)
	col.add_child(_info)

	# énergie et coque
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 12)
	col.add_child(bars)
	var eb := _bar_block("Énergie de scan", Color("c79bff"))
	bars.add_child(eb.box)
	_energy_bar = eb.bar
	_energy_label = eb.label
	var hb := _bar_block("Coque", COL_GOLD)
	bars.add_child(hb.box)
	_hull_bar = hb.bar
	_hull_label = hb.label

	# guide de départ
	_guide = PanelContainer.new()
	_guide.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.12, 0.2, 0.97), Color("80f2ff"), 12, 2, 14))
	_guide.visible = not GameState.derive_guide_seen
	_guide.set_anchors_preset(Control.PRESET_CENTER)
	_guide.anchor_left = 0.05
	_guide.anchor_right = 0.95
	_guide.anchor_top = 0.18
	_guide.anchor_bottom = 0.72
	for k in ["offset_left", "offset_right", "offset_top", "offset_bottom"]:
		_guide.set(k, 0)
	_guide.add_to_group("derive_guide")
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 6)
	_guide.add_child(gv)
	var gt := Label.new()
	gt.text = "Comment jouer"
	gt.add_theme_font_size_override("font_size", 26)
	gt.add_theme_color_override("font_color", COL_GOLD)
	gv.add_child(gt)
	var gl := Label.new()
	gl.text = "1. Touchez une case en pointillés, puis touchez-la encore pour la scanner (1 énergie). Son chiffre compte les dangers autour d'elle.\n2. Une case déjà scannée : touchez-la pour y aller. Sur une ressource (◆ ● ✦), l'extraction démarre seule.\n3. Une case hachurée : un météore tombe dans quelques secondes. Quittez-la : il détruit la case et pulvérise le vaisseau.\n4. Ramenez au moins %d ressources, puis touchez Rentrer (ou attendez la fin du temps)." % int(Sim.CFG.min_loot)
	gl.add_theme_font_size_override("font_size", 19)
	gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gv.add_child(gl)
	var gok := Button.new()
	gok.text = "Compris"
	gok.custom_minimum_size = Vector2(0, 60)
	gok.add_theme_font_size_override("font_size", 22)
	gok.pressed.connect(func():
		_guide.visible = false
		GameState.derive_guide_seen = true
		GameState.save_game())
	gv.add_child(gok)

	# grille
	var grid := GridContainer.new()
	grid.columns = Sim.COLS
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	for i in Sim.ROWS * Sim.COLS:
		var cell := Cell.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.custom_minimum_size = Vector2(0, 78)
		cell.focus_mode = Control.FOCUS_NONE
		cell.add_theme_font_size_override("font_size", 34)
		cell.pressed.connect(func(): _on_cell(i / Sim.COLS, i % Sim.COLS))
		grid.add_child(cell)
		_cells.append(cell)

	# conseil et actions de la case choisie
	_coach = Label.new()
	_coach.add_theme_font_size_override("font_size", 20)
	_coach.add_theme_color_override("font_color", Color("fff3cf"))
	_coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach.custom_minimum_size = Vector2(0, 56)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiTheme.box(Color(0.16, 0.14, 0.06, 0.6), COL_GOLD, 12, 1, 10))
	cp.add_child(_coach)
	col.add_child(cp)
	_selbar = HBoxContainer.new()
	_selbar.add_theme_constant_override("separation", 8)
	_selbar.custom_minimum_size = Vector2(0, 74)
	col.add_child(_selbar)

	# sonde et retour
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_probe_btn = Button.new()
	_probe_btn.custom_minimum_size = Vector2(0, 78)
	_probe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_probe_btn.add_theme_font_size_override("font_size", 19)
	_probe_btn.focus_mode = Control.FOCUS_NONE
	var green := Color("6eff9c")
	_probe_btn.add_theme_stylebox_override("normal", _style(Color(0.06, 0.16, 0.11, 0.95), green, 2, 12))
	_probe_btn.add_theme_stylebox_override("hover", _style(Color(0.09, 0.22, 0.15, 0.95), green, 2, 12))
	_probe_btn.add_theme_stylebox_override("pressed", _style(Color(0.12, 0.3, 0.2, 1.0), green, 3, 12))
	_probe_btn.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.09, 0.14, 0.95), Color(0.2, 0.35, 0.42), 1, 12))
	_probe_btn.pressed.connect(func():
		if running and not sim.over:
			sim.act_probe())
	row.add_child(_probe_btn)
	_leave_btn = Button.new()
	_leave_btn.text = "Rentrer"
	_leave_btn.custom_minimum_size = Vector2(190, 78)
	_leave_btn.add_theme_font_size_override("font_size", 24)
	_leave_btn.focus_mode = Control.FOCUS_NONE
	_leave_btn.add_theme_stylebox_override("normal", _style(Color(0.16, 0.08, 0.12, 0.95), COL_HAZ, 2, 12))
	_leave_btn.add_theme_stylebox_override("hover", _style(Color(0.22, 0.1, 0.15, 0.95), COL_HAZ, 2, 12))
	_leave_btn.pressed.connect(func():
		if running and not sim.over:
			sim.act_leave())
	row.add_child(_leave_btn)

	# objectifs
	var objs := HBoxContainer.new()
	objs.add_theme_constant_override("separation", 8)
	col.add_child(objs)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(120, 0)
		pc.add_child(l)
		objs.add_child(pc)
		_obj_labels.append({"panel": pc, "label": l})

	# résultat
	_result = PanelContainer.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.anchor_left = 0.06
	_result.anchor_right = 0.94
	_result.anchor_top = 0.2
	_result.anchor_bottom = 0.8
	for k in ["offset_left", "offset_right", "offset_top", "offset_bottom"]:
		_result.set(k, 0)
	_result.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.05, 0.1, 0.97), Color(0.22, 0.9, 1.0, 0.6), 14, 2, 22))
	add_child(_result)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 10)
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	_result.add_child(rc)
	_res_title = Label.new()
	_res_title.add_theme_font_size_override("font_size", 44)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_title)
	_res_stars = Label.new()
	_res_stars.add_theme_font_size_override("font_size", 46)
	_res_stars.add_theme_color_override("font_color", COL_GOLD)
	_res_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_stars)
	_res_body = Label.new()
	_res_body.add_theme_font_size_override("font_size", 22)
	_res_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_body)
	_res_info = Label.new()
	_res_info.add_theme_font_size_override("font_size", 20)
	_res_info.add_theme_color_override("font_color", COL_GOLD)
	_res_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_info)
	_again_btn = Button.new()
	_again_btn.custom_minimum_size = Vector2(0, 76)
	_again_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.style_primary(_again_btn)
	_again_btn.pressed.connect(func(): closed.emit(true))
	rc.add_child(_again_btn)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 66)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): closed.emit(false))
	rc.add_child(back)
	add_child(_guide)
	for i in 4:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)


func _chip(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 64)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	return b


func _bar_block(title: String, color: Color) -> Dictionary:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	var hl := HBoxContainer.new()
	box.add_child(hl)
	var n := Label.new()
	n.text = title
	n.add_theme_font_size_override("font_size", 17)
	n.add_theme_color_override("font_color", UiTheme.DIM)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_child(n)
	var v := Label.new()
	v.add_theme_font_size_override("font_size", 17)
	v.add_theme_color_override("font_color", color)
	hl.add_child(v)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("12304a")
	back.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	return {"box": box, "bar": bar, "label": v}


# ---------- gestes ----------

func _same_sel(r: int, c: int) -> bool:
	return sel.size() == 2 and sel[0] == r and sel[1] == c


func _scan_or_say(r: int, c: int) -> void:
	if sim.energy >= float(Sim.CFG.scan_cost):
		sim.act_scan(r, c)
	else:
		sim.say("Plus d'énergie de scan : choisissez « Avancer sans scanner » ou rentrez.")


func _on_cell(r: int, c: int) -> void:
	if sim.over or not running or sim.assist:
		return
	var cell: Dictionary = sim.cells[Sim.idx(r, c)]
	var here: bool = r == sim.ship[0] and c == sim.ship[1]
	if sim.extracting_at >= 0 and not here:
		sim.extracting_at = -1
		sim.say("Extraction annulée.")
	if here:
		sel = []
		if cell.res != "" and not cell.done:
			sim.act_extract()
		return
	var dr: int = r - sim.ship[0]
	var dc: int = c - sim.ship[1]
	var d := maxi(absi(dr), absi(dc))
	var inline := dr == 0 or dc == 0 or absi(dr) == absi(dc)
	if d == 1:
		if cell.seen:
			sel = []
			sim.act_move(r, c)               # case déjà scannée : on y va tout de suite
			return
		if _same_sel(r, c):
			sel = []
			_scan_or_say(r, c)               # deuxième toucher : l'action par défaut, scanner
			return
		sel = [r, c]
		return
	if d == 2 and inline:
		if _same_sel(r, c):
			sel = []
			if not sim.act_jump(r, c):
				sim.say("Saut impossible : il faut %d énergies." % int(Sim.CFG.jump_cost))
			return
		sel = [r, c]
		return
	sel = []
	sim.say("Trop loin : touchez une case voisine (en pointillés).")


func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.pressed or sim == null or sim.over or not running or sim.assist:
		return
	var d := Vector2i.ZERO
	match ev.keycode:
		KEY_UP, KEY_W, KEY_Z: d = Vector2i(-1, 0)
		KEY_DOWN, KEY_S: d = Vector2i(1, 0)
		KEY_LEFT, KEY_A: d = Vector2i(0, -1)
		KEY_RIGHT, KEY_D: d = Vector2i(0, 1)
		KEY_E:
			sim.act_extract()
			return
		KEY_Q:
			sim.act_probe()
			return
		KEY_L:
			sim.act_leave()
			return
	if d != Vector2i.ZERO:
		var r: int = sim.ship[0] + d.x
		var c: int = sim.ship[1] + d.y
		if not Sim.inb(r, c):
			return
		var cell: Dictionary = sim.cells[Sim.idx(r, c)]
		if cell.seen:
			_on_cell(r, c)
		elif ev.shift_pressed:
			sim.act_move(r, c)               # Maj + flèche : avancer sans scanner
		else:
			_scan_or_say(r, c)


func _play(name: String) -> void:
	if not LiveUI.sound_on:
		return
	var st := Sfx.stream(name)
	if st == null:
		return
	for pl in _players:
		if not pl.playing:
			pl.stream = st
			pl.play()
			return


func _process(delta: float) -> void:
	if sim == null:
		return
	if running and not sim.over:
		var dt := minf(delta, 0.05)
		for i in speed:
			sim.step(dt)
	for ev in sim.events:
		_play(ev)
		if ev == "hurt" and LiveUI.sound_on:
			Input.vibrate_handheld(50)
		elif (ev == "win" or ev == "lose") and LiveUI.sound_on:
			Input.vibrate_handheld(100)
	sim.events.clear()
	_refresh()
	if sim.over and not _settled:
		_settle()
	if _relaunch_t >= 0.0:
		_relaunch_t -= delta
		_again_btn.text = "Relance dans %d s (toucher pour relancer)" % int(ceil(maxf(0.0, _relaunch_t)))
		if _relaunch_t <= 0.0:
			_relaunch_t = -1.0
			closed.emit(true)


# ---------- affichage ----------

func _find_target() -> int:
	var best := -1
	var bd := 1000000
	for i in Sim.ROWS * Sim.COLS:
		var c: Dictionary = sim.cells[i]
		if c.seen and c.res != "" and not c.done and not c.destroyed:
			var d: int = absi(i / Sim.COLS - sim.ship[0]) + absi(i % Sim.COLS - sim.ship[1])
			if d < bd and d > 0:
				bd = d
				best = i
	return best


func _coach_text() -> String:
	if sim.msg_t > 0.0:
		return sim.msg
	var sr: int = sim.ship[0]
	var sc: int = sim.ship[1]
	for m in sim.meteors:
		if m.r == sr and m.c == sc:
			return "Météore sur votre case : déplacez-vous !"
	if sim.extracting_at >= 0:
		return "Extraction en cours : ne bougez pas."
	if sel.size() == 2 and not sim.over:
		return "Case choisie : touchez-la encore pour scanner, ou utilisez les boutons."
	if _find_target() >= 0:
		return "Allez sur la ressource entourée d'or : l'extraction démarre seule."
	if sim.extracted >= int(Sim.CFG.min_loot):
		return "Charge suffisante : continuez, ou touchez Rentrer pour sécuriser le butin."
	if sim.energy < float(Sim.CFG.scan_cost):
		return "Plus d'énergie de scan : marchez sur les cases connues, avancez sans scanner, ou rentrez."
	return "Touchez une case voisine en pointillés : un premier toucher la sélectionne, un second la scanne."


func _refresh() -> void:
	var rem := maxf(0.0, float(Sim.CFG.time) - sim.t)
	_timer.text = "%d:%02d" % [int(rem) / 60, int(rem) % 60]
	_energy_bar.value = sim.energy / float(Sim.CFG.energy_max)
	_energy_label.text = "%d / %d" % [int(round(sim.energy)), int(Sim.CFG.energy_max)]
	_hull_bar.value = sim.hull / sim.hull_max
	_hull_label.text = "%d / %d" % [int(sim.hull), int(sim.hull_max)]
	_info.text = "Gains x%s%s · au moins %d ressources à ramener" % [("%.2f" % mult).rstrip("0").rstrip(".").replace(".", ","),
		" · mode Aléatoire" if random else "", int(Sim.CFG.min_loot)]
	# la sélection ne vaut que pour une case encore inconnue (ou à distance de saut)
	if sel.size() == 2:
		var sc: Dictionary = sim.cells[Sim.idx(sel[0], sel[1])]
		var dd := maxi(absi(sel[0] - sim.ship[0]), absi(sel[1] - sim.ship[1]))
		if sim.over or dd < 1 or dd > 2 or (dd == 1 and sc.seen):
			sel = []
	var tgt := _find_target()
	for i in Sim.ROWS * Sim.COLS:
		var r := i / Sim.COLS
		var c := i % Sim.COLS
		var cell: Dictionary = sim.cells[i]
		var btn: Cell = _cells[i]
		var txt := ""
		var bgc := Color("0a1f33")
		var line := Color("12304a")
		var fg := Color("80b5c4")
		var lw := 1
		var label := "zone inconnue"
		var is_me: bool = r == sim.ship[0] and c == sim.ship[1]
		if cell.seen:
			bgc = Color("0f2a3e")
			line = Color("1d5468")
			fg = Color("e6faff")
			label = "zone scannée"
			if cell.haz and not cell.crater:
				bgc = Color("2a1420")
				line = COL_HAZ
				fg = COL_HAZ
				lw = 2
				txt = "✕"
				label = "danger"
			elif cell.destroyed:
				bgc = Color("14080c")
				line = Color("7a3a4a")
				fg = Color("c47a8a")
				lw = 2
				txt = "▓"
				label = "case détruite"
			elif cell.crater and cell.res == "":
				bgc = Color("1a1016")
				line = Color("4a2a3a")
				fg = Color("7a4a5a")
				txt = "·"
				label = "cratère"
			elif cell.res != "":
				lw = 2
				match cell.res:
					"min":
						bgc = Color("2a2418")
						line = COL_MIN
						fg = COL_MIN
					"dat":
						line = COL_DAT
						fg = COL_DAT
					"ene":
						bgc = Color("241a3a")
						line = COL_ENE
						fg = COL_ENE
				txt = GLYPH[cell.res]
				label = "ressource"
				if cell.done:
					txt = "✓"
					fg = Color(fg.r, fg.g, fg.b, 0.45)
			else:
				if cell.num > 0:
					txt = str(cell.num)
					fg = Color("9fe6ff") if cell.num == 1 else (COL_GOLD if cell.num == 2 else COL_HAZ)
				label = "%d danger voisin" % cell.num
		if is_me:
			bgc = Color("1b6f8c")
			line = Color("80f2ff")
			fg = Color.WHITE
			lw = 3
			txt = "◉"
			label = "votre vaisseau"
		var near: bool = not cell.seen and sim.adj(r, c) and not sim.over
		btn.near = near
		var sig := "%s|%s|%d|%s|%s" % [bgc.to_html(), line.to_html(), lw, fg.to_html(), txt]
		if i >= _cell_sigs.size():
			_cell_sigs.append("")
		if _cell_sigs[i] != sig:
			_cell_sigs[i] = sig
			btn.text = txt
			btn.add_theme_color_override("font_color", fg)
			btn.add_theme_color_override("font_hover_color", fg)
			btn.add_theme_color_override("font_pressed_color", fg)
			var sb := _style(bgc, line, lw, 10)
			for st in ["normal", "hover", "pressed", "focus", "disabled"]:
				btn.add_theme_stylebox_override(st, sb)
		btn.meteor_left = -1.0
		for m in sim.meteors:
			if m.r == r and m.c == c:
				btn.meteor_left = float(Sim.CFG.meteor_tele) - m.t
		btn.meteor_total = float(Sim.CFG.meteor_tele)
		btn.progress = (1.0 - sim.extract_t / sim.extract_total) if sim.extracting_at == i else -1.0
		btn.cost = str(int(Sim.CFG.scan_cost)) if near and sim.energy >= float(Sim.CFG.scan_cost) else ""
		btn.target = i == tgt
		btn.selected = sel.size() == 2 and sel[0] == r and sel[1] == c
		btn.queue_redraw()
		btn.tooltip_text = "ligne %d, colonne %d : %s" % [r + 1, c + 1, label]
	_coach.text = _coach_text()
	_probe_btn.text = "Sonde (Lumi) : révèle les 8 cases autour\n%d én. · %d charge%s" % [int(Sim.CFG.probe_cost), sim.probe_left, "s" if sim.probe_left > 1 else ""]
	_probe_btn.disabled = sim.over or sim.probe_left <= 0 or sim.energy < float(Sim.CFG.probe_cost) or sim.assist
	_leave_btn.disabled = sim.over
	for i in 2:
		var id: String = sim.objectives[i]
		var done: bool = sim.objective_live_done(id)
		var l: Label = _obj_labels[i].label
		l.text = ("✓ " if done else "○ ") + sim.objective_text(id)
		l.add_theme_color_override("font_color", UiTheme.GOOD if done else UiTheme.DIM)
		_obj_labels[i].panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.12, 0.2, 0.86), UiTheme.GOOD if done else Color(0.11, 0.33, 0.41), 10, 1, 8))
	_refresh_selbar()


func _refresh_selbar() -> void:
	var sig := ""
	if sel.size() == 2 and not sim.over:
		var d := maxi(absi(sel[0] - sim.ship[0]), absi(sel[1] - sim.ship[1]))
		sig = "%d:%s:%s" % [d, str(sim.energy >= float(Sim.CFG.scan_cost)), str(sim.energy >= float(Sim.CFG.jump_cost))]
	if sig == _sel_sig:
		return
	_sel_sig = sig
	for ch in _selbar.get_children():
		ch.queue_free()
	if sig == "":
		return
	var r: int = sel[0]
	var c: int = sel[1]
	var d := maxi(absi(r - sim.ship[0]), absi(c - sim.ship[1]))
	if d == 1:
		var b1 := _action_btn("Scanner\n%d énergie · sans risque" % int(Sim.CFG.scan_cost), true)
		b1.disabled = sim.energy < float(Sim.CFG.scan_cost)
		b1.pressed.connect(func():
			sel = []
			_scan_or_say(r, c))
		_selbar.add_child(b1)
		var b2 := _action_btn("Avancer sans scanner\ngratuit · un danger fait mal", false)
		b2.pressed.connect(func():
			sel = []
			sim.act_move(r, c))
		_selbar.add_child(b2)
	elif d == 2:
		var b3 := _action_btn("Sauter (Rex)\n%d énergies · en ligne droite" % int(Sim.CFG.jump_cost), true)
		b3.disabled = sim.energy < float(Sim.CFG.jump_cost)
		b3.pressed.connect(func():
			sel = []
			if not sim.act_jump(r, c):
				sim.say("Saut impossible."))
		_selbar.add_child(b3)


func _action_btn(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 74)
	b.add_theme_font_size_override("font_size", 19)
	b.focus_mode = Control.FOCUS_NONE
	var line := Color("80f2ff") if primary else Color("1d5468")
	var bg := Color(0.06, 0.16, 0.24, 0.97) if primary else Color(0.04, 0.12, 0.2, 0.9)
	b.add_theme_stylebox_override("normal", _style(bg, line, 2, 12))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.08), line, 2, 12))
	b.add_theme_stylebox_override("pressed", _style(bg.lightened(0.2), line, 3, 12))
	b.add_theme_stylebox_override("disabled", _style(Color(0.04, 0.09, 0.14, 0.95), Color(0.2, 0.35, 0.42), 1, 12))
	return b


func _settle() -> void:
	_settled = true
	var res: Dictionary = sim.result()
	GameState.finish_live(slot_i, dest, res, random, "derive")
	var win: bool = res.win
	var titles := {"hull": "COQUE DÉTRUITE", "meteor": "MÉTÉORE", "loot": "CHARGE TROP MAIGRE"}
	_res_title.text = "DÉRIVE RÉUSSIE" if win else String(titles.get(res.reason, "DÉRIVE MANQUÉE"))
	_res_title.add_theme_color_override("font_color", UiTheme.GOOD if win else Color("ff6b7a"))
	var stars := (1 + int(res.objectives_done)) if win else 0
	_res_stars.text = ("★".repeat(stars) + "☆".repeat(3 - stars)) if win else ""
	var lines: Array[String] = []
	if win:
		lines.append("✓ Dérive réussie")
	elif res.reason == "meteor":
		lines.append("✕ Le météore a pulvérisé le vaisseau")
	elif sim.hull <= 0.0:
		lines.append("✕ Coque détruite")
	else:
		lines.append("✕ Moins de %d ressources ramenées" % int(Sim.CFG.min_loot))
	for id in res.objectives:
		var ok: bool = win and sim.objective_done(id)
		lines.append(("✓ " if ok else "○ ") + sim.objective_text(id))
	lines.append("Temps %d s · impacts %d · explorée à %d %% · %d ressources" % [int(res.time), res.hits, int(round(sim.seen_share() * 100.0)), res.extracted])
	_res_body.text = "\n".join(lines)
	_res_info.text = String(GameState.slots[slot_i].last)
	_again_btn.text = "Repartir"
	if GameState.auto_relaunch(slot_i) and GameState.live_block_reason(dest, slot_i) == "":
		_relaunch_t = 4.0
	_result.visible = true
