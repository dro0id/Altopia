class_name ShopScreen
extends Overlay
## Boutique : on dépense des cristaux d'Altopia (gagnés sur les gros boss). L'achat de cristaux contre de l'argent réel viendra avec la publication.

signal bought(text: String)

var _crystals: Label
var _tokens: Label
var _credits: Label
var _free_banner: PanelContainer
var _free_btn: Button
var _free_sub: Label
var _buttons := {}
var _t := 0.0


func _init() -> void:
	super._init(690.0)
	box.add_theme_constant_override("separation", 12)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var t := UI.label(head, "Boutique", 34, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crystals = _chip(head, Color(1.0, 0.48, 0.85))
	_tokens = _chip(head, Color(0.75, 0.6, 1.0))
	_credits = _chip(head, UI.GOLD)
	# coffre gratuit : le plus important, en haut
	_free_banner = PanelContainer.new()
	_free_banner.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.2, 0.12, 0.98), UI.GREEN, 14, 12))
	box.add_child(_free_banner)
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 12)
	_free_banner.add_child(fh)
	var fv := VBoxContainer.new()
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.add_theme_constant_override("separation", 0)
	fh.add_child(fv)
	UI.label(fv, "Coffre gratuit", 26, Color.WHITE)
	_free_sub = UI.label(fv, "", 18, UI.MUTED)
	_free_btn = UI.button(fh, "Ouvrir", 24, "main")
	_free_btn.custom_minimum_size = Vector2(170, 64)
	_free_btn.pressed.connect(func():
		var c: Dictionary = Game.claim_free_chest()
		if not c.is_empty():
			Sfx.play("chest")
			Game.save_game()
			bought.emit("Coffre gratuit : +%s crédits, +%d éclats" % [Data.fmt(c.credits), int(c.shards)])
		_refresh())
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 840)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	DragScroll.attach(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	sc.add_child(inner)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	inner.add_child(grid)
	for it in Data.SHOP_ITEMS:
		grid.add_child(_card(it))
	grid.add_child(_soon_card())
	var d := UI.label(inner, "Les achats avec de l'argent réel arriveront avec la publication du jeu. En attendant, les gros boss rapportent des cristaux.", 17, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh()


func _chip(parent: Node, col: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.03, 0.06, 0.14, 0.9), UI.LINE, 22, 6))
	parent.add_child(p)
	return UI.label(p, "", 20, col)


func _card(it: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var featured: bool = it.id == "chest_epic"
	p.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), Color(0.7, 0.5, 1.0) if featured else UI.LINE, 14, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 104)
	art.draw.connect(_draw_art.bind(art, it))
	v.add_child(art)
	var n := UI.label(v, it.name, 22, Color.WHITE)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(0, 54)
	var dsc := UI.label(v, it.desc, 16, UI.MUTED)
	dsc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dsc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc.custom_minimum_size = Vector2(0, 40)
	var b := UI.button(v, "◆ %d" % int(it.cost), 26, "gold")
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(func():
		var msg: String = Game.buy(it.id)
		if msg != "":
			Sfx.play("coin")
			Game.save_game()
			bought.emit(msg)
		_refresh())
	_buttons[it.id] = b
	if featured:
		var tag := UI.label(v, "POPULAIRE", 14, Color(0.75, 0.6, 1.0))
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.move_child(tag, 0)
	return p


func _soon_card() -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.08, 0.14, 0.98), Color(0.4, 0.4, 0.55, 0.6), 14, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 104)
	art.draw.connect(_draw_art.bind(art, {"id": "crystals"}))
	v.add_child(art)
	var n := UI.label(v, "Acheter des cristaux", 22, Color(0.7, 0.75, 0.9))
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(0, 54)
	var dsc := UI.label(v, "Paiement bientôt disponible.", 16, UI.MUTED)
	dsc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dsc.custom_minimum_size = Vector2(0, 40)
	var b := UI.button(v, "Bientôt", 24, "ghost")
	b.disabled = true
	b.custom_minimum_size = Vector2(0, 58)
	return p


## Illustration d'un article : coffre de sa rareté, jetons ou cristal.
func _draw_art(art: Control, it: Dictionary) -> void:
	var c := Vector2(art.size.x * 0.5, 100.0)
	match String(it.id):
		"chest_rare":
			Art.draw_chest(art, c, 0.56, "rare", _t, 0.0, 0.0)
		"chest_epic":
			Art.draw_chest(art, c, 0.56, "epique", _t, 0.0, 0.0)
		"free_chest":
			Art.draw_chest(art, c, 0.56, "commun", _t, 0.0, 0.0)
		"token1", "token10":
			var n := 1 if it.id == "token1" else 3
			for i in n:
				_token(art, c + Vector2((i - (n - 1) * 0.5) * 46.0, -38.0 - 6.0 * (i % 2)))
		"crystals":
			var m := c + Vector2(0, -46.0)
			art.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -42), m + Vector2(32, 0), m + Vector2(0, 42), m + Vector2(-32, 0)]), Color(0.45, 0.4, 0.55))
			art.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -42), m + Vector2(32, 0), m]), Color(0.6, 0.55, 0.7))


func _token(art: Control, c: Vector2) -> void:
	Art.rrect(art, Rect2(c + Vector2(-26, -17), Vector2(52, 34)), 8.0, Color(0.48, 0.28, 0.84))
	Art.rrect(art, Rect2(c + Vector2(-22, -13), Vector2(44, 26)), 6.0, Color(0.7, 0.55, 1.0))
	art.draw_circle(c, 8.0, Color(0.16, 0.08, 0.31))


func _process(delta: float) -> void:
	_t += delta
	_refresh()


func _refresh() -> void:
	_crystals.text = "◆ %d" % Game.crystals
	_tokens.text = "● %d" % Game.tokens
	_credits.text = "¢ %s" % Data.fmt(Game.credits)
	var ready := Game.free_chest_ready()
	_free_btn.disabled = not ready
	_free_sub.text = "Prêt à ouvrir !" if ready else "Prochain dans %s" % UI.duration(Game.free_chest_remaining())
	for it in Data.SHOP_ITEMS:
		var b: Button = _buttons[it.id]
		b.disabled = Game.crystals < int(it.cost) or (it.has("free_chest") and Game.free_chest_remaining() <= 0.0)
