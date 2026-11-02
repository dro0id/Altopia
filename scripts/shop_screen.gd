class_name ShopScreen
extends Overlay
## Boutique : on dépense des cristaux d'Altopia (gagnés sur les gros boss). L'achat de cristaux contre de l'argent réel viendra avec la publication.

signal bought(text: String)

var _crystals: Label
var _buttons := {}


func _init() -> void:
	super._init(660.0)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := UI.label(head, "Boutique", 34, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := UI.button(head, "Fermer", 22, "ghost")
	x.pressed.connect(close)
	_crystals = UI.label(box, "", 28, Color(0.5, 0.86, 1.0))
	for it in Data.SHOP_ITEMS:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), UI.LINE, 12, 10))
		box.add_child(p)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		UI.label(v, it.name, 24, Color.WHITE)
		UI.label(v, it.desc, 18, UI.MUTED)
		var b := UI.button(h, "%d ◆" % int(it.cost), 24, "gold")
		b.custom_minimum_size = Vector2(130, 62)
		b.pressed.connect(func():
			var msg: String = Game.buy(it.id)
			if msg != "":
				Sfx.play("coin")
				Game.save_game()
				bought.emit(msg)
			_refresh())
		_buttons[it.id] = b
	var real := PanelContainer.new()
	real.add_theme_stylebox_override("panel", UI.box(Color(0.1, 0.1, 0.16, 0.98), Color(0.4, 0.4, 0.55, 0.6), 12, 12))
	box.add_child(real)
	var rv := VBoxContainer.new()
	real.add_child(rv)
	UI.label(rv, "Cristaux d'Altopia", 24, Color(0.7, 0.75, 0.9))
	var soon := UI.button(rv, "Acheter des cristaux : bientôt", 22, "ghost")
	soon.disabled = true
	soon.custom_minimum_size = Vector2(0, 58)
	var d := UI.label(rv, "Les achats avec de l'argent réel arriveront avec la publication du jeu. En attendant, les gros boss rapportent des cristaux.", 17, UI.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh()


func _refresh() -> void:
	_crystals.text = "Cristaux : %d ◆   ·   Jetons : %d" % [Game.crystals, Game.tokens]
	for it in Data.SHOP_ITEMS:
		var b: Button = _buttons[it.id]
		b.disabled = Game.crystals < int(it.cost) or (it.has("free_chest") and Game.free_chest_remaining() <= 0.0)
