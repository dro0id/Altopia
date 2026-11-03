class_name UI
extends RefCounted
## Petits utilitaires d'interface partagés (couleurs, boîtes, étiquettes, boutons).

# Charte de la maquette : mêmes valeurs que les planches (fond, carte, action, or, succès, danger, texte secondaire).
const BG := Color("0b1226")
const PANEL := Color("141d3a")
const PANEL2 := Color("101a3a")
const BAR := Color("0f1730")
const LINE := Color("2b3a6b")
const LINE2 := Color("1d2a52")
const ACCENT := Color("4fd8ff")
const GOLD := Color("ffd166")
const GREEN := Color("7dffb0")
const RED := Color("ff6b6b")
const MUTED := Color("a9b6d6")
const TEXT := Color("e8eefc")
const DARK := Color("06101f")
const HUD := Color(0.051, 0.082, 0.188, 0.8)      # rgba(13,21,48,.8) : pastilles et boutons posés sur le terrain


static func box(fill: Color, line: Color = LINE, radius: int = 10, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func label(parent: Node, text: String, size: int, col: Color = Color.WHITE, bold := false) -> Label:
	var l := Label.new()
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


## Bouton de la charte : `kind` = "main" (action, bleu), "gold" (premium), "ghost" (secondaire) ou "danger". Hauteur mini 96 px (48 dp).
static func button(parent: Node, text: String, size: int, kind: String = "main") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var fill := ACCENT
	var line := ACCENT
	var fg := DARK
	match kind:
		"gold":
			fill = GOLD
			line = GOLD
			fg = Color("1a1004")
		"ghost":
			fill = LINE2
			line = LINE
			fg = TEXT
		"danger":
			fill = Color("2a1626")
			line = RED
			fg = Color("ffb3b3")
	b.add_theme_stylebox_override("normal", box(fill, line, 24, 14))
	b.add_theme_stylebox_override("hover", box(fill.lightened(0.1), line, 24, 14))
	b.add_theme_stylebox_override("pressed", box(fill.darkened(0.15), line, 24, 14))
	b.add_theme_stylebox_override("disabled", box(fill.darkened(0.45) if kind != "ghost" else Color(0.08, 0.12, 0.24), line.darkened(0.5), 24, 14))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.3) if kind != "ghost" else MUTED.darkened(0.3))
	b.add_theme_font_override("font", bold_font())
	b.custom_minimum_size.y = 96.0
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	parent.add_child(b)
	return b


## Nombre avec espace entre les milliers (« 1 240 »).
static func num(v: float) -> String:
	var n := int(v)
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


## Nombre court (« 1,2k ») pour les pastilles étroites.
static func short(v: float) -> String:
	if v >= 1000.0:
		var s := "%.1f" % (v / 1000.0)
		return s.replace(".", ",").trim_suffix(",0") + "k"
	return str(int(v))


## Rectangle arrondi rempli d'un dégradé horizontal, avec bordure.
static func draw_gradient_box(ci: CanvasItem, r: Rect2, rad: float, c0: Color, c1: Color, line: Color, border := 2.0) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for cn in corners:
		for i in 9:
			var p: Vector2 = cn[0] + Vector2.from_angle(cn[1] + (PI * 0.5) * float(i) / 8.0) * rad
			pts.append(p)
			cols.append(c0.lerp(c1, clampf((p.x - r.position.x) / r.size.x, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, border, true)


## Portrait rond d'un héros sur fond sombre cerclé de turquoise (comme les portraits de la maquette).
static func portrait(ci: CanvasItem, hero: Dictionary, c: Vector2, r: float, t: float = 0.0) -> void:
	ci.draw_circle(c, r + 2.0, Color("0a1424"))
	Art.draw_portrait(ci, hero, c, r - 3.0, t)
	ci.draw_arc(c, r, 0, TAU, 48, Color(0.31, 0.72, 0.78, 0.8), 2.5, true)


static var _icons := {}
static var _bold: FontVariation


## Police grasse (la maquette met en gras titres, noms, pastilles et boutons).
static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.7
	return _bold


## Petites icônes vectorielles (pièce, éclat, jeton, cristal) pour les boutons : `kind` = "coin", "shard", "token" ou "crystal".
static func icon(kind: String, px: int = 28) -> Texture2D:
	var key := "%s%d" % [kind, px]
	if _icons.has(key):
		return _icons[key]
	if kind == "coin":
		# la pièce est dessinée pixel par pixel (le rendu SVG n'affiche pas le texte)
		var im := Image.create(px, px, false, Image.FORMAT_RGBA8)
		var c := float(px) * 0.5
		for yy in px:
			for xx in px:
				var d := Vector2(xx + 0.5 - c, yy + 0.5 - c)
				var r := d.length() / (float(px) * 0.5)
				if r <= 0.86:
					var col := Color("ffd166")
					var ang := atan2(d.y, d.x)
					if r >= 0.34 and r <= 0.62 and absf(ang) > 0.75:
						col = Color("6b4a00")
					if r <= 0.7 and absf(d.x) < float(px) * 0.045 and (r >= 0.62 or r <= 0.34):
						col = Color("6b4a00")
					im.set_pixel(xx, yy, col)
		var ct := ImageTexture.create_from_image(im)
		_icons[key] = ct
		return ct
	var svg := ""
	match kind:
		"shard":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 14 14"><path d="M7 1l5 4-2 8H4L2 5z" fill="#7fdcff"/></svg>'
		"token":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 14 14"><rect x="1" y="3" width="12" height="8" rx="2" fill="#b388ff"/><circle cx="7" cy="7" r="2" fill="#2a1450"/></svg>'
		_:
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 14 14"><path d="M7 0l6 7-6 7-6-7z" fill="#ff7ad9"/></svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, float(px) / 28.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func duration(seconds: float) -> String:
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d h %02d min" % [h, m]
	return "%d min %02d s" % [m, s % 60]
