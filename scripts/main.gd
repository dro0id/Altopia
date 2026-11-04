extends Control
## Écran principal : champ de bataille animé, pouvoirs, liste des héros, et les fenêtres (carte, résultat, réglages, hors ligne, entrée, défaite).

const Data = preload("res://scripts/data.gd")

var battle: BattleView
var skill_buttons: Array = []
var _credits_chip: HudButton
var _shards_chip: HudButton
var _stage_btn: HudButton
var _top: Control
var _info: Label
var _strip: Control
var _controls: Control
var _auto_b: Button
var _fab_cast: Button
var _fab_speed: Button
var _field: Control
var _boss_bar: BossBar
var _warn: HudButton
var _boss := ""
var _fh := 600.0
var _item_toast: Control
var _nav: NavBar
var _quit: QuitDialog
var _dy := 0.0
var _settings_btn: Button
var _tab_modal := false
var _skill_row: HBoxContainer
var _sel := -1                      # carte choisie ; -1 = le meilleur achat
var _toast: Label
var _toast_t := 0.0
var _claimed := 0.0
var _refresh_t := 0.0
var _modal: Control
var _buffs: Label
# tutoriel
var _hint: PanelContainer
var _hint_label: Label
var _hint_step: Label
var _hint_title: Label
var _toast_box: PanelContainer
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
	# le terrain occupe 600 px de haut comme dans la maquette (le combat est dessiné en 720 × 560 puis agrandi)
	_field = Control.new()
	_field.position = Vector2.ZERO
	_field.size = Vector2(720, 600)
	_field.clip_contents = true
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	battle.scale = Vector2.ONE * (600.0 / 560.0)
	battle.position = Vector2(-(720.0 * 600.0 / 560.0 - 720.0) * 0.5, 0.0)
	_field.add_child(battle)
	var shade := TextureRect.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(UI.BG, 0.9), Color(UI.BG, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	shade.texture = gt
	shade.size = Vector2(720, 130)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(shade)
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

func _build_top() -> void:
	# barre du haut (maquette BB) : étage (ouvre la carte), crédits, éclats, réglages
	_top = Control.new()
	_top.size = Vector2(720, 112)
	_top.z_index = 3000
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.draw.connect(func(): _top.draw_rect(Rect2(0, -_dy, 720, 112 + _dy), UI.BG))
	add_child(_top)
	_stage_btn = HudButton.new()
	_stage_btn.font_size = 28
	_stage_btn.bold = true
	_stage_btn.radius = 40.0
	_stage_btn.fill = M3.S3
	_stage_btn.border = M3.S3
	_stage_btn.position = Vector2(24, 16)
	_stage_btn.pressed.connect(_open_map)
	_top.add_child(_stage_btn)
	_credits_chip = M3.cur_chip("coin", "0")
	_top.add_child(_credits_chip)
	_shards_chip = M3.cur_chip("shard", "0")
	_top.add_child(_shards_chip)
	_settings_btn = M3.icon_button(_top, "⚙", 34)
	_settings_btn.add_theme_color_override("font_color", UI.MUTED)
	_settings_btn.position = Vector2(624, 8)
	_settings_btn.pressed.connect(_open_settings)
	# barre du boss et avertissement, posés en haut du terrain
	_boss_bar = BossBar.new()
	_boss_bar.size = Vector2(656, 72)
	_boss_bar.z_index = 3000
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.visible = false
	add_child(_boss_bar)
	_info = Label.new()
	_info.add_theme_font_override("font", UI.bold_font())
	_info.add_theme_font_size_override("font_size", M3.fs(24))
	_info.add_theme_color_override("font_color", UI.TEXT)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_info.add_theme_constant_override("outline_size", 6)
	_info.z_index = 3000
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_info)
	_warn = HudButton.new()
	_warn.fill = Color("3a1620ee")
	_warn.border = UI.RED
	_warn.text_color = Color("ff9b9b")
	_warn.bold = true
	_warn.font_size = 28
	_warn.radius = 32.0
	_warn.tappable = false
	_warn.z_index = 3000
	_warn.visible = false
	add_child(_warn)


func _build_skills() -> void:
	# bande des portraits (maquette BB) : un portrait par héros ; le toucher lance son pouvoir
	_strip = Control.new()
	_strip.size = Vector2(720, 148)
	_strip.draw.connect(func(): _strip.draw_rect(Rect2(Vector2.ZERO, _strip.size), UI.BG))
	add_child(_strip)
	_skill_row = HBoxContainer.new()
	_skill_row.position = Vector2(24, 4)
	_skill_row.size = Vector2(672, 136)
	_skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skill_row.add_theme_constant_override("separation", 16)
	_strip.add_child(_skill_row)
	for i in Data.SQUAD_SIZE:
		var b := SkillButton.new()
		b.slot = i
		b.hero = Data.HEROES[Game.squad[i]] if Game.squad[i] != "" else {}
		b.pressed.connect(func(slot: int):
			if battle.sim != null and battle.sim.cast(slot):
				_manual_cast = true)
		_skill_row.add_child(b)
		skill_buttons.append(b)


func _build_squad() -> void:
	# rangée d'actions : Auto (bouton tonal) et deux boutons flottants (pouvoirs prêts, vitesse)
	_controls = Control.new()
	_controls.size = Vector2(720, 128)
	_controls.draw.connect(func(): _controls.draw_rect(Rect2(Vector2.ZERO, _controls.size), UI.BG))
	add_child(_controls)
	_auto_b = M3.button(_controls, "", Rect2(32, 8, 400, 96), "ghost", 30)
	_auto_b.pressed.connect(func():
		Game.auto_cast = not Game.auto_cast
		battle.sim.auto_cast = Game.auto_cast
		Game.save_game()
		_refresh())
	_fab_cast = _fab(_controls, "✦", Rect2(448, 0, 112, 112))
	_fab_cast.pressed.connect(func():
		var n := 0
		if battle.sim != null:
			for u in battle.sim.units:
				if u.side == 0 and u.alive and battle.sim.cast(u.slot):
					n += 1
		if n > 0:
			_manual_cast = true
		else:
			Sfx.play("click", -10.0))
	_fab_speed = _fab(_controls, "⚡", Rect2(576, 0, 112, 112))
	_fab_speed.pressed.connect(func():
		Game.speed = 1.0 if Game.speed >= 3.0 else Game.speed + 1.0
		battle.speed = Game.speed
		Game.save_game()
		_refresh())


## Bouton flottant carré arrondi (56 dp, rayon 16 dp) avec un glyphe dessiné.
func _fab(parent: Control, glyph: String, r: Rect2) -> Button:
	var b := M3.button(parent, "", r, "main", 30)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(st).duplicate()
		sb.set_corner_radius_all(32)
		b.add_theme_stylebox_override(st, sb)
	var g := Control.new()
	g.size = r.size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.draw.connect(func():
		var c := r.size * 0.5
		if glyph == "✦":
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -24), c + Vector2(6, -6), c + Vector2(24, 0), c + Vector2(6, 6), c + Vector2(0, 24), c + Vector2(-6, 6), c + Vector2(-24, 0), c + Vector2(-6, -6)]), UI.DARK)
		else:
			g.draw_colored_polygon(PackedVector2Array([c + Vector2(6, -26), c + Vector2(-14, 4), c + Vector2(0, 4), c + Vector2(-6, 26), c + Vector2(14, -4), c + Vector2(0, -4)]), UI.DARK))
	b.add_child(g)
	return b


## Héros qui gagnerait le plus à être rééquipé : {hero, gain, count}.
func _equip_suggestion() -> Dictionary:
	var best := {"hero": "", "gain": 0.0, "count": 0}
	for hid in Game.squad_ids():
		var total := 0.0
		var cnt := 0
		for slot in Items.SLOTS:
			if not Game.slot_unlocked(hid, slot):
				continue
			var top := 0.0
			for it in Game.inventory_items():
				if it.slot == slot and (it.bound == "" or it.bound == hid):
					var g := Game.power_gain(it, hid)
					if g > 0.0:
						cnt += 1
						top = maxf(top, g)
			total += top
		if total > float(best.gain):
			best = {"hero": hid, "gain": total, "count": cnt}
	return best


## Bouton ou geste Retour d'Android : ferme la fenêtre ouverte ; sur le combat, demande avant de quitter.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _quit != null and is_instance_valid(_quit):
		_quit.close()
		return
	if _modal != null and is_instance_valid(_modal):
		var m := _modal
		if m is ResultScreen or m is BoostScreen or m is DefeatScreen or m is OfflineScreen:
			return                    # choix obligatoire : le geste Retour ne fait rien
		(m as Overlay).close()
		return
	if get_node_or_null("IntroScreen") != null or not Game.intro_seen:
		return
	_quit = QuitDialog.new()
	_quit.quit_pressed.connect(func():
		Game.save_game()
		get_tree().quit())
	_quit.closed.connect(func(): get_tree().paused = false)
	add_child(_quit)
	get_tree().paused = true


func _build_nav() -> void:
	_nav = NavBar.new()
	_nav.z_index = 4095
	add_child(_nav)
	_nav.tab_pressed.connect(_on_tab)


## La barre est accrochée au bas de l'écran ; le reste suit la maquette depuis le haut (terrain de 600 px, 660 px contre un boss).
func _layout() -> void:
	var h := size.y if size.y > 0.0 else 1280.0
	var ins := UI.safe_insets(get_window())
	_dy = ins.x
	NavBar.inset_bottom = ins.y
	_nav.position = Vector2(0, h - NavBar.total())
	_nav.size = Vector2(720, NavBar.total())
	_top.position = Vector2(0, _dy)
	_top.queue_redraw()
	# bas : rangée d'actions puis bande des portraits, posées au-dessus de la barre de navigation
	_controls.position = Vector2(0, h - NavBar.total() - 128.0)
	_strip.position = Vector2(0, _controls.position.y - 148.0)
	_boss = Data.boss_type(Game.stage)
	var top := 112.0 + _dy
	_fh = _strip.position.y - top
	var k := minf(_fh / 560.0, 1.25)
	_field.position = Vector2(0, top)
	_field.size = Vector2(720, _fh)
	battle.scale = Vector2.ONE * k
	battle.position = Vector2(-(720.0 * k - 720.0) * 0.5, _fh - 560.0 * k)
	battle._base = battle.position
	_boss_bar.position = Vector2(32, top + 16)
	_boss_bar.visible = _boss != ""
	_info.position = Vector2(32, top + (96.0 if _boss != "" else 16.0))
	_buffs.position = Vector2(32, _strip.position.y - 64.0)
	_toast_box.position = Vector2(32, _strip.position.y - 120.0)
	_hint.position = Vector2(32, _strip.position.y - 24.0 - 340.0)


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
	# message bref (maquette BK) : bandeau clair en bas du terrain
	_toast_box = PanelContainer.new()
	_toast_box.add_theme_stylebox_override("panel", UI.box(UI.TEXT, Color(0, 0, 0, 0), 16, 24))
	_toast_box.size = Vector2(656, 96)
	_toast_box.custom_minimum_size = Vector2(656, 96)
	_toast_box.z_index = 3000
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.modulate.a = 0.0
	add_child(_toast_box)
	_toast = UI.label(_toast_box, "", M3.fs(26), UI.BG)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## Carte du tutoriel (maquette BQ) : étape, titre, texte, Passer et Suivant ; un cadre pulse autour de l'élément à utiliser.
func _build_hint() -> void:
	_hl = Control.new()
	_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hl.draw.connect(func():
		if _hl.has_meta("rect"):
			var r: Rect2 = _hl.get_meta("rect")
			var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
			_hl.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.ACCENT, 0.5 + 0.5 * k), 32, 0), r.grow(6.0 + 3.0 * k)))
	_hl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hl.z_index = 3000
	add_child(_hl)
	_hint = PanelContainer.new()
	_hint.size = Vector2(656, 300)
	_hint.custom_minimum_size = Vector2(656, 0)
	_hint.add_theme_stylebox_override("panel", UI.box(M3.SHEET, UI.ACCENT, 48, 32))
	_hint.mouse_filter = Control.MOUSE_FILTER_STOP
	_hint.visible = false
	_hint.z_index = 3000
	add_child(_hint)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_hint.add_child(v)
	_hint_step = UI.label(v, "", M3.fs(24), UI.ACCENT, true)
	_hint_title = UI.label(v, "", M3.fs(36), UI.TEXT, true)
	_hint_label = UI.label(v, "", M3.fs(28), UI.MUTED)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var skip := UI.button(row, "Passer", M3.fs(30), "text")
	skip.custom_minimum_size = Vector2(160, 96)
	skip.pressed.connect(func():
		_tuto = 4
		Game.tutorial_done = true
		Game.save_game())
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var nxt := UI.button(row, "Suivant", M3.fs(30), "main")
	nxt.custom_minimum_size = Vector2(240, 96)
	nxt.pressed.connect(func():
		_tuto = mini(_tuto + 1, 4)
		if _tuto == 4:
			Game.tutorial_done = true
			Game.save_game()
		_tuto_t = 0.0)


func _build_buffs() -> void:
	_buffs = UI.label(self, "", M3.fs(22), UI.GOLD)
	_buffs.size = Vector2(656, 60)
	_buffs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_buffs.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_buffs.add_theme_constant_override("outline_size", 6)
	_buffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buffs.z_index = 3000


func _show_toast(text: String, secs: float = 2.5) -> void:
	_toast.text = text
	_toast_box.modulate.a = 1.0
	_toast_t = secs


# ---------------------------------------------------------------- fenêtres

## Ouvre une fenêtre. `tab` (1 à 3) : écran de la barre du bas, qui reste visible et permet de changer d'écran.
func _open_modal(ov: Control, tab: int = -1) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = ov
	_tab_modal = tab > 0
	if _tab_modal:
		(ov as Overlay).reserve_bottom(NavBar.total())
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
	s.tutorial_requested.connect(func():
		_tuto = 0)
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


func _open_collection(tab: int = 0) -> void:
	var c := CollectionScreen.new()
	c.squad_changed.connect(_start_battle)
	c.hero_requested.connect(func(id: String):
		var hs := HeroScreen.new(id)
		hs.changed.connect(_start_battle)
		hs.evolve_requested.connect(func(eid: String):
			hs.close()
			_open_evolve.call_deferred(eid))
		hs.item_slot_requested.connect(func(slot: String):
			_open_pick(id, slot))
		# fiche en plein écran ; en la quittant on revient à la collection
		hs.closed.connect(func(): _open_collection.call_deferred())
		_open_modal(hs))
	c.item_requested.connect(func(iid: int): _open_item(iid))
	c.forge_requested.connect(_open_forge)
	_open_modal(c, 1)
	if tab > 0:
		c.show_tab(tab)


## Détail d'un objet (plein écran) ; en le quittant on revient à l'onglet Objets.
func _open_item(iid: int) -> void:
	var d := ItemDetailScreen.new(iid)
	d.changed.connect(_start_battle)
	d.who_requested.connect(func(id: int): _open_who(id, "À qui l'équiper ?"))
	d.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(d)


func _open_who(iid: int, title: String, back_to_items := true) -> void:
	var w := ItemWhoScreen.new(iid, title)
	w.changed.connect(_start_battle)
	if back_to_items:
		w.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(w)


func _open_pick(hero_id: String, slot: String) -> void:
	var p := ItemPickScreen.new(hero_id, slot)
	p.changed.connect(_start_battle)
	p.closed.connect(func():
		var hs := HeroScreen.new(hero_id, 1)
		hs.changed.connect(_start_battle)
		hs.item_slot_requested.connect(func(sl: String): _open_pick(hero_id, sl))
		hs.closed.connect(func(): _open_collection.call_deferred())
		_open_modal.call_deferred(hs))
	_open_modal(p)


func _open_forge() -> void:
	var f := ForgeScreen.new()
	f.changed.connect(_start_battle)
	f.closed.connect(func(): _open_collection.call_deferred(1))
	_open_modal(f)


func _open_recruit() -> void:
	var rs := RecruitScreen.new()
	rs.inventory_requested.connect(func(): _open_collection.call_deferred(1))
	rs.equipped.connect(_start_battle)
	rs.fullscreen.connect(func(on: bool): _nav.visible = not on)
	_open_modal(rs, 2)


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

## Alerte « Objet trouvé » (planche du combat équipé) : l'objet, et un bouton pour l'équiper sur le héros qui en profite le plus.
func _show_item_toast(drop: Dictionary) -> void:
	if _item_toast != null and is_instance_valid(_item_toast):
		_item_toast.queue_free()
	var it: Dictionary = drop.item
	var col := ItemUI.color(it.rarity)
	var best: Dictionary = Game.best_hero_for(it) if drop.status == "added" else {"hero": "", "gain": 0.0}
	var can: bool = best.hero != "" and float(best.gain) > 0.0
	var c := Control.new()
	c.position = Vector2(24, _field.position.y + (104.0 if _boss != "" else 56.0))
	c.size = Vector2(672, 104)
	c.z_index = 3000
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var age := [0.0]
	c.draw.connect(func():
		c.draw_style_box(UI.box(Color(M3.SHEET, 0.96), col, 32, 0), Rect2(Vector2.ZERO, c.size))
		ItemUI.tile(c, Rect2(16, 16, 72, 72), it, false)
		var title := "Objet %s trouvé" % String(Data.RARITY_NAMES[it.rarity]).to_lower()
		var sub: String = Items.summary(it)
		if drop.status == "recycled":
			title = "Objet commun recyclé"
			sub = "+%d éclat · le recyclage automatique est activé" % int(Items.RECYCLE_SHARDS[it.rarity])
		elif drop.status == "stash":
			title = "Inventaire plein"
			sub = "L'objet attend de côté : fais de la place"
		c.draw_string(UI.bold_font(), Vector2(108, 46), title, HORIZONTAL_ALIGNMENT_LEFT, 360.0, 24, col)
		c.draw_string(ThemeDB.fallback_font, Vector2(108, 78), "%s · %s" % [it.name, sub] if drop.status == "added" else sub, HORIZONTAL_ALIGNMENT_LEFT, 380.0, 20, UI.MUTED)
		if can:
			c.draw_style_box(UI.box(Color(UI.GREEN, 0.08), Color(UI.GREEN, 0.4), 24, 0), Rect2(498, 26, 150, 52))
			c.draw_string(UI.bold_font(), Vector2(498, 62), "Équiper", HORIZONTAL_ALIGNMENT_CENTER, 130.0, 22, UI.GREEN)
			c.draw_colored_polygon(PackedVector2Array([Vector2(620, 60), Vector2(636, 60), Vector2(628, 44)]), UI.GREEN))
	c.gui_input.connect(func(ev: InputEvent):
		if ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)) and can:
			if Game.equip(int(it.id), best.hero) == "":
				Game.save_game()
				Sfx.play("chest", -4.0)
				_start_battle()
				_show_toast("%s équipé sur %s" % [it.name, String(Data.HEROES[best.hero].name).split(" ")[0]], 2.4)
				c.queue_free())
	add_child(c)
	_item_toast = c
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())


func _start_battle() -> void:
	_layout()
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
		var r := ResultScreen.new(stage, stars, chest, next_label, battle.sim.max_combo)
		var go_next := func():
			_pick_boost(func():
				if Game.best_stage > stage:
					Game.advance()
				_start_battle())
		r.who_requested.connect(func(iid: int):
			var w := ItemWhoScreen.new(iid, "Nouvel objet")
			w.changed.connect(_start_battle)
			w.closed.connect(go_next)
			_open_modal(w))
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
		if not Game.last_drop.is_empty():
			_show_item_toast(Game.last_drop)
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
		_start_battle()
		_open_collection.call_deferred(0))
	d.recruit_pressed.connect(func():
		Game.retreat()
		_start_battle()
		_open_recruit.call_deferred())
	_open_modal(d)


# ---------------------------------------------------------------- boucle

func _process(delta: float) -> void:
	if battle.sim != null:
		var diff := battle.sim.credits - _claimed
		if diff > 0.0:
			Game.credits += diff * (Data.BOOST_MULT if Game.boost_active() else 1.0)
			_claimed = battle.sim.credits
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast_box.modulate.a = 0.0 if _toast_t <= 0.0 else minf(1.0, _toast_t * 2.0)
	_tuto_update(delta)
	_refresh_t += delta
	if _refresh_t > 0.15:
		_refresh_t = 0.0
		_refresh()


func _tuto_update(delta: float) -> void:
	var title := ""
	var text := ""
	var target := Rect2()
	_tuto_t += delta
	match _tuto:
		0:
			title = "Regarde ton équipe"
			text = "Tes héros combattent tout seuls, même quand tu n'es pas là."
		1:
			title = "Lance un pouvoir"
			text = "Touche un portrait quand son anneau est plein. Deux pouvoirs rapprochés forment un combo."
			target = Rect2(_strip.position + Vector2(24, 4), Vector2(672, 136))
			if _manual_cast:
				_tuto = 2
		2:
			title = "Améliore un héros"
			text = "Ouvre Héros, choisis un héros et monte son niveau avec tes crédits."
			target = Rect2(_nav.position + Vector2(180, 8), Vector2(180, 144))
			var total := 0
			for id in Game.squad_ids():
				total += int(Game.levels[id])
			if total > Game.squad_ids().size():
				_tuto = 3
		3:
			title = "Monte les étages"
			text = "Un mini-boss t'attend à l'étage 5, un gros boss à l'étage 10."
	var show := title != "" and (_modal == null or not is_instance_valid(_modal))
	_hint.visible = show
	if show:
		_hint_step.text = "ÉTAPE %d / 4" % (_tuto + 1)
		_hint_title.text = title
		_hint_label.text = text
	if target.size != Vector2.ZERO and show:
		_hl.set_meta("rect", target)
	elif _hl.has_meta("rect"):
		_hl.remove_meta("rect")
	_hl.queue_redraw()


const BOSS_INFO := {
	"titan": {"attack": "Écrasement", "kind": "shield", "tip": "Le boss cible la ligne avant. Garde un pouvoir de soin prêt pour la phase 2."},
	"sentinelle": {"attack": "Faisceau prismatique", "kind": "gravity", "tip": "La Sentinelle tire un faisceau sur toute une ligne. Étourdis-la avec l'onde gravitationnelle."},
	"reine": {"attack": "Appel des mites", "kind": "volley", "tip": "La Reine appelle des mites. Une salve de missiles les nettoie d'un coup."},
	"foreur": {"attack": "Forage", "kind": "shield", "tip": "Le Foreur frappe un héros puis charge lentement. Garde le bouclier pour le coup."},
}
const KIND_NAMES := {"shield": "Bouclier", "gravity": "Onde", "volley": "Salve", "pierce": "Tir perforant", "repair": "Soin"}


## Contenu propre aux combats de boss : barre de vie, avertissement, conseil.
func _refresh_boss() -> void:
	if _boss == "":
		_warn.visible = false
		return
	var bu: BattleSim.Unit = null
	for u in battle.sim.units:
		if u.side == 1 and u.boss and u.alive:
			bu = u
	var big := _boss == "big"
	_boss_bar.col = UI.RED if big else Color("ffb142")
	_boss_bar.title = Data.boss_name(Game.stage)
	_boss_bar.phase = ""
	_boss_bar.frac = 0.0
	var info: Dictionary = BOSS_INFO.get(Data.boss_kind(Game.stage), BOSS_INFO.titan)
	if bu != null:
		_boss_bar.frac = bu.hp_frac()
		if big:
			_boss_bar.phase = "Phase 2" if bu.phase2 else "Phase 1"
		var warning: bool = bu.skill_cd > 0.0 and bu.skill_cd <= 2.0 and battle.sim.state == "fighting"
		_warn.visible = warning
		if warning:
			_warn.set_texts("⚠ %s dans %d s" % [info.attack, int(ceil(bu.skill_cd))])
			_warn.size = Vector2(656, 80)
			_warn.position = Vector2(32, _field.position.y + 260.0)
	else:
		_warn.visible = false
	_boss_bar.queue_redraw()


func _refresh() -> void:
	var big := _boss == "big"
	_stage_btn.set_texts(("☠ Étage %d" if big else "Étage %d ▾") % Game.stage)
	_stage_btn.text_color = Color("ff9b9b") if big else UI.TEXT
	_stage_btn.fill = Color("3a1620") if big else M3.S3
	_stage_btn.border = _stage_btn.fill
	_stage_btn.size = Vector2(M3.text_w(_stage_btn.text, 28, true) + 56.0, 80)
	_credits_chip.set_texts(UI.short(Game.credits))
	_credits_chip.fit_chip()
	_credits_chip.size.y = 64.0
	_shards_chip.set_texts(str(Game.shards))
	_shards_chip.fit_chip()
	_shards_chip.size.y = 64.0
	_shards_chip.visible = not big
	var rx := 616.0
	if _shards_chip.visible:
		_shards_chip.position = Vector2(rx - _shards_chip.size.x, 24)
		rx -= _shards_chip.size.x + 12.0
	_credits_chip.position = Vector2(rx - _credits_chip.size.x, 24)
	var sub := "Vague %d/%d" % [mini(battle.sim.wave, battle.sim.waves_total), battle.sim.waves_total]
	if battle.sim.combo > 1:
		sub += " · Combo ×%d" % battle.sim.combo
	if not Game.is_frontier() and _boss == "":
		sub = "Farm · " + sub
	_info.text = sub
	_auto_b.text = ("Auto · ×%d" if Game.auto_cast else "Manuel · ×%d") % int(Game.speed)
	_refresh_boss()
	var parts: Array = []
	if Game.perseverance > 0:
		parts.append("Persévérance + %d %%" % Game.perseverance_pct())
	if not Game.boosts.is_empty():
		var names: Array = []
		for b in Game.boosts:
			names.append(Data.BOOSTS[b].name)
		parts.append("Renforts : " + ", ".join(names))
	_buffs.text = "\n".join(parts)
	var affordable := 0
	for id in Game.squad_ids():
		if (Game.credits >= Game.level_cost(id) and not Game.can_evolve(id)) or Game.can_afford_evolve(id):
			affordable += 1
	var ready_items := 0
	for it in Game.inventory_items():
		var bh: Dictionary = Game.best_hero_for(it)
		if bh.hero != "" and float(bh.gain) > 0.0 and (it.bound == "" or it.bound == bh.hero):
			ready_items += 1
	_nav.badges = [0, affordable + (1 if ready_items > 0 else 0), Game.tokens / Data.RECRUIT_COST + Game.item_tokens / Data.ITEM_PACK_COST, 0]
