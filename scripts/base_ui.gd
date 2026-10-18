extends RefCounted
## Interface de la Base AFK, d'après la maquette validée : vue station (salles), fiche de salle, Atelier, Labo, Rang
## et rapport de retour hors ligne. Les pages Capitaine, Équipage, Expéditions et Vaisseau restent dans main.gd.

const Data = preload("res://scripts/game_data.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const UiIcons = preload("res://scripts/ui_icons.gd")
const Ring = preload("res://scripts/ring.gd")
const DashFrame = preload("res://scripts/dash_frame.gd")
const DashPanel = preload("res://scripts/dash_panel.gd")

const PANEL := Color(0.04, 0.12, 0.2, 0.86)
const SHEET := Color(0.027, 0.078, 0.165)
const INK := Color(0.02, 0.035, 0.1)
const LINE := Color(0.22, 0.9, 1.0, 0.42)
const FAINT := Color(0.114, 0.329, 0.408)          # #1d5468 : filets des éléments inactifs
const DIM := UiTheme.DIM
const TEXT := UiTheme.TEXT
const ACCENT := UiTheme.ACCENT
const GOOD := UiTheme.GOOD
const WARN := UiTheme.WARN
const MAGENTA := UiTheme.MAGENTA
const GOLD := Color(1.0, 0.82, 0.35)
const BTN := Color(0.106, 0.435, 0.549)             # #1b6f8c : bouton principal
const BTN_ACTIVE := Color(0.07, 0.26, 0.36)         # #12425c : élément sélectionné
const AVATARS := [Color("e0866a"), Color("7aa8ff"), Color("9be8c0"), Color("ff9bed"), Color("f6c177"), Color("e8c06a"), Color("b69bff"), Color("6fd3e8"), Color("ff8f8f")]
const SLOT_SHORT := {"weapon": "Arme", "helmet": "Casque", "suit": "Combi", "gloves": "Gants", "boots": "Bottes", "module": "Module"}
const TILE_NAMES := {"labo": "Labo données"}
const SECTIONS := [["salles", "Salles"], ["atelier", "Atelier"], ["lab", "Labo"], ["ship", "Vaisseau"], ["rang", "Rang"]]
## Lignes de recherche affichées dans « Parcours des lignes » : nom, couleur, paliers.
const LINES := [
	["Production", Color(1.0, 0.82, 0.35), ["calibrage", "calibrage_ii", "calibrage_iii", "calibrage_iv"]],
	["Expéditions", Color(0.5, 0.95, 1.0), ["cartographie", "cartographie_ii", "cartographie_iii", "cartographie_iv"]],
	["Butin", Color(1.0, 0.61, 0.93), ["butin", "butin_ii", "butin_iii", "butin_iv"]],
	["Entraînement", Color(0.43, 1.0, 0.61), ["entrainement", "entrainement_ii", "entrainement_iii"]],
]

var main: Control
var sections := {}                 # id -> VBoxContainer
var current := "salles"
var _pills := {}

# vue station
var _pulse_dot: PanelContainer
var _pulse_state: Label
var _pulse_big: Label
var _pulse_small: Label
var _pulse_eff: Label
var _pulse_cap: Label
var _tiles := {}
var _hub_ring: Control
var _hub_atelier: Label
var _hub_last: Label
var _goal_label: Label
var _goal_count: Label
var _goal_bar: ProgressBar
var _goal_claim: Button

# fiche de salle
var _sheet: Control
var _sheet_room := ""
var _sheet_sig := ""
var _sh := {}

# Atelier
var _at_ring: Control
var _at_time: Label
var _at_head: Label
var _at_rate: Label
var _at_worker: Label
var _at_worker_row: HBoxContainer
var _at_avatar_slot: HBoxContainer
var _at_avatar_hero := "?"
var _at_penalty: Label
var _at_slot_btns := {}
var _at_focus_btns := {}
var _at_cap_title: Label
var _at_cap_value: Label
var _at_cap_bar: ProgressBar
var _at_cap_text: Label
var _at_odds_bar: HBoxContainer
var _at_odds_text: HFlowContainer
var _at_log_box: VBoxContainer
var _at_log_sig := ""

# Labo
var _lab_sub: Label
var _lab_auto: CheckButton
var _lab_cards: Array = []
var _lab_queue_box: HFlowContainer
var _lab_queue_sig := "?"
var _lab_lines: Array = []
var _lab_catalog := {}
var _lab_premium_btns := {}
var _lab_crystals: Label

# Rang
var _rk_ring: Control
var _rk_rank: Label
var _rk_shards: Label
var _rk_record: Label
var _rk_power: Label
var _rk_keep: Label
var _rk_btn: Button
var _rk_btn_l1: Label
var _rk_btn_l2: Label
var _rk_armed_at := -100000
var _rk_perks := {}
var _rk_goal_title: Label
var _rk_goal_count: Label
var _rk_goal_bar: ProgressBar
var _rk_goal_reward: Label
var _rk_goal_btn: Button


func _init(m: Control) -> void:
	main = m


## ---------- Petits composants ----------

func _f(px: float) -> int:
	return int(round(px * 1.65))


func _g(px: float) -> int:
	return int(round(px * 1.8))


func _label(parent: Node, text: String, px: float, color: Color = TEXT, mono: bool = false, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _f(px))
	l.add_theme_color_override("font_color", color)
	if mono:
		l.add_theme_font_override("font", UiTheme.mono())
	elif bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _box(fill: Color, border: Color, radius_px: float, border_w: int = 1, pad_px: float = 12.0) -> StyleBoxFlat:
	return UiTheme.box(fill, border, _g(radius_px), border_w, _g(pad_px))


func _panel(parent: Node, fill: Color, border: Color, radius_px: float = 14.0, pad_px: float = 12.0, border_w: int = 1) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", _box(fill, border, radius_px, border_w, pad_px))
	parent.add_child(p)
	return p


func _vbox(parent: Node, gap_px: float = 8.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", _g(gap_px))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v


func _hbox(parent: Node, gap_px: float = 8.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", _g(gap_px))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(h)
	return h


func _spacer(parent: Node) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _bar(parent: Node, height_px: float, color: Color, track: Color = Color(0.04, 0.12, 0.2, 1.0)) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(0, _g(height_px))
	b.show_percentage = false
	b.max_value = 1.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("fill", UiTheme.box(color, Color(0, 0, 0, 0), _g(4), 0, 0))
	b.add_theme_stylebox_override("background", UiTheme.box(track, Color(0, 0, 0, 0), _g(4), 0, 0))
	parent.add_child(b)
	return b


func _caption(parent: Node, text: String) -> Label:
	var l := _label(parent, text, 14, DIM)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _ring(parent: Node, size_px: float, color: Color, thick_px: float) -> Control:
	var r: Control = Ring.new()
	r.custom_minimum_size = Vector2(_g(size_px), _g(size_px))
	r.color = color
	r.thickness = float(_g(thick_px))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _avatar(parent: Node, hero_id: String, size_px: float) -> PanelContainer:
	var idx := maxi(0, Data.HERO_ORDER.find(hero_id))
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(_g(size_px), _g(size_px))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := UiTheme.box(AVATARS[idx % AVATARS.size()], Color(0, 0, 0, 0), _g(size_px) / 2, 0, 0)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = String(Data.HEROES[hero_id].name).left(1)
	l.add_theme_font_size_override("font_size", _f(size_px * 0.5))
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_override("font", UiTheme.font(true))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	parent.add_child(p)
	return p


func _icon(parent: Node, name: String, color: Color, px: float) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = UiIcons.icon(name, _g(px), color)
	ic.custom_minimum_size = Vector2(_g(px), _g(px))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ic)
	return ic


## Bouton « verre » : fond, filet et texte réglables (normal / survol / appui identiques).
func _button(parent: Node, text: String, px: float, fill: Color, border: Color, text_color: Color, height_px: float = 0.0, radius_px: float = 10.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_font_size_override("font_size", _f(px))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(c, text_color if c != "font_disabled_color" else text_color.darkened(0.35))
	_style_button(b, fill, border, radius_px)
	if height_px > 0.0:
		b.custom_minimum_size = Vector2(0, _g(height_px))
	parent.add_child(b)
	return b


func _style_button(b: Button, fill: Color, border: Color, radius_px: float = 10.0) -> void:
	var sb := UiTheme.box(fill, border, _g(radius_px), 1, _g(6))
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var off := UiTheme.box(fill.darkened(0.2), border.darkened(0.3), _g(radius_px), 1, _g(6))
	b.add_theme_stylebox_override("disabled", off)


func _pill(parent: Node, text: String, active: bool) -> Button:
	var b := _button(parent, text, 16, BTN if active else Color(0, 0, 0, 0), ACCENT if active else FAINT, TEXT if active else DIM, 0.0, 22.0)
	b.add_theme_font_override("font", UiTheme.font(active))
	b.custom_minimum_size = Vector2(0, _g(36))
	return b


func _dash(parent: Control, color: Color) -> Control:
	var d: Control = DashFrame.new()
	d.color = color
	d.radius = float(_g(14))
	d.width = float(maxi(2, _g(1.2)))
	d.dash = float(_g(7))
	d.gap = float(_g(5))
	parent.add_child(d)
	return d


func _short(res_id: String) -> String:
	return {"credits": "cr", "minerals": "min", "energy": "én", "data": "don"}.get(res_id, res_id)


## Entier avec espaces entre les milliers (comme la maquette : « 1 104 ») ; au-delà du million, notation abrégée.
func _spaced(v: float) -> String:
	if absf(v) >= 1.0e6:
		return Data.fmt(v)
	var digits := str(absi(int(round(v))))
	var out := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += " "
		out += digits[i]
	return ("-" if v < 0.0 else "") + out


func _num(v: float, decimals: int = 1) -> String:
	var t := String.num(v, decimals)
	return t.replace(".", ",")


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for r in Data.RES_ORDER:
		if cost.has(r) and cost[r] > 0.0:
			parts.append("%s %s" % [Data.fmt(cost[r]), _short(r)])
	return " · ".join(parts)


func _hero_tag(rid: String, hid: String) -> String:
	if Data.HEROES[hid].get("specialty", "") == rid:
		return "spécialité"
	if Data.HEROES[hid]["class"] == Data.ROOMS[rid].affinity:
		return "affinité"
	return ""


## ---------- Navigation ----------

## Rangée de pastilles Salles · Atelier · Labo · Vaisseau · Rang (sous les ressources).
func build_subnav(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", _g(6))
	parent.add_child(row)
	for entry in SECTIONS:
		var id: String = entry[0]
		var b := _pill(row, entry[1], id == current)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(main._tap(func(): show_section(id)))
		_pills[id] = b
	return row


func show_section(id: String) -> void:
	if not sections.has(id):
		id = "salles"
	current = id
	for k in sections:
		sections[k].visible = (k == id)
	for k in _pills:
		var active: bool = (k == id)
		var b: Button = _pills[k]
		_style_button(b, BTN if active else Color(0, 0, 0, 0), ACCENT if active else FAINT, 22.0)
		b.add_theme_font_override("font", UiTheme.font(active))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, TEXT if active else DIM)
	if main.has_method("_base_section_changed"):
		main._base_section_changed(id)


## Crée les cinq sous-pages dans la page « Base » ; la page Vaisseau est remplie par main.gd.
func build_sections(page: VBoxContainer) -> void:
	for entry in SECTIONS:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", _g(10))
		page.add_child(v)
		sections[entry[0]] = v
	_build_hub(sections["salles"])
	_build_atelier(sections["atelier"])
	_build_lab(sections["lab"])
	_build_rank(sections["rang"])
	show_section("salles")


## ---------- Vue station ----------

func _build_hub(sec: VBoxContainer) -> void:
	var pulse := _panel(sec, PANEL, LINE, 14.0, 12.0)
	var row := _hbox(pulse, 12.0)
	_pulse_dot = PanelContainer.new()
	_pulse_dot.custom_minimum_size = Vector2(_g(10), _g(10))
	_pulse_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pulse_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pulse_dot)
	var mid := _vbox(row, 0.0)
	_pulse_state = _label(mid, "", 13, DIM)
	_pulse_big = _label(mid, "", 26, GOLD, true)
	_pulse_small = _label(mid, "", 12, DIM, true)
	var right := _vbox(row, 0.0)
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	var l1 := _label(right, "Hors ligne", 12, DIM)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pulse_eff = _label(right, "", 15, TEXT, true)
	_pulse_eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pulse_cap = _label(right, "", 12, DIM, true)
	_pulse_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", _g(10))
	grid.add_theme_constant_override("v_separation", _g(10))
	sec.add_child(grid)
	for rid in Data.ROOM_ORDER:
		_build_tile(grid, rid)

	var strip := _panel(sec, PANEL, Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5), 14.0, 10.0)
	var srow := _hbox(strip, 12.0)
	_hub_ring = _ring(srow, 46.0, MAGENTA, 5.0)
	var stext := _vbox(srow, 0.0)
	_hub_atelier = _wrap(_label(stext, "", 15, TEXT, false, true))
	_hub_last = _wrap(_label(stext, "", 12, DIM, true))

	var goal := _panel(sec, Color(0, 0, 0, 0), FAINT, 14.0, 9.0)
	var gv := _vbox(goal, 6.0)
	var grow := _hbox(gv, 8.0)
	_goal_label = _label(grow, "", 14, DIM)
	_goal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_label.clip_text = true
	_goal_count = _label(grow, "", 14, ACCENT, true)
	_goal_bar = _bar(gv, 8.0, MAGENTA)
	_goal_claim = _button(gv, "Récupérer la récompense", 16, BTN, ACCENT, TEXT, 44.0)
	_goal_claim.clip_text = true
	_goal_claim.pressed.connect(main._tap(func(): GameState.claim_goal()))


func _build_tile(grid: GridContainer, rid: String) -> void:
	var r: Dictionary = Data.ROOMS[rid]
	var color: Color = r.color
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, _g(100))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, _box(PANEL, color, 14.0, 1, 0.0))
	b.pressed.connect(main._tap(func(): open_room(rid)))
	grid.add_child(b)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = _g(10)
	inner.offset_right = -_g(10)
	inner.offset_top = _g(9)
	inner.offset_bottom = -_g(9)
	inner.add_theme_constant_override("separation", _g(4))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var head := _hbox(inner, 8.0)
	_icon(head, r.icon, color, 26.0)
	var name_l := _label(head, String(TILE_NAMES.get(rid, r.name)), 15, TEXT, false, true)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	var lvl := _label(head, "", 11, DIM, true)
	# équipier en poste
	var who := _hbox(inner, 8.0)
	var avatar_slot := HBoxContainer.new()
	avatar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	who.add_child(avatar_slot)
	var who_name := _label(who, "", 15, TEXT)
	var who_tag := _label(who, "", 12, GOLD)
	var out := _wrap(_label(inner, "", 12, GOOD, true))
	# salle vide
	var empty_note := _wrap(_label(inner, "Aucun équipier : la salle est à l'arrêt.", 14, WARN))
	var empty_btn := _panel(inner, Color(0, 0, 0, 0), WARN, 8.0, 2.0)
	empty_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ebl := _label(empty_btn, "Affecter quelqu'un", 14, WARN, false, true)
	ebl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dash := _dash(b, WARN)
	_tiles[rid] = {"btn": b, "lvl": lvl, "who": who, "avatar_slot": avatar_slot, "who_name": who_name, "who_tag": who_tag, "out": out,
		"empty_note": empty_note, "empty_btn": empty_btn, "dash": dash, "worker": "?"}


## ---------- Atelier ----------

func _build_atelier(sec: VBoxContainer) -> void:
	var card := _panel(sec, PANEL, Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5), 16.0, 14.0)
	var row := _hbox(card, 16.0)
	var ring_box := Control.new()
	ring_box.custom_minimum_size = Vector2(_g(128), _g(128))
	ring_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ring_box)
	_at_ring = _ring(ring_box, 128.0, MAGENTA, 10.0)
	_at_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_box.add_child(center)
	_at_time = _label(center, "", 28, TEXT, true)
	_at_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(center, "prochain objet", 13, DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var col := _vbox(row, 4.0)
	_at_head = _label(col, "", 13, DIM)
	_at_rate = _label(col, "", 20, TEXT, true)
	_at_worker_row = _hbox(col, 8.0)
	_at_avatar_slot = HBoxContainer.new()
	_at_avatar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_at_worker_row.add_child(_at_avatar_slot)
	_at_worker = _wrap(_label(_at_worker_row, "", 15, TEXT))
	_at_penalty = _wrap(_label(col, "", 13, WARN))

	_caption(sec, "EMPLACEMENT VISÉ")
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", _g(6))
	sec.add_child(slots)
	for sl in Data.EQUIP_SLOTS:
		var b := _button(slots, SLOT_SHORT[sl], 14, Color(0, 0, 0, 0), FAINT, DIM, 44.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", _f(13))
		b.pressed.connect(main._tap(func():
			GameState.atelier_slot = "" if GameState.atelier_slot == sl else sl
			GameState.changed.emit()))
		_at_slot_btns[sl] = b
	_caption(sec, "BONUS GARANTI")
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", _g(6))
	chips.add_theme_constant_override("v_separation", _g(6))
	sec.add_child(chips)
	for k in Data.AFFIX_ORDER:
		var b := _button(chips, String(Data.AFFIXES[k].name), 14, Color(0, 0, 0, 0), FAINT, DIM, 38.0, 20.0)
		b.pressed.connect(main._tap(func():
			GameState.atelier_focus = "" if GameState.atelier_focus == k else k
			GameState.changed.emit()))
		_at_focus_btns[k] = b
	var rnd := _button(chips, "Au hasard", 14, Color(0, 0, 0, 0), FAINT, DIM, 38.0, 20.0)
	rnd.pressed.connect(main._tap(func():
		GameState.atelier_focus = ""
		GameState.changed.emit()))
	_at_focus_btns[""] = rnd

	var cap := _panel(sec, Color(WARN.r, WARN.g, WARN.b, 0.07), Color(WARN.r, WARN.g, WARN.b, 0.6), 14.0, 10.0)
	var cv := _vbox(cap, 6.0)
	var chead := _hbox(cv, 6.0)
	_at_cap_title = _label(chead, "Plafond de niveau d'objet", 16, WARN, false, true)
	_at_cap_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_at_cap_value = _label(chead, "", 14, TEXT, true)
	_at_cap_bar = _bar(cv, 8.0, WARN)
	_at_cap_text = _wrap(_label(cv, "", 13, TEXT))

	_caption(sec, "CHANCES PAR OBJET")
	_at_odds_bar = HBoxContainer.new()
	_at_odds_bar.add_theme_constant_override("separation", 0)
	_at_odds_bar.custom_minimum_size = Vector2(0, _g(14))
	sec.add_child(_at_odds_bar)
	_at_odds_text = HFlowContainer.new()
	_at_odds_text.add_theme_constant_override("h_separation", _g(12))
	sec.add_child(_at_odds_text)
	_caption(sec, "DERNIÈRES FABRICATIONS")
	_at_log_box = _vbox(sec, 6.0)


## ---------- Labo ----------

func _build_lab(sec: VBoxContainer) -> void:
	var head := _hbox(sec, 10.0)
	var hv := _vbox(head, 0.0)
	_label(hv, "Recherches", 26, TEXT, false, true)
	_lab_sub = _wrap(_label(hv, "", 13, DIM, true))
	_lab_sub.custom_minimum_size = Vector2(_g(60), 0)
	var autop := _panel(head, Color(0, 0, 0, 0), FAINT, 22.0, 6.0)
	autop.size_flags_horizontal = Control.SIZE_SHRINK_END
	_lab_auto = CheckButton.new()
	_lab_auto.text = "Auto"
	_lab_auto.add_theme_font_size_override("font_size", _f(14))
	_lab_auto.mouse_filter = Control.MOUSE_FILTER_PASS
	_lab_auto.toggled.connect(func(v: bool):
		if main._dragged:
			_lab_auto.set_pressed_no_signal(not v)
		else:
			GameState.set_research_auto(v))
	autop.add_child(_lab_auto)
	# cartes des postes (jusqu'à 3)
	for i in 3:
		var card := DashPanel.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.dash_radius = float(_g(14))
		card.dash_len = float(_g(7))
		card.dash_gap = float(_g(5))
		card.dash_width = float(maxi(2, _g(1.2)))
		card.add_theme_stylebox_override("panel", _box(PANEL, FAINT, 14.0, 1, 10.0))
		sec.add_child(card)
		var v := _vbox(card, 6.0)
		var top := _hbox(v, 6.0)
		var title := _label(top, "", 18, TEXT, false, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.size_flags_stretch_ratio = 1.5
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(_g(40), 0)
		var effect := _wrap(_label(top, "", 13, TEXT, true))
		effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		effect.custom_minimum_size = Vector2(_g(40), 0)
		var bar := _bar(v, 10.0, ACCENT)
		var bottom := _hbox(v, 8.0)
		var remain := _wrap(_label(bottom, "", 13, DIM, true))
		remain.custom_minimum_size = Vector2(_g(40), 0)
		var rush := _button(bottom, "", 14, Color(0, 0, 0, 0), FAINT, DIM, 38.0)
		rush.size_flags_horizontal = Control.SIZE_SHRINK_END
		var cancel := _button(bottom, "Annuler", 14, Color(0, 0, 0, 0), Color(0.6, 0.3, 0.3), Color(1.0, 0.55, 0.5), 38.0)
		cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
		var slot := {"card": card, "title": title, "effect": effect, "bar": bar, "remain": remain, "rush": rush, "cancel": cancel, "id": ""}
		_lab_cards.append(slot)
		rush.pressed.connect(main._tap(func(): GameState.boost_research(slot.id)))
		cancel.pressed.connect(main._tap(func(): GameState.cancel_research(slot.id)))
	_caption(sec, "FILE D'ATTENTE (PAYÉE D'AVANCE, ANNULABLE)")
	_lab_queue_box = HFlowContainer.new()
	_lab_queue_box.add_theme_constant_override("h_separation", _g(8))
	_lab_queue_box.add_theme_constant_override("v_separation", _g(8))
	sec.add_child(_lab_queue_box)
	_caption(sec, "PARCOURS DES LIGNES")
	for ln in LINES:
		var lrow := _hbox(sec, 10.0)
		var nm := _label(lrow, ln[0], 14, TEXT)
		nm.custom_minimum_size = Vector2(_g(92), 0)
		var segs := HBoxContainer.new()
		segs.add_theme_constant_override("separation", _g(4))
		segs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		segs.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lrow.add_child(segs)
		var bars := []
		for t in (ln[2] as Array).size():
			var bb := _bar(segs, 10.0, ln[1], Color(0.07, 0.19, 0.29, 1.0))
			bars.append(bb)
		var tag := _label(lrow, "", 12, DIM, true)
		_lab_lines.append({"bars": bars, "tag": tag, "ids": ln[2]})
	var note := _wrap(_label(sec, "Chaque recherche affiche son gain, son temps et son coût. Un poste libre est signalé en orange sur la Base.", 13, DIM))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# catalogue complet : c'est d'ici qu'on lance une recherche
	_caption(sec, "TOUTES LES RECHERCHES")
	for id in Data.RESEARCH_ORDER:
		var r: Dictionary = Data.RESEARCH[id]
		var panel := _panel(sec, PANEL, (r.color as Color).darkened(0.25), 14.0, 10.0)
		var col := _vbox(panel, 6.0)
		var top := _hbox(col, 8.0)
		var name_l := _label(top, "", 17, r.color, false, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		name_l.custom_minimum_size = Vector2(_g(40), 0)
		name_l.size_flags_stretch_ratio = 1.4
		var desc := _wrap(_label(top, "", 13, TEXT, true))
		desc.custom_minimum_size = Vector2(_g(40), 0)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var lb := _bar(col, 8.0, r.color)
		var btn := _button(col, "", 15, BTN, ACCENT, TEXT, 44.0)
		btn.clip_text = true
		btn.pressed.connect(main._tap(func(): GameState.start_research(id)))
		_lab_catalog[id] = {"name": name_l, "desc": desc, "bar": lb, "btn": btn}
	# déblocages en Cristaux
	_caption(sec, "CRISTAUX : DÉBLOCAGES SPÉCIAUX")
	var pp := _panel(sec, PANEL, Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5), 14.0, 10.0)
	var pv := _vbox(pp, 8.0)
	_lab_crystals = _wrap(_label(pv, "", 14, MAGENTA))
	for pid in Data.PREMIUM_UNLOCKS:
		var pb := _button(pv, "", 15, Color(0, 0, 0, 0), MAGENTA, MAGENTA, 46.0)
		pb.clip_text = true
		pb.pressed.connect(main._tap(func(): GameState.buy_premium(pid)))
		_lab_premium_btns[pid] = pb


## ---------- Rang (refonte) ----------

func _build_rank(sec: VBoxContainer) -> void:
	var top := _panel(sec, PANEL, Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5), 16.0, 12.0)
	var row := _hbox(top, 14.0)
	var ring_box := Control.new()
	ring_box.custom_minimum_size = Vector2(_g(72), _g(72))
	ring_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ring_box)
	_rk_ring = _ring(ring_box, 72.0, MAGENTA, 7.0)
	_rk_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var c := VBoxContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_box.add_child(c)
	var rl := _label(c, "RANG", 12, DIM)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rk_rank = _label(c, "", 26, TEXT, true)
	_rk_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var col := _vbox(row, 2.0)
	_rk_shards = _label(col, "", 22, MAGENTA, true)
	_rk_record = _wrap(_label(col, "", 14, DIM))

	var card := _panel(sec, PANEL, LINE, 16.0, 12.0)
	var v := _vbox(card, 8.0)
	var head := _hbox(v, 6.0)
	var t := _label(head, "Refonte de la Base", 18, TEXT, false, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rk_power = _label(head, "", 13, DIM, true)
	var cols := _hbox(v, 8.0)
	var lost := _panel(cols, Color(0, 0, 0, 0), Color(WARN.r, WARN.g, WARN.b, 0.5), 10.0, 7.0)
	var lv := _vbox(lost, 2.0)
	_label(lv, "REMIS À ZÉRO", 12, WARN)
	_rk_keep = _wrap(_label(lv, "", 14, TEXT))
	var kept := _panel(cols, Color(0, 0, 0, 0), Color(GOOD.r, GOOD.g, GOOD.b, 0.5), 10.0, 7.0)
	var kv := _vbox(kept, 2.0)
	_label(kv, "CONSERVÉ", 12, GOOD)
	_wrap(_label(kv, "Équipage et niveaux\nCapitaine et équipement\nRecherches, objectifs\nBonus permanents", 14, TEXT))
	_rk_btn = _button(v, "", 19, Color(0.48, 0.165, 0.55), MAGENTA, TEXT, 56.0, 12.0)
	_rk_btn.pressed.connect(main._tap(_on_rank_pressed))
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bl.alignment = BoxContainer.ALIGNMENT_CENTER
	bl.add_theme_constant_override("separation", 0)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rk_btn.add_child(bl)
	_rk_btn_l1 = _label(bl, "", 19, TEXT, false, true)
	_rk_btn_l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rk_btn_l2 = _label(bl, "", 13, Color(1.0, 0.82, 0.96), true)
	_rk_btn_l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrap(_label(v, "Tu ne gagnes que du nouveau : refaire la même Base ne rapporte rien, dépasse ton record pour gagner plus. Jamais obligatoire.", 13, DIM))

	_caption(sec, "BONUS PERMANENTS")
	for id in Data.PRESTIGE_PERK_ORDER:
		var perk: Dictionary = Data.PRESTIGE_PERKS[id]
		var p := _panel(sec, Color(0.04, 0.12, 0.2, 1.0), FAINT, 12.0, 8.0)
		var prow := _hbox(p, 10.0)
		var pc := _vbox(prow, 4.0)
		var ptop := _hbox(pc, 6.0)
		var pname := _label(ptop, String(perk.name), 16, TEXT, false, true)
		pname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var peff := _label(ptop, "", 12, MAGENTA, true)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", _g(2))
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(pips)
		var pip_bars := []
		for i in 6:
			var pb := _bar(pips, 6.0, MAGENTA, Color(0.07, 0.19, 0.29, 1.0))
			pip_bars.append(pb)
		var buy := _button(prow, "", 14, Color(0, 0, 0, 0), MAGENTA, MAGENTA, 44.0)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_END
		buy.custom_minimum_size.x = _g(86)
		buy.pressed.connect(main._tap(func(): GameState.buy_perk(id)))
		_rk_perks[id] = {"eff": peff, "pips": pip_bars, "buy": buy, "name": pname}
	var g := _panel(sec, Color(0, 0, 0, 0), Color(MAGENTA.r, MAGENTA.g, MAGENTA.b, 0.5), 14.0, 9.0)
	var gv := _vbox(g, 6.0)
	var grow := _hbox(gv, 8.0)
	_rk_goal_title = _label(grow, "", 14, DIM)
	_rk_goal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rk_goal_title.clip_text = true
	_rk_goal_count = _label(grow, "", 14, MAGENTA, true)
	_rk_goal_bar = _bar(gv, 8.0, MAGENTA)
	_rk_goal_reward = _wrap(_label(gv, "", 12, DIM, true))
	_rk_goal_btn = _button(gv, "Récupérer", 16, BTN, ACCENT, TEXT, 44.0)
	_rk_goal_btn.clip_text = true
	_rk_goal_btn.pressed.connect(main._tap(func(): GameState.claim_prestige_goal()))


func _on_rank_pressed() -> void:
	if GameState.prestige_block_reason() != "":
		return
	var now := Time.get_ticks_msec()
	if now - _rk_armed_at > 6000:
		_rk_armed_at = now          # premier appui : on demande confirmation
		return
	_rk_armed_at = -100000
	GameState.do_prestige()


## ---------- Rafraîchissement ----------

func refresh() -> void:
	_refresh_hub()
	_refresh_atelier()
	_refresh_lab()
	_refresh_rank()
	_refresh_sheet()


func _visible(id: String) -> bool:
	return sections.has(id) and sections[id].is_visible_in_tree()


func _dur(seconds: float) -> String:
	var s := int(maxf(0.0, round(seconds)))
	if s >= 86400:
		return "%d j %d h" % [s / 86400, (s % 86400) / 3600]
	if s >= 3600:
		return "%d h %02d" % [s / 3600, (s % 3600) / 60]
	return "%d min" % maxi(1, int(ceil(float(s) / 60.0)))


func _refresh_hub() -> void:
	if not _visible("salles"):
		return
	var active := 0
	for rid in Data.ROOM_ORDER:
		if GameState.room_worker(rid) != "":
			active += 1
	var total := Data.ROOM_ORDER.size()
	var prod := GameState.production_per_sec()
	_pulse_state.text = ("%d SALLE ACTIVE SUR %d" if active == 1 else "%d SALLES ACTIVES SUR %d") % [active, total]
	_pulse_big.text = "+%s cr/h" % _spaced(prod.credits * 3600.0)
	_pulse_small.text = "+%s min · +%s én · +%s don par heure" % [_spaced(prod.minerals * 3600.0), _spaced(prod.energy * 3600.0), _spaced(prod.data * 3600.0)]
	var dot_color: Color = GOOD if active > 0 else WARN
	_pulse_dot.add_theme_stylebox_override("panel", UiTheme.box(dot_color, Color(0, 0, 0, 0), _g(5), 0, 0))
	_pulse_eff.text = "%d %%" % int(round(GameState.offline_efficiency() * 100.0))
	_pulse_cap.text = "coffre %s" % _dur(GameState.offline_cap_seconds())
	for rid in Data.ROOM_ORDER:
		_refresh_tile(rid)
	var per_hour := GameState.afk_drops_per_hour()
	_hub_ring.value = GameState.atelier_progress() if per_hour > 0.0 else 0.0
	if per_hour > 0.0:
		_hub_atelier.text = "Atelier : prochain objet dans %s" % _dur(GameState.atelier_next_in())
	else:
		_hub_atelier.text = "Atelier à l'arrêt : affecte un équipier"
	var lc: Dictionary = GameState.last_crafted
	if lc.is_empty():
		_hub_last.text = "Aucun objet fabriqué pour l'instant"
	else:
		_hub_last.text = "Dernier : %s (%s, niv. %d)" % [lc.name, String(Data.ITEM_RARITY[lc.rarity].name).to_lower(), lc.ilvl]
	var g: Dictionary = GameState.next_goal()
	if g.is_empty():
		_goal_label.text = "Objectifs : tous accomplis"
		_goal_count.text = ""
		_goal_bar.value = 1.0
		_goal_claim.visible = false
	else:
		var prog: float = GameState.goal_progress(g)
		var target := float(g.target)
		_goal_label.text = "Objectif : %s" % g.name
		_goal_count.text = "%s / %s" % [Data.fmt(minf(prog, target)), Data.fmt(target)]
		_goal_bar.value = clampf(prog / target, 0.0, 1.0)
		_goal_claim.visible = GameState.goal_ready(g)


func _refresh_tile(rid: String) -> void:
	var t: Dictionary = _tiles[rid]
	var color: Color = Data.ROOMS[rid].color
	var w := GameState.room_worker(rid)
	var staffed := w != ""
	t.lvl.text = "niv. %d" % GameState.room_level(rid)
	if w != t.worker:
		for c in t.avatar_slot.get_children():
			c.queue_free()
		if staffed:
			_avatar(t.avatar_slot, w, 26.0)
		t.worker = w
		var fill: Color = PANEL if staffed else Color(WARN.r, WARN.g, WARN.b, 0.07)
		var border: Color = color if staffed else Color(0, 0, 0, 0)
		for st in ["normal", "hover", "pressed", "focus"]:
			(t.btn as Button).add_theme_stylebox_override(st, _box(fill, border, 14.0, 1, 0.0))
	t.who.visible = staffed
	t.out.visible = staffed
	t.empty_note.visible = not staffed
	t.empty_btn.visible = not staffed
	t.dash.visible = not staffed
	if staffed:
		t.who_name.text = Data.HEROES[w].name
		var tag := _hero_tag(rid, w)
		t.who_tag.text = tag
		t.who_tag.add_theme_color_override("font_color", GOLD if tag == "spécialité" else ACCENT)
		t.out.text = _tile_output(rid, w)


func _tile_output(rid: String, w: String) -> String:
	var m := GameState.room_metric(rid, w)
	match rid:
		"atelier":
			var target := "au hasard" if GameState.atelier_slot == "" else String(SLOT_SHORT.get(GameState.atelier_slot, ""))
			return "%s objet/h · cible : %s" % [_num(m.value, 1), target]
		"quartiers":
			return "XP équipage +%d %%" % int(round(m.value))
		"soute":
			return "coffre %s" % _dur(GameState.offline_cap_seconds())
	var cr := GameState.room_credits_per_hour(rid, w)
	return "+%s %s · +%s cr/h" % [_spaced(m.value), m.unit, _spaced(cr)]


## ---------- Fiche de salle ----------

func _create_sheet() -> void:
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.055, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			close_sheet())
	_sheet.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.1
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	var sb := UiTheme.box(SHEET, LINE, _g(24), 1, _g(16))
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.border_width_bottom = 0
	panel.add_theme_stylebox_override("panel", sb)
	_sheet.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", _g(12))
	scroll.add_child(content)
	_sh = {"content": content}


func open_room(rid: String) -> void:
	if _sheet == null:
		_create_sheet()
	_sheet_room = rid
	_sheet_sig = ""
	_sheet.visible = true
	_refresh_sheet()


func close_sheet() -> void:
	_sheet_room = ""
	if _sheet != null:
		_sheet.visible = false


func sheet_open() -> bool:
	return _sheet != null and _sheet.visible and _sheet_room != ""


func _sheet_signature(rid: String) -> String:
	var parts: Array[String] = [rid, str(GameState.room_level(rid)), str(GameState.hero_order.size())]
	for r in Data.ROOM_ORDER:
		parts.append(GameState.room_worker(r))
	return ",".join(parts)


func _refresh_sheet() -> void:
	if not sheet_open():
		return
	var sig := _sheet_signature(_sheet_room)
	if sig != _sheet_sig:
		_sheet_sig = sig
		_fill_sheet(_sheet_room)
	_update_sheet(_sheet_room)


func _fmt_metric(m: Dictionary, signed: bool = false) -> String:
	var v: float = m.value
	var txt := _num(v, 2) if m.unit == "objet/h" else (_num(v, 0) if m.unit in ["% d'XP"] else (_num(v, 1) if m.unit == "h de coffre" else _spaced(v)))
	return ("+" if signed and v > 0.0 else "") + txt


func _fill_sheet(rid: String) -> void:
	var content: VBoxContainer = _sh.content
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	var r: Dictionary = Data.ROOMS[rid]
	var color: Color = r.color
	var handle := _panel(content, FAINT, Color(0, 0, 0, 0), 3.0, 0.0, 0)
	handle.custom_minimum_size = Vector2(_g(44), _g(5))
	handle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var head := _hbox(content, 12.0)
	var tile := _panel(head, PANEL, color, 12.0, 8.0)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_icon(tile, r.icon, color, 34.0)
	var nv := _vbox(head, 0.0)
	_label(nv, r.name, 26, TEXT, false, true)
	_sh["level"] = _label(nv, "", 13, DIM, true)
	var ov := _vbox(head, 0.0)
	ov.size_flags_horizontal = Control.SIZE_SHRINK_END
	_sh["out_main"] = _label(ov, "", 18, GOOD, true)
	_sh["out_main"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sh["out_cr"] = _label(ov, "", 13, GOLD, true)
	_sh["out_cr"].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sh["bar"] = _bar(content, 8.0, color)
	_caption(content, "ÉQUIPIER AFFECTÉ")
	var current := GameState.room_worker(rid)
	var free: Array = []
	var busy: Array = []
	for id in GameState.hero_order:
		if id == current:
			continue
		var where := GameState.hero_room(id)
		if where != "" and where != rid:
			busy.append(id)
		else:
			free.append(id)
	free.sort_custom(func(a, b): return GameState.room_metric(rid, a).value > GameState.room_metric(rid, b).value)
	var ordered: Array = []
	if current != "":
		ordered.append(current)
	ordered.append_array(free)
	ordered.append_array(busy)
	var rows := {}
	for id in ordered:
		rows[id] = _crew_row(content, rid, id, current, busy.has(id))
	_sh["rows"] = rows
	var empty := _button(content, "", 16, Color(0, 0, 0, 0), Color(0, 0, 0, 0), DIM, 54.0, 12.0)
	var el := _label(empty, "Laisser la salle vide (elle ne produit rien)", 16, DIM)
	el.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	el.offset_left = _g(10)
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dash(empty, FAINT)
	empty.pressed.connect(main._tap(func(): GameState.set_room_crew(rid, "")))
	_wrap(_label(content, "Chaque ligne montre l'effet du changement avant de le valider. Changer d'équipier ne coûte rien et ne fait rien perdre.", 13, DIM))
	var up := _panel(content, PANEL, LINE, 14.0, 12.0)
	var uv := _vbox(up, 8.0)
	var uh := _hbox(uv, 6.0)
	_sh["up_title"] = _label(uh, "", 18, TEXT, false, true)
	_sh["up_title"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sh["up_gain"] = _label(uh, "", 12, DIM, true)
	_sh["up_main"] = _label(uv, "", 14, TEXT, true)
	_sh["up_btn"] = _button(uv, "", 20, BTN, ACCENT, TEXT, 54.0, 12.0)
	_sh["up_btn"].clip_text = true
	_sh["up_btn"].pressed.connect(main._tap(func(): GameState.buy_room_upgrade(rid)))
	_sh["up_roi"] = _wrap(_label(uv, "", 13, DIM))


func _crew_row(parent: Node, rid: String, id: String, current: String, is_busy: bool) -> Dictionary:
	var is_cur := id == current
	var b := _button(parent, "", 16, BTN_ACTIVE if is_cur else Color(0, 0, 0, 0), ACCENT if is_cur else FAINT, TEXT, 60.0, 12.0)
	b.disabled = is_busy
	var inner := HBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = _g(10)
	inner.offset_right = -_g(10)
	inner.add_theme_constant_override("separation", _g(10))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	_avatar(inner, id, 40.0)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(col)
	var nrow := _hbox(col, 6.0)
	var nm := _label(nrow, "", 18, TEXT, false, is_cur)
	var lv := _label(nrow, "", 13, DIM, true)
	var sub := _label(col, "", 13, GOLD)
	sub.clip_text = true
	var right := _label(inner, "", 14, DIM, true)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if not is_busy:
		b.pressed.connect(main._tap(func(): GameState.set_room_crew(rid, id)))
	if is_busy:
		b.modulate = Color(1, 1, 1, 0.85)
	return {"name": nm, "lv": lv, "sub": sub, "right": right, "busy": is_busy, "cur": is_cur}


func _update_sheet(rid: String) -> void:
	var r: Dictionary = Data.ROOMS[rid]
	var w := GameState.room_worker(rid)
	var lvl := GameState.room_level(rid)
	var maxl := GameState.room_max_level()
	_sh.level.text = "niveau %d sur %d" % [lvl, maxl]
	_sh.bar.value = float(lvl) / float(maxl)
	var m := GameState.room_metric(rid, w)
	_sh.out_main.text = "%s %s" % [_fmt_metric(m, true), m.unit] if w != "" else "à l'arrêt"
	var cr := GameState.room_credits_per_hour(rid, w)
	_sh.out_cr.text = "+%s cr/h" % _spaced(cr) if cr > 0.0 else ""
	for id in _sh.rows:
		var row: Dictionary = _sh.rows[id]
		var h: Dictionary = GameState.heroes[id]
		row.name.text = String(Data.HEROES[id].name)
		row.lv.text = "niv. %d" % h.level
		if row.busy:
			var where := GameState.hero_room(id)
			row.sub.text = "déjà : %s" % Data.ROOMS[where].name
			row.sub.add_theme_color_override("font_color", DIM)
			row.right.text = "occupé"
			row.right.add_theme_color_override("font_color", DIM)
			continue
		var tag := _hero_tag(rid, id)
		var tag_txt := ""
		if tag == "spécialité":
			tag_txt = "spécialité %s : +%d %%" % [r.name, int(Data.ROOM_SPECIALTY_BONUS * 100.0)]
		elif tag == "affinité":
			tag_txt = "affinité : +%d %%" % int(Data.ROOM_AFFINITY_BONUS * 100.0)
		row.sub.text = tag_txt if tag_txt != "" else "sans bonus de classe"
		row.sub.add_theme_color_override("font_color", GOLD if tag == "spécialité" else (ACCENT if tag == "affinité" else DIM))
		if row.cur:
			row.right.text = "en poste"
			row.right.add_theme_color_override("font_color", ACCENT)
		else:
			var mm := GameState.room_metric(rid, id)
			var delta: float = mm.value - m.value
			var sign_s := "+" if delta > 0.0005 else ("−" if delta < -0.0005 else "±")
			var dm := {"value": absf(delta), "unit": mm.unit}
			row.right.text = "%s%s %s" % [sign_s, _fmt_metric(dm), mm.unit]
			row.right.add_theme_color_override("font_color", GOOD if delta > 0.0005 else (WARN if delta < -0.0005 else DIM))
	# amélioration
	var btn: Button = _sh.up_btn
	if GameState.room_maxed(rid):
		_sh.up_title.text = "Niveau maximum"
		_sh.up_gain.text = ""
		_sh.up_main.text = ""
		btn.text = "Niveau maximum"
		btn.disabled = true
		_sh.up_roi.text = ""
		return
	var cost := GameState.room_upgrade_cost(rid)
	var m2 := GameState.room_metric(rid, w, lvl + 1)
	var lf0 := 1.0 + Data.ROOM_LEVEL_GAIN * (lvl - 1)
	var lf1 := 1.0 + Data.ROOM_LEVEL_GAIN * lvl
	_sh.up_title.text = "Améliorer : niveau %d → %d" % [lvl, lvl + 1]
	_sh.up_gain.text = "+%d %% d'effet" % int(round((lf1 / lf0 - 1.0) * 100.0))
	var line := "%s %s → %s" % [m.unit, _fmt_metric(m), _fmt_metric(m2)]
	var cr2 := GameState.room_credits_per_hour(rid, w, lvl + 1)
	if cr > 0.0:
		line += "     cr/h %s → %s" % [_spaced(cr), _spaced(cr2)]
	_sh.up_main.text = line if w != "" else "Affecte un équipier pour profiter de l'amélioration."
	btn.text = "Améliorer   %s" % _cost_text(cost)
	btn.disabled = not GameState.can_afford(cost)
	var gain := cr2 - cr
	if gain > 0.0 and cost.has("credits"):
		_sh.up_roi.text = "Retour sur investissement estimé : %s de production." % _dur(float(cost.credits) / gain * 3600.0)
	else:
		_sh.up_roi.text = ""


## ---------- Atelier : rafraîchissement ----------

func _chip_style(b: Button, active: bool, radius_px: float = 10.0) -> void:
	_style_button(b, BTN_ACTIVE if active else Color(0, 0, 0, 0), ACCENT if active else FAINT, radius_px)
	b.add_theme_font_override("font", UiTheme.font(active))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, TEXT if active else DIM)


func _refresh_atelier() -> void:
	if not _visible("atelier"):
		return
	var per_hour := GameState.afk_drops_per_hour()
	var w := GameState.room_worker("atelier")
	_at_ring.value = GameState.atelier_progress() if per_hour > 0.0 else 0.0
	_at_time.text = _dur(GameState.atelier_next_in()) if per_hour > 0.0 else "—"
	_at_head.text = "ATELIER · NIVEAU %d" % GameState.room_level("atelier")
	_at_rate.text = "%s objet/h" % _num(per_hour, 1)
	if w != _at_avatar_hero:
		for c in _at_avatar_slot.get_children():
			c.queue_free()
		if w != "":
			_avatar(_at_avatar_slot, w, 24.0)
		_at_avatar_hero = w
	_at_worker.text = "%s au travail" % Data.HEROES[w].name if w != "" else "Personne à l'Atelier : il est à l'arrêt"
	_at_worker.add_theme_color_override("font_color", TEXT if w != "" else WARN)
	var penalties := (1 if GameState.atelier_slot != "" else 0) + (1 if GameState.atelier_focus != "" else 0)
	_at_penalty.visible = penalties > 0
	_at_penalty.text = "Ciblage actif : cadence −%d %%" % int(round((1.0 - pow(Data.ATELIER_TARGET_FACTOR, penalties)) * 100.0))
	for sl in _at_slot_btns:
		_chip_style(_at_slot_btns[sl], GameState.atelier_slot == sl)
	for k in _at_focus_btns:
		_chip_style(_at_focus_btns[k], GameState.atelier_focus == k, 20.0)
	# plafond de niveau d'objet
	var cap := 3 + int(float(GameState.captain_p()) * Data.AFK_ILVL_CAP_RATIO)
	var by_power := 3 + int(GameState.craft_power() / Data.AFK_ILVL_DIV)
	var lvl := GameState.loot_level()
	_at_cap_value.text = "niv. %d / %d" % [lvl, cap]
	_at_cap_bar.value = clampf(float(lvl) / float(maxi(1, cap)), 0.0, 1.0)
	if by_power < cap:
		_at_cap_text.text = "Ta puissance de fabrication limite encore le niveau des objets (niv. %d). Monte l'Atelier, l'équipage et les salles pour fabriquer mieux." % by_power
	else:
		_at_cap_text.text = "L'Atelier fabrique au plus %d %% du niveau du Capitaine (niv. %d). Pour aller plus loin, fais monter ton Capitaine dans les anomalies." % [
			int(Data.AFK_ILVL_CAP_RATIO * 100.0), GameState.captain.level]
	# chances par rareté
	var weights := GameState.drop_weights(1)
	var total := 0.0
	for k in weights:
		total += weights[k]
	if _at_odds_bar.get_child_count() == 0:
		for k in Data.ITEM_RARITY_ORDER:
			var seg := ColorRect.new()
			seg.color = Data.ITEM_RARITY[k].color
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			seg.set_meta("rarity", k)
			_at_odds_bar.add_child(seg)
			var lab := _label(_at_odds_text, "", 12, Data.ITEM_RARITY[k].color, true)
			lab.set_meta("rarity", k)
	for seg in _at_odds_bar.get_children():
		seg.size_flags_stretch_ratio = maxf(0.01, weights[seg.get_meta("rarity")] / total * 100.0)
	for lab in _at_odds_text.get_children():
		var k: String = lab.get_meta("rarity")
		var pct: float = weights[k] / total * 100.0
		lab.text = "%s %s %%" % [String(Data.ITEM_RARITY[k].name).to_lower(), _num(pct, 0 if pct >= 10.0 else 1)]
	# dernières fabrications
	var sig_parts: Array[String] = []
	var equipped_ids: Array = GameState.equipped.values()
	for e in GameState.craft_log.slice(0, 3):
		sig_parts.append("%d%s" % [e.id, "e" if equipped_ids.has(e.id) else ("k" if e.kept else "r")])
	var sig := ",".join(sig_parts)
	if sig == _at_log_sig:
		return
	_at_log_sig = sig
	for c in _at_log_box.get_children():
		_at_log_box.remove_child(c)
		c.queue_free()
	if GameState.craft_log.is_empty():
		_label(_at_log_box, "Aucune fabrication pour l'instant.", 14, DIM)
		return
	for e in GameState.craft_log.slice(0, 3):
		var rar: Dictionary = Data.ITEM_RARITY[e.rarity]
		var p := PanelContainer.new()
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		var sb := UiTheme.box(Color(0.04, 0.12, 0.2, 1.0), Color(0, 0, 0, 0), _g(6), 0, _g(8))
		sb.border_width_left = _g(4)
		sb.border_color = rar.color
		p.add_theme_stylebox_override("panel", sb)
		_at_log_box.add_child(p)
		var row := _hbox(p, 10.0)
		var nm := _label(row, e.name, 15, TEXT, false, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		_label(row, "%s · niv. %d" % [String(rar.name).to_lower(), e.ilvl], 12, rar.color, true)
		var status := "équipé" if equipped_ids.has(e.id) else ("gardé" if e.kept else "recyclé")
		_label(row, status, 12, GOOD if status == "équipé" else DIM, true)


## ---------- Labo : rafraîchissement ----------

func _effect_text(id: String, lvl: int) -> String:
	var e: Dictionary = Data.RESEARCH[id].effect
	var v: float = float(e.per) * lvl
	var txt := String.num(v, 0) if is_equal_approx(v, round(v)) else String.num(v, 1)
	return "+%s%s" % [txt, e.unit]


func _roman(i: int) -> String:
	return ["I", "II", "III", "IV"][clampi(i, 0, 3)]


func _refresh_lab() -> void:
	if not _visible("lab"):
		return
	var slots_n := GameState.research_slots()
	var active := GameState.research_active
	var q := GameState.research_queue
	var done := 0
	var total := 0
	for id in Data.RESEARCH_ORDER:
		done += GameState.research_level(id)
		total += Data.RESEARCH[id].max
	_lab_sub.text = "%d poste%s occupé%s sur %d · file %d / %d · %d / %d" % [
		active.size(), "s" if active.size() > 1 else "", "s" if active.size() > 1 else "", slots_n, q.size(), Data.RESEARCH_QUEUE_MAX, done, total]
	var auto_ok := GameState.premium_unlocked("lab_auto")
	_lab_auto.set_pressed_no_signal(GameState.research_auto)
	_lab_auto.disabled = not auto_ok
	for i in _lab_cards.size():
		var u: Dictionary = _lab_cards[i]
		var card: PanelContainer = u.card
		var border := FAINT
		card.dash_on = false
		u.bar.visible = false
		u.effect.text = ""
		u.rush.visible = false
		u.cancel.visible = false
		u.id = ""
		if i >= slots_n:
			u.title.text = "%de poste : verrouillé" % (i + 1)
			u.title.add_theme_color_override("font_color", DIM)
			u.remain.text = "Recherche « Laboratoire annexe »" if i == 1 else "Se débloque avec des %s (bientôt disponible)" % Data.PREMIUM_NAME
			u.remain.add_theme_color_override("font_color", DIM)
			card.dash_color = FAINT
			card.dash_on = true
		elif i < active.size():
			var a: Dictionary = active[i]
			var r: Dictionary = Data.RESEARCH[a.id]
			u.id = a.id
			border = r.color
			u.title.text = "%s  %d / %d" % [r.name, GameState.research_level(a.id) + 1, r.max]
			u.title.add_theme_color_override("font_color", TEXT)
			u.effect.text = _effect_text(a.id, 1)
			u.effect.add_theme_color_override("font_color", r.color)
			u.bar.visible = true
			u.bar.add_theme_stylebox_override("fill", UiTheme.box(r.color, Color(0, 0, 0, 0), _g(5), 0, 0))
			u.bar.value = clampf(1.0 - a.remaining / maxf(a.total, 1.0), 0.0, 1.0)
			u.remain.text = "reste %s" % _dur(a.remaining)
			u.remain.add_theme_color_override("font_color", DIM)
			u.rush.visible = true
			u.cancel.visible = true
			var rc := GameState.research_boost_cost(a.id)
			if GameState.research_boost_seconds(a.id) <= 0.0:
				u.rush.text = "Accélérations utilisées"
				u.rush.disabled = true
			else:
				u.rush.text = "Accélérer · %s én" % Data.fmt(rc)
				u.rush.disabled = GameState.res["energy"] < rc
		else:
			u.title.text = "Poste de recherche libre"
			u.title.add_theme_color_override("font_color", WARN)
			u.remain.text = "Lance une recherche ci-dessous : plus elle est courte, plus vite elle sert."
			u.remain.add_theme_color_override("font_color", DIM)
			card.dash_color = WARN
			card.dash_on = true
		card.add_theme_stylebox_override("panel", _box(PANEL, Color(0, 0, 0, 0) if card.dash_on else border, 14.0, 1, 10.0))
	# file d'attente
	var qsig := ",".join(PackedStringArray(q))
	if qsig != _lab_queue_sig:
		_lab_queue_sig = qsig
		for c in _lab_queue_box.get_children():
			_lab_queue_box.remove_child(c)
			c.queue_free()
		if q.is_empty():
			_label(_lab_queue_box, "File vide : les recherches en file se lancent seules quand un poste se libère.", 13, DIM)
		for rid in q:
			var qb := _button(_lab_queue_box, "%s · niv. %d  ✕" % [Data.RESEARCH[rid].name, GameState.research_level(rid) + 1], 14, Color(0, 0, 0, 0), FAINT, TEXT, 44.0, 12.0)
			qb.pressed.connect(main._tap(func(): GameState.cancel_research(rid)))
	# parcours des lignes
	for ln in _lab_lines:
		var ids: Array = ln.ids
		var top := 0
		var all_max := true
		for i in ids.size():
			var rid: String = ids[i]
			var mx: int = Data.RESEARCH[rid].max
			var lv := GameState.research_level(rid)
			(ln.bars[i] as ProgressBar).value = float(lv) / float(mx)
			if lv > 0:
				top = i
			if lv < mx:
				all_max = false
		ln.tag.text = "%s max" % _roman(ids.size() - 1) if all_max else _roman(top)
	# catalogue
	for id in Data.RESEARCH_ORDER:
		var r: Dictionary = Data.RESEARCH[id]
		var u: Dictionary = _lab_catalog[id]
		var lvl := GameState.research_level(id)
		u.name.text = "%s  %d/%d" % [r.name, lvl, r.max]
		u.bar.value = float(lvl) / float(r.max)
		u.desc.text = "%s → %s" % [_effect_text(id, lvl) if lvl > 0 else "aucun bonus", _effect_text(id, mini(lvl + 1, r.max))] if lvl < r.max else "Actuel : %s" % _effect_text(id, lvl)
		var reason := GameState.research_block_reason(id)
		if lvl >= r.max:
			u.btn.text = "Niveau maximum"
			u.btn.disabled = true
		elif reason != "":
			u.btn.text = reason
			u.btn.disabled = true
		else:
			var cost := GameState.research_cost(id)
			var verb := "Lancer" if active.size() < slots_n else "Mettre en file"
			u.btn.text = "%s — %s · %s" % [verb, _dur(GameState.research_duration(id)), _cost_text(cost)]
			u.btn.disabled = not GameState.can_afford(cost)
	# Cristaux
	_lab_crystals.text = "%s : %d  ·  ces déblocages ne s'obtiennent pas encore en jeu (achat prévu plus tard)." % [Data.PREMIUM_NAME, GameState.crystals]
	for pid in _lab_premium_btns:
		var pb: Button = _lab_premium_btns[pid]
		var pu: Dictionary = Data.PREMIUM_UNLOCKS[pid]
		if GameState.premium_unlocked(pid):
			pb.text = "%s : débloqué" % pu.name
			pb.disabled = true
		else:
			pb.text = "%s : %d %s" % [pu.name, pu.cost, Data.PREMIUM_NAME]
			pb.disabled = GameState.crystals < pu.cost


## ---------- Rang : rafraîchissement ----------

func _perk_effect(id: String, lvl: int) -> String:
	var g: float = Data.PRESTIGE_PERKS[id].gain
	match id:
		"prod":
			return "+%d %% production" % int(round(g * lvl * 100.0))
		"xp":
			return "+%d %% XP équipage" % int(round(g * lvl * 100.0))
		"atelier":
			return "+%d %% cadence Atelier" % int(round(g * lvl * 100.0))
		"craft":
			return "+%d puissance de fabrication" % int(round(g * lvl))
	return "salles dès le niv. %d" % mini(GameState.room_max_level(), 1 + int(g * lvl))


func _refresh_rank() -> void:
	if not _visible("rang"):
		return
	var power := GameState.base_power()
	_rk_ring.value = float(power) / float(maxi(GameState.prestige_best, Data.PRESTIGE_ADVISED_POWER))
	_rk_rank.text = str(GameState.prestige_count)
	_rk_shards.text = "%d éclat%s" % [GameState.prestige_points, "s" if GameState.prestige_points > 1 else ""]
	if GameState.prestige_best > 0:
		_rk_record.text = "Record de Base : %d niveaux de salles cumulés. Les salles montent jusqu'au niveau %d." % [GameState.prestige_best, GameState.room_max_level()]
	else:
		_rk_record.text = "Pas encore de refonte. Les salles montent jusqu'au niveau %d, puis +%d à chaque refonte." % [GameState.room_max_level(), Data.PRESTIGE_ROOM_CAP_PER_RANK]
	_rk_power.text = "base actuelle : %d" % power
	_rk_keep.text = "Salles (reprennent au niv. %d)\nAméliorations du vaisseau\nRessources\nExpéditions en cours" % GameState.prestige_start_level()
	var reason := GameState.prestige_block_reason()
	var armed := Time.get_ticks_msec() - _rk_armed_at <= 6000
	if reason != "":
		_rk_btn.disabled = true
		_rk_btn_l1.text = "Refonte indisponible"
		_rk_btn_l2.text = reason
	else:
		_rk_btn.disabled = false
		var gain := GameState.prestige_gain()
		_rk_btn_l1.text = "Confirmer la refonte" if armed else "Lancer la refonte"
		_rk_btn_l2.text = "+ %d éclats%s" % [gain, "" if armed else " · appuie deux fois pour confirmer"]
	for id in Data.PRESTIGE_PERK_ORDER:
		var u: Dictionary = _rk_perks[id]
		var lvl := GameState.perk_level(id)
		u.eff.text = _perk_effect(id, lvl)
		var per_pip: float = float(Data.PRESTIGE_PERK_MAX) / float(u.pips.size())
		for i in u.pips.size():
			(u.pips[i] as ProgressBar).value = clampf((float(lvl) - float(i) * per_pip) / per_pip, 0.0, 1.0)
		if GameState.perk_maxed(id):
			u.buy.text = "Maximum"
			u.buy.disabled = true
		else:
			u.buy.text = "%d éclat%s" % [GameState.perk_cost(id), "s" if GameState.perk_cost(id) > 1 else ""]
			u.buy.disabled = GameState.prestige_points < GameState.perk_cost(id)
	var pg: Dictionary = GameState.next_prestige_goal()
	if pg.is_empty():
		_rk_goal_title.text = "Objectifs de refonte : tous accomplis"
		_rk_goal_count.text = ""
		_rk_goal_bar.value = 1.0
		_rk_goal_reward.text = ""
		_rk_goal_btn.visible = false
	else:
		var prog: float = GameState.goal_progress(pg)
		var target := float(pg.target)
		_rk_goal_title.text = "Objectif de refonte : %s" % pg.name
		_rk_goal_count.text = "%s / %s" % [Data.fmt(minf(prog, target)), Data.fmt(target)]
		_rk_goal_bar.value = clampf(prog / target, 0.0, 1.0)
		_rk_goal_reward.text = "Récompense : %s" % Data.fmt_amounts(pg.reward)
		_rk_goal_btn.visible = GameState.goal_ready(pg)


## ---------- Retour hors ligne ----------

func show_offline_report(r: Dictionary) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.035, 0.1, 1.0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, _g(16))
	margin.add_theme_constant_override("margin_top", _g(44))
	margin.add_theme_constant_override("margin_bottom", _g(16))
	overlay.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _g(10))
	margin.add_child(root)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", _g(10))
	scroll.add_child(box)

	var cap := _label(box, "DE RETOUR", 13, DIM)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _label(box, "Pendant ton absence", 30, TEXT, false, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(box, "%s · comptées : %s · rendement %d %%" % [_dur(r.away), _dur(r.seconds), int(round(r.efficiency * 100.0))], 14, ACCENT, true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not GameState.premium_unlocked("offline_boost"):
		var hint := _label(box, "Rendement hors ligne de 50 %% ; 70 %% avec le déblocage en %s." % Data.PREMIUM_NAME, 12, DIM)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if float(r.away) > float(r.seconds) + 60.0:
		var warn := _panel(box, Color(WARN.r, WARN.g, WARN.b, 0.07), Color(WARN.r, WARN.g, WARN.b, 0.6), 12.0, 8.0)
		var wrow := _hbox(warn, 10.0)
		var wl := _wrap(_label(wrow, "Coffre plein à %s. Une Soute plus haute ou la recherche Soute étendue allonge la durée comptée." % _dur(r.seconds), 14, TEXT))
		wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var see := _button(wrow, "Voir", 14, Color(0, 0, 0, 0), WARN, WARN, 38.0)
		see.size_flags_horizontal = Control.SIZE_SHRINK_END
		see.pressed.connect(main._tap(func():
			overlay.queue_free()
			main._show_tab("base")
			show_section("salles")
			open_room("soute")))

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", _g(6))
	box.add_child(res_row)
	var res_names := {"credits": "crédits", "minerals": "minerais", "data": "données", "energy": "énergie"}
	for id in ["credits", "minerals", "data", "energy"]:
		var col: Color = UiTheme.RES_COLORS[id]
		var tile := _panel(res_row, Color(0.04, 0.12, 0.2, 1.0), col, 10.0, 6.0)
		var tv := _vbox(tile, 0.0)
		var v := _label(tv, "+" + Data.fmt(r.gains.get(id, 0.0)), 16, col, true)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var n := _label(tv, res_names[id], 12, DIM)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var crew: Array = r.get("crew", [])
	if not crew.is_empty():
		var cc := _panel(box, PANEL, LINE, 14.0, 10.0)
		var cv := _vbox(cc, 6.0)
		_caption(cv, "ÉQUIPAGE")
		for e in crew:
			var row := _hbox(cv, 8.0)
			_avatar(row, e.id, 26.0)
			var nm := _label(row, Data.HEROES[e.id].name, 16, TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if e.to > e.from:
				_label(row, "niv. %d → %d" % [e.from, e.to], 14, GOOD, true)
			else:
				_label(row, "+%d %% vers le niv. %d" % [int(round(float(e.frac) * 100.0)), int(e.to) + 1], 14, DIM, true)

	var ac := _panel(box, PANEL, Color(0.76, 0.42, 1.0, 0.6), 14.0, 10.0)
	var av := _vbox(ac, 8.0)
	var ah := _hbox(av, 6.0)
	var acap := _caption(ah, "ATELIER · %d OBJET%s" % [r.get("crafted", 0), "S" if int(r.get("crafted", 0)) > 1 else ""])
	acap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if float(r.recycled) > 0.0:
		_label(ah, "recyclés : +%s cr" % Data.fmt(r.recycled), 12, DIM, true)
	if int(r.get("crafted", 0)) == 0:
		_wrap(_label(av, "Aucun objet fabriqué : place un équipier à l'Atelier." if GameState.room_worker("atelier") == "" else "Aucun objet fabriqué pendant cette absence.", 14, DIM))
	elif int(r.loot_kept) > 0:
		var best: Dictionary = r.loot_best
		var rar: Dictionary = Data.ITEM_RARITY[best.rarity]
		var bp := PanelContainer.new()
		bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := UiTheme.box(Color(0.05, 0.17, 0.27, 1.0), Color(0, 0, 0, 0), _g(6), 0, _g(8))
		sb.border_width_left = _g(4)
		sb.border_color = rar.color
		bp.add_theme_stylebox_override("panel", sb)
		av.add_child(bp)
		var bh := _hbox(bp, 10.0)
		var bv := _vbox(bh, 0.0)
		_label(bv, best.name, 17, TEXT, false, true)
		var affs: Array[String] = []
		for a in best.affixes:
			affs.append("%s +%s%s" % [Data.AFFIXES[a.k].name, String.num(a.v, 1), Data.AFFIXES[a.k].unit])
		var meta := "%s · niv. %d" % [String(rar.name).to_lower(), best.ilvl]
		if not affs.is_empty():
			meta += " · " + affs[0]
		_wrap(_label(bv, meta, 12, rar.color, true))
		var cur := GameState.equipped_item(best.slot)
		var delta := GameState.power_delta(best)
		var better := delta > 0.0
		var rel := ""
		if cur.is_empty():
			rel = "nouveau"
		else:
			rel = "%s%d %%" % ["+" if better else "−", int(round(absf(delta) / maxf(1.0, GameState.item_power(cur)) * 100.0))]
		var rl := _label(bh, rel, 14, GOOD if better else DIM, true)
		rl.size_flags_horizontal = Control.SIZE_SHRINK_END
		var brow := _hbox(av, 8.0)
		var equip := _button(brow, "Équiper", 16, BTN, ACCENT, TEXT, 40.0)
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.disabled = not better or GameState.item_by_id(best.id).is_empty()
		var cmp := _button(brow, "Comparer", 16, Color(0, 0, 0, 0), FAINT, DIM, 40.0)
		cmp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var detail := _wrap(_label(av, "", 13, TEXT, true))
		detail.visible = false
		equip.pressed.connect(main._tap(func():
			if GameState.equip(best.id):
				equip.disabled = true
				equip.text = "Équipé"))
		cmp.pressed.connect(main._tap(func():
			detail.visible = not detail.visible
			var cur_txt: String = main._item_text(cur).replace("\n", " · ") if not cur.is_empty() else "aucun"
			detail.text = "Nouveau : %s\nÉquipé : %s" % [main._item_text(best).replace("\n", " · "), cur_txt]))
	else:
		_wrap(_label(av, "Tous les objets fabriqués ont été recyclés automatiquement.", 14, DIM))

	var lc := _panel(box, PANEL, LINE, 14.0, 10.0)
	var lv := _vbox(lc, 4.0)
	_caption(lv, "LABO")
	var done: Array = r.get("research_done", [])
	if done.is_empty():
		_wrap(_label(lv, "Aucune recherche terminée pendant cette absence.", 14, DIM))
	for name_txt in done:
		var lr := _hbox(lv, 8.0)
		var ln := _label(lr, String(name_txt), 15, TEXT)
		ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ln.clip_text = true
		_label(lr, "terminé", 14, GOOD, true)
	if GameState.research_active.size() < GameState.research_slots() and GameState.research_queue.is_empty():
		_wrap(_label(lv, "Un poste de recherche est libre : lance une recherche dans le Labo.", 13, WARN))
	elif not GameState.research_queue.is_empty() or not GameState.research_active.is_empty():
		_wrap(_label(lv, "La recherche suivante est déjà lancée.", 13, DIM))

	var charges := int(r.get("charges", int(GameState.anomaly_charges)))
	var full: bool = r.get("charges_full", false)
	var cb := _panel(box, Color(GOOD.r, GOOD.g, GOOD.b, 0.06) if full else Color(0, 0, 0, 0), Color(GOOD.r, GOOD.g, GOOD.b, 0.5) if full else FAINT, 12.0, 8.0)
	var ctxt := "%d / %d charges d'anomalie prêtes. La recharge s'arrête à plein : joue-les avec ton Capitaine pour ne rien perdre." % [charges, Data.ANOMALY_CHARGES_MAX] if full else "%d / %d charges d'anomalie disponibles." % [charges, Data.ANOMALY_CHARGES_MAX]
	var cl := _wrap(_label(cb, ctxt, 14, TEXT))
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ok := _button(root, "Tout récupérer", 22, BTN, ACCENT, TEXT, 58.0, 14.0)
	ok.add_theme_font_override("font", UiTheme.font(true))
	ok.pressed.connect(func(): overlay.queue_free())
