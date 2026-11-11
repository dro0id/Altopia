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
const TONAL := Color("1d3a66")               # boutons tonals et sélections (refonte Android)
## Palette à règles (maquette G1) : surfaces, actions, raretés, texte. Les écrans s'y réfèrent par leur nom.
const SURFACE := {"vide": Color("070b1a"), "fond": Color("0b1226"), "carte": Color("141d3a"), "relief": Color("1d2a52"), "trait": Color("2b3a6b")}
const ACTION := {"agir": Color("4fd8ff"), "recolter": Color("7dffb0"), "premium": Color("ffd166"), "danger": Color("ff6b6b")}
const RARITY := {"commun": Color("9aa7c7"), "normal": Color("58c98f"), "rare": Color("4fa8ff"), "epique": Color("b388ff"), "legendaire": Color("ffb142"), "ultime": Color("ff6b6b")}
const TEXT_OFF := Color("6b7aa3")
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


## Rôle visuel d'un bouton (voir GlassBox) : main, success, premium, secondary, danger, alert ; « text » reste un lien.
## Les anciens noms sont conservés : ghost, tonal et outline deviennent secondary, gold devient premium.
static func role_of(kind: String) -> String:
	match kind:
		"gold", "premium":
			return "premium"
		"ghost", "tonal", "outline", "secondary":
			return "secondary"
		"success", "collect":
			return "success"
		"danger":
			return "danger"
		"alert":
			return "alert"
	return "main"


## Clic de souris simulé à partir d'un toucher (Android) : le toucher arrive aussi, il ne faut le compter qu'une fois.
## Sans ce filtre, un appui déclenchait deux fois l'action (son doublé, fenêtre ouverte puis aussitôt refermée).
static func emulated(ev: InputEvent) -> bool:
	return ev.device == InputEvent.DEVICE_ID_EMULATION


## Donne à un bouton le style de verre facetté d'un rôle (états normal, survol, appuyé, inactif).
static func glassify(b: Button, role: String, chamfer := 0.26, inset := 0.0, hexagon := false) -> void:
	for st in ["normal", "hover", "pressed", "disabled"]:
		var g := GlassBox.make(role, st, chamfer)
		g.inset = inset
		g.hexagon = hexagon
		b.add_theme_stylebox_override(st, g)
	var fg := GlassBox.text_color(role)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", GlassBox.text_color(role, "disabled"))
	no_focus(b)


## Pas de cadre de focus : sur écran tactile, il restait dessiné autour du dernier bouton touché.
static func no_focus(b: Control) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## Change le rôle d'un bouton déjà créé (sans refaire ses styles s'il a déjà ce rôle).
static func set_role(b: Button, role: String, chamfer := 0.26) -> void:
	if String(b.get_meta("role", "")) == role:
		return
	b.set_meta("role", role)
	glassify(b, role, chamfer)


## Bouton de la charte. `kind` : voir role_of ; « text » est un lien sans plaque. Hauteur mini 96 px (48 dp).
static func button(parent: Node, text: String, size: int, kind: String = "main") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	if kind == "text":
		b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 24, 14))
		b.add_theme_stylebox_override("hover", box(Color(ACCENT, 0.1), Color(0, 0, 0, 0), 24, 14))
		b.add_theme_stylebox_override("pressed", box(Color(ACCENT, 0.2), Color(0, 0, 0, 0), 24, 14))
		b.add_theme_stylebox_override("disabled", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 24, 14))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, ACCENT)
		b.add_theme_color_override("font_disabled_color", ACCENT.darkened(0.5))
		no_focus(b)
	else:
		glassify(b, role_of(kind))
	b.add_theme_font_override("font", bold_font())
	b.custom_minimum_size.y = 96.0
	b.pressed.connect(func():
		Sfx.play("click", -6.0)
		_wave(b))
	parent.add_child(b)
	return b


## Onde claire qui part du bouton au relâchement (désactivée avec « Réduire les tremblements »).
static func _wave(b: Button) -> void:
	if Game.reduce_shake or not b.is_inside_tree() or b.size.x < 24.0:
		return
	var w := Control.new()
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.size = b.size
	w.set_meta("k", 0.0)
	w.draw.connect(func():
		var k: float = w.get_meta("k")
		var c := b.size.y * 0.26 + k * 6.0
		var r := Rect2(Vector2(-1, -1) * (k * 10.0), b.size + Vector2(2, 2) * (k * 10.0))
		var pts := PackedVector2Array([Vector2(r.position.x + c, r.position.y), Vector2(r.end.x - c, r.position.y), Vector2(r.end.x, r.position.y + c), Vector2(r.end.x, r.end.y - c), Vector2(r.end.x - c, r.end.y), Vector2(r.position.x + c, r.end.y), Vector2(r.position.x, r.end.y - c), Vector2(r.position.x, r.position.y + c), Vector2(r.position.x + c, r.position.y)])
		w.draw_polyline(pts, Color(1, 1, 1, 0.5 * (1.0 - k)), 3.0, true))
	b.add_child(w)
	var tw := w.create_tween()
	tw.tween_method(func(k: float): w.set_meta("k", k); w.queue_redraw(), 0.0, 1.0, 0.3)
	tw.finished.connect(w.queue_free)


## Marges de sécurité en px de conception (720 de large) : encoche ou caméra en haut, barre de gestes en bas.
static var fake_top := -1.0      # outils de capture : simule une encoche


static func safe_insets(win: Window) -> Vector2:
	if fake_top >= 0.0:
		return Vector2(fake_top, 0.0)
	var sa := DisplayServer.get_display_safe_area()
	var sc := DisplayServer.screen_get_size()
	if sa.size.x <= 0 or sc.x <= 0:
		return Vector2.ZERO
	var k := 720.0 / float(sc.x)
	return Vector2(maxf(0.0, float(sa.position.y) * k), maxf(0.0, float(sc.y - sa.end.y) * k))


## Nombre avec espace entre les milliers (« 1 240 »).
static func num(v: float) -> String:
	# une seule écriture (maquette XK) : en entier jusqu'à 9 999, puis trois chiffres utiles et l'unité
	var n := int(v)
	var av := absf(v)
	var sign := "-" if n < 0 else ""
	for u in [[1.0e9, "G"], [1.0e6, "M"], [1.0e4, "k"]]:
		if av >= float(u[0]):
			var x: float = av / (1000.0 if String(u[1]) == "k" else float(u[0]))
			var t := ("%.2f" % x) if x < 10.0 else (("%.1f" % x) if x < 100.0 else str(int(x)))
			if t.contains("."):
				t = t.rstrip("0").rstrip(".")
			return sign + t.replace(".", ",") + " " + String(u[1])
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return sign + out


## Nombre court : même écriture que `num`.
static func short(v: float) -> String:
	return num(v)


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
	var rar := String(hero.get("rarity", "common"))
	var fp := M3.frame_pts(c, r, rar)
	ci.draw_colored_polygon(fp.slice(0, fp.size() - 1), Color("0a1424"))
	Art.draw_portrait(ci, hero, c, r - (3.0 if rar == "common" else 6.0), t)
	ci.draw_polyline(fp, Color(0.31, 0.72, 0.78, 0.8), 2.5, true)


static var _icons := {}
static var text_scale := 1.0     # réglage « Taille du texte » : 1, 1,1 ou 1,2
static var TOP := 0.0          # encoche ou caméra en haut (px de conception) : les fenêtres commencent en dessous
static var H := 1280.0          # hauteur réelle de l'écran dans le jeu (1280 en 16:9, ~1600 sur un téléphone 20:9)
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
		"itoken":
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 14 14"><rect x="1" y="2" width="12" height="10" rx="3" fill="#ffb142"/><path d="M7 4l1.2 2.4 2.6.4-1.9 1.8.5 2.6L7 10l-2.4 1.2.5-2.6L3.2 6.8l2.6-.4z" fill="#3a2000"/></svg>'
		_:
			svg = '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 14 14"><path d="M7 0l6 7-6 7-6-7z" fill="#ff7ad9"/></svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, float(px) / 28.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


## Contenu d'un bouton fait de textes et d'icônes alignés au centre : parts = ["Texte", Texture2D, "12", ...].
static func set_button_parts(b: Button, parts: Array, fs: int, col: Color) -> void:
	b.text = ""
	b.icon = null
	var old := b.get_node_or_null("Parts")
	if old != null:
		old.free()
	var hb := HBoxContainer.new()
	hb.name = "Parts"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	for p in parts:
		if p is Texture2D:
			var tr := TextureRect.new()
			tr.texture = p
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(tr)
		else:
			var l := Label.new()
			l.text = str(p)
			l.add_theme_font_override("font", bold_font())
			l.add_theme_font_size_override("font_size", fs)
			l.add_theme_color_override("font_color", col)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(l)


static func duration(seconds: float) -> String:
	# on ne montre jamais une unité à zéro (maquette XK)
	var s := int(seconds)
	var h := s / 3600
	var m := (s % 3600) / 60
	if h > 0:
		return "%d h" % h if m == 0 else "%d h %02d" % [h, m]
	if m > 0:
		return "%d min" % m if s % 60 == 0 else "%d min %02d s" % [m, s % 60]
	return "%d s" % s


## Écrans hauts (maquette I1) : part de la hauteur gagnée au-delà de 1280, pour descendre un contenu ancré en haut.
static func tall(k := 1.0) -> float:
	return maxf(0.0, H - 1280.0) * k
