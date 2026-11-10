class_name GlassBox
extends StyleBox
## Style de bouton « verre facetté » (maquettes UA à UJ) : angles coupés à 45°, bord et remplissage en dégradé,
## reflet clair en haut à gauche, ombre en bas, lueur pour les actions. Sert pour les boutons, les puces,
## les segments et les plaques de la barre du bas.
##
## Rôles : main (action, cyan), success (récolte, vert), premium (or), secondary (verre sombre),
## danger (rouge), tab (sélection), chip (plaquette discrète).

const ROLES := {
	"main": {"b0": "c8f8ff", "b1": "1d9ccc", "f0": "66e8ff", "f1": "1bb0e4", "glow": "4fd8ff", "text": "06101f"},
	"success": {"b0": "d2ffe3", "b1": "1f9c63", "f0": "8dffc0", "f1": "2fcf82", "glow": "7dffb0", "text": "052416"},
	"premium": {"b0": "fff3c4", "b1": "b8862a", "f0": "ffdf80", "f1": "e0a83a", "glow": "ffd166", "text": "1a1004"},
	"secondary": {"b0": "5fb4e0", "b1": "2b5a8a", "f0": "28507f", "f1": "16294d", "glow": "", "text": "e8eefc"},
	"danger": {"b0": "ff9b9b", "b1": "a02f3f", "f0": "4e1b2c", "f1": "2a1020", "glow": "", "text": "ffb3b3"},
	"alert": {"b0": "ffc4c4", "b1": "b02f3f", "f0": "ff8a8a", "f1": "ff5a5a", "glow": "ff6b6b", "text": "1a0505"},
	"tab": {"b0": "6fd0f0", "b1": "3a86b4", "f0": "2d5a94", "f1": "1d3a66", "glow": "", "text": "e8eefc"},
	"sheet": {"b0": "5a78b8", "b1": "24345f", "f0": "24345f", "f1": "1a2547", "glow": "", "text": "e8eefc"},
	"card": {"b0": "33457c", "b1": "1f2b52", "f0": "182449", "f1": "121b38", "glow": "", "text": "e8eefc"},
	"cardsel": {"b0": "6fd0f0", "b1": "3a86b4", "f0": "25467a", "f1": "1a3058", "glow": "", "text": "e8eefc"},
	"chip": {"b0": "2f3f72", "b1": "232f58", "f0": "1d2a52", "f1": "16213f", "glow": "", "text": "e8eefc"},
}

var role := "main"
var state := "normal"          # normal, hover, pressed, disabled
var chamfer := 0.26            # taille des angles coupés, en fraction de la hauteur
var inset := 0.0               # marge de la plaque dans le rectangle du contrôle
var hexagon := false           # plaque hexagonale (boutons de combat)
var progress := 0.0            # jauge dorée dans le bouton (chantier en cours), 0 = aucune
var glow_on := true
var flat := false               # verre dépoli (cartes, lignes) : ni reflet, ni facette, ni ombre portée
var corner := 0.0              # angle coupé fixe en pixels (0 = fraction de la hauteur)


static func make(r: String, st := "normal", ch := 0.26) -> GlassBox:
	var g := GlassBox.new()
	g.role = r if ROLES.has(r) else "main"
	g.state = st
	g.chamfer = ch
	return g


static func text_color(r: String, st := "normal") -> Color:
	if st == "disabled":
		return Color("6b7aa3")
	return Color(String(ROLES.get(r, ROLES.main).text))


func _mix(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, k)


func _colors() -> Array:
	var d: Dictionary = ROLES[role]
	var b0 := Color(String(d.b0))
	var b1 := Color(String(d.b1))
	var f0 := Color(String(d.f0))
	var f1 := Color(String(d.f1))
	var dark := Color(0.02, 0.03, 0.08)
	match state:
		"pressed":
			b0 = _mix(b0, dark, 0.2)
			b1 = _mix(b1, dark, 0.2)
			f0 = _mix(f0, dark, 0.22)
			f1 = _mix(f1, dark, 0.22)
		"hover":
			f0 = _mix(f0, Color.WHITE, 0.08)
			f1 = _mix(f1, Color.WHITE, 0.08)
		"disabled":
			b0 = Color("2f3f72")
			b1 = Color("1c2750")
			f0 = Color("1a2547")
			f1 = Color("131c38")
	return [b0, b1, f0, f1]


## Contour d'une plaque : octogone (angles coupés) ou hexagone.
func _shape(r: Rect2, c: float) -> PackedVector2Array:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	if hexagon:
		var cx := (x0 + x1) * 0.5
		var cy := (y0 + y1) * 0.5
		var rx := r.size.x * 0.5
		var ry := r.size.y * 0.5
		return PackedVector2Array([Vector2(cx, y0), Vector2(x1, cy - ry * 0.5), Vector2(x1, cy + ry * 0.5), Vector2(cx, y1), Vector2(x0, cy + ry * 0.5), Vector2(x0, cy - ry * 0.5)])
	c = minf(c, minf(r.size.x, r.size.y) * 0.5)
	return PackedVector2Array([Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)])


func _grad(pts: PackedVector2Array, r: Rect2, c0: Color, c1: Color) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0)))
	return cols


func _poly(canvas: RID, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_polygon(canvas, pts, cols)


func _draw(canvas: RID, rect: Rect2) -> void:
	var r := Rect2(rect.position + Vector2(inset, inset), rect.size - Vector2(inset, inset) * 2.0)
	if r.size.x < 4.0 or r.size.y < 4.0:
		return
	var d: Dictionary = ROLES[role]
	var c := r.size.y * chamfer if corner <= 0.0 else corner
	var cols := _colors()
	# lueur : seulement pour les actions disponibles
	if glow_on and state != "disabled" and state != "pressed" and String(d.glow) != "":
		var gc := Color(String(d.glow))
		for i in 3:
			var g := 3.0 + i * 3.0
			var gr := r.grow(g)
			var gp := _shape(gr, c + g)
			var a := 0.1 - i * 0.03
			var gcols := PackedColorArray()
			for p in gp:
				gcols.append(Color(gc, a))
			_poly(canvas, gp, gcols)
	elif state != "disabled" and not flat:
		var sp := _shape(Rect2(r.position + Vector2(0, 2), r.size), c)
		var scols := PackedColorArray()
		for p in sp:
			scols.append(Color(0, 0, 0, 0.35))
		_poly(canvas, sp, scols)
	# bord
	var outer := _shape(r, c)
	_poly(canvas, outer, _grad(outer, r, cols[0], cols[1]))
	# remplissage
	var rim := 2.0
	var ir := r.grow(-rim)
	var inner := _shape(ir, maxf(1.0, c - rim * 0.6))
	_poly(canvas, inner, _grad(inner, ir, cols[2], cols[3]))
	# jauge (chantier en cours) : l'or monte de la gauche
	if progress > 0.0 and state != "disabled":
		var xr := ir.position.x + ir.size.x * clampf(progress, 0.0, 1.0)
		var cc := maxf(1.0, c - rim * 0.6)
		var gp2 := PackedVector2Array([Vector2(ir.position.x + cc, ir.position.y), Vector2(maxf(xr, ir.position.x + cc), ir.position.y), Vector2(maxf(xr, ir.position.x + cc), ir.end.y), Vector2(ir.position.x + cc, ir.end.y), Vector2(ir.position.x, ir.end.y - cc), Vector2(ir.position.x, ir.position.y + cc)])
		var gg := PackedColorArray()
		for p in gp2:
			gg.append(Color("ffdf80", 0.85).lerp(Color("e0a83a", 0.85), clampf((p.y - ir.position.y) / ir.size.y, 0.0, 1.0)))
		_poly(canvas, gp2, gg)
	# ombre intérieure en bas
	var sh_top := ir.position.y + ir.size.y * 0.68
	var shade := PackedVector2Array([Vector2(ir.position.x, sh_top), Vector2(ir.end.x, sh_top), Vector2(ir.end.x, ir.end.y - c), Vector2(ir.end.x - c, ir.end.y), Vector2(ir.position.x + c, ir.end.y), Vector2(ir.position.x, ir.end.y - c)])
	if hexagon:
		shade = PackedVector2Array()
	if shade.size() > 2 and not flat:
		var shc := PackedColorArray()
		for p in shade:
			shc.append(Color(0, 0, 0, 0.0 if p.y <= sh_top + 0.5 else 0.22))
		_poly(canvas, shade, shc)
	# reflet : plan clair en haut à gauche, voile sur la moitié haute
	if state != "pressed" and state != "disabled" and not flat:
		var mid := ir.position.y + ir.size.y * 0.46
		var hl := PackedVector2Array()
		var cc2 := maxf(1.0, c - rim * 0.6)
		if hexagon:
			hl = PackedVector2Array([Vector2(ir.position.x + ir.size.x * 0.5, ir.position.y), Vector2(ir.end.x, ir.position.y + ir.size.y * 0.25), Vector2(ir.end.x, mid), Vector2(ir.position.x, mid), Vector2(ir.position.x, ir.position.y + ir.size.y * 0.25)])
		else:
			hl = PackedVector2Array([Vector2(ir.position.x + cc2, ir.position.y), Vector2(ir.end.x - cc2, ir.position.y), Vector2(ir.end.x, ir.position.y + cc2), Vector2(ir.end.x, mid), Vector2(ir.position.x, mid), Vector2(ir.position.x, ir.position.y + cc2)])
		var hc := PackedColorArray()
		for p in hl:
			hc.append(Color(1, 1, 1, 0.26 if p.y <= ir.position.y + cc2 + 0.5 else 0.0))
		_poly(canvas, hl, hc)
		# facette : bande oblique sur la gauche
		var fw := ir.size.x * 0.26
		if not hexagon and ir.size.x > 60.0:
			var fp := PackedVector2Array([Vector2(ir.position.x + cc2, ir.position.y), Vector2(ir.position.x + fw, ir.position.y), Vector2(ir.position.x + fw * 0.62, mid), Vector2(ir.position.x, mid), Vector2(ir.position.x, ir.position.y + cc2)])
			var fc := PackedColorArray()
			for p in fp:
				fc.append(Color(1, 1, 1, 0.12))
			_poly(canvas, fp, fc)
