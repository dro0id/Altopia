extends RefCounted
## Thème R2 : verre bleu nuit, filets cyan, polices Rajdhani / Share Tech Mono.

const BG := Color(0.02, 0.04, 0.09)
const PANEL := Color(0.04, 0.12, 0.2, 0.86)
const LINE := Color(0.22, 0.9, 1.0, 0.42)
const ACCENT := Color(0.5, 0.95, 1.0)
const TEXT := Color(0.9, 0.98, 1.0)
const DIM := Color(0.5, 0.71, 0.77)
const GOOD := Color(0.43, 1.0, 0.61)
const WARN := Color(1.0, 0.7, 0.42)
const MAGENTA := Color(1.0, 0.61, 0.93)

const Icons = preload("res://scripts/ui_icons.gd")
const RES_COLORS := {"credits": Color(1.0, 0.82, 0.35), "data": Color(0.5, 0.95, 1.0), "minerals": Color(0.8, 0.7, 0.62), "energy": Color(0.75, 0.55, 1.0)}

static var _theme: Theme


static func box(fill: Color, line: Color = LINE, radius: int = 6, border: int = 1, margin: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## Panneau « verre » avec un filet d'accent à gauche.
static func card_box(accent: Color = ACCENT) -> StyleBoxFlat:
	var sb := box(PANEL, LINE, 6, 1, 16)
	sb.border_width_left = 4
	sb.border_color = accent.lerp(Color(0.22, 0.9, 1.0), 0.0)
	sb.border_blend = false
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


static func font(bold: bool = false) -> Font:
	return load("res://assets/fonts/Rajdhani-%s.ttf" % ("Bold" if bold else "SemiBold"))


static func mono() -> Font:
	return load("res://assets/fonts/ShareTechMono-Regular.ttf")


static func build() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 24
	t.set_color("font_color", "Label", TEXT)
	for c in ["Button", "OptionButton", "CheckButton"]:
		t.set_color("font_color", c, TEXT)
		t.set_color("font_hover_color", c, Color.WHITE)
		t.set_color("font_pressed_color", c, Color.WHITE)
		t.set_color("font_disabled_color", c, Color(0.4, 0.5, 0.58))
		t.set_color("icon_normal_color", c, ACCENT)
		t.set_color("icon_pressed_color", c, Color.WHITE)
		t.set_color("icon_disabled_color", c, Color(0.35, 0.45, 0.52))
		t.set_font_size("font_size", c, 23)
	var normal := box(Color(0.05, 0.15, 0.24, 0.92), LINE, 6, 1, 10)
	var hover := box(Color(0.07, 0.2, 0.31, 0.95), Color(0.22, 0.9, 1.0, 0.7), 6, 1, 10)
	var pressed := box(Color(0.1, 0.36, 0.5, 0.98), ACCENT, 6, 2, 10)
	var disabled := box(Color(0.05, 0.08, 0.13, 0.8), Color(0.3, 0.4, 0.5, 0.3), 6, 1, 10)
	for c in ["Button", "OptionButton"]:
		t.set_stylebox("normal", c, normal)
		t.set_stylebox("hover", c, hover)
		t.set_stylebox("pressed", c, pressed)
		t.set_stylebox("hover_pressed", c, pressed)
		t.set_stylebox("disabled", c, disabled)
		t.set_stylebox("focus", c, StyleBoxEmpty.new())
	# interrupteurs : fond neutre (plus de remplissage plein), pastille dessinée
	var flat := box(Color(0.04, 0.12, 0.2, 0.55), Color(0.22, 0.9, 1.0, 0.25), 6, 1, 10)
	for st in ["normal", "pressed", "hover_pressed", "hover", "disabled"]:
		t.set_stylebox(st, "CheckButton", flat)
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", Icons.toggle(true))
	t.set_icon("unchecked", "CheckButton", Icons.toggle(false))
	t.set_icon("checked_disabled", "CheckButton", Icons.toggle(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", Icons.toggle(false, true))
	t.set_icon("checked_mirrored", "CheckButton", Icons.toggle(true))
	t.set_icon("unchecked_mirrored", "CheckButton", Icons.toggle(false))
	t.set_icon("checked_disabled_mirrored", "CheckButton", Icons.toggle(true, true))
	t.set_icon("unchecked_disabled_mirrored", "CheckButton", Icons.toggle(false, true))
	t.set_constant("h_separation", "CheckButton", 14)
	t.set_stylebox("panel", "PopupPanel", box(Color(0.03, 0.08, 0.14, 0.98), LINE, 6, 1, 8))
	t.set_stylebox("panel", "PopupMenu", box(Color(0.03, 0.08, 0.14, 0.98), LINE, 6, 1, 8))
	t.set_stylebox("hover", "PopupMenu", box(Color(0.1, 0.36, 0.5, 0.9), ACCENT, 4, 0, 6))
	t.set_stylebox("panel", "PanelContainer", card_box())
	t.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.08, 0.14), Color(0.22, 0.9, 1.0, 0.25), 4, 1, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT.darkened(0.15), Color(0, 0, 0, 0), 4, 0, 0))
	var grab := box(Color(0.22, 0.9, 1.0, 0.55), Color(0, 0, 0, 0), 4, 0, 0)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", box(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0), 4, 0, 0))
	_theme = t
	return t


## Bouton d'action principale : plein, cyan.
static func style_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.5, 0.62, 0.96), ACCENT, 6, 2, 10))
	b.add_theme_stylebox_override("hover", box(Color(0.13, 0.58, 0.72, 0.98), Color.WHITE, 6, 2, 10))
	b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.7, 0.85, 1.0), Color.WHITE, 6, 2, 10))
	b.add_theme_stylebox_override("disabled", box(Color(0.06, 0.12, 0.18, 0.85), Color(0.3, 0.4, 0.5, 0.3), 6, 1, 10))


## Bouton d'action risquée (rappeler, recycler…) : contour orange.
static func style_danger(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(Color(0.2, 0.1, 0.07, 0.9), WARN, 6, 1, 10))
	b.add_theme_stylebox_override("hover", box(Color(0.28, 0.13, 0.08, 0.95), WARN, 6, 2, 10))
	b.add_theme_stylebox_override("pressed", box(Color(0.4, 0.2, 0.1, 0.98), WARN, 6, 2, 10))


## Bouton « carte » à filet de couleur à gauche (destinations).
static func style_card_button(b: Button, color: Color) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var fill := Color(0.05, 0.15, 0.24, 0.92) if st != "disabled" else Color(0.04, 0.07, 0.11, 0.85)
		if st == "hover":
			fill = Color(0.08, 0.21, 0.32, 0.95)
		if st == "pressed" or st == "hover_pressed":
			fill = Color(0.12, 0.34, 0.48, 0.98)
		var line := color if st != "disabled" else color.darkened(0.6)
		var sb := box(fill, LINE, 6, 1, 14)
		sb.border_width_left = 6
		sb.border_color = line
		b.add_theme_stylebox_override(st, sb)
