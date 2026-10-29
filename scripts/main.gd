extends Control
## Écran principal : champ de bataille animé, pouvoirs des héros, liste des héros à améliorer.

const Data = preload("res://scripts/data.gd")
const BG := Color(0.02, 0.04, 0.09)
const PANEL := Color(0.05, 0.12, 0.2, 0.92)
const LINE := Color(0.3, 0.85, 1.0, 0.45)
const ACCENT := Color(0.5, 0.95, 1.0)
const GOLD := Color(1.0, 0.82, 0.35)

var battle: BattleView
var skill_buttons: Array = []
var rows := {}
var _credits_label: Label
var _stage_label: Label
var _auto_btn: Button
var _speed_btn: Button
var _toast: Label
var _toast_t := 0.0
var _claimed := 0.0
var _refresh_t := 0.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	battle = BattleView.new()
	battle.position = Vector2(0, 118)
	add_child(battle)
	battle.stage_cleared.connect(_on_cleared)
	battle.stage_failed.connect(_on_failed)
	_build_top()
	_build_skills()
	_build_heroes()
	_build_toast()
	_start_battle()
	if not Game.offline_report.is_empty():
		_show_toast("De retour ! +%s crédits gagnés hors ligne" % Data.fmt(Game.offline_report.credits), 4.0)
		Game.offline_report = {}


func _box(fill: Color, line: Color = LINE, radius: int = 10, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _label(parent: Node, text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _box(Color(0.1, 0.42, 0.55, 0.96), ACCENT, 8, 8))
	b.add_theme_stylebox_override("hover", _box(Color(0.13, 0.52, 0.68), Color.WHITE, 8, 8))
	b.add_theme_stylebox_override("pressed", _box(Color(0.2, 0.65, 0.8), Color.WHITE, 8, 8))
	b.add_theme_stylebox_override("disabled", _box(Color(0.06, 0.1, 0.16, 0.9), Color(0.3, 0.4, 0.5, 0.35), 8, 8))
	parent.add_child(b)
	return b


func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(12, 14)
	bar.size = Vector2(696, 92)
	bar.add_theme_stylebox_override("panel", _box(PANEL))
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	bar.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_stage_label = _label(v, "", 26, ACCENT)
	_credits_label = _label(v, "", 28, GOLD)
	_auto_btn = _button(h, "", 22)
	_auto_btn.custom_minimum_size = Vector2(110, 0)
	_auto_btn.pressed.connect(func():
		Game.auto_cast = not Game.auto_cast
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	_speed_btn = _button(h, "", 22)
	_speed_btn.custom_minimum_size = Vector2(70, 0)
	_speed_btn.pressed.connect(func():
		Game.speed = 1.0 if Game.speed >= 3.0 else Game.speed + 1.0
		battle.speed = Game.speed
		_refresh())


func _build_skills() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(12, 686)
	row.size = Vector2(696, 108)
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	for i in Data.HERO_ORDER.size():
		var b := SkillButton.new()
		b.slot = i
		b.hero = Data.HEROES[Data.HERO_ORDER[i]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(slot: int):
			if battle.sim != null:
				battle.sim.cast(slot))
		row.add_child(b)
		skill_buttons.append(b)


func _build_heroes() -> void:
	var sc := ScrollContainer.new()
	sc.position = Vector2(12, 804)
	sc.size = Vector2(696, 464)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	sc.add_child(col)
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(684, 96)
		var rc: Color = Data.RARITY_COLORS[h.rarity]
		var sb := _box(PANEL, rc, 10, 8)
		sb.border_width_left = 6
		panel.add_theme_stylebox_override("panel", sb)
		col.add_child(panel)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		panel.add_child(hb)
		var icon := HeroIcon.new()
		icon.hero = h
		hb.add_child(icon)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 0)
		hb.add_child(vb)
		var nm := _label(vb, "", 26, rc)
		var info := _label(vb, "", 18, Color(0.6, 0.78, 0.86))
		var stats := _label(vb, "", 19, Color(0.9, 0.97, 1.0))
		var up := _button(hb, "", 21)
		up.custom_minimum_size = Vector2(190, 0)
		up.pressed.connect(func():
			if Game.level_up(id):
				_rebuild_stats()
			_refresh())
		rows[id] = {"name": nm, "info": info, "stats": stats, "up": up}


func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", GOLD)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.position = Vector2(30, 560)
	_toast.size = Vector2(660, 120)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _show_toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = secs


func _start_battle() -> void:
	battle.speed = Game.speed
	battle.start(Game.team(), Game.stage, Game.auto_cast)
	_claimed = 0.0
	for i in skill_buttons.size():
		skill_buttons[i].unit = null
	for u in battle.sim.units:
		if u.side == 0:
			skill_buttons[u.slot].unit = u
	_rebuild_stats()
	_refresh()


func _rebuild_stats() -> void:
	# nouvelles statistiques affichées (la simulation en cours garde les anciennes jusqu'au prochain combat)
	pass


func _on_cleared(_credits: float) -> void:
	Game.stage_cleared()
	_show_toast("Secteur %d vaincu !" % (Game.stage - 1), 1.6)
	_start_battle()


func _on_failed() -> void:
	Game.retreat()
	_show_toast("Escouade tombée : retour au secteur %d" % Game.stage, 2.0)
	_start_battle()


func _process(delta: float) -> void:
	if battle.sim != null:
		var diff := battle.sim.credits - _claimed
		if diff > 0.0:
			Game.credits += diff
			_claimed = battle.sim.credits
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.modulate.a = 0.0
		else:
			_toast.modulate.a = minf(1.0, _toast_t * 2.0)
	_refresh_t += delta
	if _refresh_t > 0.15:
		_refresh_t = 0.0
		_refresh()


func _refresh() -> void:
	var boss := Data.is_boss_stage(Game.stage)
	var wave_txt := ""
	if battle.sim != null:
		wave_txt = "  ·  vague %d/%d" % [battle.sim.wave, battle.sim.waves_total]
	_stage_label.text = "Chapitre %d · Secteur %d%s%s" % [Data.chapter_of(Game.stage), Game.stage, "  ☠" if boss else "", wave_txt]
	_credits_label.text = "%s crédits" % Data.fmt(Game.credits)
	_auto_btn.text = "Auto ✓" if Game.auto_cast else "Auto ✗"
	_speed_btn.text = "x%d" % int(Game.speed)
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var lv: int = Game.levels[id]
		var m := Data.hero_mult(lv)
		var r: Dictionary = rows[id]
		r.name.text = "%s  niv. %d" % [h.name, lv]
		r.info.text = "%s · %s · %s" % [h.job, Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role]]
		r.stats.text = "PV %d   ATQ %d   DÉF %d" % [h.hp * m, h.atk * m, h.def * m]
		var cost := Game.level_cost(id)
		r.up.text = "Améliorer\n%s cr" % Data.fmt(cost)
		r.up.disabled = Game.credits < cost
