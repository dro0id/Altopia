class_name BoostScreen
extends Overlay
## Choix d'un renfort parmi trois, actif jusqu'au prochain boss.

signal picked(id: String)

var offer: Array = []


func _init(p_offer: Array, next_boss: int) -> void:
	super._init(640.0)
	offer = p_offer
	centered("CHOISIS UN RENFORT", 36, UI.ACCENT)
	centered("Actif jusqu'au boss de l'étage %d" % next_boss, 22, UI.MUTED)
	for id in offer:
		var b: Dictionary = Data.BOOSTS[id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), b.color, 14, 12))
		box.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)
		var ic := BoostIcon.new()
		ic.boost = id
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(v)
		UI.label(v, b.name, 28, b.color)
		var d := UI.label(v, b.desc, 20, Color(0.85, 0.92, 1.0))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var go := UI.button(h, "Choisir", 24, "main")
		go.custom_minimum_size = Vector2(150, 70)
		go.pressed.connect(func():
			picked.emit(id)
			close())
	if not Game.boosts.is_empty():
		var names: Array = []
		for id in Game.boosts:
			names.append(Data.BOOSTS[id].name)
		centered("Déjà actifs : %s" % ", ".join(names), 18, UI.MUTED)
