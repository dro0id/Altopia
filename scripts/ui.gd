class_name UI
extends RefCounted
## Petits utilitaires d'interface partagés (couleurs, boîtes, étiquettes, boutons).

const BG := Color(0.02, 0.04, 0.09)
const PANEL := Color(0.05, 0.12, 0.2, 0.94)
const LINE := Color(0.3, 0.85, 1.0, 0.45)
const ACCENT := Color(0.5, 0.95, 1.0)
const GOLD := Color(1.0, 0.82, 0.35)
const GREEN := Color(0.49, 1.0, 0.69)
const RED := Color(1.0, 0.5, 0.45)
const MUTED := Color(0.66, 0.74, 0.88)


static func box(fill: Color, line: Color = LINE, radius: int = 10, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func label(parent: Node, text: String, size: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


## Bouton : `kind` = "main" (bleu), "gold", "ghost" (discret) ou "danger".
static func button(parent: Node, text: String, size: int, kind: String = "main") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var fill := Color(0.1, 0.42, 0.55, 0.96)
	var line := ACCENT
	match kind:
		"gold":
			fill = Color(0.72, 0.52, 0.12, 0.96)
			line = GOLD
		"ghost":
			fill = Color(0.07, 0.13, 0.22, 0.9)
			line = Color(0.3, 0.45, 0.6, 0.7)
		"danger":
			fill = Color(0.35, 0.1, 0.12, 0.95)
			line = Color(1.0, 0.45, 0.4)
	b.add_theme_stylebox_override("normal", box(fill, line, 8, 8))
	b.add_theme_stylebox_override("hover", box(fill.lightened(0.12), Color.WHITE, 8, 8))
	b.add_theme_stylebox_override("pressed", box(fill.lightened(0.25), Color.WHITE, 8, 8))
	b.add_theme_stylebox_override("disabled", box(Color(0.06, 0.1, 0.16, 0.9), Color(0.3, 0.4, 0.5, 0.35), 8, 8))
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	parent.add_child(b)
	return b


static func duration(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d h %02d min" % [h, m]
	return "%d min %02d s" % [m, s % 60]
