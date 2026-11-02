class_name CollectionScreen
extends Overlay
## Collection de héros : escouade de cinq emplacements, synergies actives et grille des 15 héros.

signal squad_changed

var _syn_label: Label
var _slots: HBoxContainer
var _grid: GridContainer


func _init() -> void:
	super._init(690.0)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := UI.label(head, "Collection · %d / %d" % [Game.owned.size(), Data.ALL_HEROES.size()], 32, UI.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := UI.button(head, "Fermer", 22, "ghost")
	x.pressed.connect(close)
	UI.label(box, "Escouade (emplacement 1 : cible principale des ennemis)", 20, UI.MUTED)
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 6)
	box.add_child(_slots)
	_syn_label = UI.label(box, "", 20, UI.GREEN)
	_syn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 640)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sc)
	DragScroll.attach(sc)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_grid)
	_rebuild()


func _rebuild() -> void:
	for c in _slots.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	for i in Data.SQUAD_SIZE:
		var id: String = Game.squad[i]
		var h: Dictionary = Data.HEROES[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(122, 128)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rc: Color = Data.RARITY_COLORS[h.rarity]
		b.add_theme_stylebox_override("normal", UI.box(Color(0.07, 0.14, 0.24), rc, 10, 4))
		b.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.2, 0.32), Color.WHITE, 10, 4))
		b.add_theme_stylebox_override("pressed", UI.box(Color(0.13, 0.26, 0.4), Color.WHITE, 10, 4))
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var ic := HeroIcon.new()
		ic.hero = h
		ic.custom_minimum_size = Vector2(70, 70)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ic)
		var l := UI.label(v, "%d · %s" % [i + 1, h.name.split(" ")[0]], 17, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l2 := UI.label(v, "niv. %d" % Game.levels[id], 16, UI.MUTED)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func(): _open_hero(id))
		_slots.add_child(b)
	var syn: Array = Game.synergy().list
	if syn.is_empty():
		_syn_label.text = "Aucune synergie : mélange les espèces et les rôles."
		_syn_label.add_theme_color_override("font_color", UI.MUTED)
	else:
		var parts: Array = []
		for s in syn:
			parts.append("%s (%s)" % [s.name, s.desc])
		_syn_label.text = "Synergies : " + " · ".join(parts)
		_syn_label.add_theme_color_override("font_color", UI.GREEN)
	for id in Data.ALL_HEROES:
		_grid.add_child(_card(id))


func _card(id: String) -> Control:
	var h: Dictionary = Data.HEROES[id]
	var have := Game.is_owned(id)
	var rc: Color = Data.RARITY_COLORS[h.rarity]
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", UI.box(Color(0.06, 0.12, 0.21, 0.98), rc if have else Color(0.25, 0.32, 0.42), 12, 6))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.1, 0.2, 0.32), Color.WHITE, 12, 6))
	b.add_theme_stylebox_override("pressed", UI.box(Color(0.13, 0.26, 0.4), Color.WHITE, 12, 6))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := HeroIcon.new()
	ic.hero = h
	ic.custom_minimum_size = Vector2(80, 80)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if have else Color(0.25, 0.25, 0.3)
	v.add_child(ic)
	var nm := UI.label(v, h.name if have else "???", 20, rc if have else UI.MUTED)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ""
	if have:
		var st: int = Game.hero_stars[id]
		line = "★".repeat(st) + "☆".repeat(Data.MAX_STARS - st)
	else:
		line = "Non recruté · %s" % Data.RARITY_NAMES_HERO[h.rarity]
	var l2 := UI.label(v, line, 18, UI.GOLD if have else UI.MUTED)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if have and int(Game.hero_stars[id]) < Data.MAX_STARS:
		var need := Game.star_cost(id)
		var l3 := UI.label(v, "%d / %d fragments" % [Game.fragments[id], need], 15, UI.GREEN if Game.can_star_up(id) else UI.MUTED)
		l3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(func(): _open_hero(id))
	return b


func _open_hero(id: String) -> void:
	var hs := HeroScreen.new(id)
	hs.changed.connect(func():
		squad_changed.emit()
		_rebuild())
	hs.tree_exited.connect(_rebuild)
	get_parent().add_child(hs)
