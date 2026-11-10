class_name RecruitScreen
extends Overlay
## Recruter (maquettes BF et BY) : barre du haut avec jetons, segments Héros / Objets, bannière ou caisse, garanties, deux ouvertures.

signal inventory_requested
signal equipped
signal fullscreen(on: bool)

var _stage: Control
var _chip: HudButton
var _seg: M3Seg
var _mode := 0
var _hero: Control
var _items: Control
var _ten: Button
var _one: Button
var _results: PullResults
var _t := 0.0


func _init() -> void:
	super._init(720.0)
	panel.custom_minimum_size = Vector2(720, (UI.H - 160.0))
	panel.add_theme_stylebox_override("panel", UI.box(UI.BG, Color(0, 0, 0, 0), 0, 0))
	box.add_theme_constant_override("separation", 0)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2(720, (UI.H - 160.0))
	box.add_child(_stage)
	_chip = M3.cur_chip("token", str(Game.tokens))
	M3.top_bar(_stage, "Recruter", Callable(), [_chip])
	_seg = M3Seg.new(["Héros", "Objets"], 0)
	_seg.position = Vector2(32, 112)
	_seg.changed.connect(_set_mode)
	_stage.add_child(_seg)
	_hero = Control.new()
	_hero.size = Vector2(720, 860)
	_hero.position = Vector2(0, 216 + UI.tall(0.25))
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.draw.connect(_draw_hero)
	_stage.add_child(_hero)
	_items = Control.new()
	_items.size = Vector2(720, 700)
	_items.position = Vector2(0, 192)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.draw.connect(_draw_items)
	_stage.add_child(_items)
	_ten = M3.button(_stage, "", Rect2(32, UI.H - 160.0 - 248.0, 656, 112), "main", 30)
	_ten.pressed.connect(func(): _pull(10))
	_one = M3.button(_stage, "", Rect2(32, UI.H - 160.0 - 120.0, 656, 96), "ghost", 30)
	_one.pressed.connect(func(): _pull(1))
	_set_mode(0)


func _set_mode(m: int) -> void:
	_mode = m
	_seg.sel = m
	_seg.queue_redraw()
	_hero.visible = m == 0
	_items.visible = m == 1
	_chip.icon = "token" if m == 0 else "itoken"
	if m == 0:
		_ten.text = "Ouvrir ×10 · %d jetons" % Data.RECRUIT_COST_10
		_one.text = "Ouvrir ×1 · %d jetons" % Data.RECRUIT_COST
	else:
		_ten.text = "Ouvrir ×10 · %d jetons" % Data.ITEM_PACK_COST_10
		_one.text = "Ouvrir ×1 · %d jetons" % Data.ITEM_PACK_COST
	_refresh()


func _refresh() -> void:
	var have: int = Game.tokens if _mode == 0 else Game.item_tokens
	_chip.set_texts(str(have))
	_chip.fit_chip()
	_chip.size.y = 64.0
	_chip.position.x = 704.0 - _chip.size.x - 8.0
	_ten.disabled = have < (Data.RECRUIT_COST_10 if _mode == 0 else Data.ITEM_PACK_COST_10)
	_one.disabled = have < (Data.RECRUIT_COST if _mode == 0 else Data.ITEM_PACK_COST)
	# un seul bouton principal : le ×10 s'il est payable, sinon le ×1
	UI.set_role(_ten, "main" if not _ten.disabled else "secondary")
	UI.set_role(_one, "secondary" if not _ten.disabled else "main")


func _process(delta: float) -> void:
	_t += delta
	_refresh()
	(_hero if _mode == 0 else _items).queue_redraw()


# ---------------------------------------------------------------- Héros (BF)

func _draw_hero() -> void:
	var c := _hero
	var r := Rect2(32, 0, 656, 420)
	UI.draw_gradient_box(c, r, 48.0, Color("3d2185"), Color("1f1040"), Color(0, 0, 0, 0), 0.0)
	var fh: String = Data.featured_hero(int(Time.get_unix_time_from_system() / 86400.0))
	M3.avatar(c, Data.HEROES[fh], Vector2(588, 250), 92.0, Color("b388ff"), _t)
	M3.text(c, Vector2(64, 56), "BANNIÈRE EN COURS", 24, Color("b388ff"), true)
	M3.text(c, Vector2(64, 118), "Signal de", 48, UI.TEXT, true)
	M3.text(c, Vector2(64, 172), "recrutement", 48, UI.TEXT, true)
	M3.text(c, Vector2(64, 220), "En vedette : %s" % String(Data.HEROES[fh].name).split(" ")[0], 26, UI.MUTED)
	var rates: Dictionary = Data.RECRUIT_RATES
	var x := 64.0
	for part in [["Normal %d %%" % int(round((1.0 - float(rates.rare) - float(rates.epic)) * 100.0)), UI.GREEN], [" · ", UI.TEXT], ["Rare %d %%" % int(round(float(rates.rare) * 100.0)), Color("4fa8ff")], [" · ", UI.TEXT], ["Épique %d %%" % int(round(float(rates.epic) * 100.0)), Color("b388ff")]]:
		M3.text(c, Vector2(x, 392), part[0], 24, part[1], true)
		x += M3.text_w(part[0], 24, true)
	# garanties
	for i in 2:
		var pr := Rect2(32.0 + i * 336.0, 444, 320, 128)
		M3.card(c, pr)
		var col := Color("4fa8ff") if i == 0 else Color("b388ff")
		var mx: int = Data.PITY_RARE if i == 0 else Data.PITY_EPIC
		var v: int = int(Game.recruit_pity.get("rare" if i == 0 else "epic", 0))
		M3.text(c, pr.position + Vector2(32, 48), "Rare garanti" if i == 0 else "Épique garanti", 24, col, true)
		M3.text(c, pr.position + Vector2(32, 96), "%d / %d" % [v, mx], 36, UI.TEXT, true)


# ---------------------------------------------------------------- Objets (BY)

func _draw_items() -> void:
	var c := _items
	var ctr := Vector2(360, 250)
	for i in 14:
		c.draw_circle(ctr, 300.0 - i * 18.0, Color(1.0, 0.69, 0.26, 0.016))
	for i in 40:
		var a := TAU * i / 40.0 + _t * 0.12
		c.draw_arc(ctr, 210.0, a, a + TAU / 80.0, 6, Color(1.0, 0.69, 0.26, 0.4), 4.0, true)
	var bob := sin(_t * 2.4) * 6.0
	var cr := Rect2(ctr + Vector2(-110, -140 + bob), Vector2(220, 280))
	UI.draw_gradient_box(c, cr, 40.0, Color("ffe2a8"), Color("5a3000"), Color("ffd78a"), 2.0)
	ItemUI.slot_icon(c, "module", cr.get_center(), 120.0, Color("3a2000"))
	# garanties
	var cols := [Color("b388ff"), Color("ffb142")]
	var names := ["Épique garanti", "Légendaire garanti"]
	var vals := [int(Game.item_pack_pity.epic), int(Game.item_pack_pity.leg)]
	var maxs := [Data.ITEM_PITY_EPIC, Data.ITEM_PITY_LEG]
	for i in 2:
		var x := 32.0 + i * 336.0
		M3.text(c, Vector2(x, 536), names[i], 24, cols[i], true)
		M3.text(c, Vector2(x, 536), "%d/%d" % [vals[i], maxs[i]], 24, UI.MUTED, false, 320, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.bar(c, Rect2(x, 552, 320, 12), float(vals[i]) / float(maxs[i]), cols[i])
	M3.text(c, Vector2(32, 632), "Derniers", 24, UI.MUTED)
	for i in 6:
		var r := Rect2(144.0 + i * 92.0, 592, 76, 76)
		if i < Game.item_pulls.size():
			ItemUI.tile(c, r, {"slot": Game.item_pulls[i].slot, "rarity": Game.item_pulls[i].rarity, "level": 1}, false)
		else:
			c.draw_style_box(UI.box(M3.S2, M3.S3, 16, 0), r)


# ---------------------------------------------------------------- tirages

func _pull(count: int) -> void:
	if _results != null:
		return
	var res: Array = Game.recruit(count) if _mode == 0 else Game.open_item_packs(count)
	if res.is_empty():
		return
	Game.save_game()
	Sfx.play("chest", -2.0)
	_results = PullResults.new("hero" if _mode == 0 else "item", res, count)
	_results.closed.connect(func():
		_results = null
		fullscreen.emit(false))
	_results.again.connect(func(): _pull.call_deferred(count))
	_results.inventory.connect(func(): inventory_requested.emit())
	_results.equip_best.connect(func():
		var n: int = Game.equip_best_all()
		Game.save_game()
		Sfx.play("chest" if n > 0 else "click", -4.0)
		equipped.emit())
	add_child(_results)
	fullscreen.emit(true)
