class_name HeroScreen
extends Overlay
## Fiche héros (maquette BD), plein écran : barre du haut, en-tête (portrait, niveau, palier), segments Stats / Équipement / Pouvoirs.

signal changed
signal evolve_requested(id: String)
signal item_slot_requested(slot: String)

const PAGES := ["Stats", "Équipement", "Pouvoirs"]

var _id := ""
var _fig: Node2D
var _stage: Control
var _t := 0.0
var _picker: Control
var _page := 0
var _head: Control
var level_button: Button        # « Monter le niveau » (le tutoriel le met en avant)


## `page` : 0 statistiques, 1 équipement, 2 pouvoirs.
func _init(id: String, page: int = 0) -> void:
	super._init(720.0)
	_id = id
	_page = page
	panel.custom_minimum_size = Vector2(720, UI.H)
	panel.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	dim.color = UI.BG
	box.add_theme_constant_override("separation", 0)
	_rebuild()


func _rebuild() -> void:
	if _stage != null:
		_stage.queue_free()
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, UI.H)
	box.add_child(_stage)
	var h: Dictionary = Data.HEROES[_id]
	var have := Game.is_owned(_id)
	set_backdrop(Data.RARITY_COLORS[h.rarity])      # fond teinté par la rareté (maquette G3)
	var acts: Array = []
	if have:
		acts.append(["⋮", func(): M3.menu(_stage, Vector2(704, 96), [["Placer en escouade", _open_picker], ["Tout retirer", func():
			Game.unequip_all(_id)
			Game.save_game()
			changed.emit()
			_rebuild()]])])
	M3.top_bar(_stage, String(h.name).split(" ")[0], close, acts)
	var n0 := _stage.get_child_count()
	# en-tête
	_head = Control.new()
	_head.position = Vector2(0, 112)
	_head.size = Vector2(720, 160)
	_head.draw.connect(_draw_head)
	_stage.add_child(_head)
	var seg := M3Seg.new(PAGES, _page)
	seg.position = Vector2(32, 280)
	seg.changed.connect(func(i: int):
		_page = i
		_rebuild())
	_stage.add_child(seg)
	match _page:
		0:
			_build_stats(h, have)
		1:
			_build_equipment(h, have)
		_:
			_build_powers(h)
	_hero_band(h, n0)


## Écran haut : une bande montre le héros en pied sous la barre du haut ; le reste de la fiche descend d'autant.
func _hero_band(h: Dictionary, n0: int) -> void:
	var hb := minf(UI.tall(), 300.0)
	if hb < 120.0:
		return
	for i in range(n0, _stage.get_child_count()):
		var ch := _stage.get_child(i)
		if ch is Control and ch.position.y < UI.H - 320.0:
			ch.position.y += hb
	var band := Control.new()
	band.position = Vector2(0, 112)
	band.size = Vector2(720, hb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = Data.RARITY_COLORS[h.rarity]
	band.draw.connect(func():
		for i in 9:
			band.draw_circle(Vector2(360, hb * 0.62), hb * 0.9 - i * hb * 0.09, Color(col, 0.022))
		var pts := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(Vector2(360, hb - 26.0) + Vector2(cos(a) * 150.0, sin(a) * 22.0))
		band.draw_colored_polygon(pts, Color(col, 0.16))
		band.draw_polyline(pts, Color(col, 0.6), 2.0))
	_stage.add_child(band)
	var fig := Node2D.new()
	fig.position = Vector2(350, 112 + hb - 30.0)
	var k := (hb - 50.0) / 150.0
	fig.scale = Vector2(k, k)
	var owned := Game.is_owned(_id)
	if not owned:
		fig.modulate = Color(0.1, 0.12, 0.2)
	fig.draw.connect(func(): Art.draw_hero(fig, h, {"t": _t}))
	_stage.add_child(fig)
	_fig = fig


func hero_id() -> String:
	return _id


## Glisser à gauche ou à droite sur le haut de la fiche : héros suivant ou précédent (maquette E6).
var _swipe0 := Vector2(-1, -1)


func _input(ev: InputEvent) -> void:
	var down: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	var up: bool = (ev is InputEventScreenTouch and not ev.pressed) or (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if not (down or up) or not is_visible_in_tree():
		return
	var p: Vector2 = get_global_transform_with_canvas().affine_inverse() * ev.position
	if down:
		var top := 112.0 + 160.0 + maxf(0.0, minf(UI.tall(), 300.0))
		_swipe0 = p if p.y > 112.0 and p.y < top and p.x > 40.0 else Vector2(-1, -1)
		return
	if _swipe0.x < 0.0:
		return
	var d := p - _swipe0
	_swipe0 = Vector2(-1, -1)
	if absf(d.x) > 140.0 and absf(d.y) < 110.0:
		var ids: Array = Data.HEROES.keys()
		var mine := ids.filter(func(x): return Game.is_owned(x))
		var lst: Array = mine if mine.has(_id) else ids
		var i := lst.find(_id)
		_id = lst[(i + (1 if d.x < 0.0 else -1) + lst.size()) % lst.size()]
		Sfx.play("click", -8.0)
		get_viewport().set_input_as_handled()
		_rebuild()


func _process(delta: float) -> void:
	_t += delta
	if _fig != null and is_instance_valid(_fig):
		_fig.queue_redraw()
	if _head != null:
		_head.queue_redraw()


func _draw_head() -> void:
	var h: Dictionary = Data.HEROES[_id]
	var have := Game.is_owned(_id)
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	M3.avatar(_head, h, Vector2(104, 80), 72.0, rc, _t)
	var stars: int = int(Game.hero_stars[_id]) if have else 0
	M3.text(_head, Vector2(208, 44), "%s · %s · %s" % [Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role], star_text(stars)], 24, UI.MUTED)
	if not have:
		M3.text(_head, Vector2(208, 92), "Non recruté", 30, UI.RED, true)
		return
	var lv: int = int(Game.levels[_id])
	var cap: int = Data.level_cap(stars)
	M3.text(_head, Vector2(208, 92), "Niveau %d / %d" % [lv, cap], 30, UI.TEXT, true)
	var lo: int = cap - Data.LEVELS_PER_STAR
	M3.bar(_head, Rect2(208, 112, 480, 12), clampf(float(lv - lo) / float(Data.LEVELS_PER_STAR), 0.0, 1.0))


## « ★★ » pour 2 étoiles ; « ★★★★★ MAX » au dernier rang.
static func star_text(rank: int) -> String:
	if rank <= 0:
		return ""
	return "★".repeat(Data.shown_stars(rank)) + (" MAX" if rank >= Data.MAX_STARS else "")


# ---------------------------------------------------------------- Stats

func _build_stats(h: Dictionary, have: bool) -> void:
	var lv: int = int(Game.levels[_id])
	var stars: int = int(Game.hero_stars[_id]) if have else 0
	var m: float = Data.hero_mult(lv) * Data.star_mult(maxi(1, stars)) * Data.EVO_STAT_MULT[Game.tier(_id)]
	var own_copies := int(Game.fragments[_id]) if have else 0
	var wild_copies: int = Game.wild if have else 0
	var eq: Dictionary = Items.totals(Game.hero_items(_id))
	var vals := [
		["PV", (h.hp * m + float(eq.hp)) * (1.0 + float(eq.hp_pct)), UI.GREEN],
		["ATQ", (h.atk * m + float(eq.atk)) * (1.0 + float(eq.atk_pct)), UI.RED],
		["DÉF", (h.def * m + float(eq.def)) * (1.0 + float(eq.def_pct)), UI.ACCENT]]
	var cost := Game.star_cost(_id) if have and stars < Data.MAX_STARS else 0
	var fr := own_copies + wild_copies
	var body := Control.new()
	body.position = Vector2(0, 384)
	body.size = Vector2(720, 600)
	body.draw.connect(func():
		for i in 3:
			var r := Rect2(32, i * 144.0, 656, 128)
			M3.row(body, r)
			M3.text(body, r.position + Vector2(32, 76), vals[i][0], 30, UI.TEXT, true)
			M3.text(body, r.position + Vector2(0, 78), UI.num(float(vals[i][1])), 36, vals[i][2], true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		var r2 := Rect2(32, 432, 656, 152)
		M3.card(body, r2)
		M3.text(body, r2.position + Vector2(32, 52), ("Vers %s" % star_text(stars + 1)) if cost > 0 else "Étoiles", 28, UI.TEXT, true, 400)
		if cost > 0:
			M3.text(body, r2.position + Vector2(0, 52), "%d / %d doublons" % [mini(fr, cost), cost], 28, UI.GOLD, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			M3.bar(body, Rect2(r2.position + Vector2(32, 76), Vector2(592, 12)), minf(1.0, float(fr) / float(cost)), UI.GOLD)
			var note := "Touche pour monter d'une étoile" if fr >= cost else "Encore %d doublon%s" % [cost - fr, "s" if cost - fr > 1 else ""]
			if wild_copies > 0 and fr < cost:
				note += " · dont %d au choix" % wild_copies
			M3.text(body, r2.position + Vector2(32, 128), note, 24, UI.GOLD if fr >= cost else UI.MUTED, false, 592)
		elif have:
			M3.text(body, r2.position + Vector2(32, 104), "Étoiles au maximum", 26, UI.GOLD)
		else:
			M3.text(body, r2.position + Vector2(32, 104), "Obtiens ce héros au recrutement.", 26, UI.MUTED))
	body.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y > 432 and have and stars < Data.MAX_STARS:
			evolve_requested.emit(_id))
	_stage.add_child(body)
	if not have:
		return
	var capped := Game.at_cap(_id)
	var cost_v: int = Game.level_cost(_id)
	var label := "Monter le niveau · %s ¢" % UI.num(cost_v)
	if capped:
		label = "Niveau maximum" if stars >= 5 else ("Monter à %s" % star_text(stars + 1))
	var up := M3.button(_stage, label, Rect2(32, UI.H - 136.0, 656, 104), "premium" if capped else "main")
	up.disabled = (not capped and Game.credits < cost_v) or (capped and stars >= 5)
	if capped and stars < 5 and not Game.can_star_up(_id):
		var miss := Game.star_cost(_id) - Game.copies_for(_id)
		up.disabled = true
		up.text = "Il manque %d doublon%s" % [miss, "s" if miss > 1 else ""]
	level_button = up
	up.pressed.connect(func():
		if capped:
			evolve_requested.emit(_id)
			return
		if Game.level_up(_id):
			Sfx.play("coin", -4.0)
			changed.emit()
			_rebuild())


# ---------------------------------------------------------------- Pouvoirs

func _build_powers(h: Dictionary) -> void:
	var body := Control.new()
	body.position = Vector2(0, 384)
	body.size = Vector2(720, 400)
	body.draw.connect(func():
		var r := Rect2(32, 0, 656, 320)
		M3.card(body, r)
		body.draw_style_box(UI.box(Color("2a2010"), UI.GOLD, 24, 0), Rect2(64, 32, 112, 112))
		SkillButton.draw_glyph(body, int(SkillButton.LOOK.get(h.skill.kind, SkillButton.LOOK.shield).glyph), Vector2(120, 88), UI.GOLD, 0.95)
		M3.section(body, Vector2(208, 64), "COMPÉTENCE")
		M3.text(body, Vector2(208, 112), String(h.skill.name), 34, UI.TEXT, true)
		M3.para(body, Vector2(64, 196), String(h.skill.desc), 26, UI.MUTED, 592)
		M3.text(body, Vector2(64, 292), "Recharge %d s · combo si deux pouvoirs à moins de 3 s" % int(h.skill.cd), 24, UI.ACCENT))
	_stage.add_child(body)


## Choix de l'emplacement dans l'escouade (feuille du bas).
func _open_picker() -> void:
	if _picker != null:
		_picker.queue_free()
	_picker = Control.new()
	_picker.size = Vector2(720, UI.H)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_picker)
	var y0 := UI.H - 800.0
	_picker.draw.connect(func():
		_picker.draw_rect(Rect2(0, 0, 720, UI.H), Color(0, 0, 0, 0.6))
		M3.sheet(_picker, Rect2(0, y0, 720, 800))
		_picker.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, y0 + 16, 64, 8))
		M3.text(_picker, Vector2(32, y0 + 88), "Choisir l'emplacement", 40, UI.TEXT, true))
	_picker.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < y0:
			_picker.queue_free())
	for i in Data.SQUAD_SIZE:
		var cur: String = Game.squad[i]
		var who := String(Data.HEROES[cur].name).split(" ")[0] if cur != "" else "vide"
		var b := M3.button(_picker, "%s %d · %s" % ["Avant" if i < 3 else "Arrière", i + 1 if i < 3 else i - 2, who], Rect2(32, y0 + 128 + i * 112.0, 656, 96), "main" if cur == _id else "ghost", 28)
		var slot := i
		b.pressed.connect(func():
			if Game.set_slot(slot, _id):
				Game.save_game()
				changed.emit()
			_picker.queue_free()
			_rebuild())


# ---------------------------------------------------------------- Équipement

func _build_equipment(_h: Dictionary, have: bool) -> void:
	var better := {}
	for it in Game.inventory_items():
		if Game.slot_unlocked(_id, it.slot) and (it.bound == "" or it.bound == _id) and Game.power_gain(it, _id) > 0.0:
			better[it.slot] = maxf(float(better.get(it.slot, 0.0)), Game.power_gain(it, _id))
	var gain := 0.0
	for s in better:
		gain += float(better[s])
	var grid := Control.new()
	grid.position = Vector2(0, 384)
	grid.size = Vector2(720, 420)
	grid.draw.connect(func():
		for i in 4:
			var slot: String = Items.SLOTS[i]
			var r := Rect2(32.0 + (i % 2) * 336.0, (i / 2) * 168.0, 320, 152)
			M3.card(grid, r)
			var tr := Rect2(r.position + Vector2(20, 20), Vector2(112, 112))
			var nm := "Vide"
			if not Game.slot_unlocked(_id, slot):
				ItemUI.locked(grid, tr)
				nm = "Niveau %d" % int(Items.SLOT_UNLOCK[slot])
			else:
				var it: Dictionary = Game.slot_item(_id, slot)
				if it.is_empty():
					ItemUI.empty(grid, tr)
				else:
					ItemUI.tile(grid, tr, it, true)
					nm = String(it.name)
				if better.has(slot):
					ItemUI.dot(grid, tr.position + Vector2(tr.size.x - 4.0, 4.0), "▲")
			M3.text(grid, r.position + Vector2(152, 66), String(Items.SLOT_NAMES[slot]), 24, UI.MUTED)
			var lines := _wrap2(nm, 22, 152.0)
			M3.text(grid, r.position + Vector2(152, 100), lines[0], 22, UI.TEXT, true)
			if lines[1] != "":
				M3.text(grid, r.position + Vector2(152, 132), lines[1], 22, UI.TEXT, true)
		if gain > 0.0:
			grid.draw_style_box(UI.box(Color("10331f"), Color(0, 0, 0, 0), 24, 0), Rect2(32, 344, 656, 72))
			M3.text(grid, Vector2(64, 390), "▲ Gain possible : +%s de puissance" % UI.num(gain), 26, UI.GREEN))
	grid.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < 320:
			var i := clampi(int((ev.position.x - 32.0) / 336.0), 0, 1) + (2 if ev.position.y > 160 else 0)
			var slot: String = Items.SLOTS[i]
			if not Game.slot_unlocked(_id, slot):
				Sfx.play("click", -10.0)
				return
			item_slot_requested.emit(slot)
			close())
	_stage.add_child(grid)
	if not have:
		return
	var hand := M3.button(_stage, "Choisir", Rect2(32, UI.H - 136.0, 248, 104), "ghost")
	hand.pressed.connect(func():
		for slot in Items.SLOTS:
			if Game.slot_unlocked(_id, slot):
				item_slot_requested.emit(slot)
				close()
				return)
	var best := M3.button(_stage, "Équiper au mieux", Rect2(296, UI.H - 136.0, 392, 104), "main")
	best.pressed.connect(func():
		var cnt: int = Game.equip_best(_id)
		Game.save_game()
		Sfx.play("chest" if cnt > 0 else "click", -4.0)
		changed.emit()
		_rebuild())


## Coupe un nom en deux lignes au plus (la seconde finit par « … » si elle déborde).
static func _wrap2(s: String, size: int, w: float) -> Array:
	var l1 := ""
	var l2 := ""
	for word in s.split(" "):
		if l2 == "" and M3.text_w((l1 + " " + word).strip_edges(), size, true) <= w:
			l1 = (l1 + " " + word).strip_edges()
		else:
			l2 = (l2 + " " + word).strip_edges()
	while l2 != "" and M3.text_w(l2, size, true) > w:
		l2 = l2.substr(0, l2.length() - 2).strip_edges() + "…"
	return [l1, l2]
