class_name OfflineScreen
extends Overlay
## Retour de session (maquette XJ) : le second raconte l'absence, une frise montre ce qui s'est passé,
## les gains s'additionnent (mission et réserves de l'Aurore), et un conseil dit ce qui a été perdu.

signal chest_claimed(chest: Dictionary)
signal room_requested(room: String)

const FLAVOR := [
	"%s a encore gagné aux cartes.",
	"%s a réparé la machine à café. Elle fait des bulles, maintenant.",
	"%s a compté les étoiles. Deux fois.",
	"%s a rangé la soute. Personne ne retrouve plus rien.",
	"%s s'est endormi au poste. Je n'ai rien vu.",
]

var _report := {}
var _ev := {}
var _lost_room := ""


func _init(report: Dictionary) -> void:
	super._init(720.0)
	_report = report
	_ev = report.get("ship", {})
	var st := use_stage(1.0)
	set_backdrop(UI.ACCENT)
	var ready := Game.free_chest_ready()
	_lost_room = _worst_room()
	var body := Control.new()
	body.size = Vector2(720, 1100)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.draw.connect(func(): _draw_body(body))
	st.add_child(body)
	if _lost_room != "":
		var up := M3.button(body, "Agrandir", Rect2(468, _lost_y() + 34, 196, 80), "secondary", 26)
		up.pressed.connect(func():
			Game.ship.collect_all(Game)
			Game.changed.emit()
			room_requested.emit(_lost_room)
			close())
	var h := UI.H
	var ok := M3.button(st, "Tout récupérer", Rect2(32, h - 32 - (96 + 16 if ready else 0) - 104, 656, 104), "success", 32)
	ok.pressed.connect(func():
		Game.ship.collect_all(Game)
		Game.changed.emit()
		close())
	if ready:
		var oc := M3.button(st, "Récupérer et ouvrir le coffre gratuit", Rect2(32, h - 32 - 96, 656, 96), "ghost", 28)
		oc.pressed.connect(func():
			Game.ship.collect_all(Game)
			var c: Dictionary = Game.claim_free_chest()
			if not c.is_empty():
				chest_claimed.emit(c)
			Game.changed.emit()
			close())
	Sfx.play("coin")


# ---------------------------------------------------------------- contenu

## Ce que le second raconte : un fait ou deux, puis une anecdote de bord.
func _quote() -> String:
	var facts := []
	if _lost_room != "":
		var who := _le(String(Ship.ROOMS[_lost_room].short))
		facts.append(who.substr(0, 1).to_lower() + who.substr(1) + " a débordé")
	for sh in _ev.get("shuttles", []):
		facts.append("%s est rentrée" % String(Ship.SHUTTLES[sh].name))
	for d in _ev.get("done", []):
		facts.append("le chantier %s est fini" % _de(String(Ship.ROOMS[d.room].short)))
	if String(_ev.get("research", "")) != "":
		facts.append("le Labo a fini « %s »" % String(Ship.RESEARCH[_ev.research].name))
	var s := "Rien de cassé, Capitaine."
	if not facts.is_empty():
		var f := ", et ".join(facts.slice(0, 2))
		s += " " + f.substr(0, 1).to_upper() + f.substr(1) + "."
	var crew: Array = Game.squad_ids().filter(func(id): return id != "vance")
	if not crew.is_empty():
		var k := int(_report.get("seconds", 0.0)) / 600
		s += " " + FLAVOR[k % FLAVOR.size()] % String(Data.HEROES[crew[k % crew.size()]].name).split(" ")[0]
	return "« %s »" % s       # espaces insécables : les guillemets restent collés au texte


static func _de(room: String) -> String:
	return ("de l’" if room.substr(0, 1) in ["A", "E", "I", "O", "U", "H", "É"] else "de la ") + room if room not in ["Pont", "Labo", "Hangar"] else "du " + room


## Événements datés de l'absence, dans l'ordre : chantiers, recherche, navettes, réserves pleines.
func _timeline() -> Array:
	var start := int(_ev.get("start", 0))
	var out := []
	for d in _ev.get("done", []):
		out.append({"t": int(d.get("end", start)) - start, "kind": "build", "text": "%s niv. %d" % [Ship.ROOMS[d.room].short, int(d.to)]})
	var at: Dictionary = _ev.get("at", {})
	if at.has("research"):
		out.append({"t": int(at.research) - start, "kind": "research", "text": String(Ship.RESEARCH[_ev.research].name)})
	for sh in _ev.get("shuttles", []):
		var key := "shuttle_" + String(sh)
		out.append({"t": int(at.get(key, start)) - start, "kind": "shuttle", "text": "%s rentrée" % String(Ship.SHUTTLES[sh].name)})
	var full: Dictionary = _ev.get("full", {})
	for r in full:
		var secs := float(_report.get("seconds", 0.0)) - float(full[r])
		out.append({"t": int(secs), "kind": "full", "text": "%s %s" % [String(Ship.ROOMS[r].short), "plein" if _masc(String(Ship.ROOMS[r].short)) else "pleine"]})
	out.sort_custom(func(a, b): return int(a.t) < int(b.t))
	return out.slice(0, 4)


## Salle dont la réserve pleine a coûté le plus, ou "".
func _worst_room() -> String:
	var lost: Dictionary = _ev.get("lost", {})
	var best := ""
	var bv := 0.0
	for r in lost:
		var v := float(lost[r])
		if String(Ship.ROOMS[r].res) == "credits":
			v /= 50.0                         # les crédits comptent moins que les éclats et les jetons
		if v >= 1.0 and v > bv:
			bv = v
			best = String(r)
	return best


func _gains() -> Array:
	var stock: Dictionary = _ev.get("stock", {})
	var by := {"credits": float(_report.get("credits", 0.0)), "shards": float(_report.get("shards", 0)), "tokens": 0.0, "item_tokens": 0.0}
	for r in stock:
		var res := String(Ship.ROOMS[r].res)
		if by.has(res):
			by[res] += float(stock[r])
	var out := []
	out.append(["coin", "Crédits · secteur %d" % int(Game.stage), "+" + UI.num(by.credits), UI.GOLD])
	out.append(["shard", "Éclats de verre", "+%d" % int(by.shards), Color("7fdcff")])
	if by.tokens >= 1.0:
		out.append(["token", "Jetons de recrutement", "+%d" % int(by.tokens), Color("b388ff")])
	if by.item_tokens >= 1.0:
		out.append(["itoken", "Jetons d’objet", "+%d" % int(by.item_tokens), Color("ffb142")])
	return out


## Bas de la bulle du second (sa hauteur suit le texte).
func _bubble_end() -> float:
	return 48.0 + 72.0 + _para_h(_quote(), 26, 464, 1.35)


func _tl_y() -> float:
	return maxf(200.0, _bubble_end()) + 56.0


func _rows_top() -> float:
	return _tl_y() + 116.0 if not _timeline().is_empty() else maxf(200.0, _bubble_end()) + 32.0


func _lost_y() -> float:
	return _rows_top() + _gains().size() * 84.0 + 16.0


func _draw_body(c: Control) -> void:
	var secs := float(_report.get("seconds", 0.0))
	# le second parle
	Art.draw_portrait(c, Data.HEROES["vance"], Vector2(96, 120), 56.0, 0.0)
	c.draw_arc(Vector2(96, 120), 60, 0, TAU, 40, UI.ACCENT, 4.0, true)
	var q := _quote()
	var qh := 0.0
	var bubble := Rect2(176, 48, 512, 40)
	qh = _para_h(q, 26, 464, 1.35)
	bubble.size.y = 72.0 + qh
	M3.glass_card(c, bubble, false, 18.0)
	M3.text(c, bubble.position + Vector2(24, 40), "Vance · %s sans vous" % UI.duration(secs), 22, UI.ACCENT, true, 464)
	M3.para(c, bubble.position + Vector2(24, 78), q, 26, UI.TEXT, 464, 1.35)
	# frise
	var tl := _timeline()
	if not tl.is_empty():
		var y := _tl_y()
		var n := tl.size()
		var x0 := 80.0
		var x1 := 640.0
		c.draw_line(Vector2(x0 - 32, y), Vector2(x1 + 32, y), M3.S3, 4.0)
		for i in n:
			var e: Dictionary = tl[i]
			var x := x0 if n == 1 else lerpf(x0, x1, float(i) / float(n - 1))
			var col := {"build": UI.ACCENT, "research": UI.GREEN, "shuttle": Color("b388ff"), "full": Color("ff9f6b")}[e.kind] as Color
			var hex := PackedVector2Array()
			for k in 6:
				var a := PI / 6.0 + k * PI / 3.0
				hex.append(Vector2(x, y) + Vector2(cos(a), sin(a)) * 24.0)
			c.draw_colored_polygon(hex, col)
			M3.text(c, Vector2(x - 20, y + 9), {"build": "⚒", "research": "✓", "shuttle": "➤", "full": "!"}[e.kind], 22, Color("06101f"), true, 40, HORIZONTAL_ALIGNMENT_CENTER)
			M3.text(c, Vector2(x - 80, y + 58), UI.duration(maxf(60.0, float(e.t))), 20, UI.TEXT, true, 160, HORIZONTAL_ALIGNMENT_CENTER)
			M3.text(c, Vector2(x - 80, y + 84), String(e.text), 20, UI.MUTED, false, 160, HORIZONTAL_ALIGNMENT_CENTER)
	# gains
	var yy := _rows_top()
	for g in _gains():
		var r := Rect2(32, yy, 656, 72)
		M3.glass_card(c, r, false, 16.0)
		var hb := HudButton.new()
		hb.icon = String(g[0])
		hb.draw_icon(c, r.position + Vector2(44, 36))
		hb.free()
		M3.text(c, r.position + Vector2(84, 46), String(g[1]), 28, UI.TEXT, true, 380)
		M3.text(c, r.position + Vector2(0, 48), String(g[2]), 34, g[3], true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		yy += 84.0
	# manque à gagner
	if _lost_room != "":
		var ly := _lost_y()
		var lr := Rect2(32, ly, 656, 148)
		c.draw_style_box(UI.box(Color("2a1a0a", 0.9), Color(Color("ffb142"), 0.7), 22, 0), lr)
		M3.text(c, Vector2(64, ly + 44), "MANQUE À GAGNER", 22, Color("ffb142"), true)
		var res := String(Ship.ROOMS[_lost_room].res)
		var lost := float(_ev.lost[_lost_room])
		var full := float(_ev.get("full", {}).get(_lost_room, 0.0))
		var name := String(Ship.RES_NAMES[res])
		var rn := String(Ship.ROOMS[_lost_room].short)
		M3.para(c, Vector2(64, ly + 82), "%s est %s %s : %s %s perdus." % [_le(rn), "resté plein" if _masc(rn) else "restée pleine", UI.duration(full).replace(" ", " "), UI.num(lost) if res == "credits" else str(int(lost)), name], 24, UI.TEXT, 380, 1.3)


static func _le(room: String) -> String:
	if room in ["Pont", "Labo", "Hangar"]:
		return "Le " + room
	return ("L’" if room.substr(0, 1) in ["A", "E", "I", "O", "U", "H", "É"] else "La ") + room


static func _masc(room: String) -> bool:
	return room in ["Atelier", "Pont", "Labo", "Hangar", "Observatoire"]


## Hauteur d'un paragraphe (même découpe que M3.para), sans dessiner.
static func _para_h(text: String, size: int, width: float, line_h: float) -> float:
	var f: Font = ThemeDB.fallback_font
	var n := 0
	var line := ""
	for w in text.split(" "):
		var tryl: String = w if line == "" else line + " " + w
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(size)).x > width and line != "":
			n += 1
			line = w
		else:
			line = tryl
	if line != "":
		n += 1
	return n * M3.fs(size) * line_h
