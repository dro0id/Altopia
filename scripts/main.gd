extends Control
## Écran principal : champ de bataille animé, pouvoirs, liste des héros, et les fenêtres (carte, résultat, réglages, hors ligne, entrée, défaite).

const Data = preload("res://scripts/data.gd")

var battle: BattleView
var skill_buttons: Array = []
var rows := {}
var _credits_label: Label
var _stage_label: Label
var _auto_btn: Button
var _speed_btn: Button
var _map_btn: Button
var _toast: Label
var _toast_t := 0.0
var _claimed := 0.0
var _refresh_t := 0.0
var _modal: Control
var _scroll: ScrollContainer
# tutoriel
var _hint: PanelContainer
var _hint_label: Label
var _hl: Control
var _tuto := 0
var _tuto_t := 0.0
var _manual_cast := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
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
	_build_hint()
	_start_battle()
	_tuto = 4 if Game.tutorial_done else 0
	if not Game.intro_seen:
		var intro := IntroScreen.new()
		add_child(intro)
		get_tree().paused = true
		intro.finished.connect(func():
			Game.intro_seen = true
			get_tree().paused = false)
	elif not Game.offline_report.is_empty():
		_open_offline()


# ---------------------------------------------------------------- construction

func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(12, 14)
	bar.size = Vector2(696, 92)
	bar.add_theme_stylebox_override("panel", UI.box(UI.PANEL))
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_stage_label = UI.label(v, "", 25, UI.ACCENT)
	_credits_label = UI.label(v, "", 28, UI.GOLD)
	_auto_btn = UI.button(h, "", 20)
	_auto_btn.custom_minimum_size = Vector2(96, 0)
	_auto_btn.pressed.connect(func():
		Game.auto_cast = not Game.auto_cast
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	_speed_btn = UI.button(h, "", 20)
	_speed_btn.custom_minimum_size = Vector2(62, 0)
	_speed_btn.pressed.connect(func():
		Game.speed = 1.0 if Game.speed >= 3.0 else Game.speed + 1.0
		battle.speed = Game.speed
		_refresh())
	_map_btn = UI.button(h, "Carte", 20)
	_map_btn.custom_minimum_size = Vector2(96, 0)
	_map_btn.pressed.connect(_open_map)
	var sb := UI.button(h, "⚙", 24, "ghost")
	sb.custom_minimum_size = Vector2(56, 0)
	sb.pressed.connect(_open_settings)


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
			if battle.sim != null and battle.sim.cast(slot):
				_manual_cast = true)
		row.add_child(b)
		skill_buttons.append(b)


func _build_heroes() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(12, 804)
	_scroll.size = Vector2(696, 464)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	_scroll.add_child(col)
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(684, 96)
		var rc: Color = Data.RARITY_COLORS[h.rarity]
		var sb := UI.box(UI.PANEL, rc, 10, 8)
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
		var nm := UI.label(vb, "", 26, rc)
		var info := UI.label(vb, "", 18, Color(0.6, 0.78, 0.86))
		var stats := UI.label(vb, "", 19, Color(0.9, 0.97, 1.0))
		var up := UI.button(hb, "", 21)
		up.custom_minimum_size = Vector2(190, 0)
		up.pressed.connect(func():
			if Game.level_up(id):
				Sfx.play("coin", -4.0)
			_refresh())
		rows[id] = {"name": nm, "info": info, "stats": stats, "up": up}


func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", UI.GOLD)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.position = Vector2(30, 560)
	_toast.size = Vector2(660, 120)
	_toast.modulate.a = 0.0
	add_child(_toast)


## Bulle d'aide du tutoriel, avec un cadre qui pulse autour de l'élément à utiliser.
func _build_hint() -> void:
	_hl = Control.new()
	_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hl.draw.connect(func():
		if _hl.has_meta("rect"):
			var r: Rect2 = _hl.get_meta("rect")
			var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			_hl.draw_rect(r.grow(4.0 + 3.0 * k), Color(1.0, 0.85, 0.3, 0.5 + 0.5 * k), false, 4.0))
	_hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hl.z_index = 3000
	add_child(_hl)
	_hint = PanelContainer.new()
	_hint.position = Vector2(30, 618)
	_hint.size = Vector2(660, 64)
	_hint.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.16, 0.3, 0.96), UI.GOLD, 12, 14))
	_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_tuto = mini(_tuto + 1, 4)
			if _tuto == 4:
				Game.tutorial_done = true
			_tuto_t = 0.0)
	_hint.visible = false
	_hint.z_index = 3000
	add_child(_hint)
	_hint_label = UI.label(_hint, "", 22, Color.WHITE)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _show_toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = secs


# ---------------------------------------------------------------- fenêtres

func _open_modal(ov: Control) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = ov
	add_child(ov)
	var tr := get_tree()
	tr.paused = true
	ov.tree_exited.connect(func():
		if _modal == ov:
			_modal = null
			tr.paused = false)


func _open_map() -> void:
	var m := MapScreen.new()
	m.stage_chosen.connect(func(n: int):
		Game.go_to(n)
		_start_battle())
	m.chest_claimed.connect(_show_chest_toast)
	_open_modal(m)


func _open_settings() -> void:
	var s := SettingsScreen.new()
	s.changed.connect(func():
		battle.speed = Game.speed
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	s.erase_requested.connect(func():
		Game.reset()
		Game.save_game()
		_tuto = 0
		_start_battle())
	_open_modal(s)


func _open_offline() -> void:
	var o := OfflineScreen.new(Game.offline_report)
	Game.offline_report = {}
	o.chest_claimed.connect(_show_chest_toast)
	_open_modal(o)


func _show_chest_toast(c: Dictionary) -> void:
	Sfx.play("chest")
	_show_toast("Coffre %s : +%s crédits, +%d éclats" % [String(Data.RARITY_NAMES[c.rarity]).to_lower(), Data.fmt(c.credits), int(c.shards)], 3.0)


# ---------------------------------------------------------------- combat

func _start_battle() -> void:
	battle.speed = Game.speed
	battle.start(Game.team(), Game.stage, Game.auto_cast)
	_claimed = 0.0
	_tuto_t = 0.0
	for i in skill_buttons.size():
		skill_buttons[i].unit = null
	for u in battle.sim.units:
		if u.side == 0:
			skill_buttons[u.slot].unit = u
			if _tuto < 2 and u.slot == 0:
				u.skill_cd = 0.5        # pendant le tutoriel, le premier pouvoir est prêt tout de suite
	_refresh()


func _on_cleared(_credits: float) -> void:
	var stage := Game.stage
	var stars: int = battle.sim.stars
	var frontier := Game.is_frontier()
	var chest: Dictionary = Game.stage_cleared(stars)
	Game.save_game()
	if _tuto == 3:
		_tuto = 4
		Game.tutorial_done = true
	if frontier or Data.is_boss_stage(stage):
		var next_label := "Monter à l'étage %d" % (stage + 1) if Game.best_stage > stage else "Rejouer l'étage %d" % stage
		var r := ResultScreen.new(stage, stars, chest, next_label)
		r.next_pressed.connect(func():
			if Game.best_stage > stage:
				Game.advance()
			_start_battle())
		r.replay_pressed.connect(_start_battle)
		r.map_pressed.connect(func():
			_start_battle()
			_open_map.call_deferred())
		_open_modal(r)
	else:
		_show_toast("Étage %d vaincu · coffre %s : +%s" % [stage, String(Data.RARITY_NAMES[chest.rarity]).to_lower(), Data.fmt(chest.credits)], 1.8)
		Sfx.play("coin", -6.0)
		_start_battle()


func _on_failed() -> void:
	var d := DefeatScreen.new(Game.stage)
	d.retry_pressed.connect(_start_battle)
	d.farm_pressed.connect(func():
		Game.retreat()
		_start_battle())
	d.upgrade_pressed.connect(func():
		Game.retreat()
		_start_battle())
	_open_modal(d)


# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	if battle.sim != null:
		var diff := battle.sim.credits - _claimed
		if diff > 0.0:
			Game.credits += diff
			_claimed = battle.sim.credits
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = 0.0 if _toast_t <= 0.0 else minf(1.0, _toast_t * 2.0)
	_tuto_update(delta)
	_refresh_t += delta
	if _refresh_t > 0.15:
		_refresh_t = 0.0
		_refresh()


func _tuto_update(delta: float) -> void:
	var text := ""
	var target := Rect2()
	_tuto_t += delta
	match _tuto:
		0:
			text = "Tes héros combattent tout seuls. Regarde-les faire !"
			if _tuto_t > 2.5:
				_tuto = 1
		1:
			var ready := false
			for b in skill_buttons:
				if b.unit != null and b.unit.alive and b.unit.skill_cd <= 0.0:
					ready = true
			if ready:
				text = "Touche un portrait pour lancer son pouvoir au bon moment."
				target = Rect2(12, 686, 696, 108)
			if _manual_cast:
				_tuto = 2
		2:
			var cheapest := 1.0e18
			for id in Data.HERO_ORDER:
				cheapest = minf(cheapest, float(Game.level_cost(id)))
			if Game.credits >= cheapest:
				text = "Tu as assez de crédits : améliore un héros pour devenir plus fort."
				target = Rect2(12, 804 - _scroll.scroll_vertical, 696, 104)
			var total := 0
			for id in Data.HERO_ORDER:
				total += int(Game.levels[id])
			if total > Data.HERO_ORDER.size():
				_tuto = 3
		3:
			text = "Bien joué ! Monte les étages : un mini-boss t'attend à l'étage 5."
	_hint.visible = text != ""
	_hint_label.text = text
	if target.size != Vector2.ZERO:
		_hl.set_meta("rect", target)
	elif _hl.has_meta("rect"):
		_hl.remove_meta("rect")
	_hl.queue_redraw()


func _refresh() -> void:
	var tag := ""
	match Data.boss_type(Game.stage):
		"mini":
			tag = " · MINI-BOSS"
		"big":
			tag = " · GROS BOSS"
	if not Game.is_frontier() and tag == "":
		tag = " · farm"
	_stage_label.text = "Étage %d%s" % [Game.stage, tag]
	_credits_label.text = "%s crédits" % Data.fmt(Game.credits)
	_auto_btn.text = "Auto ✓" if Game.auto_cast else "Auto ✗"
	_speed_btn.text = "x%d" % int(Game.speed)
	_map_btn.text = "Carte ●" if Game.free_chest_ready() else "Carte"
	var best := Game.best_buy()
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var lv: int = Game.levels[id]
		var m := Data.hero_mult(lv)
		var r: Dictionary = rows[id]
		r.name.text = "%s  niv. %d" % [h.name, lv]
		r.info.text = "%s · %s · %s" % [h.job, Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role]]
		r.stats.text = "PV %d   ATQ %d   DÉF %d" % [h.hp * m, h.atk * m, h.def * m]
		var cost := Game.level_cost(id)
		r.up.text = "%sAméliorer\n%s cr" % ["★ Meilleur achat\n" if id == best and Game.credits >= cost else "", Data.fmt(cost)]
		r.up.disabled = Game.credits < cost
		r.up.modulate = Color(1.0, 0.92, 0.55) if id == best and Game.credits >= cost else Color.WHITE
