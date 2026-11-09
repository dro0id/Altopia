class_name PullResults
extends Control
## Résultat d'ouverture (maquette BZ), plein écran : grille des tirages, meilleur résultat, bilan par rareté, actions.
## `kind` = "item" (caisses d'équipement) ou "hero" (recrutement).

const Data = preload("res://scripts/data.gd")

signal closed
signal again
signal equip_best
signal inventory

var kind := "item"
var res: Array = []
var count := 1
var _reveal := 0.0
var _t := 0.0
var _body: Control
var _again: Button


func _init(k: String, results: Array, n: int) -> void:
	kind = k
	res = results
	count = n
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	M3.top_bar(self, "Ouverture ×%d" % count, func(): _close())
	_body = Control.new()
	_body.position = Vector2(0, 112)
	_body.size = Vector2(720, 900)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.draw.connect(_draw_body)
	add_child(_body)
	var h := size.y if size.y > 0.0 else 1280.0
	var cost: int = (Data.ITEM_PACK_COST_10 if count == 10 else Data.ITEM_PACK_COST) if kind == "item" else (Data.RECRUIT_COST_10 if count == 10 else Data.RECRUIT_COST)
	var have: int = Game.item_tokens if kind == "item" else Game.tokens
	if kind == "item":
		var eq := M3.button(self, "Équiper au mieux", Rect2(32, h - 32 - 96 - 16 - 104, 656, 104), "main")
		eq.pressed.connect(func(): equip_best.emit(); _close())
		var inv := M3.button(self, "Inventaire", Rect2(32, h - 32 - 96, 320, 96), "ghost")
		inv.pressed.connect(func(): inventory.emit(); _close())
		_again = M3.button(self, "Encore ×%d" % count, Rect2(368, h - 32 - 96, 320, 96), "ghost")
	else:
		var ok := M3.button(self, "Continuer", Rect2(32, h - 32 - 96 - 16 - 104, 656, 104), "main")
		ok.pressed.connect(_close)
		_again = M3.button(self, "Encore ×%d · %d jetons" % [count, cost], Rect2(32, h - 32 - 96, 656, 96), "ghost")
	_again.disabled = have < cost
	_again.pressed.connect(func(): _close(); again.emit())


func _close() -> void:
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	var before := int(_reveal)
	_reveal = minf(_reveal + delta * 7.0, float(res.size()))
	if int(_reveal) != before:
		var ri := _rank(res[int(_reveal) - 1])
		Sfx.play("star" if ri < 3 else "chest", -3.0, 0.9 + 0.08 * float(ri))
	_body.queue_redraw()


## Rang de rareté commun à tous les tirages (0 normal … 4 légendaire).
func _rank(r: Dictionary) -> int:
	if kind == "item":
		return Items.rarity_index(r.item.rarity)
	return [1, 2, 3][Data.RARITIES_HERO.find(r.rarity)]


func _color(r: Dictionary) -> Color:
	return ItemUI.color(r.item.rarity) if kind == "item" else Data.RARITY_COLORS[r.rarity]


func _tile(r: Dictionary, rect: Rect2) -> void:
	if kind == "item":
		ItemUI.tile(_body, rect, r.item, false)
	else:
		var c := _color(r)
		_body.draw_style_box(UI.box(Color(c, 0.12), c, int(rect.size.x * 0.19), 0), rect)
		M3.avatar(_body, Data.HEROES[r.id], rect.get_center(), rect.size.x * 0.42, c, _t)


func _draw_body() -> void:
	var n := res.size()
	var cols := mini(n, 5)
	var x0 := 360.0 - (cols * 116.0 + (cols - 1) * 16.0) * 0.5
	for i in mini(n, int(_reveal) + 1):
		var r := Rect2(x0 + (i % 5) * 132.0, 16.0 + (i / 5) * 132.0, 116, 116)
		var grow := 1.0 if i < int(_reveal) else 0.6 + 0.4 * (_reveal - float(i))
		_tile(res[i], Rect2(r.get_center() - r.size * 0.5 * grow, r.size * grow))
		if i < int(_reveal) and kind == "hero" and res[i].new:
			ItemUI.dot(_body, r.position + Vector2(r.size.x - 4.0, 4.0), "!", UI.GOLD)
	var y := 16.0 + (((n - 1) / 5) + 1) * 132.0 + 8.0
	# meilleur résultat
	var best: Dictionary = res[0]
	for r in res:
		if _rank(r) > _rank(best) or (kind == "item" and _rank(r) == _rank(best) and Items.power(r.item) > Items.power(best.item)):
			best = r
	var col := _color(best)
	UI.draw_gradient_box(_body, Rect2(32, y, 656, 144), 40.0, Color(col.r * 0.25, col.g * 0.2, col.b * 0.1), M3.S2, col, 3.0)
	_tile(best, Rect2(56, y + 16, 112, 112))
	M3.text(_body, Vector2(192, y + 52), "MEILLEUR OBJET" if kind == "item" else "MEILLEUR HÉROS", 22, col, true)
	var nm: String = String(best.item.name) if kind == "item" else String(Data.HEROES[best.id].name)
	M3.text(_body, Vector2(192, y + 92), nm, 30, col, true, 360)
	if kind == "item":
		var bg: Dictionary = Game.best_hero_for(best.item)
		if bg.hero != "" and bg.gain > 0.0:
			M3.text(_body, Vector2(32, y + 92), "▲ +%s" % UI.num(bg.gain), 28, UI.GREEN, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		M3.text(_body, Vector2(192, y + 124), "Nouveau héros !" if best.new else "+ %d doublons" % int(best.fragments), 24, UI.GREEN if best.new else UI.GOLD)
	y += 168.0
	# bilan par rareté (puces)
	var counts := {}
	for r in res:
		var key: String = r.item.rarity if kind == "item" else r.rarity
		counts[key] = int(counts.get(key, 0)) + 1
	var order: Array = Items.RARITIES.duplicate() if kind == "item" else Data.RARITIES_HERO.duplicate()
	order.reverse()
	var x := 32.0
	for k in order:
		if not counts.has(k):
			continue
		var nmr: String = String(Data.RARITY_NAMES[k] if kind == "item" else Data.RARITY_NAMES_HERO[k]).to_lower()
		if int(counts[k]) > 1:
			nmr = nmr.trim_suffix("al") + "aux" if nmr.ends_with("al") else nmr + "s"
		var txt := "%d %s" % [counts[k], nmr]
		var w := M3.text_w(txt, 24, true) + 40.0
		if x + w > 688.0:
			x = 32.0
			y += 76.0
		_body.draw_style_box(UI.box(Color(0, 0, 0, 0), M3.OUT, 16, 0), Rect2(x, y, w, 64))
		M3.text(_body, Vector2(x, y + 32 + M3.fs(24) * 0.36), txt, 24, UI.MUTED, true, w, HORIZONTAL_ALIGNMENT_CENTER)
		x += w + 12.0
	y += 104.0
	if kind == "item":
		M3.para(_body, Vector2(32, y), "Inventaire %d / %d. S'il est plein, le surplus part en réserve." % [Game.inventory_count(), Items.INVENTORY_MAX], 26, UI.MUTED, 656)
	else:
		var news := 0
		var frags := 0
		for r in res:
			news += 1 if r.new else 0
			frags += int(r.fragments)
		M3.para(_body, Vector2(32, y), "%d nouveau%s héros · %d doublons" % [news, "x" if news > 1 else "", frags], 26, UI.MUTED, 656)
