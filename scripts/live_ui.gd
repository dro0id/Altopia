extends Control
## Écran du combat en direct, par-dessus le jeu : en-tête (vagues, vitesse, équipage assisté, pause), arène, coque, objectifs, quatre compétences
## et le résultat. À la fin du combat il règle le butin avec GameState.finish_live().

const Data = preload("res://scripts/game_data.gd")
const Sim = preload("res://scripts/live_sim.gd")
const LiveView = preload("res://scripts/live_view.gd")
const Sfx = preload("res://scripts/live_sfx.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

signal closed(replay: bool)

const ABILITIES := [
	{"id": "dodge", "name": "Esquive", "who": "Rex", "color": Color("80f2ff")},
	{"id": "shield", "name": "Bouclier", "who": "Gorn", "color": Color("ffb26b")},
	{"id": "scan", "name": "Analyse", "who": "Lumi", "color": Color("6eff9c")},
	{"id": "charge", "name": "Tir chargé", "who": "", "color": Color("ffd159")},
]

static var sound_on := true
static var assist_on := false

var sim: Sim
var view: LiveView
var slot_i := 0
var dest := ""
var random := false
var mult := 1.0
var chance := 0.0

var _wave_label: Label
var _speed_btn: Button
var _assist_btn: Button
var _pause_btn: Button
var _sound_btn: Button
var _quit_btn: Button
var _hull_bar: ProgressBar
var _hull_label: Label
var _loot_label: Label
var _chance_label: Label
var _obj_labels: Array = []
var _ab_btns: Dictionary = {}
var _result: PanelContainer
var _res_title: Label
var _res_stars: Label
var _res_body: Label
var _res_info: Label
var _again_btn: Button
var _players: Array = []
var _settled := false
var _relaunch_t := -1.0
var _info_label: Label


## Prépare et démarre un combat : `cfg` vient de GameState.live_config, `mult` est le multiplicateur de gains annoncé.
func begin(p_slot: int, p_dest: String, cfg: Dictionary, p_random: bool, p_mult: float, p_chance: float) -> void:
	slot_i = p_slot
	dest = p_dest
	random = p_random
	mult = p_mult
	chance = p_chance
	cfg["assist"] = assist_on
	sim = Sim.new()
	sim.setup(cfg)
	_build()
	view.attach(sim)
	_refresh()


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
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	# en-tête
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	top.add_child(titles)
	var dest_label := Label.new()
	dest_label.text = Data.DEST[dest].name.to_upper()
	dest_label.add_theme_font_size_override("font_size", 17)
	dest_label.add_theme_color_override("font_color", UiTheme.DIM)
	titles.add_child(dest_label)
	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 30)
	titles.add_child(_wave_label)
	_speed_btn = _chip("x1", 76)
	_speed_btn.pressed.connect(func():
		view.speed = 2 if view.speed == 1 else 1
		_speed_btn.text = "x%d" % view.speed)
	top.add_child(_speed_btn)
	_assist_btn = _chip("Auto", 96)
	_assist_btn.toggle_mode = true
	_assist_btn.button_pressed = assist_on
	_assist_btn.tooltip_text = "Équipage assisté : il esquive seul, sans combo."
	_assist_btn.toggled.connect(func(v: bool):
		assist_on = v
		sim.assist = v)
	top.add_child(_assist_btn)
	_sound_btn = _chip("Son", 90)
	_sound_btn.toggle_mode = true
	_sound_btn.button_pressed = sound_on
	_sound_btn.toggled.connect(func(v: bool): sound_on = v)
	top.add_child(_sound_btn)
	_pause_btn = _chip("II", 70)
	_pause_btn.pressed.connect(_toggle_pause)
	top.add_child(_pause_btn)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.add_theme_color_override("font_color", UiTheme.DIM)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info_label)

	# arène
	view = LiveView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(view)

	# coque, butin, chance
	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 12)
	col.add_child(hud)
	var hull_col := VBoxContainer.new()
	hull_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hull_col.add_theme_constant_override("separation", 0)
	hud.add_child(hull_col)
	var hl := HBoxContainer.new()
	hull_col.add_child(hl)
	var hn := Label.new()
	hn.text = "Coque"
	hn.add_theme_font_size_override("font_size", 17)
	hn.add_theme_color_override("font_color", UiTheme.DIM)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.add_child(hn)
	_hull_label = Label.new()
	_hull_label.add_theme_font_size_override("font_size", 17)
	_hull_label.add_theme_color_override("font_color", Color("ffd159"))
	hl.add_child(_hull_label)
	_hull_bar = ProgressBar.new()
	_hull_bar.show_percentage = false
	_hull_bar.custom_minimum_size = Vector2(0, 14)
	_hull_bar.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ffd159")
	fill.set_corner_radius_all(5)
	_hull_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("12304a")
	back.set_corner_radius_all(5)
	_hull_bar.add_theme_stylebox_override("background", back)
	hull_col.add_child(_hull_bar)
	_loot_label = Label.new()
	_loot_label.add_theme_font_size_override("font_size", 18)
	_loot_label.add_theme_color_override("font_color", Color("ffd159"))
	_loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_loot_label)
	_chance_label = Label.new()
	_chance_label.add_theme_font_size_override("font_size", 19)
	hud.add_child(_chance_label)

	# objectifs
	var objs := HBoxContainer.new()
	objs.add_theme_constant_override("separation", 8)
	col.add_child(objs)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(120, 0)
		pc.add_child(l)
		objs.add_child(pc)
		_obj_labels.append({"panel": pc, "label": l})

	# compétences
	var abs_row := HBoxContainer.new()
	abs_row.add_theme_constant_override("separation", 8)
	col.add_child(abs_row)
	for a in ABILITIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		b.focus_mode = Control.FOCUS_NONE
		var c: Color = a.color
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(c.r * 0.18, c.g * 0.18, c.b * 0.18, 0.95), c, 12, 2, 6))
		b.add_theme_stylebox_override("hover", UiTheme.box(Color(c.r * 0.26, c.g * 0.26, c.b * 0.26, 0.95), c, 12, 2, 6))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Color(c.r * 0.4, c.g * 0.4, c.b * 0.4, 1.0), c, 12, 3, 6))
		b.add_theme_stylebox_override("disabled", UiTheme.box(Color(0.04, 0.09, 0.14, 0.95), Color(0.2, 0.35, 0.42), 12, 1, 6))
		b.pressed.connect(func(): _use(a.id))
		abs_row.add_child(b)
		_ab_btns[a.id] = b

	var hint := Label.new()
	hint.text = "Touchez un couloir ou glissez pour changer de couloir."
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", UiTheme.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint)

	_quit_btn = Button.new()
	_quit_btn.text = "Abandonner (le butin tombe à 25 %)"
	_quit_btn.visible = false
	_quit_btn.pressed.connect(func():
		sim.abandon()
		_toggle_pause())
	col.add_child(_quit_btn)

	# résultat
	_result = PanelContainer.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.anchor_left = 0.06
	_result.anchor_right = 0.94
	_result.anchor_top = 0.2
	_result.anchor_bottom = 0.8
	_result.offset_left = 0
	_result.offset_right = 0
	_result.offset_top = 0
	_result.offset_bottom = 0
	_result.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.05, 0.1, 0.97), Color(0.22, 0.9, 1.0, 0.6), 14, 2, 22))
	add_child(_result)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 10)
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	_result.add_child(rc)
	_res_title = Label.new()
	_res_title.add_theme_font_size_override("font_size", 52)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_title)
	_res_stars = Label.new()
	_res_stars.add_theme_font_size_override("font_size", 46)
	_res_stars.add_theme_color_override("font_color", Color("ffd159"))
	_res_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_stars)
	_res_body = Label.new()
	_res_body.add_theme_font_size_override("font_size", 22)
	_res_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_body)
	_res_info = Label.new()
	_res_info.add_theme_font_size_override("font_size", 20)
	_res_info.add_theme_color_override("font_color", Color("ffd159"))
	_res_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_info)
	_again_btn = Button.new()
	_again_btn.custom_minimum_size = Vector2(0, 76)
	_again_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.style_primary(_again_btn)
	_again_btn.pressed.connect(func(): closed.emit(true))
	rc.add_child(_again_btn)
	var back_btn := Button.new()
	back_btn.text = "Retour"
	back_btn.custom_minimum_size = Vector2(0, 66)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func(): closed.emit(false))
	rc.add_child(back_btn)
	# lecteurs audio
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


func _toggle_pause() -> void:
	view.running = not view.running
	_pause_btn.text = "▶" if not view.running else "II"
	_quit_btn.visible = not view.running and not sim.over


func _use(id: String) -> void:
	if sim.over or not view.running:
		return
	sim.use_ability(id)


func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.pressed or sim == null:
		return
	match ev.keycode:
		KEY_LEFT, KEY_Q, KEY_A: sim.set_lane(sim.lane - 1)
		KEY_RIGHT, KEY_D: sim.set_lane(sim.lane + 1)
		KEY_1: _use("dodge")
		KEY_2: _use("shield")
		KEY_3: _use("scan")
		KEY_4: _use("charge")
		KEY_P: _toggle_pause()


func _play(name: String) -> void:
	if not sound_on:
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
	for ev in sim.events:
		_play(ev)
		if ev == "hurt" and sound_on:
			Input.vibrate_handheld(40)
		elif (ev == "win" or ev == "lose") and sound_on:
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


func _refresh() -> void:
	_wave_label.text = "Vague %d / %d" % [clampi(sim.wave + 1, 1, Sim.WAVE_COUNT), Sim.WAVE_COUNT]
	_hull_bar.value = sim.hull / sim.hull_max
	_hull_label.text = "%d / %d" % [int(sim.hull), int(sim.hull_max)]
	_loot_label.text = "+%d min\n+%d don" % [sim.minerals, sim.data]
	var p := chance
	var label := "sûr" if p >= Data.WIN_CHANCE_SAFE else ("risqué" if p >= 0.5 else "très risqué")
	_chance_label.text = "%s %d %%" % [label, int(round(p * 100.0))]
	var cc := UiTheme.GOOD if p >= Data.WIN_CHANCE_SAFE else (UiTheme.WARN if p >= 0.5 else Color("ff6b7a"))
	_chance_label.add_theme_color_override("font_color", cc)
	var ship: Dictionary = Sim.SHIPS[sim.tier]
	_info_label.text = "%s · palier %d · gains x%s%s" % [ship.name, sim.tier + 1, ("%.2f" % mult).rstrip("0").rstrip(".").replace(".", ","),
		" · mode Aléatoire" if random else ""]
	for i in 2:
		var id: String = sim.objectives[i]
		var done: bool = sim.objective_done(id) and id not in ["hits", "hull", "fast"]
		var l: Label = _obj_labels[i].label
		l.text = ("✓ " if done else "○ ") + sim.objective_text(id)
		l.add_theme_color_override("font_color", UiTheme.GOOD if done else UiTheme.DIM)
		_obj_labels[i].panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.12, 0.2, 0.86), UiTheme.GOOD if done else Color(0.11, 0.33, 0.41), 10, 1, 8))
	for a in ABILITIES:
		var b: Button = _ab_btns[a.id]
		var id2: String = a.id
		var txt := ""
		var ready := false
		if id2 == "charge":
			ready = sim.gauge >= 100.0
			txt = "Tir chargé\n%s" % ("prêt" if ready else "jauge %d %%" % int(sim.gauge))
		else:
			var left: float = sim.cd[id2]
			ready = left <= 0.0
			txt = "%s\n%s" % [a.name, ("%s · %s" % [a.who, "prête" if id2 != "shield" else "prêt"]) if ready else ("%.1f s" % left).replace(".", ",")]
		b.text = txt
		b.disabled = not ready or sim.over
		b.modulate = Color.WHITE if ready else Color(1, 1, 1, 0.85)


func _settle() -> void:
	_settled = true
	var res: Dictionary = sim.result()
	var info: Dictionary = GameState.finish_live(slot_i, dest, res, random)
	var win: bool = res.win
	_res_title.text = "VICTOIRE" if win else "DÉFAITE"
	_res_title.add_theme_color_override("font_color", UiTheme.GOOD if win else Color("ff6b7a"))
	var stars := (1 + int(res.objectives_done)) if win else 0
	_res_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars) if win else ""
	var lines: Array[String] = []
	lines.append(("✓ " if win else "✕ ") + ("Victoire" if win else "Coque détruite"))
	for id in res.objectives:
		var ok: bool = win and sim.objective_done(id)
		lines.append(("✓ " if ok else "○ ") + sim.objective_text(id))
	lines.append("Temps %d s · impacts %d · combo max x%d" % [int(res.time), res.hits, res.max_combo])
	_res_body.text = "\n".join(lines)
	_res_info.text = String(GameState.slots[slot_i].last)
	_again_btn.text = "Rejouer"
	if GameState.auto_relaunch(slot_i) and GameState.live_block_reason(dest, slot_i) == "":
		_relaunch_t = 4.0
	_result.visible = true
