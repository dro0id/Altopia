extends Control
## Carte du secteur de la Route : étapes, chemins, position du convoi. Touchez une étape dorée pour y aller.

signal node_pressed(id: int)

const UiTheme = preload("res://scripts/ui_theme.gd")
const COLORS := {
	"depart": Color("80f2ff"), "combat": Color("ffb26b"), "elite": Color("ff6b7a"), "epave": Color("ffd159"), "recolte": Color("ccb39e"),
	"repos": Color("6eff9c"), "gardien": Color("ff9bed"), "inconnu": Color("7aa6b5"),
}

var sim
var enabled := true


func _pos(nd: Dictionary) -> Vector2:
	var pad := Vector2(40, 46)
	var layers: int = sim.meta.layers
	return Vector2(pad.x + float(nd.x) * (size.x - pad.x * 2.0), size.y - pad.y - float(nd.L) / float(layers - 1) * (size.y - pad.y * 2.0))


func _draw() -> void:
	if sim == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.15, 0.9))
	var cur: Dictionary = sim.nodes[sim.at]
	for nd in sim.nodes:
		for nid in nd.next:
			var on_path: bool = nd.id == sim.at
			draw_line(_pos(nd), _pos(sim.nodes[nid]), Color(1.0, 0.82, 0.35, 0.9) if on_path else Color(0.22, 0.6, 0.75, 0.4), 4.0 if on_path else 2.5, true)
	var font := UiTheme.font(true)
	for nd in sim.nodes:
		var p := _pos(nd)
		var ty: String = sim.shown_type(nd)
		var col: Color = COLORS[ty]
		var here: bool = nd.id == sim.at
		var next: bool = cur.next.has(nd.id) and sim.phase == "map" and not sim.over
		var alpha := 0.55 if (nd.done and not here) else 1.0
		draw_circle(p, 25.0, Color(0.04, 0.1, 0.18, 0.95))
		draw_arc(p, 25.0, 0.0, TAU, 40, Color(col.r, col.g, col.b, alpha), 3.5, true)
		if here:
			draw_arc(p, 31.0, 0.0, TAU, 40, Color("80f2ff"), 4.0, true)
		elif next:
			draw_arc(p, 31.0, 0.0, TAU, 40, Color("ffd159"), 4.0, true)
		var glyph: String = sim.TYPES[ty].glyph
		draw_string(font, p + Vector2(-12, 9), glyph, HORIZONTAL_ALIGNMENT_CENTER, 24, 26, Color(col.r, col.g, col.b, alpha))
		if next or here:
			draw_string(font, p + Vector2(-60, 50), "Départ" if ty == "depart" else String(sim.TYPES[ty].name), HORIZONTAL_ALIGNMENT_CENTER, 120, 16, UiTheme.TEXT)


func _gui_input(ev: InputEvent) -> void:
	if not enabled or sim == null or sim.over or sim.phase != "map":
		return
	var pressed: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if not pressed:
		return
	var best := -1
	var bd := 38.0
	for nid in sim.nodes[sim.at].next:
		var d := _pos(sim.nodes[nid]).distance_to(ev.position)
		if d < bd:
			bd = d
			best = nid
	if best >= 0:
		node_pressed.emit(best)
