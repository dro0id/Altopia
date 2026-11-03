extends Control
## Écran principal : champ de bataille animé, pouvoirs, liste des héros, et les fenêtres (carte, résultat, réglages, hors ligne, entrée, défaite).

const Data = preload("res://scripts/data.gd")

var battle: BattleView
var skill_buttons: Array = []
var cards: Array = []
var _credits_label: Label
var _shards_label: Label
var _stage_btn: Button
var _combo_label: Label
var _auto_btn: Button
var _speed_btn: Button
var _nav: NavBar
var _tab_modal := false
var _skill_row: HBoxContainer
var _squad_head: Label
var _syn_label: Label
var _cards_row: HBoxContainer
var _up_panel: PanelContainer
var _up_icon: HeroIcon
var _up_name: Label
var _up_info: Label
var _up_btn: Button
var _sel := -1                      # carte choisie ; -1 = le meilleur achat
var _up_slot := 0
var _toast: Label
var _toast_t := 0.0
var _claimed := 0.0
var _refresh_t := 0.0
var _modal: Control
var _buffs: Label
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
	battle.position = Vector2.ZERO
	add_child(battle)
	battle.stage_cleared.connect(_on_cleared)
	battle.stage_failed.connect(_on_failed)
	_build_top()
	_build_skills()
	_build_squad()
	_build_nav()
	_build_toast()
	_build_hint()
	_build_buffs()
	resized.connect(_layout)
	_layout()
	_start_battle()
	_tuto = 4 if Game.tutorial_done else 0
	if not Game.intro_seen:
		var intro := IntroScreen.new()
		add_child(intro)
		get_tree().paused = true
		_nav.visible = false
		intro.finished.connect(func():
			Game.intro_seen = true
			_nav.visible = true
			get_tree().paused = false)
	elif not Game.offline_report.is_empty():
		_open_offline()


# ---------------------------------------------------------------- construction

## Pastille d'information (fond sombre arrondi) ; renvoie son étiquette.
func _chip(pos: Vector2, col: Color) -> Label:
	var p := PanelContainer.new()
	p.position = pos
	p.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.06, 0.14, 0.82), UI.LINE, 24, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 3000
	add_child(p)
	var l := UI.label(p, "", 24, col)
	return l


func _build_top() -> void:
	_credits_label = _chip(Vector2(12, 12), UI.GOLD)
	_shards_label = _chip(Vector2(190, 12), Color(0.55, 0.9, 1.0))
	var sb := UI.button(self, "⚙", 28, "ghost")
	sb.z_index = 3000
	sb.position = Vector2(652, 10)
	sb.custom_minimum_size = Vector2(58, 58)
	sb.size = Vector2(58, 58)
	sb.pressed.connect(_open_settings)
	# l'étage en cours ouvre la carte
	_stage_btn = UI.button(self, "", 26, "ghost")
	_stage_btn.z_index = 3000
	_stage_btn.position = Vector2(210, 74)
	_stage_btn.size = Vector2(300, 74)
	_stage_btn.pressed.connect(_open_map)
	_combo_label = UI.label(self, "", 24, UI.GOLD)
	_combo_label.z_index = 3000
	_combo_label.position = Vector2(210, 152)
	_combo_label.size = Vector2(300, 32)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_auto_btn = UI.button(self, "", 20)
	_auto_btn.z_index = 3000
	_auto_btn.position = Vector2(642, 250)
	_auto_btn.size = Vector2(66, 66)
	_auto_btn.pressed.connect(func():
		Game.auto_cast = not Game.auto_cast
		battle.sim.auto_cast = Game.auto_cast
		_refresh())
	_speed_btn = UI.button(self, "", 24)
	_speed_btn.z_index = 3000
	_speed_btn.position = Vector2(642, 326)
	_speed_btn.size = Vector2(66, 66)
	_speed_btn.pressed.connect(func():
		Game.speed = 1.0 if Game.speed >= 3.0 else Game.speed + 1.0
		battle.speed = Game.speed
		_refresh())


func _build_skills() -> void:
	var band := ColorRect.new()
	band.color = Color(0.02, 0.04, 0.09, 0.9)
	band.position = Vector2(0, 560)
	band.size = Vector2(720, 104)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_skill_row = HBoxContainer.new()
	_skill_row.position = Vector2(12, 564)
	_skill_row.size = Vector2(696, 96)
	_skill_row.add_theme_constant_override("separation", 4)
	add_child(_skill_row)
	for i in Data.SQUAD_SIZE:
		var b := SkillButton.new()
		b.slot = i
		b.hero = Data.HEROES[Game.squad[i]]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(slot: int):
			if battle.sim != null and battle.sim.cast(slot):
				_manual_cast = true)
		_skill_row.add_child(b)
		skill_buttons.append(b)


func _build_squad() -> void:
	_squad_head = UI.label(self, "Escouade", 28, Color.WHITE)
	_syn_label = UI.label(self, "", 20, UI.GREEN)
	_syn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_syn_label.clip_text = true
	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 14)
	add_child(_cards_row)
	for slot in Data.SQUAD_SIZE:
		var c := SquadCard.new()
		c.slot = slot
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.pressed.connect(func(sl: int):
			_sel = sl
			Sfx.play("click", -8.0)
			_refresh())
		_cards_row.add_child(c)
		cards.append(c)
	# une seule action d'achat : le héros choisi, ou le meilleur achat
	_up_panel = PanelContainer.new()
	_up_panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 16, 12))
	add_child(_up_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	_up_panel.add_child(hb)
	_up_icon = HeroIcon.new()
	_up_icon.custom_minimum_size = Vector2(76, 76)
	hb.add_child(_up_icon)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	_up_name = UI.label(vb, "", 26, Color.WHITE)
	_up_info = UI.label(vb, "", 20, UI.MUTED)
	_up_btn = UI.button(hb, "", 26)
	_up_btn.custom_minimum_size = Vector2(210, 76)
	_up_btn.pressed.connect(func():
		var id: String = Game.squad[_up_slot]
		if Game.can_evolve(id):
			_open_evolve(id)
		elif Game.level_up(id):
			Sfx.play("coin", -4.0)
		_refresh())


func _build_nav() -> void:
	_nav = NavBar.new()
	_nav.z_index = 4095
	add_child(_nav)
	_nav.tab_pressed.connect(_on_tab)


## Les zones du bas sont accrochées au bas de l'écran, y compris sur les téléphones plus allongés.
func _layout() -> void:
	var h := size.y if size.y > 0.0 else 1280.0
	_nav.position = Vector2(0, h - NavBar.HEIGHT)
	_nav.size = Vector2(720, NavBar.HEIGHT)
	# le bloc escouade (titre, cartes, achat) est centré entre le bas du terrain et la barre du bas
	var top := 676.0 + 40.0
	var block := 42.0 + 190.0 + 14.0 + 94.0
	var y_head := top + maxf(0.0, (_nav.position.y - top - block - 12.0) * 0.5)
	var y_cards := y_head + 42.0
	var y_up := y_cards + 190.0 + 14.0
	_up_panel.position = Vector2(12, y_up)
	_up_panel.size = Vector2(696, 94)
	_cards_row.position = Vector2(12, y_cards)
	_cards_row.size = Vector2(696, 190)
	_squad_head.position = Vector2(16, y_cards - 42)
	_syn_label.position = Vector2(250, y_cards - 38)
	_syn_label.size = Vector2(454, 30)


func _on_tab(i: int) -> void:
	if i == 0:
		if _modal != null and is_instance_valid(_modal) and _tab_modal:
			(_modal as Overlay).close()
		return
	match i:
		1:
			_open_collection()
		2:
			_open_recruit()
		3:
			_open_shop()


func _build_toast() -> void:
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_color", UI.GOLD)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.position = Vector2(30, 440)
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
	_hint.position = Vector2(30, 476)
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


func _build_buffs() -> void:
	_buffs = UI.label(self, "", 19, UI.GOLD)
	_buffs.position = Vector2(16, 676)
	_buffs.size = Vector2(688, 60)
	_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buffs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_buffs.add_theme_constant_override("outline_size", 6)
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buffs.z_index = 3000


func _show_toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = secs


# ---------------------------------------------------------------- fenêtres

## Ouvre une fenêtre. `tab` (1 à 3) : écran de la barre du bas, qui reste visible et permet de changer d'écran.
func _open_modal(ov: Control, tab: int = -1) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = ov
	_tab_modal = tab > 0
	if _tab_modal:
		(ov as Overlay).reserve_bottom(NavBar.HEIGHT + 8.0)
		_nav.active = tab
	_nav.visible = _tab_modal
	add_child(ov)
	# la barre doit rester au-dessus de la fenêtre pour recevoir les appuis (le z_index ne suffit pas pour les clics)
	move_child(_nav, get_child_count() - 1)
	var tr := get_tree()
	tr.paused = true
	ov.tree_exited.connect(func():
		if _modal == ov:
			_modal = null
			_tab_modal = false
			_nav.active = 0
			_nav.visible = true
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


func _open_evolve(id: String) -> void:
	var e := EvolveScreen.new(id)
	e.evolved.connect(func():
		_start_battle())
	_open_modal(e)


func _open_collection() -> void:
	var c := CollectionScreen.new()
	c.squad_changed.connect(_start_battle)
	_open_modal(c, 1)


func _open_recruit() -> void:
	_open_modal(RecruitScreen.new(), 2)


func _open_shop() -> void:
	var sh := ShopScreen.new()
	sh.bought.connect(_show_toast.bind(3.0))
	_open_modal(sh, 3)


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
			skill_buttons[u.slot].hero = Data.HEROES[u.id]
			if _tuto < 2 and u.slot == 0:
				u.skill_cd = 0.5        # pendant le tutoriel, le premier pouvoir est prêt tout de suite
	_refresh()


func _on_cleared(_credits: float) -> void:
	var stage := Game.stage
	var stars: int = battle.sim.stars
	var frontier := Game.is_frontier()
	var shows_chest := frontier or Data.is_boss_stage(stage)
	var chest: Dictionary = Game.stage_cleared(stars, battle.sim.max_combo, shows_chest)
	Game.save_game()
	if _tuto == 3:
		_tuto = 4
		Game.tutorial_done = true
	if shows_chest:
		var next_label := "Monter à l'étage %d" % (stage + 1) if Game.best_stage > stage else "Rejouer l'étage %d" % stage
		var r := ResultScreen.new(stage, stars, chest, next_label)
		# après un étage de progression, on choisit un renfort avant de repartir
		r.next_pressed.connect(func():
			_pick_boost(func():
				if Game.best_stage > stage:
					Game.advance()
				_start_battle()))
		r.replay_pressed.connect(func(): _pick_boost(_start_battle))
		r.map_pressed.connect(func():
			_pick_boost(func():
				_start_battle()
				_open_map.call_deferred()))
		_open_modal(r)
	else:
		_show_toast("Étage %d vaincu · coffre %s : +%s" % [stage, String(Data.RARITY_NAMES[chest.rarity]).to_lower(), Data.fmt(chest.credits)], 1.8)
		Sfx.play("coin", -6.0)
		_start_battle()


## Propose trois renforts puis continue ; `then` est appelé après le choix.
func _pick_boost(then: Callable) -> void:
	var next_boss := Game.stage + 1
	while not Data.is_boss_stage(next_boss):
		next_boss += 1
	var offer: Array = Game.offer_boosts()
	# la fenêtre de résultat se ferme juste après ce signal : on ouvre le choix à l'image suivante
	var open := func():
		var bs := BoostScreen.new(offer, next_boss)
		bs.picked.connect(func(id: String):
			Game.add_boost(id)
			Game.save_game()
			then.call())
		_open_modal(bs)
	open.call_deferred()


func _on_failed() -> void:
	Game.defeated()
	Game.save_game()
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
				target = Rect2(12, 564, 696, 96)
			if _manual_cast:
				_tuto = 2
		2:
			var cheapest := 1.0e18
			for id in Game.squad_ids():
				cheapest = minf(cheapest, float(Game.level_cost(id)))
			if Game.credits >= cheapest:
				text = "Tu as assez de crédits : améliore un héros pour devenir plus fort."
				target = Rect2(_up_panel.position, _up_panel.size)
			var total := 0
			for id in Game.squad_ids():
				total += int(Game.levels[id])
			if total > Game.squad_ids().size():
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
			tag = "Mini-boss"
		"big":
			tag = "Gros boss"
	if not Game.is_frontier() and tag == "":
		tag = "Farm"
	_stage_btn.text = "Étage %d  ▾%s\n%s" % [Game.stage, "  ●" if Game.free_chest_ready() else "", tag if tag != "" else "Vague %d / %d" % [mini(battle.sim.wave, battle.sim.waves_total), battle.sim.waves_total]]
	_credits_label.text = "¢ %s" % Data.fmt(Game.credits)
	_shards_label.text = "◆ %s" % Data.fmt(float(Game.shards))
	_combo_label.text = "Combo ×%d" % battle.sim.combo if battle.sim.combo > 1 else ""
	_auto_btn.text = "AUTO" if Game.auto_cast else "Auto\nOff"
	_auto_btn.modulate = Color.WHITE if Game.auto_cast else Color(0.7, 0.7, 0.78)
	_speed_btn.text = "×%d" % int(Game.speed)
	var parts: Array = []
	if Game.perseverance > 0:
		parts.append("Persévérance + %d %%" % Game.perseverance_pct())
	if not Game.boosts.is_empty():
		var names: Array = []
		for b in Game.boosts:
			names.append(Data.BOOSTS[b].name)
		parts.append("Renforts : " + ", ".join(names))
	_buffs.text = "\n".join(parts)
	var syn: Array = Game.synergy().list
	var syn_txt: Array = []
	for e in syn.slice(0, 2):
		syn_txt.append(String(e.name))
	_syn_label.text = " · ".join(syn_txt) + (" +%d" % (syn.size() - 2) if syn.size() > 2 else "")
	# achat : héros choisi, sinon le meilleur achat
	var best := Game.best_buy()
	var up_id := ""
	if _sel >= 0 and _sel < Data.SQUAD_SIZE and Game.squad[_sel] != "":
		up_id = Game.squad[_sel]
		_up_slot = _sel
	else:
		up_id = best
		if up_id == "":
			# rien d'abordable : on montre le héros le moins cher à améliorer
			var cheapest := 1.0e18
			for id in Game.squad_ids():
				var c: float = float(Game.level_cost(id))
				if c < cheapest:
					cheapest = c
					up_id = id
		_up_slot = Game.squad.find(up_id)
	var affordable := 0
	for slot in Data.SQUAD_SIZE:
		var id: String = Game.squad[slot]
		var c: SquadCard = cards[slot]
		c.visible = id != ""
		if id == "":
			continue
		var can := Game.credits >= Game.level_cost(id) and not Game.can_evolve(id)
		if can:
			affordable += 1
		c.hero = Data.HEROES[id]
		c.level = int(Game.levels[id])
		c.stars = int(Game.hero_stars[id])
		c.affordable = can or (Game.can_evolve(id) and Game.can_afford_evolve(id))
		c.selected = slot == _up_slot
	_nav.badges = [0, affordable, Game.tokens / Data.RECRUIT_COST, 0]
	if up_id == "":
		_up_panel.visible = false
		return
	_up_panel.visible = true
	var h: Dictionary = Data.HEROES[up_id]
	var lv: int = Game.levels[up_id]
	var base: float = Data.star_mult(Game.hero_stars[up_id]) * Data.EVO_STAT_MULT[Game.tier(up_id)]
	var m0: float = Data.hero_mult(lv) * base
	var m1: float = Data.hero_mult(lv + 1) * base
	_up_icon.hero = h
	_up_name.text = "%s%s · Nv %d → %d" % [h.name, ["", " II", " III"][Game.tier(up_id)], lv, lv + 1]
	_up_name.add_theme_color_override("font_color", Data.RARITY_COLORS[h.rarity])
	_up_info.text = "PV +%d · ATQ +%d" % [h.hp * (m1 - m0), h.atk * (m1 - m0)]
	var cost := Game.level_cost(up_id)
	if Game.can_evolve(up_id):
		var ec: Dictionary = Game.evolve_cost(up_id)
		_up_name.text = "%s · palier d'évolution" % h.name
		_up_info.text = "%s ¢ · %d ◆" % [Data.fmt(ec.credits), int(ec.shards)]
		_up_btn.text = "Évoluer"
		_up_btn.disabled = false
		_up_btn.modulate = Color(1.0, 0.85, 0.35) if Game.can_afford_evolve(up_id) else Color(0.8, 0.8, 0.85)
	else:
		_up_btn.text = "¢ %s" % Data.fmt(cost)
		_up_btn.disabled = Game.credits < cost
		_up_btn.modulate = Color(1.0, 0.92, 0.55) if up_id == best and Game.credits >= cost else Color.WHITE
