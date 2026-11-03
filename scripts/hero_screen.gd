class_name HeroScreen
extends Overlay
## Fiche héros (maquette G), plein écran : portrait, statistiques, compétence, étoiles par fragments, placement en escouade et niveau.

signal changed
signal evolve_requested(id: String)

var _id := ""
var _stage: Control
var _t := 0.0
var _picker: Control


func _init(id: String) -> void:
	super._init(720.0)
	_id = id
	panel.custom_minimum_size = Vector2(720, 1280)
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_rebuild()


func _rebuild() -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, 1280)
	box.add_child(_stage)
	var h: Dictionary = Data.HEROES[_id]
	var have := Game.is_owned(_id)
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	# retour et titre
	var back := Button.new()
	back.text = "‹"
	back.position = Vector2(32, 20)
	back.size = Vector2(96, 96)
	back.add_theme_font_size_override("font_size", 40)
	for st in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(st, UI.box(UI.LINE2, Color(0, 0, 0, 0), 24, 0))
	back.pressed.connect(close)
	_stage.add_child(back)
	var title := UI.label(_stage, "Fiche héros", 36, Color.WHITE, true)
	title.position = Vector2(152, 38)
	# carte du héros
	var lv: int = int(Game.levels[_id])
	var stars: int = int(Game.hero_stars[_id]) if have else 0
	var m: float = Data.hero_mult(lv) * Data.star_mult(maxi(1, stars)) * Data.EVO_STAT_MULT[Game.tier(_id)]
	var card := Control.new()
	card.position = Vector2(32, 136)
	card.size = Vector2(656, 416)
	card.draw.connect(func():
		UI.draw_gradient_box(card, Rect2(Vector2.ZERO, card.size), 28.0, Color("1a2142"), Color("141d3a"), rc, 3.0)
		card.draw_style_box(UI.box(Color("0d1530"), Color(rc.r, rc.g, rc.b, 0.45), 24, 0), Rect2(28, 28, 300, 358))
		var c := Vector2(178, 178)
		UI.portrait(card, h, c, 128.0, _t)
		if not have:
			card.draw_circle(c, 132.0, Color(0.04, 0.06, 0.12, 0.72))
		var lab := String(Data.RARITY_NAMES_HERO[h.rarity]).to_upper() if have else "NON RECRUTÉ"
		var col: Color = rc if have else UI.RED
		var tw := 0.0
		for ch in lab:
			tw += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		var x := 178.0 - tw * 0.5
		for ch in lab:
			card.draw_string(UI.bold_font(), Vector2(x, 360), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
			x += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		var f := ThemeDB.fallback_font
		card.draw_string(UI.bold_font(), Vector2(356, 60), String(h.name).split(" ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("e8eefc"))
		card.draw_string(f, Vector2(356, 96), "%s · %s" % [Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.MUTED)
		card.draw_string(f, Vector2(356, 142), "★".repeat(stars) + "☆".repeat(Data.MAX_STARS - stars), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UI.GOLD)
		var caps := {"hp": 0.0, "atk": 0.0, "def": 0.0}
		for hid in Data.ALL_HEROES:
			for k in caps:
				caps[k] = maxf(caps[k], float(Data.HEROES[hid][k]))
		var rows := [["PV", h.hp * m, UI.GREEN, "hp"], ["ATQ", h.atk * m, UI.RED, "atk"], ["DÉF", h.def * m, UI.ACCENT, "def"]]
		for i in 3:
			var y := 214.0 + i * 78.0
			var v: float = rows[i][1]
			var cc: Color = rows[i][2]
			card.draw_string(f, Vector2(356, y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.MUTED)
			card.draw_string(UI.bold_font(), Vector2(0, y + 4), str(int(v)), HORIZONTAL_ALIGNMENT_RIGHT, 628.0, 40, cc)
			card.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 6, 0), Rect2(356, y + 16, 272, 12))
			card.draw_style_box(UI.box(cc, Color(0, 0, 0, 0), 6, 0), Rect2(356, y + 16, maxf(12.0, 272.0 * clampf(v / (float(caps[rows[i][3]]) * m * 1.25), 0.0, 1.0)), 12)))
	_stage.add_child(card)
	# compétence
	var sk := Control.new()
	sk.position = Vector2(32, 576)
	sk.size = Vector2(656, 205)
	sk.draw.connect(func():
		sk.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, sk.size))
		sk.draw_style_box(UI.box(Color("2a2010"), UI.GOLD, 20, 0), Rect2(24, 54, 96, 96))
		SkillButton.draw_glyph(sk, int(SkillButton.LOOK.get(h.skill.kind, SkillButton.LOOK.shield).glyph), Vector2(72, 102), UI.GOLD, 0.85)
		var tw := 0.0
		for ch in "COMPÉTENCE":
			tw += 0.0
		var x := 144.0
		for ch in "COMPÉTENCE":
			sk.draw_string(UI.bold_font(), Vector2(x, 62), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.GOLD)
			x += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 3.0
		sk.draw_string(UI.bold_font(), Vector2(144, 104), h.skill.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE))
	_stage.add_child(sk)
	var dsc := UI.label(sk, "%s Recharge %d s." % [h.skill.desc, int(h.skill.cd)], 26, UI.MUTED)
	dsc.position = Vector2(144, 118)
	dsc.size = Vector2(490, 70)
	dsc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dsc.add_theme_constant_override("line_spacing", -4)
	# prochaine étoile
	var sc := Control.new()
	sc.position = Vector2(32, 806)
	sc.size = Vector2(656, 164)
	var cost := Game.star_cost(_id) if have and stars < Data.MAX_STARS else 0
	var fr := int(Game.fragments[_id]) if have else 0
	sc.draw.connect(func():
		sc.draw_style_box(UI.box(UI.PANEL, Color(0, 0, 0, 0), 28, 0), Rect2(Vector2.ZERO, sc.size))
		var f := ThemeDB.fallback_font
		sc.draw_string(UI.bold_font(), Vector2(24, 50), "Prochaine étoile" if cost > 0 else "Étoiles", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		if cost > 0:
			sc.draw_string(UI.bold_font(), Vector2(0, 50), "%d / %d" % [fr, cost], HORIZONTAL_ALIGNMENT_RIGHT, 632.0, 28, UI.GOLD)
			sc.draw_style_box(UI.box(UI.LINE2, Color(0, 0, 0, 0), 10, 0), Rect2(24, 78, 608, 20))
			var w := maxf(20.0, 608.0 * clampf(float(fr) / float(cost), 0.0, 1.0))
			UI.draw_gradient_box(sc, Rect2(24, 78, w, 20), 10.0, Color("ffb142"), Color("ffd166"), Color(0, 0, 0, 0), 0.0)
			var msg := "%d fragments avant la %dᵉ étoile" % [maxi(0, cost - fr), stars + 1]
			if fr >= cost:
				msg = "Touche ici pour monter d'une étoile"
			sc.draw_string(f, Vector2(24, 142), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UI.GOLD if fr >= cost else UI.MUTED)
		elif have:
			sc.draw_string(f, Vector2(24, 100), "Étoiles au maximum", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.GOLD)
		else:
			sc.draw_string(f, Vector2(24, 100), "Obtiens ce héros au recrutement.", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UI.MUTED))
	sc.gui_input.connect(func(ev: InputEvent):
		if ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed)) and Game.can_star_up(_id):
			if Game.star_up(_id):
				Sfx.play("chest")
				Game.save_game()
				changed.emit()
				_rebuild())
	_stage.add_child(sc)
	if not have:
		return
	# actions
	var place := UI.button(_stage, "Placer en escouade", 32, "main")
	place.position = Vector2(32, 1032)
	place.size = Vector2(656, 104)
	place.custom_minimum_size = Vector2(0, 104)
	place.pressed.connect(_open_picker)
	var up := UI.button(_stage, "", 28, "ghost")
	up.position = Vector2(32, 1152)
	up.size = Vector2(656, 96)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.add_child(row)
	var l1 := UI.label(row, "Monter le niveau ·" if not Game.can_evolve(_id) else "Évoluer ·", 28, Color("e8eefc"), true)
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UI.icon("coin")
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var cost_v: int = Game.level_cost(_id) if not Game.can_evolve(_id) else int(Game.evolve_cost(_id).credits)
	var l2 := UI.label(row, UI.num(cost_v), 28, Color("e8eefc"), true)
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	up.disabled = Game.credits < cost_v and not Game.can_evolve(_id)
	up.pressed.connect(func():
		if Game.can_evolve(_id):
			evolve_requested.emit(_id)
			return
		if Game.level_up(_id):
			Sfx.play("coin", -4.0)
			changed.emit()
			_rebuild())


func _process(delta: float) -> void:
	_t += delta
	if _stage != null:
		_stage.get_child(2).queue_redraw()


## Choix de l'emplacement dans l'escouade (3 devant, 2 derrière).
func _open_picker() -> void:
	if _picker != null:
		_picker.queue_free()
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(dim)
	var p := PanelContainer.new()
	p.position = Vector2(32, 330)
	p.size = Vector2(656, 560)
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL, UI.LINE, 28, 24))
	_picker.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	UI.label(v, "Choisir l'emplacement", 30, Color.WHITE, true)
	for i in Data.SQUAD_SIZE:
		var cur: String = Game.squad[i]
		var who := String(Data.HEROES[cur].name).split(" ")[0] if cur != "" else "vide"
		var b := UI.button(v, "%s %d · %s" % ["Avant" if i < 3 else "Arrière", i + 1 if i < 3 else i - 2, who], 26, "main" if Game.squad[i] == _id else "ghost")
		b.custom_minimum_size = Vector2(0, 72)
		var slot := i
		b.pressed.connect(func():
			if Game.set_slot(slot, _id):
				Game.save_game()
				changed.emit()
			_picker.queue_free()
			_rebuild())
	var cancel := UI.button(v, "Annuler", 24, "ghost")
	cancel.custom_minimum_size = Vector2(0, 64)
	cancel.pressed.connect(func(): _picker.queue_free())
