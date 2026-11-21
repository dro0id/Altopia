class_name CosmeticsScreen
extends Overlay
## Succès, peintures de l'Aurore et tenues des héros (maquette YG). On les porte pour le plaisir.

var _st: Control
var _scroll: ScrollContainer
var _body: Control
var _t := 0.0
var _hero_i := 0
var _figs: Array = []
var _press := Vector2.ZERO

const PAINT_Y := 24.0
const OUTFIT_Y := 360.0
const ACH_Y := 760.0


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("b388ff"))
	M3.top_bar(_st, "Succès et tenues", close)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 112)
	_scroll.size = Vector2(720, UI.H - 112)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_st.add_child(_scroll)
	DragScroll.attach(_scroll)
	_body = Control.new()
	_body.custom_minimum_size = Vector2(720, ACH_Y + 60 + Cosmetics.LIST.size() * 112.0 + 40.0)
	_body.draw.connect(_draw_body)
	_body.gui_input.connect(_input_body)
	_scroll.add_child(_body)
	_build_figs()


func _owned() -> Array:
	return Data.ALL_HEROES.filter(func(id): return Game.is_owned(id))


func _hero() -> String:
	var o := _owned()
	return String(o[posmod(_hero_i, o.size())]) if not o.is_empty() else "mara"


## Le héros choisi, dessiné dans chaque tenue (un nœud par carte).
func _build_figs() -> void:
	for f in _figs:
		f.queue_free()
	_figs = []
	var h: Dictionary = Data.HEROES[_hero()]
	var keys := Cosmetics.OUTFITS.keys()
	for i in keys.size():
		var o := String(keys[i])
		var preview := h.duplicate()
		preview.name = ""                         # pas de tenue appliquée : on montre celle de la carte
		if o != "origine":
			var look: Dictionary = (h.look as Dictionary).duplicate()
			look.suit = Cosmetics.OUTFITS[o].suit
			look.accent = Cosmetics.OUTFITS[o].accent
			preview.look = look
		var fig := Node2D.new()
		var r := _outfit_rect(i)
		fig.position = r.position + Vector2(r.size.x * 0.5, 196)
		fig.scale = Vector2(0.82, 0.82)
		if not Cosmetics.outfit_open(o, Game):
			fig.modulate = Color(0.12, 0.14, 0.24)
		fig.draw.connect(func(): Art.draw_hero(fig, preview, {"t": _t}))
		_body.add_child(fig)
		_figs.append(fig)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()
	for f in _figs:
		f.queue_redraw()


func _paint_rect(i: int) -> Rect2:
	return Rect2(32 + i * 166.0, PAINT_Y + 48, 154, 248)


func _outfit_rect(i: int) -> Rect2:
	return Rect2(32 + i * 166.0, OUTFIT_Y + 112, 154, 250)


func _draw_body() -> void:
	var c := _body
	# peintures
	M3.section(c, Vector2(32, PAINT_Y + 24), "PEINTURES DE L’AURORE")
	var pk := Cosmetics.PAINTS.keys()
	for i in pk.size():
		var id := String(pk[i])
		var pt: Dictionary = Cosmetics.PAINTS[id]
		var r := _paint_rect(i)
		var open := Cosmetics.paint_open(id, Game)
		c.draw_style_box(UI.box(pt.bg, UI.ACCENT if Game.paint == id else Color(0, 0, 0, 0), 16, 0), r)
		_mini_ship(c, r.position + Vector2(r.size.x * 0.5, 104), pt, open)
		M3.text(c, r.position + Vector2(0, 204), String(pt.name), 24, UI.TEXT if open else UI.MUTED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, r.position + Vector2(0, 232), "d’origine" if id == "amiraute" else (("✓ portée" if Game.paint == id else "toucher") if open else _cond_for("paint", id)), 18, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if not open:
			M3.lock(c, r.position + Vector2(r.size.x - 24, 24), UI.MUTED, 0.8)
	# tenues
	M3.section(c, Vector2(32, OUTFIT_Y + 24), "TENUES")
	var hid := _hero()
	var hr := Rect2(32, OUTFIT_Y + 44, 656, 56)
	M3.glass_card(c, hr, false, 14.0)
	M3.text(c, Vector2(32, OUTFIT_Y + 82), "‹", 34, UI.ACCENT, true, 80, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(608, OUTFIT_Y + 82), "›", 34, UI.ACCENT, true, 80, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(0, OUTFIT_Y + 82), String(Data.HEROES[hid].name), 26, UI.TEXT, true, 720, HORIZONTAL_ALIGNMENT_CENTER)
	var ok := Cosmetics.OUTFITS.keys()
	var cur := String(Game.outfits.get(hid, "origine"))
	for i in ok.size():
		var o := String(ok[i])
		var r := _outfit_rect(i)
		var open := Cosmetics.outfit_open(o, Game)
		c.draw_style_box(UI.box(M3.S2, UI.ACCENT if cur == o else Color(0, 0, 0, 0), 16, 0), r)
		M3.text(c, r.position + Vector2(0, 222), String(Cosmetics.OUTFITS[o].name), 20, UI.TEXT if open else UI.MUTED, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(c, r.position + Vector2(0, 244), ("✓ portée" if cur == o else "toucher") if open else _cond_for("outfit", o), 18, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if not open:
			M3.lock(c, r.position + Vector2(r.size.x - 24, 24), UI.MUTED, 0.8)
	# succès
	M3.section(c, Vector2(32, ACH_Y + 24), "SUCCÈS")
	M3.text(c, Vector2(32, ACH_Y + 24), "aucun bonus de combat : on les porte pour le plaisir", 18, UI.MUTED, false, 656, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in Cosmetics.LIST.size():
		var a: Dictionary = Cosmetics.LIST[i]
		var y := ACH_Y + 48 + i * 112.0
		var r := Rect2(32, y, 656, 100)
		var done := Cosmetics.is_done(a, Game)
		M3.glass_card(c, r, done, 16.0)
		Art.star(c, r.position + Vector2(44, 50), 16.0, UI.GOLD if done else M3.OUT, 0.0)
		M3.text(c, r.position + Vector2(80, 40), String(a.name), 26, UI.TEXT, true, 380)
		M3.text(c, r.position + Vector2(80, 74), String(a.desc), 20, UI.MUTED, false, 380)
		M3.text(c, r.position + Vector2(0, 40), Cosmetics.reward_text(a), 20, UI.GOLD if done else UI.MUTED, true, 632, HORIZONTAL_ALIGNMENT_RIGHT)
		var pr := mini(Cosmetics.progress(String(a.id), Game), int(a.goal))
		M3.bar(c, Rect2(468, y + 62, 164, 10), float(pr) / float(a.goal), UI.GOLD)
		M3.text(c, r.position + Vector2(0, 88), "%d / %d" % [pr, int(a.goal)], 18, UI.MUTED, false, 632, HORIZONTAL_ALIGNMENT_RIGHT)


func _cond_for(kind: String, id: String) -> String:
	for a in Cosmetics.LIST:
		if String(a.reward.get(kind, "")) == id:
			return String(a.desc)
	return ""


## Petite Aurore dans les couleurs d'une peinture.
func _mini_ship(c: Control, at: Vector2, pt: Dictionary, open: bool) -> void:
	var k := 1.0 if open else 0.45
	var light: Color = (pt.light as Color) * Color(k, k, k)
	var navy: Color = (pt.navy as Color) * Color(k, k, k)
	c.draw_circle(at + Vector2(0, -58), 26, Color(light, 0.9))
	c.draw_rect(Rect2(at + Vector2(-30, -58), Vector2(60, 108)), light)
	var marks: Array = pt.marks
	for i in 5:
		c.draw_rect(Rect2(at + Vector2(-30, -48 + i * 20), Vector2(60, 5)), Color(marks[i], k))
	c.draw_rect(Rect2(at + Vector2(-30, 34), Vector2(60, 16)), navy)
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-14, 50), at + Vector2(14, 50), at + Vector2(0, 76)]), Color(UI.ACCENT, 0.8 * k))
	for sx in [-1, 1]:
		c.draw_rect(Rect2(at + Vector2(sx * 34 - (12 if sx < 0 else 0), -20), Vector2(12, 40)), Color("2b3a6b"))


func _input_body(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		return
	if not M3.is_release(ev) or ev.position.distance_to(_press) > 14.0:
		return
	var p: Vector2 = ev.position
	var pk := Cosmetics.PAINTS.keys()
	for i in pk.size():
		if _paint_rect(i).has_point(p):
			var id := String(pk[i])
			if Cosmetics.paint_open(id, Game):
				Game.paint = id
				Sfx.play("star", -6.0)
				Game.save_game()
				Game.changed.emit()
			else:
				M3.toast(self, _cond_for("paint", id), UI.GOLD)
			return
	if p.y > OUTFIT_Y + 44 and p.y < OUTFIT_Y + 100:
		_hero_i += -1 if p.x < 360.0 else 1
		Sfx.play("click", -8.0)
		_build_figs()
		return
	var ok := Cosmetics.OUTFITS.keys()
	for i in ok.size():
		if _outfit_rect(i).has_point(p):
			var o := String(ok[i])
			if Cosmetics.outfit_open(o, Game):
				Game.outfits[_hero()] = o
				Sfx.play("star", -6.0)
				Game.save_game()
				Game.changed.emit()
			else:
				M3.toast(self, _cond_for("outfit", o), UI.GOLD)
			return
