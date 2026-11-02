class_name HeroScreen
extends Overlay
## Fiche d'un héros : statistiques, pouvoir, étoiles (fragments) et choix de l'emplacement dans l'escouade.

signal changed


func _init(id: String) -> void:
	super._init(660.0)
	var h: Dictionary = Data.HEROES[id]
	var have := Game.is_owned(id)
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var ic := HeroIcon.new()
	ic.hero = h
	ic.custom_minimum_size = Vector2(130, 130)
	ic.modulate = Color.WHITE if have else Color(0.3, 0.3, 0.36)
	top.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	top.add_child(v)
	UI.label(v, h.name, 32, rc)
	UI.label(v, "%s · %s · %s" % [h.job, Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role]], 20, UI.MUTED)
	UI.label(v, "Rareté : %s" % Data.RARITY_NAMES_HERO[h.rarity], 20, rc)
	if have:
		var st: int = Game.hero_stars[id]
		UI.label(v, "%s   niveau %d%s" % ["★".repeat(st) + "☆".repeat(Data.MAX_STARS - st), Game.levels[id], ["", " · palier II", " · palier III"][Game.tier(id)]], 22, UI.GOLD)
	else:
		UI.label(v, "Non recruté", 22, UI.RED)
	var lv: int = Game.levels[id]
	var m: float = Data.hero_mult(lv) * Data.star_mult(Game.hero_stars[id]) * Data.EVO_STAT_MULT[Game.tier(id)]
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), UI.LINE, 12, 12))
	box.add_child(sp)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	sp.add_child(sv)
	UI.label(sv, "PV %d    ATQ %d    DÉF %d" % [h.hp * m, h.atk * m, h.def * m], 24, Color.WHITE)
	UI.label(sv, "Pouvoir : %s" % h.skill.name, 24, UI.ACCENT)
	var d := UI.label(sv, "%s Recharge %d s." % [h.skill.desc, int(h.skill.cd)], 19, Color(0.85, 0.92, 1.0))
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if have and int(Game.hero_stars[id]) < Data.MAX_STARS:
		var cost := Game.star_cost(id)
		var fr: int = Game.fragments[id]
		var row := HBoxContainer.new()
		box.add_child(row)
		var l := UI.label(row, "Fragments : %d / %d" % [fr, cost], 22, Color.WHITE)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var up := UI.button(row, "★ Monter d'une étoile", 22, "gold")
		up.custom_minimum_size = Vector2(250, 60)
		up.disabled = not Game.can_star_up(id)
		up.pressed.connect(func():
			if Game.star_up(id):
				Sfx.play("chest")
				changed.emit()
				close())
		UI.label(box, "Les doublons obtenus au recrutement donnent des fragments. Chaque étoile : + 12 % de statistiques et de puissance du pouvoir.", 17, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif have:
		UI.label(box, "Étoiles au maximum.", 20, UI.GOLD)
	if have:
		UI.label(box, "Placer dans l'escouade :", 22, Color.WHITE)
		var slots := HBoxContainer.new()
		slots.add_theme_constant_override("separation", 6)
		box.add_child(slots)
		for i in Data.SQUAD_SIZE:
			var cur: String = Game.squad[i]
			var here := cur == id
			var b := UI.button(slots, "%d%s" % [i + 1, "\n(ici)" if here else "\n" + Data.HEROES[cur].name.split(" ")[0]], 17, "main" if here else "ghost")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 70)
			b.pressed.connect(func():
				if Game.set_slot(i, id):
					changed.emit()
					close())
		UI.label(box, "1 à 3 : première ligne (les plus visés). 4 et 5 : deuxième ligne.", 17, UI.MUTED)
	else:
		UI.label(box, "Recrute ce héros avec des jetons : le tirage est ouvert à tous les héros.", 20, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cl := UI.button(box, "Fermer", 24, "ghost")
	cl.custom_minimum_size = Vector2(0, 58)
	cl.pressed.connect(close)
