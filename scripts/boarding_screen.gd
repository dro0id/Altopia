class_name BoardingScreen
extends Overlay
## Abordage (maquette WM) : la coupe de l'Aurore devient le champ de bataille. Les héros aux postes défendent
## leur salle ; à chaque vague, le Capitaine envoie l'escouade renforcer une salle assaillie.

var _b := Boarding.new()
var _st: Control
var _view: ShipView
var _over: Control
var _go: Button
var _t := 0.0
var _sel := ""
var _pause := 0.0            # courte pause entre deux vagues
var _chips := {}             # salle -> Rect2 (toucher : choisir la salle à défendre)
var _finished := false
var _paid := false
var _mites: Array = []


func _init() -> void:
	super._init(720.0)
	z_index = 0
	_st = use_stage(1.0)
	set_backdrop(UI.RED)
	_view = ShipView.new()
	_view.position = Vector2(0, 112)
	_view.size = Vector2(720, UI.H - NavBar.total() - 112 - 152)
	_st.add_child(_view)
	_view.setup(Game.ship.level, Game.ship.posts, Game.ship.rooms)
	_view.set_cut(true)
	_over = Control.new()
	_over.position = _view.position
	_over.size = _view.size
	_over.draw.connect(_draw_over)
	_over.gui_input.connect(_over_input)
	_st.add_child(_over)
	var head := Control.new()
	head.size = Vector2(720, 112)
	head.draw.connect(func(): _draw_head(head))
	_st.add_child(head)
	_go = M3.button(_st, "", Rect2(32, UI.H - NavBar.total() - 128, 656, 104), "main", 28)
	# mites de verre à l'assaut, dessinées par des nœuds (le dessin d'un ennemi pose sa propre transformation)
	for i in 9:
		var m := Node2D.new()
		m.scale = Vector2(0.32, 0.32)
		m.visible = false
		var k := i
		m.draw.connect(func(): Art.draw_enemy_front(m, "mite", {"t": _t + k}))
		_over.add_child(m)
		_mites.append(m)
	_go.pressed.connect(_on_go)
	_b.start(Game)
	Sfx.play("warn")
	Game.haptic("alert")
	_pick_default()
	_refresh_button()


func _process(delta: float) -> void:
	_t += delta
	_over.queue_redraw()
	for c in _st.get_children():
		if c is Control and c != _view:
			(c as Control).queue_redraw()
	if _finished:
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_b.next_wave(Game)
			if _b.done():
				_finish()
			else:
				Sfx.play("warn", -6.0)
				_pick_default()
				_refresh_button()
		return
	if _b.step(Game, delta):
		Sfx.play("boom", -6.0)
		_pause = 1.6
		_refresh_button()


## Par défaut, la salle la plus menacée.
func _pick_default() -> void:
	var worst := ""
	var wv := -1.0
	for a in _b.assaults:
		var k := float(a.attack) / maxf(1.0, _b.defense(Game, String(a.room)))
		if k > wv:
			wv = k
			worst = String(a.room)
	_sel = worst


func _refresh_button() -> void:
	if _finished:
		M3.price(_go, "Récupérer · %s" % Orders.reward_text(_b.reward()) if _b.held > 0 else "Fermer", [])
		UI.set_role(_go, "success" if _b.held > 0 else "secondary")
		_go.disabled = false
		return
	if _pause > 0.0:
		M3.price(_go, "Vague suivante…", [])
		_go.disabled = true
		return
	_go.disabled = _sel == "" or _b.deployed != ""
	if _b.deployed != "":
		M3.price(_go, "Escouade à %s" % _le(String(Ship.ROOMS[_b.deployed].short)).to_lower(), [])
	else:
		M3.price(_go, "Envoyer l’escouade %s" % _a(String(Ship.ROOMS[_sel].short)) if _sel != "" else "Choisis une salle", [])


func _on_go() -> void:
	if _finished:
		_pay()
		close()
		return
	if _sel != "" and _b.deployed == "":
		_b.deploy(_sel)
		Sfx.play("cast", -4.0)
		_refresh_button()


func _finish() -> void:
	_finished = true
	Game.boarding_day = Boarding.today()
	Game.save_game()
	_refresh_button()


func _pay() -> void:
	if _paid:
		return
	_paid = true
	Orders.give(_b.reward(), Game)
	Game.captain_gain("boarding")
	Game.boarding_day = Boarding.today()
	Game.save_game()
	Game.changed.emit()


## Quitter en cours de route : les vagues restantes se jouent sans l'escouade, la récompense est versée.
func close() -> void:
	if not _finished:
		while not _b.done():
			if _b.step(Game, Boarding.WAVE_TIME):
				_b.next_wave(Game)
		_finished = true
	_pay()
	super.close()


static func _le(room: String) -> String:
	return OfflineScreen._le(room)


## « à la Serre », « à l'Atelier », « au Pont ».
static func _a(room: String) -> String:
	var le := OfflineScreen._le(room)
	if le.begins_with("Le "):
		return "au " + room
	return "à " + le.substr(0, 1).to_lower() + le.substr(1)


func _draw_head(c: Control) -> void:
	var r := Rect2(24, 16, 672, 80)
	c.draw_style_box(UI.box(Color("3a1620", 0.95), Color(UI.RED, 0.8), 20, 0), r)
	M3.text(c, Vector2(52, 66), "⚠ ABORDAGE", 30, Color("ff9b9b"), true)
	var wv := mini(_b.wave, Boarding.WAVES)
	M3.text(c, Vector2(280, 66), "vague %d / %d" % [wv, Boarding.WAVES] if not _finished else "terminé", 24, UI.TEXT)
	if not _finished:
		var left := maxf(0.0, Boarding.WAVE_TIME - _b.t) if _pause <= 0.0 else 0.0
		M3.text(c, Vector2(0, 66), "0:%02d" % int(ceil(left)), 30, UI.TEXT, true, 664, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_over() -> void:
	var c := _over
	_chips = {}
	for m in _mites:
		m.visible = false
	var now := ShipState.now()
	var shown := {}
	if _finished:
		_draw_result(c)
		return
	for a in _b.assaults:
		var r := String(a.room)
		shown[r] = true
		var lp := _view.label_pos(r)
		if lp.is_empty():
			continue
		var at: Vector2 = lp.pos
		# mites à l'assaut autour de la salle
		var ai := _b.assaults.find(a)
		for k in 3:
			var mi := ai * 3 + k
			if mi >= _mites.size():
				break
			var ph := _t * 1.3 + k * 2.1 + at.x * 0.01
			var m: Node2D = _mites[mi]
			m.position = at + Vector2(cos(ph) * 90.0, 70.0 + sin(ph * 1.7) * 8.0)
			m.visible = _pause <= 0.0 or float(a.attack) > _b.defense(Game, r)
			m.queue_redraw()
		var pr := float(a.progress)
		var lost: bool = _pause > 0.0 and float(a.attack) > _b.defense(Game, r)
		var held: bool = _pause > 0.0 and not lost
		_chip(c, r, at, "perdue · 1 h" if lost else ("tenue" if held else "assaut · %d %%" % int(minf(pr, 1.0) * 100.0)), UI.RED if (lost or (pr >= 0.7 and not held)) else (UI.GREEN if held else Color("ffb142")), _sel == r, true)
	# salles déjà perdues pendant cet abordage
	for h in _b.history:
		var r := String(h.room)
		if shown.has(r) or bool(h.held) or int(Game.ship.blocked.get(r, 0)) <= now:
			continue
		shown[r] = true
		var lp := _view.label_pos(r)
		if not lp.is_empty():
			_chip(c, r, lp.pos, "perdue · 1 h", UI.RED, false, false)
	# trait de l'escouade vers la salle choisie
	if _sel != "" and _b.deployed == "":
		var lp2 := _view.label_pos(_sel)
		if not lp2.is_empty():
			var from := Vector2(360, c.size.y - 10)
			var to: Vector2 = lp2.pos + Vector2(0, 30)
			var n := 16
			for i in n:
				if i % 2 == 0:
					c.draw_line(from.lerp(to, float(i) / n), from.lerp(to, float(i + 1) / n), UI.RED, 4.0)


func _chip(c: Control, r: String, at: Vector2, status: String, col: Color, sel: bool, tappable: bool) -> void:
	var crew: Array = Game.ship.posts.get(r, [])
	var name := String(Ship.ROOMS[r].short)
	var w := maxf(M3.text_w(name, 24, true), M3.text_w(status, 20, true)) + 40.0 + crew.size() * 40.0
	var rect := Rect2(clampf(at.x - w * 0.5, 12.0, 708.0 - w), at.y - 38.0, w, 76.0)
	c.draw_style_box(UI.box(Color(0.04, 0.06, 0.13, 0.92), col if not sel else UI.ACCENT, 22, 0), rect)
	if sel:
		c.draw_style_box(UI.box(Color(0, 0, 0, 0), Color(UI.ACCENT, 0.5 + 0.5 * sin(_t * 6.0)), 24, 0), rect.grow(4))
	var x := rect.position.x + 14.0
	for h in crew:
		M3.avatar(c, Data.HEROES[h], Vector2(x + 18, rect.position.y + 38), 18.0, Color("7dffb0") if Ship.is_ideal(String(h), r) else Color("4fb8c8"), _t)
		x += 40.0
	if _b.deployed == r:
		M3.text(c, Vector2(rect.end.x - 34, rect.position.y + 30), "★", 22, UI.ACCENT, true)
	M3.text(c, Vector2(x + 6, rect.position.y + 32), name, 24, UI.TEXT, true)
	M3.text(c, Vector2(x + 6, rect.position.y + 60), status, 20, col, true)
	if tappable:
		_chips[r] = rect.grow(10)


func _draw_result(c: Control) -> void:
	var r := Rect2(48, c.size.y * 0.5 - 170, 624, 340)
	M3.dialog(c, r)
	M3.text(c, Vector2(r.position.x, r.position.y + 70), "L’Aurore a tenu" if _b.held >= _b.lost else "L’essaim est reparti", 36, UI.TEXT, true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	M3.text(c, Vector2(r.position.x, r.position.y + 120), "%d salle%s tenue%s · %d perdue%s (arrêtée%s 1 h)" % [_b.held, "s" if _b.held > 1 else "", "s" if _b.held > 1 else "", _b.lost, "s" if _b.lost > 1 else "", "s" if _b.lost > 1 else ""], 24, UI.MUTED, false, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	var y := r.position.y + 170
	for h in _b.history.slice(maxi(0, _b.history.size() - 4)):
		M3.text(c, Vector2(r.position.x + 48, y), "Vague %d · %s" % [int(h.wave), Ship.ROOMS[h.room].short], 22, UI.TEXT)
		M3.text(c, Vector2(r.position.x, y), "tenue" if bool(h.held) else "perdue", 22, UI.GREEN if bool(h.held) else UI.RED, true, r.size.x - 48, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 36


func _over_input(ev: InputEvent) -> void:
	if not M3.is_tap(ev) or _finished or _b.deployed != "":
		return
	for r in _chips:
		if (_chips[r] as Rect2).has_point(ev.position):
			_sel = String(r)
			Sfx.play("click", -6.0)
			_refresh_button()
			accept_event()
			return
