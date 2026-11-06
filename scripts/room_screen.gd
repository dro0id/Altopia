class_name RoomScreen
extends Control
## Écran d'une salle de l'Aurore (maquettes IC, IE, IF, IG, IH, LB, LC, PD) : production et réserve, postes,
## amélioration en temps réel (accélérable contre des cristaux), et le contenu propre à la salle :
## niveaux du Pont, recherches du Labo, entraînement des Quartiers, navettes du Hangar.

const Data = preload("res://scripts/data.gd")

var room := ""
var _scroll: ScrollContainer
var _content: Control
var _hits: Array = []                 # [Rect2, Callable]
var _b_left: Button
var _b_right: Button
var _dialog: Control
var _t := 0.0
var _branch := 0                      # Labo : 0 combat, 1 butin, 2 vaisseau
var _press := Vector2.ZERO


func _init(r: String) -> void:
	room = r
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2.ZERO
	size = Vector2(720, 1280 - NavBar.total())
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 10
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.size = size
	add_child(bg)
	M3.top_bar(self, String(Ship.ROOMS[r].name), close)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0, 112)
	_scroll.size = Vector2(720, size.y - 112 - 144)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	DragScroll.attach(_scroll)
	_content = Control.new()
	_content.custom_minimum_size = Vector2(720, 900)
	_content.draw.connect(_draw_content)
	_content.gui_input.connect(_on_content_input)
	_scroll.add_child(_content)
	_b_left = M3.button(self, "", Rect2(32, size.y - 128, 300, 104), "tonal", 28)
	_b_right = M3.button(self, "", Rect2(348, size.y - 128, 340, 104), "main", 28)
	_b_left.pressed.connect(_on_left)
	_b_right.pressed.connect(_on_right)
	Game.changed.connect(_refresh)
	_refresh()


func close() -> void:
	queue_free()


func _exit_tree() -> void:
	if Game.changed.is_connected(_refresh):
		Game.changed.disconnect(_refresh)


func _process(delta: float) -> void:
	_t += delta
	if fmod(_t, 0.5) < delta:
		_refresh()


func s() -> ShipState:
	return Game.ship


func _refresh() -> void:
	var st := s()
	var res := String(Ship.ROOMS[room].res)
	var b := st.building(room)
	_b_left.visible = true
	if res != "":
		var v := floorf(float(st.stock.get(room, 0.0)))
		_b_left.text = "Récolter %s" % (UI.num(v) if res == "credits" else str(int(v)))
		_b_left.disabled = v < 1.0
	elif room == "hangar":
		_b_left.text = "Expédition"
		_b_left.disabled = _free_shuttle() == ""
	else:
		_b_left.visible = false
	var full := not _b_left.visible
	_b_right.position.x = 32.0 if full else 348.0
	_b_right.size.x = 656.0 if full else 340.0
	if not b.is_empty():
		_b_right.text = "Accélérer · %d ◆" % Ship.rush_cost(st.remaining(int(b.end)))
		_b_right.disabled = false
	else:
		var lv := st.room_level(room)
		var block := st.upgrade_block(Game, room)
		if lv >= Ship.MAX_LEVEL:
			_b_right.text = "Niveau maximum"
			_b_right.disabled = true
		else:
			_b_right.text = ("Améliorer → niv. %d" % (lv + 1)) if (block == "" or block == "Pas assez de ressources") else block
			_b_right.disabled = block != "" and block != "Pas assez de ressources"
	_content.queue_redraw()


# ---------------------------------------------------------------- contenu

func _hit(r: Rect2, f: Callable) -> void:
	_hits.append([r, f])


func _draw_content() -> void:
	_hits = []
	var c := _content
	var st := s()
	var info: Dictionary = Ship.ROOMS[room]
	var col: Color = info.color
	var lv := st.room_level(room)
	# carte d'en-tête
	var hr := Rect2(32, 8, 656, 184)
	M3.card(c, hr, M3.S2, 40, Color(col, 0.35))
	c.draw_style_box(UI.box(Color("0a1424"), Color(0, 0, 0, 0), 36, 0), Rect2(60, 36, 128, 128))
	_room_glyph(c, room, Vector2(124, 100), col, 1.5)
	M3.text(c, Vector2(216, 70), "NIVEAU %d" % lv, 24, col, true)
	M3.text(c, Vector2(216, 116), _headline(), 38, UI.TEXT, true, 450)
	M3.text(c, Vector2(216, 156), _subline(), 24, UI.MUTED, false, 450)
	var y := 216.0
	var res := String(info.res)
	if res != "":
		var cap := st.capacity(room, Game.best_stage)
		var v := float(st.stock.get(room, 0.0))
		var left := (cap - v) / maxf(0.0001, st.rate(room, Game.best_stage)) * 3600.0
		M3.text(c, Vector2(32, y + 24), "Réserve", 24, UI.MUTED)
		M3.text(c, Vector2(32, y + 24), "%s / %s · %s" % [_n(v, res), _n(cap, res), "pleine" if left <= 1.0 else "pleine dans " + UI.duration(left)], 24, UI.MUTED, false, 656, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.bar(c, Rect2(32, y + 44, 656, 20), v / maxf(0.001, cap), col)
		y += 96.0
	# chantier en cours
	var b := st.building(room)
	if not b.is_empty():
		var br := Rect2(32, y, 656, 120)
		M3.card(c, br, M3.S2, 32, Color(UI.GOLD, 0.5))
		M3.text(c, Vector2(64, y + 50), "Amélioration → niveau %d" % int(b.to), 28, UI.TEXT, true)
		var tot := float(Ship.upgrade_cost(room, int(b.to), st.rank("logistique")).time)
		var rem := float(st.remaining(int(b.end)))
		M3.text(c, Vector2(64, y + 50), "⏱ " + UI.duration(rem), 26, UI.GOLD, true, 592, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.bar(c, Rect2(64, y + 76, 592, 14), 1.0 - rem / maxf(1.0, tot), UI.GOLD)
		y += 144.0
	match room:
		"pont":
			y = _pont(c, y)
		"labo":
			y = _labo(c, y)
		"hangar":
			y = _hangar(c, y)
	y = _posts(c, y)
	if room in ["centrale", "observatoire", "serre", "atelier", "antenne", "raffinerie"]:
		var jobs := ", ".join(info.jobs)
		y += 8.0
		var h := M3.para(c, Vector2(64, y + 44), "Métiers idéaux : %s. Seuls les héros hors escouade peuvent travailler." % jobs, 24, UI.MUTED, 592)
		c.draw_style_box(UI.box(M3.S2, Color(0, 0, 0, 0), 24, 0), Rect2(32, y, 656, h + 40))
		M3.para(c, Vector2(64, y + 44), "Métiers idéaux : %s. Seuls les héros hors escouade peuvent travailler." % jobs, 24, UI.MUTED, 592)
		y += h + 56.0
	_content.custom_minimum_size.y = y + 24.0


func _headline() -> String:
	var st := s()
	var lv := st.room_level(room)
	var res := String(Ship.ROOMS[room].res)
	match room:
		"pont":
			return "Vaisseau niveau %d" % st.level
		"centrale":
			return "Autonomie %d h" % int(round(st.autonomy_hours()))
		"labo":
			return "Rang max %d" % mini(Ship.RESEARCH_MAX, lv)
		"quartiers":
			return "+1 niveau / %s" % UI.duration(Ship.train_hours(lv) * 3600.0)
		"hangar":
			return "%d navette%s" % [st.fleet().size(), "s" if st.fleet().size() > 1 else ""]
		"observatoire":
			return "+%d %% de butin" % int(round(Ship.observatory_bonus(lv) * (1.0 + st.workers_bonus(room)) * 100.0))
	var rate := st.rate(room, Game.best_stage)
	if res == "credits":
		return "%s crédits / h" % UI.num(rate)
	if rate >= 1.0:
		return "%s %s / h" % [str(snappedf(rate, 0.1)), "éclats" if res == "shards" else "jetons"]
	return "1 jeton / %s" % UI.duration(3600.0 / maxf(0.001, rate))


func _subline() -> String:
	var st := s()
	match room:
		"pont":
			return "Les salles montent jusqu’au niveau du Pont"
		"centrale":
			return "Production et gains hors ligne"
		"quartiers":
			return "jusqu’au niveau moyen de l’escouade − 3"
		"observatoire":
			return "dans les secteurs générés (étage 41+)"
		"labo":
			return "Bonus permanents sur toute l’escouade"
		"hangar":
			return "Expéditions de 1 à 12 h"
	var wb := st.workers_bonus(room)
	return "Base %s · postes +%d %%" % [_n(Ship.base_rate(room, st.room_level(room), Game.best_stage), String(Ship.ROOMS[room].res)) + " / h", int(round(wb * 100.0))]


func _n(v: float, res: String) -> String:
	if res == "credits":
		return UI.num(v)
	if v < 10.0 and absf(v - roundf(v)) > 0.05:
		return str(snappedf(v, 0.1))
	return str(int(v))


## Postes (ou lits des Quartiers) : héros affectés, place libre, place encore fermée.
func _posts(c: Control, y: float) -> float:
	var st := s()
	var maxp := st.max_posts(room)
	var crew: Array = st.posts.get(room, [])
	var title := "AU REPOS" if room == "quartiers" else "POSTES"
	M3.section(c, Vector2(32, y + 32), "%s · %d / %d" % [title, crew.size(), maxp])
	y += 56.0
	if room == "quartiers":
		for i in maxp:
			var r := Rect2(32, y, 656, 120)
			if i < crew.size():
				var hid := String(crew[i])
				M3.card(c, r)
				M3.avatar(c, Data.HEROES[hid], r.position + Vector2(64, 60), 44.0, Color("7dffb0"), _t)
				var lvh := int(Game.levels.get(hid, 1))
				var target := int(Game.squad_avg_level()) - 3
				M3.text(c, r.position + Vector2(128, 50), String(Data.HEROES[hid].name), 28, UI.TEXT, true)
				var step := Ship.train_hours(st.room_level(room)) * 3600.0
				var acc := float(st.training.get(hid, 0.0))
				if lvh >= target:
					M3.text(c, r.position + Vector2(128, 86), "Niv. %d · a rattrapé l’escouade" % lvh, 24, UI.MUTED)
				else:
					M3.text(c, r.position + Vector2(128, 86), "Niv. %d → %d · prochain niveau dans %s" % [lvh, lvh + 1, UI.duration(step - acc)], 24, UI.MUTED, false, 500)
					M3.bar(c, Rect2(r.position.x + 128, r.position.y + 100, 480, 10), acc / step, Color("7dffb0"))
				_hit(r, _assign_sheet.bind(hid))
			else:
				_empty_slot(c, r, "Coucher un héros")
			y += 136.0
		return y + 8.0
	var w := (656.0 - 16.0 * 2.0) / 3.0
	for i in 3:
		var r := Rect2(32 + i * (w + 16.0), y, w, 220)
		if i < crew.size():
			var hid := String(crew[i])
			var ideal := Ship.is_ideal(hid, room)
			M3.card(c, r, M3.S2, 32, Color("7dffb0", 0.6) if ideal else Color(M3.OUT, 0.8))
			M3.avatar(c, Data.HEROES[hid], r.position + Vector2(w / 2.0, 70), 48.0, Color("7dffb0") if ideal else Color("4fb8c8"), _t)
			M3.text(c, r.position + Vector2(0, 156), String(Data.HEROES[hid].name).split(" ")[0], 26, UI.TEXT, true, w, HORIZONTAL_ALIGNMENT_CENTER)
			M3.text(c, r.position + Vector2(0, 192), "+%d %%%s" % [int(Ship.worker_bonus(hid, room) * 100.0), " · idéal" if ideal else ""], 22, Color("7dffb0") if ideal else UI.MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
			_hit(r, _assign_sheet.bind(hid))
		elif i < maxp:
			_empty_slot(c, r, "Affecter")
		else:
			M3.card(c, r, Color(M3.S2, 0.55))
			M3.lock(c, r.position + Vector2(w / 2.0, 80), UI.MUTED, 1.4)
			M3.text(c, r.position + Vector2(0, 140), "Poste %d" % (i + 1), 22, UI.MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
			M3.text(c, r.position + Vector2(0, 172), "vaisseau niv. %d" % (8 if i == 1 else 14), 22, UI.MUTED, false, w, HORIZONTAL_ALIGNMENT_CENTER)
	return y + 244.0


func _empty_slot(c: Control, r: Rect2, label: String) -> void:
	var sb := UI.box(Color(0, 0, 0, 0), M3.OUT, 32, 0)
	sb.set_border_width_all(3)
	c.draw_style_box(sb, r)
	var cy := r.position.y + (60.0 if r.size.y > 150 else r.size.y / 2.0)
	var cx := r.position.x + (r.size.x / 2.0 if r.size.y > 150 else 64.0)
	c.draw_arc(Vector2(cx, cy), 40, 0, TAU, 40, M3.OUT, 3.0, true)
	M3.text(c, Vector2(cx - 40, cy + 14), "+", 40, UI.MUTED, false, 80, HORIZONTAL_ALIGNMENT_CENTER)
	if r.size.y > 150:
		M3.text(c, r.position + Vector2(0, 156), label, 24, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		M3.text(c, r.position + Vector2(128, r.size.y / 2.0 + 10), label, 26, UI.MUTED)
	_hit(r, _assign_sheet.bind(""))


# ---------------------------------------------------------------- Pont (maquette IF)

func _pont(c: Control, y: float) -> float:
	var st := s()
	M3.section(c, Vector2(32, y + 32), "PROCHAINS NIVEAUX")
	y += 48.0
	var unl := {}
	for r in Ship.ORDER:
		unl[int(Ship.ROOMS[r].unlock)] = String(Ship.ROOMS[r].name)
	var shown := 0
	for lv in range(st.level, Ship.MAX_LEVEL + 1):
		if shown >= 6:
			break
		var what: Array = []
		if unl.has(lv) and lv > 1:
			what.append(unl[lv])
		if lv == 8 or lv == 14:
			what.append("poste %d dans chaque salle" % (2 if lv == 8 else 3))
		if lv == 5:
			what.append("2e chantier en parallèle")
		if lv in [6, 11, 16, 20]:
			what.append("nouvelle version : %s" % Ship.tier_info(lv).name)
		if what.is_empty() and lv != st.level:
			continue
		var cur := lv == st.level
		var ok := Game.best_stage > int(Ship.PONT_STAGE[lv]) - 1
		c.draw_circle(Vector2(66, y + 44), 34, UI.ACCENT if cur else M3.S3)
		M3.text(c, Vector2(32, y + 56), str(lv), 26, Color("06101f") if cur else (Color("7dffb0") if ok else UI.MUTED), true, 68, HORIZONTAL_ALIGNMENT_CENTER)
		var t := ", ".join(what) if not what.is_empty() else "Niveau actuel"
		M3.text(c, Vector2(124, y + 40), t.substr(0, 1).to_upper() + t.substr(1), 26, UI.TEXT if (ok or cur) else UI.MUTED, true, 560)
		M3.text(c, Vector2(124, y + 74), "Atteint" if lv <= st.level else ("Étage %d atteint ✓" % int(Ship.PONT_STAGE[lv]) if ok else "Étage %d requis" % int(Ship.PONT_STAGE[lv])), 22, Color("7dffb0") if ok else UI.MUTED)
		c.draw_line(Vector2(32, y + 96), Vector2(688, y + 96), M3.S3, 2)
		y += 104.0
		shown += 1
	return y + 16.0


# ---------------------------------------------------------------- Labo (maquette IG)

func _labo(c: Control, y: float) -> float:
	var st := s()
	var labels := ["Combat", "Butin", "Vaisseau"]
	var keys := ["combat", "butin", "vaisseau"]
	var w := 656.0 / 3.0
	for i in 3:
		var r := Rect2(32 + i * w, y, w, 80)
		var on := i == _branch
		var sb := UI.box(M3.TONAL if on else Color(0, 0, 0, 0), M3.OUT, 40 if (i == 0 or i == 2) else 0, 0)
		sb.set_border_width_all(2)
		c.draw_style_box(sb, r)
		M3.text(c, r.position + Vector2(0, 50), ("✓ " if on else "") + labels[i], 26, UI.TEXT if on else UI.MUTED, on, w, HORIZONTAL_ALIGNMENT_CENTER)
		var bi := i
		_hit(r, func():
			_branch = bi
			Sfx.play("click", -8.0)
			_content.queue_redraw())
	y += 104.0
	for id in Ship.RESEARCH_ORDER:
		var info: Dictionary = Ship.RESEARCH[id]
		if String(info.branch) != keys[_branch]:
			continue
		var running: bool = not st.research_job.is_empty() and String(st.research_job.id) == id
		var r := Rect2(32, y, 656, 128)
		M3.card(c, r, M3.S2, 32, Color(UI.GOLD, 0.6) if running else Color(0, 0, 0, 0))
		var rk := st.rank(id)
		M3.text(c, r.position + Vector2(32, 48), String(info.name), 28, UI.TEXT, true)
		M3.text(c, r.position + Vector2(32 + M3.text_w(String(info.name), 28, true) + 14, 48), "rang %d / %d" % [rk, Ship.RESEARCH_MAX], 22, UI.MUTED)
		M3.text(c, r.position + Vector2(32, 92), "%s · actuel +%d %%" % [info.desc, int(round(st.research_bonus(id) * 100.0))], 22, Color("7dffb0"), false, 600 if (block_of(id) != "" and block_of(id) != "Pas assez de ressources" and not running) else 420)
		var block := st.research_block(Game, id)
		if running:
			var rem := st.remaining(int(st.research_job.end))
			M3.text(c, r.position + Vector2(0, 56), "⏱ " + UI.duration(rem), 24, UI.GOLD, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			M3.text(c, r.position + Vector2(0, 92), "Accélérer · %d ◆" % Ship.rush_cost(rem), 22, UI.ACCENT, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			_hit(r, _rush_research)
		elif block == "" or block == "Pas assez de ressources":
			var cost := st.research_cost(Game, id)
			M3.text(c, r.position + Vector2(0, 56), "%s ¢ · %d ◇" % [UI.num(float(cost.credits)), int(cost.shards)], 22, UI.TEXT if block == "" else UI.RED, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			M3.text(c, r.position + Vector2(0, 92), "⏱ " + UI.duration(float(cost.time)), 22, UI.MUTED, false, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			_hit(r, _start_research.bind(id))
		else:
			M3.text(c, r.position + Vector2(0, 48), block, 22, UI.MUTED, false, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 144.0
	return y + 8.0


func block_of(id: String) -> String:
	return s().research_block(Game, id)


func _start_research(id: String) -> void:
	if s().start_research(Game, id):
		Sfx.play("coin")
		Game.save_game()
		Game.changed.emit()
	else:
		Sfx.play("click", -10.0)


func _rush_research() -> void:
	var cost := Ship.rush_cost(s().remaining(int(s().research_job.end)))
	_confirm_rush(cost, func(): return s().rush_research(Game))


# ---------------------------------------------------------------- Hangar (maquettes LB, LC, LD)

func _free_shuttle() -> String:
	for sh in s().fleet():
		if s().shuttle_state(sh).is_empty():
			return sh
	return ""


func _hangar(c: Control, y: float) -> float:
	var st := s()
	M3.section(c, Vector2(32, y + 32), "FLOTTE")
	y += 48.0
	for sh in Ship.SHUTTLE_ORDER:
		var info: Dictionary = Ship.SHUTTLES[sh]
		var r := Rect2(32, y, 656, 132)
		var owned := st.fleet().has(sh)
		M3.card(c, r, M3.S2, 32, Color(info.color, 0.4) if owned else Color(M3.OUT, 0.6))
		c.draw_style_box(UI.box(Color("0a1424"), Color(0, 0, 0, 0), 24, 0), Rect2(r.position + Vector2(20, 20), Vector2(92, 92)))
		_shuttle_icon(c, sh, r.position + Vector2(66, 66), info.color if owned else UI.MUTED)
		var state := st.shuttle_state(sh)
		M3.text(c, r.position + Vector2(132, 52), String(info.name), 28, UI.TEXT if owned else UI.MUTED, true)
		var role := "%s · %s" % [info.role, ["−25 % de durée", "+50 % de butin", "va plus loin, trouvailles ×2"][Ship.SHUTTLE_ORDER.find(sh)]]
		if not owned:
			M3.text(c, r.position + Vector2(132, 90), "S’ouvre au Hangar niveau %d" % int(info.hangar), 22, UI.MUTED)
		elif state.is_empty():
			M3.text(c, r.position + Vector2(132 + M3.text_w(String(info.name), 28, true) + 12, 52), "· à quai", 22, info.color, true)
			M3.text(c, r.position + Vector2(132, 90), role, 22, UI.MUTED, false, 360)
			var br := Rect2(r.position + Vector2(500, 34), Vector2(136, 64))
			c.draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 32, 0), br)
			M3.text(c, br.position + Vector2(0, 42), "Lancer", 24, Color("06101f"), true, 136, HORIZONTAL_ALIGNMENT_CENTER)
			_hit(r, _expedition_sheet.bind(sh))
		else:
			var rem := st.remaining(int(state.end))
			var dest: Dictionary = Ship.DESTS[state.dest]
			if rem <= 0:
				M3.text(c, r.position + Vector2(132 + M3.text_w(String(info.name), 28, true) + 12, 52), "· rentrée", 22, Color("7dffb0"), true)
				M3.text(c, r.position + Vector2(132, 90), String(dest.name), 22, UI.MUTED)
				var br := Rect2(r.position + Vector2(470, 34), Vector2(166, 64))
				c.draw_style_box(UI.box(Color("7dffb0"), Color(0, 0, 0, 0), 32, 0), br)
				M3.text(c, br.position + Vector2(0, 42), "Récupérer", 24, Color("06101f"), true, 166, HORIZONTAL_ALIGNMENT_CENTER)
				_hit(r, _claim.bind(sh))
			else:
				M3.text(c, r.position + Vector2(132 + M3.text_w(String(info.name), 28, true) + 12, 52), "· en expédition", 22, info.color, true)
				M3.text(c, r.position + Vector2(132, 90), "%s · retour dans %s" % [dest.name, UI.duration(rem)], 22, UI.MUTED, false, 480)
				var tot := st.expedition_hours(String(state.dest), sh, String(state.get("hero", ""))) * 3600.0
				M3.bar(c, Rect2(r.position.x + 132, r.position.y + 104, 480, 10), 1.0 - rem / maxf(1.0, tot), info.color)
				_hit(r, _confirm_rush.bind(Ship.rush_cost(rem), func(): return s().rush_shuttle(Game, sh)))
		y += 148.0
	return y + 8.0


func _claim(sh: String) -> void:
	var out := s().claim(Game, sh)
	if out.is_empty():
		return
	Sfx.play("chest")
	Game.save_game()
	Game.changed.emit()
	_show_return(sh, out)


# ---------------------------------------------------------------- boutons du bas

func _on_left() -> void:
	var res := String(Ship.ROOMS[room].res)
	if res != "":
		if not s().collect(Game, room).is_empty():
			Sfx.play("coin")
			Game.changed.emit()
	elif room == "hangar":
		var sh := _free_shuttle()
		if sh != "":
			_expedition_sheet(sh)


func _on_right() -> void:
	var st := s()
	var b := st.building(room)
	if not b.is_empty():
		_confirm_rush(Ship.rush_cost(st.remaining(int(b.end))), func(): return st.rush_build(Game, room))
		return
	_upgrade_dialog()


# ---------------------------------------------------------------- fenêtres : amélioration, accélération, affectation, expédition

func _open_dialog() -> Control:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = Control.new()
	_dialog.size = size
	_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog.z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.7)
	dim.size = size
	_dialog.add_child(dim)
	dim.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			_dialog.queue_free())
	add_child(_dialog)
	return _dialog


## Amélioration (maquette IE) : avant → après, coûts, durée.
func _upgrade_dialog() -> void:
	var st := s()
	var lv := st.room_level(room)
	var c := Ship.upgrade_cost(room, lv + 1, st.rank("logistique"))
	var d := _open_dialog()
	var box := Control.new()
	box.position = Vector2(40, 180)
	box.size = Vector2(640, 640)
	d.add_child(box)
	var lines := _upgrade_lines(lv)
	var block := st.upgrade_block(Game, room)
	box.draw.connect(func():
		box.draw_style_box(UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0), Rect2(Vector2.ZERO, box.size))
		_room_glyph(box, room, Vector2(80, 84), Ship.ROOMS[room].color, 1.0)
		M3.text(box, Vector2(140, 78), "%s · niveau %d" % [Ship.ROOMS[room].short, lv + 1], 34, UI.TEXT, true, 470)
		M3.text(box, Vector2(140, 116), "Amélioration", 24, UI.MUTED)
		var yy := 168.0
		for l in lines:
			M3.text(box, Vector2(40, yy), String(l[0]), 26, UI.MUTED)
			M3.text(box, Vector2(40, yy), "%s → " % l[1], 26, UI.MUTED, false, 560 - M3.text_w(String(l[2]), 26, true), HORIZONTAL_ALIGNMENT_RIGHT)
			M3.text(box, Vector2(40, yy), String(l[2]), 26, Color("7dffb0"), true, 560, HORIZONTAL_ALIGNMENT_RIGHT)
			box.draw_line(Vector2(40, yy + 20), Vector2(600, yy + 20), M3.S3, 2)
			yy += 60.0
		var x := 40.0
		for it in [["coin", UI.num(float(c.credits)), Game.credits >= float(c.credits)], ["shard", str(int(c.shards)), Game.shards >= int(c.shards)], ["", "⏱ " + UI.duration(float(c.time)), true]]:
			var w := M3.text_w(String(it[1]), 24, true) + (64.0 if it[0] != "" else 32.0)
			box.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 30, 0), Rect2(x, yy, w, 60))
			if it[0] != "":
				box.draw_texture(UI.icon(String(it[0]), 28), Vector2(x + 14, yy + 16))
			M3.text(box, Vector2(x + (52.0 if it[0] != "" else 16.0), yy + 40), String(it[1]), 24, UI.TEXT if it[2] else UI.RED, true)
			x += w + 12.0
		var note := "Un chantier à la fois. Le vaisseau continue de produire pendant les travaux." if st.max_builds() == 1 else "Deux chantiers en parallèle. Le vaisseau continue de produire."
		M3.para(box, Vector2(40, yy + 108), block if block != "" else note, 22, UI.RED if block != "" else UI.MUTED, 560))
	var cancel := M3.button(box, "Annuler", Rect2(40, 520, 250, 96), "tonal", 28)
	cancel.pressed.connect(func(): d.queue_free())
	var ok := M3.button(box, "Améliorer", Rect2(306, 520, 294, 96), "main", 28)
	ok.disabled = block != ""
	ok.pressed.connect(func():
		if st.start_upgrade(Game, room):
			Sfx.play("coin")
			Game.save_game()
			Game.changed.emit()
		d.queue_free())


func _upgrade_lines(lv: int) -> Array:
	var st := s()
	var out: Array = []
	var res := String(Ship.ROOMS[room].res)
	match room:
		"pont":
			out.append(["Production partout", "+%d %%" % int(Ship.PONT_BONUS * lv * 100.0), "+%d %%" % int(Ship.PONT_BONUS * (lv + 1) * 100.0)])
			out.append(["Niveau max des salles", str(lv), str(lv + 1)])
			out.append(["Postes par salle", str(Ship.posts(lv)), str(Ship.posts(lv + 1))])
		"centrale":
			out.append(["Autonomie", "%s h" % str(snappedf(Ship.autonomy_hours(lv), 0.5)), "%s h" % str(snappedf(Ship.autonomy_hours(lv + 1), 0.5))])
		"labo":
			out.append(["Rang maximal", str(mini(10, lv)), str(mini(10, lv + 1))])
		"quartiers":
			out.append(["Un niveau toutes les", UI.duration(Ship.train_hours(lv) * 3600.0), UI.duration(Ship.train_hours(lv + 1) * 3600.0)])
			out.append(["Lits", str(Ship.beds(lv)), str(Ship.beds(lv + 1))])
		"hangar":
			out.append(["Navettes", str(Ship.shuttles_for(lv).size()), str(Ship.shuttles_for(lv + 1).size())])
		"observatoire":
			out.append(["Butin des secteurs générés", "+%d %%" % int(Ship.observatory_bonus(lv) * 100.0), "+%d %%" % int(Ship.observatory_bonus(lv + 1) * 100.0)])
	if res != "":
		var m := st.production_mult(room)
		var a := Ship.base_rate(room, lv, Game.best_stage) * m
		var b := Ship.base_rate(room, lv + 1, Game.best_stage) * m
		out.append(["Production / h", _n(a, res), _n(b, res)])
		out.append(["Réserve", _n(a * st.autonomy_hours(), res), _n(b * st.autonomy_hours(), res)])
	return out


## Terminer tout de suite contre des cristaux (maquette PD).
func _confirm_rush(cost: int, action: Callable) -> void:
	var d := _open_dialog()
	var box := Control.new()
	box.position = Vector2(40, 240)
	box.size = Vector2(640, 520)
	d.add_child(box)
	var enough := Game.crystals >= cost
	box.draw.connect(func():
		box.draw_style_box(UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0), Rect2(Vector2.ZERO, box.size))
		M3.text(box, Vector2(40, 80), "Terminer tout de suite", 34, UI.TEXT, true)
		M3.text(box, Vector2(40, 124), "1 cristal par tranche de 10 min restantes", 24, UI.MUTED)
		box.draw_texture(UI.icon("crystal", 56), Vector2(40, 170))
		M3.text(box, Vector2(112, 214), "%d cristaux · tu en as %d" % [cost, Game.crystals], 30, UI.TEXT if enough else UI.RED, true)
		if not enough:
			M3.para(box, Vector2(40, 290), "Pas assez de cristaux. Ils se gagnent sur les gros boss et dans les expéditions ; leur achat arrivera avec la publication du jeu.", 24, UI.MUTED, 560))
	var cancel := M3.button(box, "Attendre", Rect2(40, 396, 250, 96), "tonal", 28)
	cancel.pressed.connect(func(): d.queue_free())
	var ok := M3.button(box, "Terminer · %d ◆" % cost, Rect2(306, 396, 294, 96), "main", 28)
	ok.disabled = not enough
	ok.pressed.connect(func():
		if action.call():
			Sfx.play("chest")
			Game.save_game()
			Game.changed.emit()
		d.queue_free())


## Affecter un héros (maquette ID) : héros hors escouade, triés par bonus ; « Retirer » pour celui déjà là.
func _assign_sheet(current: String) -> void:
	var st := s()
	var d := _open_dialog()
	var sheet := Control.new()
	var cands: Array = []
	for hid in Data.ALL_HEROES:
		if Game.is_owned(hid):
			cands.append(hid)
	cands.sort_custom(func(a, b):
		var sa: int = 1 if Game.squad_ids().has(a) else 0
		var sb: int = 1 if Game.squad_ids().has(b) else 0
		if sa != sb:
			return sa < sb
		return Ship.worker_bonus(a, room) > Ship.worker_bonus(b, room))
	var rows := mini(cands.size(), 7)
	var h := 200.0 + rows * 112.0 + (112.0 if current != "" else 0.0) + 40.0
	sheet.size = Vector2(720, h)
	sheet.position = Vector2(0, size.y - h)
	d.add_child(sheet)
	var hits: Array = []
	sheet.draw.connect(func():
		hits.clear()
		var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		sheet.draw_style_box(UI.box(M3.OUT, Color(0, 0, 0, 0), 4, 0), Rect2(328, 16, 64, 8))
		M3.text(sheet, Vector2(32, 92), ("Coucher aux Quartiers" if room == "quartiers" else "Affecter : %s" % Ship.ROOMS[room].short), 34, UI.TEXT, true)
		M3.text(sheet, Vector2(32, 134), ("Les héros au repos rattrapent l’escouade" if room == "quartiers" else "Métiers idéaux : " + ", ".join(Ship.ROOMS[room].jobs)), 22, UI.MUTED, false, 656)
		var yy := 168.0
		if current != "":
			var rr := Rect2(32, yy, 656, 96)
			M3.card(sheet, rr, Color("3a1620"))
			M3.text(sheet, rr.position + Vector2(32, 58), "Retirer %s de son poste" % String(Data.HEROES[current].name).split(" ")[0], 26, Color("ff9b9b"), true)
			hits.append([rr, ""])
			yy += 112.0
		for i in rows:
			var hid: String = cands[i]
			var rr := Rect2(32, yy, 656, 96)
			var in_squad: bool = Game.squad_ids().has(hid)
			var post := st.post_of(hid)
			M3.card(sheet, rr, M3.S2 if not in_squad else Color(M3.S2, 0.5))
			M3.avatar(sheet, Data.HEROES[hid], rr.position + Vector2(52, 48), 36.0, Data.RARITY_COLORS[Data.HEROES[hid].rarity], _t)
			M3.text(sheet, rr.position + Vector2(104, 42), String(Data.HEROES[hid].name), 26, UI.TEXT if not in_squad else UI.MUTED, true)
			var where := "dans l’escouade" if in_squad else ("à " + String(Ship.ROOMS[post].short) if post != "" else "libre")
			M3.text(sheet, rr.position + Vector2(104, 76), "%s · niv. %d · %s" % [Data.HEROES[hid].get("job", ""), int(Game.levels[hid]), where], 22, UI.MUTED, false, 400)
			if room != "quartiers":
				var ideal := Ship.is_ideal(hid, room)
				M3.text(sheet, rr.position + Vector2(0, 58), "Escouade" if in_squad else "+%d %%%s" % [int(Ship.worker_bonus(hid, room) * 100.0), " idéal" if ideal else ""], 24, Color("7dffb0") if (ideal and not in_squad) else UI.MUTED, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
			if not in_squad:
				hits.append([rr, hid])
			yy += 112.0)
	sheet.gui_input.connect(func(ev: InputEvent):
		if not M3.is_tap(ev):
			return
		for hh in hits:
			if (hh[0] as Rect2).has_point(ev.position):
				if hh[1] == "":
					st.unassign(current)
				else:
					if current != "" and current != hh[1]:
						st.unassign(current)
					if not st.assign(Game, String(hh[1]), room):
						Sfx.play("click", -10.0)
						return
				Sfx.play("click", -6.0)
				Game.save_game()
				Game.changed.emit()
				d.queue_free()
				return
		sheet.accept_event())


## Lancer une expédition (maquette LC) : destination, pilote facultatif.
func _expedition_sheet(sh: String) -> void:
	var st := s()
	var d := _open_dialog()
	var sheet := Control.new()
	var h := 1090.0
	sheet.size = Vector2(720, h)
	sheet.position = Vector2(0, size.y - h)
	d.add_child(sheet)
	var sel := {"dest": "epave" if st.dest_open(Game, "epave", sh) else "asteroides", "pilot": _best_pilot()}
	var hits: Array = []
	var info: Dictionary = Ship.SHUTTLES[sh]
	sheet.draw.connect(func():
		hits.clear()
		var sb := UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		_shuttle_icon(sheet, sh, Vector2(76, 84), info.color)
		M3.text(sheet, Vector2(140, 80), "%s · expédition" % info.name, 34, UI.TEXT, true)
		M3.text(sheet, Vector2(140, 118), "%s : %s" % [info.role, ["−25 % de durée", "+50 % de butin", "va plus loin, trouvailles ×2"][Ship.SHUTTLE_ORDER.find(sh)]], 24, info.color)
		var yy := 152.0
		for dest in Ship.DEST_ORDER:
			var dd: Dictionary = Ship.DESTS[dest]
			var open := st.dest_open(Game, dest, sh)
			var on: bool = sel.dest == dest
			var rr := Rect2(32, yy, 656, 148)
			M3.card(sheet, rr, M3.TONAL if on else M3.S2, 32, UI.ACCENT if on else Color(0, 0, 0, 0), 3)
			M3.text(sheet, rr.position + Vector2(28, 46), String(dd.name), 28, UI.TEXT if open else UI.MUTED, true)
			M3.text(sheet, rr.position + Vector2(0, 46), "⏱ " + UI.duration(st.expedition_hours(dest, sh, String(sel.pilot)) * 3600.0), 24, UI.GOLD, true, 628, HORIZONTAL_ALIGNMENT_RIGHT)
			M3.text(sheet, rr.position + Vector2(28, 82), String(dd.sub) if open else "S’ouvre à l’étage %d" % (int(dd.stage) - (10 if sh == "sterne" else 0)), 22, UI.MUTED)
			var rw := Ship.dest_reward(dest, Game.best_stage)
			var x := 28.0
			for k in rw:
				var txt := ""
				var ic := ""
				match k:
					"shards":
						ic = "shard"
						txt = "+%d" % int(round(float(rw[k]) * float(info.loot)))
					"item_tokens":
						ic = "itoken"
						txt = "+%d" % int(round(float(rw[k]) * float(info.loot)))
					"tokens":
						ic = "token"
						txt = "+%d" % int(round(float(rw[k]) * float(info.loot)))
					"crystals":
						ic = "crystal"
						txt = "+%d" % int(round(float(rw[k]) * float(info.loot)))
					"credits":
						ic = "coin"
						txt = "+" + UI.num(float(rw[k]) * float(info.loot))
					"chest":
						txt = "Coffre épique"
				var w := M3.text_w(txt, 22, true) + (56.0 if ic != "" else 28.0)
				sheet.draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 22, 0), Rect2(rr.position.x + x, rr.position.y + 98, w, 40))
				if ic != "":
					sheet.draw_texture(UI.icon(ic, 24), rr.position + Vector2(x + 12, 106))
				M3.text(sheet, rr.position + Vector2(x + (44.0 if ic != "" else 14.0), 126), txt, 22, UI.TEXT, true)
				x += w + 10.0
			if open:
				hits.append([rr, "d:" + dest])
			yy += 162.0
		var pr := Rect2(32, yy + 6, 656, 112)
		M3.card(sheet, pr)
		var p := String(sel.pilot)
		if p != "":
			M3.avatar(sheet, Data.HEROES[p], pr.position + Vector2(60, 56), 38.0, Color("7dffb0"), _t)
			M3.text(sheet, pr.position + Vector2(116, 48), "%s · %s" % [String(Data.HEROES[p].name).split(" ")[0], Data.HEROES[p].get("job", "")], 26, UI.TEXT, true)
			var pil := String(Data.HEROES[p].get("job", "")) == "Pilote"
			M3.text(sheet, pr.position + Vector2(116, 84), "métier idéal : −25 % de durée" if pil else "aux commandes", 22, Color("7dffb0") if pil else UI.MUTED)
		else:
			M3.text(sheet, pr.position + Vector2(32, 66), "Sans pilote (un Pilote hors escouade réduit la durée)", 24, UI.MUTED, false, 520)
		M3.text(sheet, pr.position + Vector2(0, 66), "Changer", 24, UI.ACCENT, true, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		hits.append([pr, "p"]))
	var go := M3.button(sheet, "", Rect2(32, h - 136, 656, 104), "main", 28)
	var upd := func():
		go.text = "Lancer %s · retour dans %s" % [info.name, UI.duration(st.expedition_hours(String(sel.dest), sh, String(sel.pilot)) * 3600.0)]
		sheet.queue_redraw()
	upd.call()
	go.pressed.connect(func():
		if st.launch(Game, sh, String(sel.dest), String(sel.pilot)):
			Sfx.play("coin")
			Game.save_game()
			Game.changed.emit()
		d.queue_free())
	sheet.gui_input.connect(func(ev: InputEvent):
		if not M3.is_tap(ev):
			return
		for hh in hits:
			if (hh[0] as Rect2).has_point(ev.position):
				var k := String(hh[1])
				if k.begins_with("d:"):
					sel.dest = k.substr(2)
				else:
					sel.pilot = _next_pilot(String(sel.pilot))
				Sfx.play("click", -8.0)
				upd.call()
				break
		sheet.accept_event())


func _bench() -> Array:
	var out: Array = []
	for hid in Data.ALL_HEROES:
		if Game.is_owned(hid) and not Game.squad_ids().has(hid):
			out.append(hid)
	return out


func _best_pilot() -> String:
	for hid in _bench():
		if String(Data.HEROES[hid].get("job", "")) == "Pilote":
			return hid
	return ""


func _next_pilot(cur: String) -> String:
	var b := _bench()
	b.push_front("")
	var i := b.find(cur)
	return String(b[(i + 1) % b.size()])


## Retour d'expédition (maquette LD).
func _show_return(sh: String, out: Dictionary) -> void:
	var d := _open_dialog()
	var box := Control.new()
	box.position = Vector2(40, 200)
	box.size = Vector2(640, 560)
	d.add_child(box)
	var info: Dictionary = Ship.SHUTTLES[sh]
	box.draw.connect(func():
		box.draw_style_box(UI.box(M3.SHEET, Color(0, 0, 0, 0), 56, 0), Rect2(Vector2.ZERO, box.size))
		_shuttle_icon(box, sh, Vector2(320, 90), info.color, 2.2)
		M3.text(box, Vector2(0, 190), "%s EST RENTRÉE" % String(info.name).to_upper(), 24, UI.ACCENT, true, 640, HORIZONTAL_ALIGNMENT_CENTER)
		M3.text(box, Vector2(0, 236), String(Ship.DESTS[out.dest].name), 34, UI.TEXT, true, 640, HORIZONTAL_ALIGNMENT_CENTER)
		var parts: Array = []
		for k in ["shards", "item_tokens", "tokens", "crystals"]:
			if out.has(k):
				parts.append("+%d %s" % [int(out[k]), {"shards": "éclats", "item_tokens": "jetons d’objet", "tokens": "jetons", "crystals": "cristaux"}[k]])
		if out.has("credits"):
			parts.append("+%s crédits" % UI.num(float(out.credits)))
		if out.has("chest"):
			parts.append("coffre %s" % String(Data.RARITY_NAMES[out.chest.rarity]).to_lower())
		M3.para(box, Vector2(40, 300), " · ".join(parts), 28, UI.TEXT, 560)
		if out.has("fragments"):
			var fr: Dictionary = out.fragments
			box.draw_style_box(UI.box(Color("10331f"), Color(0, 0, 0, 0), 24, 0), Rect2(40, 360, 560, 64))
			M3.text(box, Vector2(64, 402), "Trouvaille rare : fragments de %s ×%d" % [String(Data.HEROES[fr.hero].name).split(" ")[0], int(fr.n)], 24, Color("7dffb0"), true, 520))
	var ok := M3.button(box, "Récupérer", Rect2(40, 444, 560, 96), "main", 28)
	ok.pressed.connect(func(): d.queue_free())


# ---------------------------------------------------------------- toucher, dessins

func _on_content_input(ev: InputEvent) -> void:
	if M3.is_tap(ev):
		_press = ev.position
		return
	if not M3.is_release(ev) or ev.position.distance_to(_press) > 14.0:
		return
	for h in _hits:
		if (h[0] as Rect2).has_point(ev.position):
			(h[1] as Callable).call()
			return


static func _room_glyph(ci: CanvasItem, r: String, c: Vector2, col: Color, k := 1.0) -> void:
	match r:
		"raffinerie":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -34) * k, c + Vector2(22, -10) * k, c + Vector2(12, 34) * k, c + Vector2(-12, 34) * k, c + Vector2(-22, -10) * k]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -34) * k, c + Vector2(22, -10) * k, c + Vector2(0, -2) * k, c + Vector2(-22, -10) * k]), Color("e0f7ff"))
		"centrale":
			ci.draw_arc(c, 30 * k, 0, TAU, 40, col, 5 * k, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(4, -26) * k, c + Vector2(-12, 4) * k, c + Vector2(0, 4) * k, c + Vector2(-4, 26) * k, c + Vector2(12, -6) * k, c + Vector2(0, -6) * k]), col)
		"atelier":
			ci.draw_arc(c, 18 * k, 0, TAU, 32, col, 8 * k, true)
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 22 * k, c + Vector2(cos(a), sin(a)) * 34 * k, col, 9 * k)
		"labo":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -32) * k, c + Vector2(8, -32) * k, c + Vector2(8, -8) * k, c + Vector2(26, 30) * k, c + Vector2(-26, 30) * k, c + Vector2(-8, -8) * k]), Color(col, 0.35))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-17, 12) * k, c + Vector2(17, 12) * k, c + Vector2(26, 30) * k, c + Vector2(-26, 30) * k]), col)
		"quartiers":
			ci.draw_rect(Rect2(c + Vector2(-30, -16) * k, Vector2(60, 12) * k), col)
			ci.draw_rect(Rect2(c + Vector2(-30, 10) * k, Vector2(60, 12) * k), col)
			ci.draw_line(c + Vector2(-32, -26) * k, c + Vector2(-32, 30) * k, col, 4 * k)
			ci.draw_line(c + Vector2(32, -26) * k, c + Vector2(32, 30) * k, col, 4 * k)
		"antenne":
			ci.draw_arc(c + Vector2(-6, 6) * k, 28 * k, -PI * 0.75, PI * 0.25, 24, col, 5 * k, true)
			ci.draw_line(c + Vector2(-24, -14) * k, c + Vector2(14, 24) * k, col, 3 * k)
			ci.draw_circle(c, 6 * k, col)
		"hangar":
			_shuttle_icon(ci, "colibri", c, col, k * 1.4)
		"serre":
			for i in 3:
				ci.draw_circle(c + Vector2(-18 + i * 18, -6) * k, 12 * k, col)
			ci.draw_rect(Rect2(c + Vector2(-30, 8) * k, Vector2(60, 20) * k), Color(col, 0.6))
		"observatoire":
			ci.draw_arc(c + Vector2(0, 12) * k, 30 * k, PI, TAU, 24, col, 4 * k, true)
			ci.draw_line(c + Vector2(-8, 10) * k, c + Vector2(20, -22) * k, col, 8 * k)
		_:
			ci.draw_arc(c + Vector2(0, 8) * k, 30 * k, PI, TAU, 24, col, 4 * k, true)
			ci.draw_circle(c + Vector2(0, 12) * k, 10 * k, Color(0, 0, 0, 0))
			ci.draw_arc(c + Vector2(0, 14) * k, 12 * k, 0, TAU, 24, col, 4 * k, true)


## Profil des navettes (maquette LE) : Colibri fin, Martin trapu à soute, Sterne long à anneau.
static func _shuttle_icon(ci: CanvasItem, kind: String, c: Vector2, col: Color, k := 1.0) -> void:
	var L := Color("dfe6f5")
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * k * 1.5
	match kind:
		"martin":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-15, -7), P.call(6, -7), P.call(15, -1), P.call(15, 5), P.call(-15, 5)]), L)
			ci.draw_rect(Rect2(P.call(-15, 2), Vector2(30, 3.5) * k * 1.5), Color("1e2a55"))
			ci.draw_rect(Rect2(P.call(-11, 5.5), Vector2(16, 5.5) * k * 1.5), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(7, -6), P.call(13, -2), P.call(7, -2)]), Color("9fe9ff"))
		"sterne":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-20, 0), P.call(-10, -4), P.call(14, -3), P.call(28, 0), P.call(14, 2), P.call(-10, 3)]), L)
			ci.draw_rect(Rect2(P.call(-9, 1.2), Vector2(20, 2.2) * k * 1.5), Color("c3cce3"))
			ci.draw_arc(P.call(-21, 0), 5.0 * k * 1.5, 0, TAU, 16, col, 1.6 * k * 1.5, true)
			ci.draw_circle(P.call(0, 6.5), 2.6 * k * 1.5, col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([P.call(-9, 1), P.call(7, 1), P.call(-13, 10)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-16, 0), P.call(-6, -5), P.call(10, -4), P.call(23, 0), P.call(10, 3), P.call(-6, 4)]), L)
			ci.draw_circle(P.call(8, -3), 3.0 * k * 1.5, Color("9fe9ff"))
			ci.draw_circle(P.call(-19, 0), 3.0 * k * 1.5, Color("7fe3ff"))
