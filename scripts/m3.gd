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
	return int(round(float(step(n)) * UI.text_scale))


## Échelle de texte (maquette I7) : étiquette 20, détail 22, corps 24 et 26, sous-titre 28, titre 34, affiche 48 et plus.
static func step(n: int) -> int:
	if n <= 21:
		return 20 if n >= 19 else n
	if n <= 23:
		return 22
	if n <= 27:
		return 24 if n <= 25 else 26
	if n <= 31:
		return 28
	if n <= 38:
		return 34
	return n


static func is_tap(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)


static func is_release(ev: InputEvent) -> bool:
	return (ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and not ev.pressed)


## Barre du haut de 56 dp : retour facultatif, titre, actions à droite (glyphes ou contrôles déjà construits).
static func top_bar(parent: Control, title: String, on_back: Callable = Callable(), actions: Array = [], help := true) -> Control:
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
	var help_btn := []
	if help and Help.has(title):
		# mémo de l'écran (maquette E5), à droite de tout
		acts.append(["?", func():
			Help.show(bar, title)
			if not help_btn.is_empty():
				(help_btn[0] as Button).add_theme_color_override("font_color", UI.TEXT)])
	acts.reverse()
	for a in acts:
		var c: Control
		if a is Control:
			c = a
			if c is Wallet:
				# porte-monnaie : masque d'abord les crédits plutôt que de couper le titre
				(c as Wallet).max_w = 712.0 - x - text_w(title, 40, true) - 40.0 - (720.0 - rx)
				(c as Wallet).refresh()
			bar.add_child(c)
			c.position = Vector2(rx - c.size.x - 8.0, 56 - c.size.y * 0.5)
			rx -= c.size.x + 16.0
		else:
			var ib := icon_button(bar, String(a[0]), 36)
			ib.pressed.connect(a[1])
			if String(a[0]) == "?":
				help_btn.append(ib)
				if not Help.seen(title):
					ib.add_theme_color_override("font_color", UI.GOLD)
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


static var _cards := {}


## Plaque de verre dépoli à angles coupés (maquette G2) : cartes et lignes partagent la matière des boutons.
static func glass_card(ci: CanvasItem, r: Rect2, sel := false, corner := 20.0) -> void:
	var key := "%s%d" % ["s" if sel else "c", int(corner)]
	if not _cards.has(key):
		var g := GlassBox.make("cardsel" if sel else "card")
		g.flat = true
		g.corner = corner
		_cards[key] = g
	(_cards[key] as GlassBox).draw(ci.get_canvas_item(), r)


## Feuille du bas (maquette G2) : verre à deux angles coupés en haut, liseré clair.
static func sheet(ci: CanvasItem, r: Rect2) -> void:
	var c := 28.0
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	var pts := PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1), Vector2(x0, y1), Vector2(x0, y0 + c)])
	var top := Color("24345f")
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(SHEET, clampf((p.y - y0) / 240.0, 0.0, 1.0)))
	ci.draw_polygon(pts, cols)
	ci.draw_polyline(PackedVector2Array([pts[5], pts[0], pts[1], pts[2]]), Color("5a78b8"), 2.0, true)


## Boîte de dialogue : verre à quatre angles coupés.
static func dialog(ci: CanvasItem, r: Rect2) -> void:
	if not _cards.has("dlg"):
		var g := GlassBox.make("sheet")
		g.flat = true
		g.corner = 28.0
		_cards["dlg"] = g
	(_cards["dlg"] as GlassBox).draw(ci.get_canvas_item(), r)


## Contour d'un cadre de portrait selon la rareté (maquette G4) : rond, angles coupés, hexagone.
static func frame_pts(c: Vector2, r: float, rarity: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match rarity:
		"rare":
			for i in 8:
				var a := TAU * (i + 0.5) / 8.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.06)
		"epic":
			for i in 6:
				var a := TAU * i / 6.0 - PI / 2.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.1)
		_:
			for i in 40:
				var a := TAU * i / 40.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(pts[0])
	return pts


static func card(ci: CanvasItem, r: Rect2, fill: Color = S2, radius: int = 32, border: Color = Color(0, 0, 0, 0), bw: int = 2) -> void:
	if fill == S2 and border.a <= 0.0 and r.size.y >= 56.0:
		glass_card(ci, r, false, 20.0 if radius >= 28 else 12.0)
		return
	if fill == TONAL and border == UI.ACCENT and r.size.y >= 56.0:
		glass_card(ci, r, true)
		return
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
	var rar := String(hero.get("rarity", "common"))
	var fp := frame_pts(c, r - 2.0, rar)
	ci.draw_colored_polygon(fp.slice(0, fp.size() - 1), Color("0a1424"))
	Art.draw_portrait(ci, hero, c, r - (6.0 if rar == "common" else 9.0), t)
	if rar == "epic":
		ci.draw_polyline(frame_pts(c, r + 2.0, rar), Color(ring, 0.35), 8.0, true)
	ci.draw_polyline(fp, ring, 4.0, true)


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


## Bouton qui porte son prix (maquette E3) : libellé en haut, coûts en dessous, ce qui manque en rouge.
## `items` : [[icône, montant (texte), suffisant (bool)], …] ; icônes de UI.icon (coin, shard, crystal…) ou "" (durée).
## Rappeler la fonction pour changer libellé ou prix ; un tableau vide revient au bouton simple.
static func price(b: Button, label: String, items: Array) -> void:
	if items.is_empty():
		b.set_meta("price", null)
		b.text = label
		b.queue_redraw()
		return
	var first := not b.has_meta("price")
	b.set_meta("price", [label, items])
	b.text = ""
	b.queue_redraw()
	if not first:
		return
	b.draw.connect(func():
		var m = b.get_meta("price", null)
		if m == null:
			return
		var off := b.disabled
		var col := b.get_theme_color("font_disabled_color" if off else "font_color")
		var lab := String(m[0])
		var w := b.size.x - 24.0
		var y0 := b.size.y * 0.5 - 2.0
		text(b, Vector2(12, y0), lab, 28, col, true, w, HORIZONTAL_ALIGNMENT_CENTER)
		var ps := 20
		var parts := []
		var tw := 0.0
		for it in m[1]:
			var t := String(it[1])
			var iw := (26.0 if String(it[0]) != "" else 0.0)
			parts.append([String(it[0]), t, bool(it[2]), iw])
			tw += iw + text_w(t, ps, true) + 14.0
		tw -= 14.0
		var x := (b.size.x - tw) * 0.5
		var yb := y0 + 10.0 + fs(ps)
		for p in parts:
			if p[0] != "":
				b.draw_texture_rect(UI.icon(p[0], 22), Rect2(x, yb - fs(ps) + 1.0, 22, 22), false, Color(1, 1, 1, 0.6 if off else 1.0))
				x += p[3]
			var c: Color = Color("ff9b9b") if not p[2] else Color(col, 0.85)
			text(b, Vector2(x, yb), p[1], ps, c, true)
			x += text_w(p[1], ps, true) + 14.0)


## Message bref (maquette I6) : une plaquette de verre en haut du contenu, 2 s, qui ne masque ni les boutons ni le combat.
static func toast(from: Node, msg: String, col: Color = UI.GREEN) -> void:
	var vp := from.get_viewport()
	if vp == null:
		return
	for old in vp.get_children():
		if old.has_meta("toast"):
			old.queue_free()
	var t := Control.new()
	t.set_meta("toast", true)
	t.z_index = 4096
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.process_mode = Node.PROCESS_MODE_ALWAYS
	var w := minf(656.0, text_w(msg, 26, true) + 96.0)
	t.size = Vector2(w, 72)
	t.position = Vector2((720.0 - w) * 0.5, 128)
	t.draw.connect(func():
		glass_card(t, Rect2(Vector2.ZERO, t.size), true, 16.0)
		t.draw_circle(Vector2(36, 36), 8, col)
		text(t, Vector2(60, 36 + fs(26) * 0.36), msg, 26, UI.TEXT, true, w - 80.0))
	vp.add_child(t)
	t.modulate.a = 0.0
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.0)
	tw.tween_property(t, "modulate:a", 0.0, 0.3)
	tw.tween_callback(t.queue_free)


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
