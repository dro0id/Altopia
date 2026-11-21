class_name CaptainScreen
extends Overlay
## Grade et doctrine du Capitaine (maquette WN) : trois branches de quatre nœuds, un point par grade.

const COL_X := [24.0, 252.0, 480.0]
const NODE := Vector2(216, 96)
const TREE_Y := 330.0
const STEP := 120.0

var _st: Control
var _body: Control
var _t := 0.0


func _init() -> void:
	super._init(720.0)
	_st = use_stage(1.0)
	set_backdrop(Color("ffd166"))
	M3.top_bar(_st, "Capitaine", close)
	_body = Control.new()
	_body.position = Vector2(0, 112)
	_body.size = Vector2(720, UI.H - 112)
	_body.draw.connect(_draw_body)
	_body.gui_input.connect(_input)
	_st.add_child(_body)


func _process(delta: float) -> void:
	_t += delta
	_body.queue_redraw()


func _node_rect(b: int, i: int) -> Rect2:
	return Rect2(COL_X[b], TREE_Y + i * STEP, NODE.x, NODE.y)


static func _oct(r: Rect2, k: float) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(k, 0), Vector2(r.end.x - k, r.position.y), Vector2(r.end.x, r.position.y + k), Vector2(r.end.x, r.end.y - k), Vector2(r.end.x - k, r.end.y), Vector2(r.position.x + k, r.end.y), Vector2(r.position.x, r.end.y - k), Vector2(r.position.x, r.position.y + k)])


func _draw_body() -> void:
	var c := _body
	var g: int = Game.captain_grade()
	var pr: Array = Captain.progress(Game.captain_xp)
	# en-tête : grade, titre, progression, points à placer
	var hr := Rect2(24, 16, 672, 160)
	M3.glass_card(c, hr, false, 24.0)
	var hc := Vector2(100, 96)
	var hex := PackedVector2Array()
	for k in 6:
		var a := -PI / 2.0 + k * PI / 3.0
		hex.append(hc + Vector2(cos(a), sin(a)) * 56.0)
	c.draw_colored_polygon(hex, UI.GOLD)
	c.draw_colored_polygon(PackedVector2Array([hc, hex[2], hex[3], hex[4]]), UI.GOLD.darkened(0.2))
	M3.text(c, hc + Vector2(-50, 16), str(g), 44, Color("1a1206"), true, 100, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(180, 66), "%s · grade %d" % [Captain.title(g), g], 32, UI.TEXT, true, 340)
	var nxt := "Commodore au grade 10 · Amiral au grade 30" if g < 10 else ("Amiral au grade 30" if g < 30 else "le plus haut des titres")
	M3.text(c, Vector2(180, 104), nxt, 20, UI.MUTED, false, 340)
	M3.bar(c, Rect2(180, 130, 340, 12), float(pr[0]) / float(pr[1]), UI.GOLD)
	M3.text(c, Vector2(180, 164), "%d / %d xp" % [int(pr[0]), int(pr[1])], 18, UI.MUTED)
	var pts: int = Game.captain_unspent()
	var lab := "%d point%s" % [pts, "s" if pts > 1 else ""]
	var pw := M3.text_w(lab, 24, true) + 36.0
	var pr2 := Rect2(668 - pw, 72, pw, 48)
	c.draw_style_box(UI.box(Color(UI.GOLD, 0.15), Color(UI.GOLD, 0.7 if pts > 0 else 0.3), 24, 0), pr2)
	M3.text(c, pr2.position + Vector2(0, 33), lab, 24, UI.GOLD if pts > 0 else UI.MUTED, true, pw, HORIZONTAL_ALIGNMENT_CENTER)
	# branches
	for b in Captain.BRANCHES.size():
		var br: Dictionary = Captain.BRANCHES[b]
		M3.text(c, Vector2(COL_X[b], TREE_Y - 28), String(br.name), 22, br.col, true, NODE.x, HORIZONTAL_ALIGNMENT_CENTER)
		for i in br.nodes.size():
			var n: Dictionary = br.nodes[i]
			var r := _node_rect(b, i)
			var id := String(n.id)
			var taken: bool = Game.doctrine.has(id)
			var open := Captain.can_take(id, Game.doctrine, g)
			if i > 0:
				c.draw_line(Vector2(r.get_center().x, r.position.y - STEP + NODE.y + 6), Vector2(r.get_center().x, r.position.y - 6), M3.OUT, 4.0)
			var poly := _oct(r, 18.0)
			var fill := UI.GOLD if taken else (M3.S2 if open else Color(M3.S2, 0.55))
			c.draw_colored_polygon(poly, fill)
			var edge := poly.duplicate()
			edge.append(poly[0])
			if open:
				var k := 0.6 + 0.4 * sin(_t * 4.0)
				c.draw_polyline(edge, Color(UI.ACCENT, k), 3.0, true)
			elif not taken:
				c.draw_polyline(edge, M3.OUT, 2.0, true)
			var ink := Color("1a1206") if taken else (UI.TEXT if open else UI.MUTED)
			var sub := Color("4a3a14") if taken else UI.MUTED
			M3.text(c, r.position + Vector2(8, 38), String(n.name), 24, ink, true, NODE.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
			M3.text(c, r.position + Vector2(8, 70), String(n.desc), 18, sub, false, NODE.x - 16, HORIZONTAL_ALIGNMENT_CENTER)
	var y := TREE_Y + 4 * STEP + 24
	M3.text(c, Vector2(32, y), "L’expérience vient de tout : combats, récoltes, ordres, événements.", 22, UI.MUTED, false, 656)
	M3.text(c, Vector2(32, y + 36), "Un point par grade. Toucher un nœud pris le rend (et ceux qui le suivent).", 22, UI.MUTED, false, 656)


func _input(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	for b in Captain.BRANCHES.size():
		var br: Dictionary = Captain.BRANCHES[b]
		for i in br.nodes.size():
			if not _node_rect(b, i).has_point(ev.position):
				continue
			var id := String(br.nodes[i].id)
			if Game.doctrine.has(id):
				Game.doctrine = Captain.drop(id, Game.doctrine)
				Sfx.play("click", -4.0)
				M3.toast(self, "Point rendu", UI.MUTED)
			elif Captain.can_take(id, Game.doctrine, Game.captain_grade()):
				Game.doctrine.append(id)
				Sfx.play("star", -4.0)
			else:
				Sfx.play("click", -10.0)
				M3.toast(self, "Plus de point à placer" if Game.captain_unspent() == 0 else "Prends d’abord le nœud au-dessus", UI.GOLD)
			Game.save_game()
			Game.changed.emit()
			accept_event()
			return
