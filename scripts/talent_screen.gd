class_name TalentScreen
extends Overlay
## Talents d'un héros (maquette WG) : à chaque étoile de 2★ à 5★, un choix entre deux talents.
## Choisir est gratuit ; changer d'avis coûte des éclats.

signal changed

var _id := ""
var _st: Control
var _sheet: Control
var _t := 0.0
var _fig: Node2D

const ROW := 150.0
const TOP := 216.0


func _init(id: String) -> void:
	super._init(720.0)
	_id = id
	_st = use_stage(0.7)
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := TOP + 4 * ROW + 40.0
	_sheet.size = Vector2(720, h)
	_sheet.position = Vector2(0, UI.H - h)
	_sheet.draw.connect(_draw_sheet)
	_sheet.gui_input.connect(_input_sheet)
	_st.add_child(_sheet)
	_st.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev) and ev.position.y < _sheet.position.y:
			close())
	var hd: Dictionary = Data.HEROES[id]
	_fig = Node2D.new()
	_fig.position = Vector2(84, 196)
	_fig.scale = Vector2(0.62, 0.62)
	_fig.draw.connect(func(): Art.draw_hero(_fig, hd, {"t": _t}))
	_sheet.add_child(_fig)


func _process(delta: float) -> void:
	_t += delta
	_sheet.queue_redraw()
	_fig.queue_redraw()


func _card(tier_i: int, j: int) -> Rect2:
	return Rect2(152.0 + j * 276.0, TOP + tier_i * ROW, 264, ROW - 14.0)


func _draw_sheet() -> void:
	var c := _sheet
	var h: Dictionary = Data.HEROES[_id]
	var role := String(h.role)
	var stars := int(Game.hero_stars.get(_id, 1))
	M3.sheet(c, Rect2(Vector2.ZERO, c.size))
	c.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
	M3.text(c, Vector2(176, 84), String(h.name), 36, UI.TEXT, true, 340)
	for i in 5:
		Art.star(c, Vector2(530 + i * 32, 72), 13.0, UI.GOLD if i < Data.shown_stars(stars) else M3.OUT, 0.0)
	M3.text(c, Vector2(176, 124), "%s · %s" % [Data.ROLE_NAMES[role], h.skill.name], 24, UI.MUTED, false, 500)
	M3.text(c, Vector2(176, 168), "Choisir est gratuit · changer d’avis : %d éclats" % Data.TALENT_RESPEC, 20, UI.MUTED, false, 500)
	for ti in Data.TALENT_TIERS.size():
		var tier: int = Data.TALENT_TIERS[ti]
		var open := stars >= tier
		var y := TOP + ti * ROW
		# pastille de l'étoile : dorée si atteinte, sinon les doublons à réunir
		var badge := Rect2(24, y, 112, ROW - 14.0)
		var bc := Color("3a2c08") if open else M3.S2
		var pl := PackedVector2Array([badge.position + Vector2(18, 0), Vector2(badge.end.x - 18, badge.position.y), Vector2(badge.end.x, badge.position.y + 18), Vector2(badge.end.x, badge.end.y - 18), Vector2(badge.end.x - 18, badge.end.y), badge.position + Vector2(18, badge.size.y), Vector2(badge.position.x, badge.end.y - 18), badge.position + Vector2(0, 18)])
		c.draw_colored_polygon(pl, bc)
		M3.text(c, Vector2(24, y + (ROW - 14.0) * 0.5 + 12), "%d★" % tier, 34, UI.GOLD if open else UI.MUTED, true, 112, HORIZONTAL_ALIGNMENT_CENTER)
		if not open:
			M3.text(c, Vector2(24, y + ROW - 34), "%d doubl." % Data.star_cost(tier - 1), 18, UI.MUTED, false, 112, HORIZONTAL_ALIGNMENT_CENTER)
		var chosen := Game.talent_choice(_id, tier)
		for j in 2:
			var t: Dictionary = Data.TALENTS[role][tier][j]
			var r := _card(ti, j)
			var sel := chosen == j
			M3.glass_card(c, r, sel, 16.0)
			if sel:
				c.draw_style_box(UI.box(Color(0, 0, 0, 0), UI.ACCENT, 16, 0), r)
			var a := 1.0 if open else 0.45
			if chosen >= 0 and not sel:
				a = 0.7
			var name := ("✓ " if sel else "") + String(t.name)
			M3.text(c, r.position + Vector2(18, 40), name, 26, Color(1, 1, 1, a), true, r.size.x - 36.0)
			M3.para(c, r.position + Vector2(18, 76), String(t.desc), 21, Color(UI.MUTED, a), r.size.x - 36.0, 1.3)


func _input_sheet(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	for ti in Data.TALENT_TIERS.size():
		for j in 2:
			if _card(ti, j).has_point(ev.position):
				var tier: int = Data.TALENT_TIERS[ti]
				var before := Game.talent_choice(_id, tier)
				var res: String = Game.set_talent(_id, tier, j)
				if res != "":
					Sfx.play("click", -10.0)
					M3.toast(self, res, UI.GOLD)
					return
				if before != j:
					Sfx.play("star", -4.0)
					M3.toast(self, "%s choisi%s" % [Data.TALENTS[Data.HEROES[_id].role][tier][j].name, "" if before < 0 else " · −%d éclats" % Data.TALENT_RESPEC], UI.GREEN)
					Game.save_game()
					changed.emit()
				return
