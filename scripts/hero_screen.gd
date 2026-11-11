class_name HeroScreen
extends Overlay
## Fiche héros (maquette XF), plein écran et sans onglets : le héros en pied avec son équipement autour,
## son identité, ses étoiles, son niveau, ses statistiques et son pouvoir ; en bas « Équiper au mieux » et « Monter ».

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
var _body: Control
var level_button: Button        # bouton « Niveau N » (le tutoriel le met en avant)


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


## Hauteur de la scène du héros (héros en pied et équipement autour) : elle grandit avec l'écran.
func _band_h() -> float:
	return clampf(UI.H - 1040.0, 300.0, 460.0)


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
		acts.append(["⋮", func(): M3.menu(_stage, Vector2(704, 96), [["Placer en escouade", _open_picker], ["Liens d’équipage", func(): add_child(BondsScreen.new())], ["Tout retirer", func():
			Game.unequip_all(_id)
			Game.save_game()
			changed.emit()
			_rebuild()]])])
	M3.top_bar(_stage, "", close, acts)
	var bh := _band_h()
	# scène : le héros en pied, l'équipement autour (maquette XF)
	_head = Control.new()
	_head.position = Vector2(0, 96)
	_head.size = Vector2(720, bh)
	_head.draw.connect(_draw_band)
	_head.gui_input.connect(_band_input)
	_stage.add_child(_head)
	var fig := Node2D.new()
	fig.position = Vector2(360, 96 + bh - 48.0)
	var k := (bh - 90.0) / 150.0
	fig.scale = Vector2(k, k)
	if not have:
		fig.modulate = Color(0.1, 0.12, 0.2)
	fig.draw.connect(func(): Art.draw_hero(fig, h, {"t": _t}))
	_stage.add_child(fig)
	_fig = fig
	# le reste de la fiche
	var body := Control.new()
	body.position = Vector2(0, 96 + bh)
	body.size = Vector2(720, UI.H - 96 - bh)
	body.draw.connect(_draw_body)
	body.gui_input.connect(func(ev: InputEvent):
		if not M3.is_tap(ev) or not have:
			return
		if ev.position.y > _stars_y() and ev.position.y < _stars_y() + 72.0 and int(Game.hero_stars[_id]) < Data.MAX_STARS:
			evolve_requested.emit(_id)
		elif ev.position.y > _talent_y() and ev.position.y < _talent_y() + 72.0:
			Sfx.play("click", -6.0)
			var ts := TalentScreen.new(_id)
			ts.changed.connect(func(): changed.emit())
			ts.closed.connect(func(): _body.queue_redraw())
			add_child(ts))
	_stage.add_child(body)
	_body = body
	if not have:
		return
	# actions : équiper au mieux, puis monter (niveau ou étoile)
	var best := M3.button(_stage, "Équiper au mieux", Rect2(32, UI.H - 136.0, 300, 104), "secondary", 28)
	best.pressed.connect(func():
		var cnt: int = Game.equip_best(_id)
		Game.save_game()
		Sfx.play("chest" if cnt > 0 else "click", -4.0)
		if cnt > 0:
			M3.toast(self, "%d objet%s équipé%s" % [cnt, "s" if cnt > 1 else "", "s" if cnt > 1 else ""], UI.GREEN)
		changed.emit()
		_rebuild())
	var stars: int = int(Game.hero_stars[_id])
	var capped := Game.at_cap(_id)
	var cost_v: int = Game.level_cost(_id)
	var up := M3.button(_stage, "", Rect2(348, UI.H - 136.0, 340, 104), "gold" if capped else "main", 28)
	if capped:
		M3.price(up, "Niveau maximum" if stars >= Data.MAX_STARS else "Monter à %s" % star_text(stars + 1), [])
	else:
		M3.price(up, "Niveau %d" % (int(Game.levels[_id]) + 1), [["coin", UI.num(cost_v), Game.credits >= cost_v]])
	up.disabled = (not capped and Game.credits < cost_v) or (capped and stars >= Data.MAX_STARS)
	if capped and stars < Data.MAX_STARS and not Game.can_star_up(_id):
		var miss := Game.star_cost(_id) - Game.copies_for(_id)
		up.disabled = true
		M3.price(up, "Il manque %d doublon%s" % [miss, "s" if miss > 1 else ""], [])
	level_button = up
	up.pressed.connect(func():
		if capped:
			evolve_requested.emit(_id)
			return
		if Game.level_up(_id):
			Sfx.play("coin", -4.0)
			changed.emit()
			_rebuild())


## Emplacements d'équipement autour du héros : arme et armure à gauche, module et relique à droite.
func _slot_rect(i: int) -> Rect2:
	var x := 32.0 if i < 2 else 600.0
	var y := 40.0 + (i % 2) * 132.0
	return Rect2(x, y, 88, 88)


func _draw_band() -> void:
	var c := _head
	var h: Dictionary = Data.HEROES[_id]
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	var bh := c.size.y
	for i in 9:
		c.draw_circle(Vector2(360, bh * 0.55), bh * 0.6 - i * bh * 0.06, Color(rc, 0.025))
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * i / 24.0
		pts.append(Vector2(360, bh - 44.0) + Vector2(cos(a) * 150.0, sin(a) * 24.0))
	c.draw_colored_polygon(pts, Color(rc, 0.14))
	c.draw_polyline(pts, Color(rc, 0.55), 2.0)
	if not Game.is_owned(_id):
		return
	for i in 4:
		var slot: String = Items.SLOTS[i]
		var r := _slot_rect(i)
		if not Game.slot_unlocked(_id, slot):
			ItemUI.locked(c, r)
			M3.text(c, Vector2(r.position.x - 20, r.end.y + 26), "niv. %d" % int(Items.SLOT_UNLOCK[slot]), 20, UI.MUTED, false, r.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)
			continue
		var it: Dictionary = Game.slot_item(_id, slot)
		if it.is_empty():
			ItemUI.empty(c, r)
		else:
			ItemUI.tile(c, r, it, true)
		if _better().has(slot):
			ItemUI.dot(c, r.position + Vector2(r.size.x - 4.0, 4.0), "▲")
		M3.text(c, Vector2(r.position.x - 20, r.end.y + 26), String(Items.SLOT_NAMES[slot]), 20, UI.MUTED, false, r.size.x + 40, HORIZONTAL_ALIGNMENT_CENTER)


## Emplacements où un objet du stock ferait mieux.
func _better() -> Dictionary:
	var better := {}
	for it in Game.inventory_items():
		if Game.slot_unlocked(_id, it.slot) and (it.bound == "" or it.bound == _id) and Game.power_gain(it, _id) > 0.0:
			better[it.slot] = maxf(float(better.get(it.slot, 0.0)), Game.power_gain(it, _id))
	return better


func _band_input(ev: InputEvent) -> void:
	if not M3.is_tap(ev) or not Game.is_owned(_id):
		return
	for i in 4:
		if _slot_rect(i).grow(12).has_point(ev.position):
			var slot: String = Items.SLOTS[i]
			if not Game.slot_unlocked(_id, slot):
				Sfx.play("click", -10.0)
				return
			accept_event()
			item_slot_requested.emit(slot)
			close()
			return


func _stars_y() -> float:
	return 118.0


func _draw_body() -> void:
	var c := _body
	var h: Dictionary = Data.HEROES[_id]
	var have := Game.is_owned(_id)
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	# nom, identité
	M3.text(c, Vector2(0, 46), String(h.name), 44, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	var meta := "%s · %s" % [h.job, Data.SPECIES_NAMES[h.species]]
	var chips := [String(Data.ROLE_NAMES[h.role]), String({"common": "Commun", "rare": "Rare", "epic": "Épique"}.get(h.rarity, h.rarity))]
	var tw := M3.text_w(meta, 22, false) + 12.0
	for ch in chips:
		tw += M3.text_w(ch, 20, true) + 36.0
	var x := (720.0 - tw) * 0.5
	M3.text(c, Vector2(x, 92), meta, 22, UI.MUTED)
	x += M3.text_w(meta, 22, false) + 12.0
	for ch in chips:
		var w := M3.text_w(ch, 20, true) + 28.0
		c.draw_style_box(UI.box(Color(rc, 0.12), Color(rc, 0.7), 16, 0), Rect2(x, 66, w, 36))
		M3.text(c, Vector2(x + 14, 91), ch, 20, rc.lightened(0.3), true)
		x += w + 8.0
	if not have:
		M3.text(c, Vector2(0, 170), "Pas encore dans l’équipage : à trouver au Recrutement.", 24, UI.MUTED, false, 720, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_power(c, h, 220.0)
		return
	# étoiles et doublons (toucher : nouvelle étoile)
	var stars: int = int(Game.hero_stars[_id])
	var sy := _stars_y()
	var sr := Rect2(32, sy, 656, 64)
	M3.glass_card(c, sr, Game.can_star_up(_id), 18.0)
	for i in 5:
		Art.star(c, Vector2(66 + i * 34, sy + 32), 14.0, UI.GOLD if i < Data.shown_stars(stars) else M3.OUT, 0.0)
	var cost := Game.star_cost(_id) if stars < Data.MAX_STARS else 0
	if cost > 0:
		var fr := Game.copies_for(_id)
		M3.bar(c, Rect2(250, sy + 26, 220, 12), minf(1.0, float(fr) / float(cost)), UI.GOLD)
		M3.text(c, Vector2(0, sy + 42), "%d / %d doublons" % [mini(fr, cost), cost], 22, UI.GOLD, true, 640, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		M3.text(c, Vector2(0, sy + 42), "Étoiles au maximum", 22, UI.GOLD, true, 640, HORIZONTAL_ALIGNMENT_RIGHT)
	# niveau
	var lv: int = int(Game.levels[_id])
	var cap: int = Data.level_cap(stars)
	M3.text(c, Vector2(32, sy + 108), "Niveau %d / %d" % [lv, cap], 24, UI.TEXT, true)
	var lo: int = cap - Data.LEVELS_PER_STAR
	M3.bar(c, Rect2(232, sy + 94, 456, 12), clampf(float(lv - lo) / float(Data.LEVELS_PER_STAR), 0.0, 1.0))
	# statistiques : valeur et part apportée par l'équipement
	var m: float = Data.hero_mult(lv) * Data.star_mult(maxi(1, stars)) * Data.EVO_STAT_MULT[Game.tier(_id)]
	var eq: Dictionary = Items.totals(Game.hero_items(_id))
	var vals := [
		["PV", h.hp * m, float(eq.hp), float(eq.hp_pct), UI.GREEN],
		["ATQ", h.atk * m, float(eq.atk), float(eq.atk_pct), UI.RED],
		["DÉF", h.def * m, float(eq.def), float(eq.def_pct), UI.ACCENT]]
	for i in 3:
		var r := Rect2(32 + i * 224.0, sy + 132, 208, 92)
		M3.glass_card(c, r, false, 16.0)
		var base: float = vals[i][1]
		var total: float = (base + vals[i][2]) * (1.0 + vals[i][3])
		M3.text(c, r.position + Vector2(20, 32), String(vals[i][0]), 20, vals[i][4], true)
		M3.text(c, r.position + Vector2(20, 74), UI.num(roundf(total)), 34, vals[i][4], true)
		var plus := total - base
		if plus >= 1.0:
			M3.text(c, r.position + Vector2(24 + M3.text_w(UI.num(roundf(total)), 34, true), 74), "+" + UI.num(roundf(plus)), 20, vals[i][4], true)
	_draw_power(c, h, sy + 240.0)
	_draw_talents(c, h, _talent_y())


func _talent_y() -> float:
	return _stars_y() + 240.0 + (132.0 if Data.SIGNATURES.has(_id) else 96.0) + 16.0


## Ligne des talents (maquette WG) : ceux choisis, ou combien sont à choisir ; toucher ouvre le choix.
func _draw_talents(c: Control, h: Dictionary, y: float) -> void:
	var open := Game.talents_open(_id)
	var r := Rect2(32, y, 656, 72)
	M3.glass_card(c, r, open > 0, 18.0)
	var names := []
	for tier in Data.TALENT_TIERS:
		var ch := Game.talent_choice(_id, tier)
		if ch >= 0:
			names.append(String(Data.TALENTS[h.role][tier][ch].name))
	M3.text(c, Vector2(56, y + 46), "Talents", 26, UI.TEXT, true)
	var txt := ", ".join(names) if not names.is_empty() else ("à partir de 2★" if int(Game.hero_stars.get(_id, 1)) < 2 else "")
	if open > 0:
		txt = "%d à choisir" % open
	M3.text(c, Vector2(176, y + 46), txt + "  ›", 22, UI.GOLD if open > 0 else UI.MUTED, open > 0, 488, HORIZONTAL_ALIGNMENT_RIGHT)


## Pouvoir et effet propre (maquettes XF et WA).
func _draw_power(c: Control, h: Dictionary, y: float) -> void:
	var r := Rect2(32, y, 656, 96 if not Data.SIGNATURES.has(_id) else 132)
	M3.glass_card(c, r, false, 18.0)
	var gc := Vector2(84, y + 48)
	var hex := PackedVector2Array()
	for k in 6:
		var a := PI / 6.0 + k * PI / 3.0
		hex.append(gc + Vector2(cos(a), sin(a)) * 32.0)
	c.draw_colored_polygon(hex, Color("0a1424"))
	c.draw_polyline(hex + PackedVector2Array([hex[0]]), UI.ACCENT, 3.0, true)
	SkillButton.draw_glyph(c, int(SkillButton.LOOK.get(h.skill.kind, SkillButton.LOOK.shield).glyph), gc, UI.ACCENT, 0.5)
	M3.text(c, Vector2(136, y + 40), "%s · %d s" % [h.skill.name, int(h.skill.cd)], 26, UI.TEXT, true, 520)
	M3.text(c, Vector2(136, y + 76), String(h.skill.desc), 22, UI.MUTED, false, 520)
	if Data.SIGNATURES.has(_id):
		var sg: Dictionary = Data.SIGNATURES[_id]
		M3.text(c, Vector2(136, y + 112), "%s : %s" % [sg.name, sg.desc], 20, UI.GOLD, true, 520)

func hero_id() -> String:
	return _id


## Glisser à gauche ou à droite sur le haut de la fiche : héros suivant ou précédent (maquette E6).
var _swipe0 := Vector2(-1, -1)


func _input(ev: InputEvent) -> void:
	var down: bool = (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and not UI.emulated(ev) and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	var up: bool = (ev is InputEventScreenTouch and not ev.pressed) or (ev is InputEventMouseButton and not UI.emulated(ev) and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)
	if not (down or up) or not is_visible_in_tree():
		return
	var p: Vector2 = _stage.get_global_transform_with_canvas().affine_inverse() * ev.position
	if down:
		# zone du héros en pied, entre les colonnes d'équipement
		var top := 96.0 + _band_h()
		_swipe0 = p if p.y > 112.0 and p.y < top and p.x > 140.0 and p.x < 580.0 else Vector2(-1, -1)
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
	if _body != null:
		_body.queue_redraw()


## « ★★ » pour 2 étoiles ; « ★★★★★ MAX » au dernier rang.
static func star_text(rank: int) -> String:
	if rank <= 0:
		return ""
	return "★".repeat(Data.shown_stars(rank)) + (" MAX" if rank >= Data.MAX_STARS else "")


# ---------------------------------------------------------------- Stats

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
