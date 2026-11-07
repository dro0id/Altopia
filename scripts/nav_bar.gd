class_name NavBar
extends Control
## Barre de navigation du bas, avec pastilles de notification. Avant l'Aurore (étage 5) : Combat, Héros, Recruter, Boutique.
## Ensuite le vaisseau passe en premier (maquette RB) : Aurore, Mission (le combat), Héros, Recruter, Boutique.
## Les indices restent ceux de ALL : 0 combat, 1 héros, 2 vaisseau, 3 recruter, 4 boutique.

signal tab_pressed(index: int)

const ALL := ["Combat", "Héros", "Vaisseau", "Recruter", "Boutique"]
const HEIGHT := 160.0          # 80 dp, comme les barres de navigation Android
static var inset_bottom := 0.0  # barre de gestes du téléphone


static func total() -> float:
	return HEIGHT + inset_bottom

var active := 0
var badges: Array = [0, 0, 0, 0, 0]
var ship_on := true            # onglet Vaisseau visible
var mission_locked := false    # chapitre 1 : la mission attend l'arrivée (cadenas)


## Onglets affichés (indices de ALL).
func tabs() -> Array:
	return [2, 0, 1, 3, 4] if ship_on else [0, 1, 3, 4]


## Nom affiché d'un onglet.
func label_of(i: int) -> String:
	if ship_on and i == 0:
		return "Mission"
	if i == 2:
		return "Aurore"
	return ALL[i]


## Rectangle (local) de l'onglet d'indice `i` de ALL.
func tab_rect(i: int) -> Rect2:
	var tb := tabs()
	var j := tb.find(i)
	var w := (size.x - 16.0) / tb.size()
	return Rect2(8.0 + w * maxi(j, 0), 8.0, w, 136.0)
var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(720, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	t += delta
	mission_locked = not Game.mission_open()
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	else:
		return
	var tb := tabs()
	var i := clampi(int(pos.x / (size.x / tb.size())), 0, tb.size() - 1)
	Sfx.play("click", -6.0)
	tab_pressed.emit(tb[i])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BAR)
	draw_rect(Rect2(0, 0, size.x, 2), UI.LINE2)
	var tb := tabs()
	var w := (size.x - 16.0) / tb.size()
	var f := ThemeDB.fallback_font
	for j in tb.size():
		var i: int = tb[j]
		var on := i == active
		var col := UI.ACCENT if on else UI.MUTED
		var x0 := 8.0 + w * j
		var cx := x0 + w * 0.5
		# pastille d'indicateur (64 × 32 dp) derrière l'icône de l'onglet actif
		if on:
			UI.draw_gradient_box(self, Rect2(cx - minf(64.0, w * 0.42), 24.0, minf(128.0, w * 0.84), 64.0), 32.0, UI.TONAL, UI.TONAL, UI.TONAL, 1.0)
		if i == 0 and mission_locked:
			M3.lock(self, Vector2(cx, 56), col if on else Color(UI.MUTED, 0.6), 1.2)
		else:
			_icon(i, Vector2(cx, 56), col)
		var lab := label_of(i)
		draw_string(UI.bold_font() if on else f, Vector2(x0, 128), lab, HORIZONTAL_ALIGNMENT_CENTER, w, 23 if tb.size() > 4 else 24, UI.TEXT if on else UI.MUTED)
		var n: int = badges[i]
		if n > 0:
			var bc := Vector2(cx + 34.0, 28.0)
			draw_circle(bc, 20, UI.BAR)
			draw_circle(bc, 16, UI.RED)
			draw_string(UI.bold_font(), bc + Vector2(-16, 8), str(mini(n, 9)), HORIZONTAL_ALIGNMENT_CENTER, 32, 22, Color.WHITE)


func _icon(i: int, c: Vector2, col: Color) -> void:
	match i:
		0:    # ⚔ épées croisées, trait fin
			draw_line(c + Vector2(-13, 14), c + Vector2(13, -14), col, 3.0, true)
			draw_line(c + Vector2(-13, -14), c + Vector2(13, 14), col, 3.0, true)
			draw_line(c + Vector2(-16, 6), c + Vector2(-6, 16), col, 3.0, true)
			draw_line(c + Vector2(16, 6), c + Vector2(6, 16), col, 3.0, true)
		1:    # 🛡 bouclier (contour)
			var pts := PackedVector2Array([c + Vector2(-16, -16), c + Vector2(16, -16), c + Vector2(16, 2), c + Vector2(0, 19), c + Vector2(-16, 2), c + Vector2(-16, -16)])
			draw_polyline(pts, col, 3.0, true)
		2:    # vaisseau (fusée vue de face)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(9, -6), c + Vector2(9, 10), c + Vector2(-9, 10), c + Vector2(-9, -6)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 2), c + Vector2(-16, 14), c + Vector2(-9, 12)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(9, 2), c + Vector2(16, 14), c + Vector2(9, 12)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 12), c + Vector2(5, 12), c + Vector2(0, 20)]), UI.GOLD if col == UI.ACCENT else col)
			draw_circle(c + Vector2(0, -4), 3.5, UI.BAR)
		3:    # ✦ étoile à quatre branches
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -16), c + Vector2(4, -4), c + Vector2(16, 0), c + Vector2(4, 4), c + Vector2(0, 16), c + Vector2(-4, 4), c + Vector2(-16, 0), c + Vector2(-4, -4)]), col)
		4:    # ◆ losange plein
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -19), c + Vector2(19, 0), c + Vector2(0, 19), c + Vector2(-19, 0)]), col)
