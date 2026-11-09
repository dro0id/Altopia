class_name M3
extends RefCounted
## Kit de la refonte Android (maquettes BA à BZ) : barre du haut, cartes, lignes de liste, pastilles de monnaie, barres de progression.
## Coordonnées de conception : 720 px de large (1 dp = 2 px).

const SHEET := Color("1a2547")       # feuilles du bas et boîtes de dialogue
const TONAL := Color("1d3a66")       # sélection, boutons tonals
const S2 := Color("141d3a")          # conteneur (cartes)
const S3 := Color("1d2a52")          # conteneur + (puces, pastilles)
const OUT := Color("2b3a6b")         # contour


## Taille de texte selon le réglage de lisibilité (Normal / Grand / Très grand).
static func fs(n: int) -> int:
	return int(round(float(n) * UI.text_scale))


static func is_tap(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)


static func is_release(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and not ev.pressed)


## Barre du haut de 56 dp : retour facultatif, titre, actions à droite (glyphes ou contrôles déjà construits).
static func top_bar(parent: Control, title: String, on_back: Callable = Callable(), actions: Array = []) -> Control:
	var bar := Control.new()
	bar.name = "TopBar"
	bar.size = Vector2(720, 112)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(bar)
	var x := 32.0
	if on_back.is_valid():
		var b := icon_button(bar, "←", 44)
		b.position = Vector2(8, 8)
		b.pressed.connect(on_back)
		x = 112.0
	var t := UI.label(bar, title, fs(40), UI.TEXT, true)
	t.name = "Title"
	t.position = Vector2(x, 56 - (fs(40) + 14) * 0.5)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS     # titre trop long : coupé par « … »
	t.size = Vector2(600 - x, fs(40) + 14)
	var rx := 712.0
	var acts := actions.duplicate()
	acts.reverse()
	for a in acts:
		var c: Control
		if a is Control:
			c = a
			bar.add_child(c)
			c.position = Vector2(rx - c.size.x - 8.0, 56 - c.size.y * 0.5)
			rx -= c.size.x + 16.0
		else:
			var ib := icon_button(bar, String(a[0]), 36)
			ib.pressed.connect(a[1])
			ib.position = Vector2(rx - 96.0, 8)
			rx -= 96.0
	# le titre s'arrête avant les actions (coupé par « … » s'il est trop long)
	t.size.x = minf(t.size.x, rx - x - 8.0)
	return bar


## Bouton icône : octogone de verre de 44 dp (la plaque est en retrait dans la zone d'appui de 48 dp).
static func icon_button(parent: Node, glyph: String, size: int = 36) -> Button:
	var b := Button.new()
	b.text = glyph
	b.size = Vector2(96, 96)
	b.custom_minimum_size = Vector2(96, 96)
	b.add_theme_font_size_override("font_size", size)
	UI.glassify(b, "secondary", 0.3, 6.0)
	b.add_theme_stylebox_override("focus", GlassBox.make("secondary", "normal", 0.3))
	(b.get_theme_stylebox("focus") as GlassBox).inset = 6.0
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UI.TEXT)
	b.pressed.connect(func(): Sfx.play("click", -6.0))
	parent.add_child(b)
	return b


## Pastille de monnaie (32 dp) : icône dessinée + valeur.
static func cur_chip(icon: String, text: String) -> HudButton:
	var c := HudButton.new()
	c.icon = icon
	c.font_size = fs(26)
	c.bold = true
	c.fill = S3
	c.border = S3
	c.radius = 32.0
	c.tappable = false
	c.set_texts(text)
	c.fit_chip()
	c.size.y = 64.0
	return c


static func card(ci: CanvasItem, r: Rect2, fill: Color = S2, radius: int = 32, border: Color = Color(0, 0, 0, 0), bw: int = 2) -> void:
	var sb := UI.box(fill, border, radius, 0)
	sb.set_border_width_all(bw if border.a > 0.0 else 0)
	ci.draw_style_box(sb, r)


## Ligne de liste (64 dp mini) : sélectionnée = teinte tonale et contour primaire.
static func row(ci: CanvasItem, r: Rect2, sel := false) -> void:
	card(ci, r, TONAL if sel else S2, 32, UI.ACCENT if sel else Color(0, 0, 0, 0), 3)


static func bar(ci: CanvasItem, r: Rect2, ratio: float, col: Color = UI.ACCENT) -> void:
	var rad := int(r.size.y * 0.5)
	ci.draw_style_box(UI.box(S3, Color(0, 0, 0, 0), rad, 0), r)
	if ratio > 0.0:
		ci.draw_style_box(UI.box(col, Color(0, 0, 0, 0), rad, 0), Rect2(r.position, Vector2(maxf(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y), r.size.y)))


## Portrait rond cerclé (couleur de rareté ou turquoise).
static func avatar(ci: CanvasItem, hero: Dictionary, c: Vector2, r: float, ring: Color = Color("4fb8c8"), t := 0.0) -> void:
	ci.draw_circle(c, r, Color("0a1424"))
	Art.draw_portrait(ci, hero, c, r - 6.0, t)
	ci.draw_arc(c, r - 2.0, 0, TAU, 56, ring, 4.0, true)


## Texte dessiné ; avec une largeur donnée, la taille diminue (jusqu'à 70 %) plutôt que de couper le texte.
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color = UI.TEXT, bold := false, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f: Font = UI.bold_font() if bold else ThemeDB.fallback_font
	var n := fs(size)
	if width > 0.0:
		var lo := int(n * 0.7)
		while n > lo and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > width:
			n -= 1
		# toujours trop long à 70 % : on coupe proprement avec « … » plutôt que de déborder sur le voisin
		if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > width:
			var t := s
			while t.length() > 1 and f.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > width:
				t = t.substr(0, t.length() - 1)
			s = t.strip_edges() + "…"
	ci.draw_string(f, pos, s, align, width, n, col)


static func text_w(s: String, size: int, bold := false) -> float:
	return (UI.bold_font() if bold else ThemeDB.fallback_font).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(size)).x


## Texte sur plusieurs lignes dans une largeur donnée ; renvoie la hauteur utilisée.
static func para(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, width: float, line_h := 1.45, bold := false) -> float:
	var f: Font = UI.bold_font() if bold else ThemeDB.fallback_font
	var words := s.split(" ")
	var line := ""
	var y := pos.y
	var lh := fs(size) * line_h
	for w in words:
		var tryl := w if line == "" else line + " " + w
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(size)).x > width and line != "":
			ci.draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(size), col)
			y += lh
			line = w
		else:
			line = tryl
	if line != "":
		ci.draw_string(f, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(size), col)
		y += lh
	return y - pos.y


## Titre de section (12 sp, majuscules espacées, couleur primaire).
static func section(ci: CanvasItem, pos: Vector2, s: String) -> void:
	var x := pos.x
	for ch in s:
		ci.draw_string(UI.bold_font(), Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(24), UI.ACCENT)
		x += UI.bold_font().get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs(24)).x + 2.0


## Gros bouton de pied d'écran (pilule) à position absolue.
static func button(parent: Node, text: String, rect: Rect2, kind := "main", size := 30) -> Button:
	var b := UI.button(parent, text, fs(size), kind)
	b.position = rect.position
	b.size = rect.size
	b.custom_minimum_size = Vector2(0, rect.size.y)
	fit_button(b, fs(size))
	return b


## Le libellé d'un bouton rétrécit (jusqu'à 70 %) s'il ne tient pas dans le bouton, même quand le texte change ensuite.
static func fit_button(b: Button, base: int) -> void:
	var fit := func():
		var f: Font = b.get_theme_font("font")
		var n := base
		var room := b.size.x - 40.0
		while n > int(base * 0.7) and f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, n).x > room:
			n -= 1
		if b.get_theme_font_size("font_size") != n:
			b.add_theme_font_size_override("font_size", n)
	b.draw.connect(fit)


## Menu déroulant (⋮) : liste d'actions de 48 dp ; un appui ailleurs le ferme.
static func menu(parent: Control, anchor_right: Vector2, items: Array) -> Control:
	var veil := Control.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.size = parent.size
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	veil.z_index = 50
	parent.add_child(veil)
	var w := 0.0
	for it in items:
		w = maxf(w, text_w(String(it[0]), 28) + 96.0)
	w = maxf(w, 320.0)
	var r := Rect2(anchor_right.x - w, anchor_right.y, w, 16.0 + items.size() * 96.0 + 16.0)
	veil.draw.connect(func():
		veil.draw_style_box(UI.box(SHEET, OUT, 16, 0), r)
		for i in items.size():
			text(veil, Vector2(r.position.x + 40.0, r.position.y + 16.0 + i * 96.0 + 48.0 + fs(28) * 0.36), String(items[i][0]), 28, UI.TEXT))
	veil.gui_input.connect(func(ev: InputEvent):
		if is_tap(ev):
			var p: Vector2 = ev.position
			veil.queue_free()
			if r.has_point(p):
				var i := clampi(int((p.y - r.position.y - 16.0) / 96.0), 0, items.size() - 1)
				Sfx.play("click", -6.0)
				(items[i][1] as Callable).call())
	return veil


## Petit cadenas dessiné (la police du jeu n'a pas l'emoji).
static func lock(ci: CanvasItem, c: Vector2, col: Color, s := 1.0) -> void:
	ci.draw_style_box(UI.box(col, Color(0, 0, 0, 0), int(3 * s), 0), Rect2(c + Vector2(-10, -2) * s, Vector2(20, 16) * s))
	ci.draw_arc(c + Vector2(0, -3) * s, 6.5 * s, PI, TAU, 10, col, 3.0 * s)
