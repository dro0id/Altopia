class_name EvolveScreen
extends Overlay
## Palier d'évolution d'un héros : plus de puissance pour son pouvoir et ses statistiques, payé en crédits et éclats de verre.

signal evolved


func _init(id: String) -> void:
	super._init(640.0)
	var h: Dictionary = Data.HEROES[id]
	var tier: int = Game.tier(id)
	var lv: int = Game.levels[id]
	centered("PALIER D'ÉVOLUTION", 22, UI.GOLD)
	centered("%s · niveau %d" % [h.name, lv], 36, Color.WHITE)
	var icon := HeroIcon.new()
	icon.hero = h
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), UI.LINE, 12, 14))
	box.add_child(pan)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pan.add_child(v)
	var roman := ["", " II", " III"]
	UI.label(v, "%s%s" % [h.skill.name, roman[tier + 1]], 28, UI.ACCENT)
	_row(v, "Puissance du pouvoir", "×%.1f  →  ×%.1f" % [Data.EVO_SKILL_MULT[tier], Data.EVO_SKILL_MULT[tier + 1]])
	_row(v, "Statistiques", "+%d %%  →  +%d %%" % [int(round((Data.EVO_STAT_MULT[tier] - 1.0) * 100.0)), int(round((Data.EVO_STAT_MULT[tier + 1] - 1.0) * 100.0))])
	if h.skill.kind == "gravity":
		_row(v, "Étourdissement", "%.1f s  →  %.1f s" % [2.0 + 0.5 * tier, 2.0 + 0.5 * (tier + 1)])
	var cost: Dictionary = Game.evolve_cost(id)
	var ok_c: bool = Game.credits >= cost.credits
	var ok_s: bool = Game.shards >= cost.shards
	var cr := HBoxContainer.new()
	box.add_child(cr)
	var l := UI.label(cr, "Coût", 26, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(cr, "%s cr" % Data.fmt(cost.credits), 26, UI.GOLD if ok_c else UI.RED)
	UI.label(cr, "  ·  %d éclats" % int(cost.shards), 26, Color(0.5, 0.86, 1.0) if ok_s else UI.RED)
	var go := UI.button(box, "Évoluer", 30, "gold")
	go.custom_minimum_size = Vector2(0, 72)
	go.disabled = not (ok_c and ok_s)
	go.pressed.connect(func():
		if Game.evolve(id):
			Sfx.play("chest")
			evolved.emit()
			close())
	if not (ok_c and ok_s):
		centered("Il manque %s%s. Vaincs des étages pour gagner des crédits et des éclats de verre." % ["" if ok_c else "des crédits", "" if ok_s else (" et des éclats" if not ok_c else "des éclats")], 19, UI.MUTED)
	var later := UI.button(box, "Plus tard", 22, "ghost")
	later.custom_minimum_size = Vector2(0, 56)
	later.pressed.connect(close)


func _row(parent: Node, a: String, b: String) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var l := UI.label(h, a, 22, UI.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(h, b, 24, UI.GREEN)
