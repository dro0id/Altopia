class_name Coach
extends Control
## Tutoriel guidé (maquettes DA à DH) : jeu en pause, projecteur sur l'élément réel à toucher, bulle fléchée.
## Le coach reçoit tous les appuis pendant une étape et déclenche lui-même l'action de l'élément éclairé
## (le jeu est en pause, les boutons du combat ne répondraient pas).

const Data = preload("res://scripts/data.gd")

signal done

const STEPS := [
	{"title": "Ton escouade combat seule", "text": "Tes héros attaquent tout seuls, même quand tu quittes le jeu. Le jeu est en pause le temps du tutoriel.", "btn": "Suivant"},
	{"title": "Lance un pouvoir", "text": "L'anneau de %s est plein : son pouvoir est prêt.", "action": "Touche le portrait de %s"},
	{"title": "Fais progresser ton escouade", "text": "Tu as gagné des crédits. Ils servent à monter le niveau de tes héros.", "action": "Touche « Héros »"},
	{"title": "Choisis un héros", "text": "Chaque carte ouvre la fiche du héros : statistiques, équipement, pouvoir.", "action": "Touche la carte de %s"},
	{"title": "Monte son niveau", "text": "Chaque niveau augmente PV, attaque et défense. Au niveau 10, le héros devra évoluer.", "action": "Touche « Monter le niveau »"},
	{"title": "Monte les étages", "text": "Le jeu passe seul à l'étage suivant. Touche l'étage pour voir la carte, farmer un étage ou revoir le journal.", "btn": "Terminer"},
]
const TIP := {"eyebrow": "ASTUCE · PREMIER OBJET", "title": "Équipe ton butin", "text": "Les coffres donnent des objets. Un seul bouton les place sur les héros qui en profitent le plus.", "action": "Touche « Équiper au mieux »"}

var main: Control
var step := -1                 # -1 : inactif ; 0 à 5 : étapes ; 10 : astuce du premier objet
var _wait := 0.0               # courte reprise du combat après le pouvoir
var _t := 0.0
var _target := Rect2()
var _circle := false
var _bubble := Rect2()
var _btn_rect := Rect2()
var _skip_rect := Rect2()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 4096


func start() -> void:
	step = 0
	_wait = 0.0


func tip() -> void:
	step = 10


func active() -> bool:
	return step >= 0 and _wait <= 0.0


## Héros mis en avant : Mara si elle est dans l'escouade, sinon le premier héros de l'escouade.
func hero_id() -> String:
	var ids: Array = Game.squad_ids()
	return "mara" if ids.has("mara") else (String(ids[0]) if not ids.is_empty() else "mara")


func _has_point(_p: Vector2) -> bool:
	return active() and _target.size != Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if get_index() != get_parent().get_child_count() - 1:
		get_parent().move_child.call_deferred(self, -1)
	if step < 0:
		visible = false
		return
	if _wait > 0.0:
		_wait -= delta
		visible = false
		if _wait <= 0.0:
			step += 1
		return
	_target = _find_target()
	visible = _target.size != Vector2.ZERO
	# combat en pause pendant les étapes jouées sur l'écran de combat
	if step in [0, 1, 2, 5] and (main._modal == null or not is_instance_valid(main._modal)):
		get_tree().paused = true
	if step == 1:
		for u in main.battle.sim.units:
			if u.side == 0 and u.id == hero_id() and u.alive:
				u.skill_cd = 0.0
	if step == 4 and Game.credits < Game.level_cost(hero_id()):
		Game.credits = float(Game.level_cost(hero_id()))
	queue_redraw()


## Rectangle (en coordonnées de l'écran) de l'élément réel à éclairer, ou vide s'il n'est pas à l'écran.
func _find_target() -> Rect2:
	var m = main._modal
	var has_modal: bool = m != null and is_instance_valid(m)
	_circle = false
	match step:
		0:
			return main._field.get_global_rect().grow(-6)
		1:
			var slot: int = Game.squad.find(hero_id())
			if slot < 0 or has_modal:
				return Rect2()
			var b: Control = main.skill_buttons[slot]
			_circle = true
			return Rect2(b.get_global_position() + Vector2(4, 0), Vector2(104, 104))
		2:
			if has_modal:
				return Rect2()
			var nav: Control = main._nav
			var w := (nav.size.x - 16.0) / 4.0
			return Rect2(nav.global_position + Vector2(8.0 + w + 12.0, 8.0), Vector2(w - 24.0, 136.0))
		3:
			if not (has_modal and m is CollectionScreen):
				if not has_modal:
					step = 2
				return Rect2()
			var i: int = m._cells.find(hero_id())
			if i < 0 or not m._grid.is_visible_in_tree():
				return Rect2()
			var r: Rect2 = m._cell_rect(i)
			return Rect2(m._grid.get_global_position() + r.position, r.size)
		4:
			if not (has_modal and m is HeroScreen) or m.level_button == null or not is_instance_valid(m.level_button):
				return Rect2()
			return m.level_button.get_global_rect()
		5:
			if has_modal:
				return Rect2()
			return main._stage_btn.get_global_rect().grow(6)
		10:
			if not (has_modal and m is CollectionScreen) or not m._items_view.is_visible_in_tree():
				return Rect2()
			return m._items_view._fab.get_global_rect()
	return Rect2()


func _gui_input(ev: InputEvent) -> void:
	if not M3.is_tap(ev):
		return
	accept_event()
	var p: Vector2 = ev.position
	if _skip_rect.has_point(p):
		Sfx.play("click", -6.0)
		_finish()
		return
	var info: Dictionary = TIP if step == 10 else STEPS[step]
	if info.has("btn"):
		if _btn_rect.has_point(p) or _target.has_point(p):
			Sfx.play("click", -6.0)
			if step == 5:
				_finish()
			else:
				step += 1
		return
	if not _target.has_point(p):
		return
	Sfx.play("click", -6.0)
	match step:
		1:
			get_tree().paused = false
			var slot: int = Game.squad.find(hero_id())
			main.battle.sim.cast(slot)
			main._manual_cast = true
			_wait = 1.6
		2:
			get_tree().paused = false
			main._open_collection(0)
			step = 3
		3:
			main._modal.hero_requested.emit(hero_id())
			step = 4
		4:
			var hs: HeroScreen = main._modal
			hs.level_button.pressed.emit()
			Game.save_game()
			# retour direct au combat (sans repasser par la collection)
			hs.queue_free()
			step = 5
		10:
			main._modal._items_view._fab.pressed.emit()
			_finish()


func _finish() -> void:
	if step == 10:
		if not Game.tips.has("items"):
			Game.tips.append("items")
	else:
		Game.tutorial_done = true
	Game.save_game()
	step = -1
	visible = false
	if main._modal == null or not is_instance_valid(main._modal):
		get_tree().paused = false
	done.emit()


# ---------------------------------------------------------------- dessin

func _draw() -> void:
	if not visible:
		return
	var r := _target
	var dim := Color(0.016, 0.03, 0.08, 0.8)
	var vw := size.x
	var vh := size.y
	# voile percé autour de la cible (coins arrondis ou cercle)
	draw_rect(Rect2(0, 0, vw, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, vw, vh - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, vw - r.end.x, r.size.y), dim)
	var rad := minf(r.size.x, r.size.y) * 0.5 if _circle else minf(32.0, minf(r.size.x, r.size.y) * 0.5)
	_corner(r.position, r.position + Vector2(rad, rad), PI, PI * 1.5, rad, dim)
	_corner(Vector2(r.end.x, r.position.y), Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5, TAU, rad, dim)
	_corner(r.end, r.end - Vector2(rad, rad), 0.0, PI * 0.5, rad, dim)
	_corner(Vector2(r.position.x, r.end.y), Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5, PI, rad, dim)
	var k := 0.5 + 0.5 * sin(_t * 4.0)
	var ring := UI.box(Color(0, 0, 0, 0), Color(UI.ACCENT, 0.6 + 0.4 * k), int(rad + 6.0), 0)
	ring.set_border_width_all(5)
	draw_style_box(ring, r.grow(5.0 + 3.0 * k))
	_draw_bubble()
	# repères fixes : jeu en pause, passer
	var paused_ui := step in [0, 1, 2, 5]
	var top := 112.0 + float(main._dy) + 16.0
	if paused_ui:
		var pr := Rect2(32, top, 260, 64)
		if step != 0 and (pr.intersects(r) or pr.intersects(_bubble)):
			pr.position.y = r.end.y + 40.0 if r.end.y + 120.0 < _bubble.position.y or _bubble.position.y < r.position.y else _bubble.end.y + 24.0
		draw_style_box(UI.box(M3.S3, Color(0, 0, 0, 0), 32, 0), pr)
		draw_rect(Rect2(pr.position + Vector2(28, 20), Vector2(7, 24)), UI.TEXT)
		draw_rect(Rect2(pr.position + Vector2(41, 20), Vector2(7, 24)), UI.TEXT)
		M3.text(self, pr.position + Vector2(64, 32 + M3.fs(24) * 0.36), "Jeu en pause", 24, UI.TEXT, true)
	var skip_txt := "Plus tard" if step == 10 else "Passer le tutoriel"
	var sw := M3.text_w(skip_txt, 26, true) + 48.0
	_skip_rect = Rect2(vw - 24.0 - sw, top if paused_ui else 24.0 + float(main._dy), sw, 64)
	if step != 0 and (_skip_rect.intersects(r) or _skip_rect.intersects(_bubble)):
		_skip_rect.position.y = vh - 260.0 if r.position.y < vh * 0.5 and _bubble.end.y < vh - 280.0 else top
	M3.text(self, _skip_rect.position + Vector2(0, 32 + M3.fs(26) * 0.36), skip_txt, 26, UI.ACCENT, true, sw, HORIZONTAL_ALIGNMENT_CENTER)


func _corner(corner: Vector2, center: Vector2, a0: float, a1: float, rad: float, col: Color) -> void:
	var pts := PackedVector2Array([corner])
	for i in 9:
		pts.append(center + Vector2.from_angle(lerpf(a0, a1, float(i) / 8.0)) * rad)
	draw_colored_polygon(pts, col)


func _draw_bubble() -> void:
	var info: Dictionary = TIP if step == 10 else STEPS[step]
	var nm := String(Data.HEROES[hero_id()].name).split(" ")[0]
	var title := String(info.title)
	var text := String(info.text) % nm if String(info.text).find("%s") >= 0 else String(info.text)
	var w := 600.0
	var f := ThemeDB.fallback_font
	# hauteur du texte
	var lines := 1
	var line := ""
	for word in text.split(" "):
		var tryl := word if line == "" else line + " " + word
		if f.get_string_size(tryl, HORIZONTAL_ALIGNMENT_LEFT, -1, M3.fs(26)).x > w - 64.0 and line != "":
			lines += 1
			line = word
		else:
			line = tryl
	var h := 32.0 + 28.0 + 44.0 + lines * M3.fs(26) * 1.45 + 24.0 + (88.0 if info.has("btn") else 48.0) + 8.0
	var r := _target
	var cx := clampf(r.get_center().x, 64.0, size.x - 64.0)
	var x := clampf(cx - w * 0.5, 32.0, size.x - 32.0 - w)
	var below := r.get_center().y < size.y * 0.45
	var y := r.end.y + 32.0 if below else r.position.y - 32.0 - h
	if step == 0:
		below = r.end.y + 32.0 + h < size.y - 40.0
		y = r.end.y + 32.0 if below else r.position.y + r.size.y - h - 40.0
	_bubble = Rect2(x, y, w, h)
	draw_style_box(UI.box(M3.SHEET, UI.ACCENT, 40, 0), _bubble)
	var ax := clampf(cx, x + 48.0, x + w - 48.0)
	if step != 0:
		var tip_pts := PackedVector2Array([Vector2(ax - 18, y + (0.0 if below else h)), Vector2(ax + 18, y + (0.0 if below else h)), Vector2(ax, y + (-18.0 if below else h + 18.0))])
		draw_colored_polygon(tip_pts, M3.SHEET)
		draw_polyline(PackedVector2Array([tip_pts[0], tip_pts[2], tip_pts[1]]), UI.ACCENT, 3.0, true)
	var eyebrow := String(info.get("eyebrow", "ÉTAPE %d / %d" % [step + 1, STEPS.size()]))
	M3.text(self, Vector2(x + 32, y + 48), eyebrow, 22, UI.GOLD if step == 10 else UI.ACCENT, true)
	M3.text(self, Vector2(x + 32, y + 92), title, 34, UI.TEXT, true, w - 64.0)
	var th := M3.para(self, Vector2(x + 32, y + 136), text, 26, UI.MUTED, w - 64.0)
	if info.has("btn"):
		var bw := M3.text_w(String(info.btn), 30, true) + 72.0
		_btn_rect = Rect2(x + w - 32.0 - bw, y + 136 + th + 4.0, bw, 88)
		draw_style_box(UI.box(UI.ACCENT, Color(0, 0, 0, 0), 44, 0), _btn_rect)
		M3.text(self, _btn_rect.position + Vector2(0, 44 + M3.fs(30) * 0.36), String(info.btn), 30, UI.DARK, true, bw, HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_btn_rect = Rect2()
		M3.text(self, Vector2(x + 32, y + 136 + th + 30.0), "→ " + (String(info.action) % nm if String(info.action).find("%s") >= 0 else String(info.action)), 26, UI.ACCENT, true, w - 64.0)
