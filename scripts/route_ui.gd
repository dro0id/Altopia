extends Control
## Écran de la Route, par-dessus le jeu : la scène 3D remplit l'écran (RouteScene) et l'interface est en surimpression (en-tête, secteur, objectifs,
## équipage, journal, choix de l'étape). Les combats ouvrent le combat en direct (LiveUI en mode Route). À la fin, GameState.finish_live règle le butin.

const Data = preload("res://scripts/game_data.gd")
const Sim = preload("res://scripts/route_sim.gd")
const RouteScene = preload("res://scripts/route_scene.gd")
const MapView = preload("res://scripts/route_map_view.gd")
const LiveUI = preload("res://scripts/live_ui.gd")
const Sfx = preload("res://scripts/live_sfx.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

signal closed(replay: bool)

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float warp = 0.0;
uniform float hit = 0.0;
void fragment() {
	vec2 d = SCREEN_UV - 0.5;
	float r = dot(d, d);
	float ab = 0.0016 + warp * 0.012 + hit * 0.01;
	float k = warp * 0.07;
	vec3 c = vec3(0.0);
	for (int i = 0; i < 6; i++) {
		float s = 1.0 - k * float(i) / 5.0;
		c.r += texture(screen_tex, 0.5 + d * (s + ab)).r;
		c.g += texture(screen_tex, 0.5 + d * s).g;
		c.b += texture(screen_tex, 0.5 + d * (s - ab)).b;
	}
	c /= 6.0;
	c *= 1.0 - r * 1.1;
	c = mix(c, vec3(c.r + 0.3 * hit, c.g * (1.0 - 0.4 * hit), c.b * (1.0 - 0.4 * hit)), hit * 0.6);
	COLOR = vec4(c, 1.0);
}
"""

const TYPE_COLORS := {"combat": Color("ffb26b"), "elite": Color("ff6b7a"), "epave": Color("ffd159"), "recolte": Color("ccb39e"),
	"repos": Color("6eff9c"), "gardien": Color("ff9bed"), "inconnu": Color("7aa6b5")}
const ROLE_COLORS := {"pilot": Color("80f2ff"), "engineer": Color("ffb26b"), "scientist": Color("6eff9c"), "cap": Color("ffd159")}

static var sound_on := true

var sim
var scene: Node3D
var slot_i := 0
var dest := ""
var random := false
var mult := 1.0
var auto_mode := false

var _vp: SubViewport
var _post: ColorRect
var _post_mat: ShaderMaterial
var _flash: ColorRect
var _title: Label
var _step: Label
var _sector: Label
var _obj_labels: Array = []
var _crew_bars: Dictionary = {}
var _loot: Label
var _log: Label
var _action: VBoxContainer
var _sheet: Control
var _map: Control
var _auto_btn: Button
var _result: PanelContainer
var _res_title: Label
var _res_stars: Label
var _res_body: Label
var _res_info: Label
var _again_btn: Button
var _fight: Control
var _players: Array = []
var _busy := false
var _settled := false
var _auto_t := 1.2
var _relaunch_t := -1.0


## Prépare un voyage : `cfg` vient de GameState.route_config, `p_mult` est le multiplicateur de gains annoncé (mode Aléatoire, secteur du jour).
func begin(p_slot: int, p_dest: String, cfg: Dictionary, p_random: bool, p_mult: float, p_seed: int = 0) -> void:
	slot_i = p_slot
	dest = p_dest
	random = p_random
	mult = p_mult
	auto_mode = LiveUI.assist_on
	sim = Sim.new(p_seed)
	sim.setup(cfg)
	_build()
	_refresh()


func _label(text: String, size: int, color: Color = UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _chip(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 60)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	return b


func _glass(accent: Color = UiTheme.LINE, alpha: float = 0.74) -> StyleBoxFlat:
	return UiTheme.box(Color(0.03, 0.08, 0.15, alpha), accent, 12, 1, 9)


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# la scène 3D, plein écran
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.handle_input_locally = false
	_vp.msaa_3d = Viewport.MSAA_DISABLED if OS.has_feature("mobile") else Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cont.add_child(_vp)
	scene = RouteScene.new()
	scene.theme_id = sim.meta.theme.id            # lus par la scène à son démarrage
	scene.mod_id = sim.meta.mod.id
	_vp.add_child(scene)
	scene.arrived.connect(_on_arrived)
	# flou radial et vignette (distorsion), éclair
	_post = ColorRect.new()
	_post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_SHADER
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = sh
	_post.material = _post_mat
	add_child(_post)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# interface en surimpression
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	top.add_child(titles)
	titles.add_child(_label("ROUTE · %s" % Data.DEST[dest].name.to_upper(), 16, UiTheme.DIM))
	_title = _label("Le voyage", 30)
	titles.add_child(_title)
	_step = _label("", 17, Color("ffd159"))
	titles.add_child(_step)
	var map_btn := _chip("Carte", 92)
	map_btn.pressed.connect(func(): _toggle_sheet(not _sheet.visible))
	top.add_child(map_btn)
	_auto_btn = _chip("Auto", 92)
	_auto_btn.toggle_mode = true
	_auto_btn.button_pressed = auto_mode
	_auto_btn.tooltip_text = "Équipage assisté : il choisit la route et les actions, et pilote les combats."
	_auto_btn.toggled.connect(func(v: bool):
		auto_mode = v
		LiveUI.assist_on = v
		_auto_t = 0.8)
	top.add_child(_auto_btn)
	var quit := _chip("✕", 64)
	quit.tooltip_text = "Abandonner le voyage (le butin tombe à 25 %)"
	quit.pressed.connect(_abandon)
	top.add_child(quit)

	_sector = _label("", 16, Color("ffd159"))
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _glass())
	sp.add_child(_sector)
	col.add_child(sp)
	var objs := HBoxContainer.new()
	objs.add_theme_constant_override("separation", 6)
	col.add_child(objs)
	for i in 2:
		var pc := PanelContainer.new()
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := _label("", 15, UiTheme.DIM)
		l.clip_text = true
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		pc.add_child(l)
		objs.add_child(pc)
		_obj_labels.append({"panel": pc, "label": l})
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	# équipage et soute
	var convoy := PanelContainer.new()
	convoy.add_theme_stylebox_override("panel", _glass(UiTheme.LINE, 0.8))
	col.add_child(convoy)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	convoy.add_child(cv)
	var crew := HBoxContainer.new()
	crew.add_theme_constant_override("separation", 8)
	cv.add_child(crew)
	for id in ["cap", "pilot", "engineer", "scientist"]:
		var cc := VBoxContainer.new()
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cc.add_theme_constant_override("separation", 0)
		var nm := _label("", 15, ROLE_COLORS[id])
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		cc.add_child(nm)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 9)
		bar.max_value = 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("6eff9c")
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		var back := StyleBoxFlat.new()
		back.bg_color = Color("12304a")
		back.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", back)
		cc.add_child(bar)
		crew.add_child(cc)
		_crew_bars[id] = {"name": nm, "bar": bar, "fill": fill}
	var lr := HBoxContainer.new()
	cv.add_child(lr)
	var ln := _label("Soute du convoi", 15, UiTheme.DIM)
	ln.autowrap_mode = TextServer.AUTOWRAP_OFF
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lr.add_child(ln)
	_loot = _label("", 16, Color("ffd159"))
	_loot.autowrap_mode = TextServer.AUTOWRAP_OFF
	lr.add_child(_loot)

	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.1, 0.04, 0.78), Color("ffd159"), 10, 1, 8))
	_log = _label("", 17, Color("fff3cf"))
	lp.add_child(_log)
	col.add_child(lp)
	_action = VBoxContainer.new()
	_action.add_theme_constant_override("separation", 6)
	col.add_child(_action)

	_build_sheet()
	_build_result()
	for i in 4:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)


func _build_sheet() -> void:
	_sheet = PanelContainer.new()
	_sheet.visible = false
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(_sheet as PanelContainer).add_theme_stylebox_override("panel", UiTheme.box(Color(0.01, 0.025, 0.06, 0.985), Color(0, 0, 0, 0), 0, 0, 14))
	add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_sheet.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := _label("Carte du secteur", 26)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var close := _chip("✕", 64)
	close.pressed.connect(func(): _toggle_sheet(false))
	h.add_child(close)
	_map = MapView.new()
	_map.sim = sim
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(0, 520)
	_map.node_pressed.connect(func(id: int):
		_toggle_sheet(false)
		_choose_node(id))
	v.add_child(_map)
	var info := _label("Touchez une étape dorée pour y aller. Zone hostile : combat en direct. Épave : un événement, l'équipier choisi tente sa chance. Repos : soigne. Gardien : l'épreuve finale. Une défaite garde 25 % du butin.", 16, UiTheme.DIM)
	v.add_child(info)


func _build_result() -> void:
	_result = PanelContainer.new()
	_result.visible = false
	_result.set_anchors_preset(Control.PRESET_CENTER)
	_result.anchor_left = 0.06
	_result.anchor_right = 0.94
	_result.anchor_top = 0.16
	_result.anchor_bottom = 0.84
	_result.offset_left = 0
	_result.offset_right = 0
	_result.offset_top = 0
	_result.offset_bottom = 0
	_result.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.05, 0.1, 0.96), Color(0.22, 0.9, 1.0, 0.6), 14, 2, 22))
	add_child(_result)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 10)
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	_result.add_child(rc)
	_res_title = _label("", 46)
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_title)
	_res_stars = _label("", 44, Color("ffd159"))
	_res_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_stars)
	_res_body = _label("", 21)
	_res_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_body)
	_res_info = _label("", 20, Color("ffd159"))
	_res_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(_res_info)
	_again_btn = Button.new()
	_again_btn.custom_minimum_size = Vector2(0, 76)
	_again_btn.add_theme_font_size_override("font_size", 24)
	UiTheme.style_primary(_again_btn)
	_again_btn.pressed.connect(func(): closed.emit(true))
	rc.add_child(_again_btn)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(0, 66)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func(): closed.emit(false))
	rc.add_child(back)


func _toggle_sheet(v: bool) -> void:
	_sheet.visible = v
	_map.queue_redraw()


func _play(name: String) -> void:
	if not sound_on:
		return
	var st := Sfx.stream(name)
	if st == null:
		return
	for pl in _players:
		if not pl.playing:
			pl.stream = st
			pl.play()
			return


# ---------- affichage ----------

func _refresh() -> void:
	_title.text = "Secteur %s" % sim.meta.name
	_step.text = "étape %d / %d" % [sim.steps, int(sim.meta.layers) - 1]
	_sector.text = "%s · %s\n%s : %s." % [sim.meta.theme.name, "%d étapes" % int(sim.meta.layers), sim.meta.mod.name, sim.meta.mod.desc]
	for i in 2:
		var id: String = sim.objectives[i]
		var done: bool = sim.over and sim.win and sim.objective_done(id)
		var l: Label = _obj_labels[i].label
		l.text = ("✓ " if done else "○ ") + sim.objective_text(id)
		l.add_theme_color_override("font_color", UiTheme.GOOD if done else UiTheme.DIM)
		_obj_labels[i].panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.09, 0.16, 0.72), UiTheme.GOOD if done else Color(0.11, 0.33, 0.41), 9, 1, 6))
	var hull: float = sim.hull
	_set_bar("cap", "Capitaine", hull)
	for r in Sim.ROLES:
		var c: Dictionary = sim.crew[r]
		_set_bar(r, String(c.name) if c.present else "—", float(c.hp) if c.present else 0.0)
	_loot.text = "%d min · %d don · %d én" % [sim.loot.min, sim.loot.dat, sim.loot.ene]
	var lines: Array = sim.log.slice(-2)
	_log.text = "\n".join(lines.map(func(s): return "▸ " + String(s))) if not lines.is_empty() else ""
	_map.queue_redraw()
	_build_action()


func _set_bar(id: String, name: String, hp: float) -> void:
	var b: Dictionary = _crew_bars[id]
	b.name.text = "%s %d %%" % [name, int(round(hp))] if hp > 0.0 or id == "cap" else name
	b.bar.value = hp
	b.fill.bg_color = Color("6eff9c") if hp >= 50.0 else (Color("ffb26b") if hp >= 25.0 else Color("ff6b7a"))


func _clear_action() -> void:
	for c in _action.get_children():
		c.queue_free()


func _panel_box(tag: String, title: String, text: String = "") -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _glass(UiTheme.LINE, 0.84))
	_action.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	if tag != "":
		v.add_child(_label(tag, 14, UiTheme.DIM))
	if title != "":
		v.add_child(_label(title, 24))
	if text != "":
		v.add_child(_label(text, 17, Color("cfe8ef")))
	return v


func _option_button(parent: Control, title: String, sub: String, color: Color, cb: Callable, disabled: bool = false, tag: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 20)
	b.text = "%s%s\n%s" % [title, "   [%s]" % tag if tag != "" else "", sub] if sub != "" else title
	UiTheme.style_card_button(b, color)
	b.disabled = disabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_action() -> void:
	_clear_action()
	if _busy or _fight != null:
		return
	if sim.over:
		return
	match sim.phase:
		"map":
			var v := _panel_box("PROCHAINE ÉTAPE", "Où aller ?")
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			v.add_child(row)
			for nd in sim.reachable():
				var ty: String = sim.shown_type(nd)
				var b := Button.new()
				b.custom_minimum_size = Vector2(0, 98)
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.focus_mode = Control.FOCUS_NONE
				b.add_theme_font_size_override("font_size", 19)
				b.text = "%s\n%s" % [Sim.TYPES[ty].glyph, Sim.TYPES[ty].name]
				UiTheme.style_card_button(b, TYPE_COLORS[ty])
				b.tooltip_text = _node_hint(ty)
				var nid: int = nd.id
				b.pressed.connect(func(): _choose_node(nid))
				row.add_child(b)
			v.add_child(_label(_hint_line(), 15, UiTheme.DIM))
		"event":
			var ev: Dictionary = sim.event
			var v2 := _panel_box("ÉVÉNEMENT", ev.title, ev.text)
			for i in ev.opts.size():
				var o: Dictionary = ev.opts[i]
				var p: float = sim.option_chance(o)
				var who: String = sim._who_name(o.who)
				var sub := "%s · %s" % [who, "sans risque" if float(o.base) >= 1.0 else "%s %d %%" % [Sim.label_of(p), int(round(p * 100.0))]]
				if float(o.base) < 1.0:
					sub += " · gain %s" % Sim.loot_text(o.win)
				var idx: int = i
				_option_button(v2, o.name, sub, ROLE_COLORS[o.who], func(): _pick_option(idx), not sim.option_available(o))
		"combat":
			var kind := "GARDIEN" if sim.current_type() == "gardien" else ("EMBUSCADE" if sim.elite else "ZONE HOSTILE")
			var title: String = sim.meta.guard.name if sim.current_type() == "gardien" else ("Embuscade" if sim.elite else "Combat")
			var txt := "Le gardien du secteur. S'il tombe, le voyage est réussi." if sim.current_type() == "gardien" else "Des intercepteurs barrent la route."
			var v3 := _panel_box(kind, title, "%s La coque se garde d'un combat à l'autre : %d %%." % [txt, int(round(sim.hull))])
			var go := Button.new()
			go.text = "Lancer le combat"
			go.custom_minimum_size = Vector2(0, 76)
			go.add_theme_font_size_override("font_size", 24)
			go.focus_mode = Control.FOCUS_NONE
			UiTheme.style_primary(go)
			go.pressed.connect(_start_fight)
			v3.add_child(go)
		"harvest":
			var v4 := _panel_box("CHAMP DE RESSOURCES", "")
			var row2 := HBoxContainer.new()
			row2.add_theme_constant_override("separation", 6)
			v4.add_child(row2)
			var boost := 1.5 if sim.meta.mod.id == "pluie" else 1.0
			for h in [["min", "Minerais", "+%d" % int(round(46 * boost)), Color("ccb39e")], ["dat", "Données", "+%d +%d én" % [int(round(34 * boost)), int(round(10 * boost))], Color("80f2ff")], ["ene", "Énergie", "+%d" % int(round(40 * boost)), Color("c08cff")]]:
				var b2 := Button.new()
				b2.custom_minimum_size = Vector2(0, 92)
				b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b2.focus_mode = Control.FOCUS_NONE
				b2.add_theme_font_size_override("font_size", 19)
				b2.text = "%s\n%s" % [h[1], h[2]]
				UiTheme.style_card_button(b2, h[3])
				var kind2: String = h[0]
				b2.pressed.connect(func(): _harvest(kind2))
				row2.add_child(b2)
		"rest":
			var v5 := _panel_box("POINT DE REPOS", "Se réparer ?", "La coque récupère %d %% et chaque équipier %d %%." % [int(Sim.REST_HULL), int(Sim.REST_CREW)])
			var row3 := HBoxContainer.new()
			row3.add_theme_constant_override("separation", 6)
			v5.add_child(row3)
			var rb := Button.new()
			rb.text = "Se reposer"
			rb.custom_minimum_size = Vector2(0, 76)
			rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rb.focus_mode = Control.FOCUS_NONE
			rb.add_theme_font_size_override("font_size", 22)
			UiTheme.style_primary(rb)
			rb.pressed.connect(_rest)
			row3.add_child(rb)
			var sb := Button.new()
			sb.text = "Continuer"
			sb.custom_minimum_size = Vector2(0, 76)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.focus_mode = Control.FOCUS_NONE
			sb.add_theme_font_size_override("font_size", 22)
			sb.pressed.connect(_skip_rest)
			row3.add_child(sb)


func _hint_line() -> String:
	return "Dans la nébuleuse, les étapes lointaines restent cachées (?)." if sim.meta.fog else "Choisissez la prochaine étape, ou ouvrez la carte."


func _node_hint(ty: String) -> String:
	return String(Sim.TYPES[ty].name)


# ---------- déroulement ----------

func _choose_node(id: int) -> void:
	if _busy or _fight != null or sim.over or sim.phase != "map":
		return
	var from_x: float = sim.nodes[sim.at].x
	var nd: Dictionary = sim.nodes[id]
	if not sim.go_to(id):
		return
	_busy = true
	_play("move")
	_refresh()
	scene.travel(String(nd.type), clampf((float(nd.x) - from_x) * 3.0, -1.0, 1.0))
	await scene.arrived
	_busy = false
	_refresh()


func _on_arrived() -> void:
	pass


func _pick_option(i: int) -> void:
	if _busy or sim.phase != "event":
		return
	_busy = true
	var res: Dictionary = sim.pick_option(i)
	_play("probe" if res.ok else "hurt")
	_refresh()
	scene.event_fx(bool(res.ok))
	await scene.fx_done
	_busy = false
	_after_step()


func _harvest(kind: String) -> void:
	if _busy or sim.phase != "harvest":
		return
	_busy = true
	sim.harvest(kind)
	_play("extract")
	_refresh()
	scene.harvest()
	await scene.fx_done
	_busy = false
	_after_step()


func _rest() -> void:
	if _busy or sim.phase != "rest":
		return
	_busy = true
	sim.rest()
	_play("done")
	_refresh()
	scene.rest()
	await scene.fx_done
	_busy = false
	_after_step()


func _skip_rest() -> void:
	if _busy or sim.phase != "rest":
		return
	sim.skip_rest()
	scene.leave()
	_refresh()


func _after_step() -> void:
	if sim.over:
		_finish()
	else:
		_refresh()


func _start_fight() -> void:
	if _busy or _fight != null or sim.phase != "combat":
		return
	var guard: bool = sim.current_type() == "gardien"
	var ui := LiveUI.new()
	_fight = ui
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED      # la scène 3D se repose pendant le combat
	add_child(ui)
	var title: String = String(sim.meta.guard.name) if guard else ("Embuscade" if sim.elite else "Zone hostile")
	ui.begin_route(dest, sim.fight_cfg(LiveUI.assist_on), title, auto_mode)
	ui.fight_done.connect(func(res: Dictionary):
		ui.queue_free()
		_fight = null
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_end_fight(res, guard))
	_clear_action()


func _end_fight(res: Dictionary, guard: bool) -> void:
	_busy = true
	var win: bool = res.win
	sim.apply_fight(res)
	_refresh()
	_play("kill" if win else "lose")
	scene.fight(win and not (sim.over and not sim.win), guard)
	await scene.fx_done
	if not sim.over:
		scene.leave()
		await get_tree().create_timer(0.9).timeout
	_busy = false
	_after_step()


func _abandon() -> void:
	if _busy or _fight != null or sim.over or _settled:
		return
	sim._finish(false, "abandon")
	_finish()


func _finish() -> void:
	if _settled:
		return
	_settled = true
	_busy = false
	_clear_action()
	var res: Dictionary = sim.result()
	GameState.finish_live(slot_i, dest, res, random, "route")
	var win: bool = res.win
	_refresh()
	if win:
		_play("win")
		scene.win_fx()
		await get_tree().create_timer(1.6).timeout
	else:
		_play("lose")
	_res_title.text = "VOYAGE RÉUSSI" if win else ("VOYAGE ABANDONNÉ" if sim.why == "abandon" else "COQUE DÉTRUITE")
	_res_title.add_theme_color_override("font_color", UiTheme.GOOD if win else Color("ff6b7a"))
	var stars := (1 + int(res.objectives_done)) if win else 0
	_res_stars.text = ("★".repeat(stars) + "☆".repeat(3 - stars)) if win else ""
	var lines: Array[String] = [("✓ " if win else "✕ ") + ("« %s » vaincu" % sim.meta.guard.name if win else "Le voyage s'arrête à l'étape %d" % sim.steps)]
	for id in res.objectives:
		var ok: bool = win and sim.objective_done(id)
		lines.append(("✓ " if ok else "○ ") + sim.objective_text(id))
	lines.append("%d étapes · %d combats · coque %d %% · soute %d" % [sim.steps, sim.fights, int(round(sim.hull)), sim.total_loot()])
	_res_body.text = "\n".join(lines)
	_res_info.text = String(GameState.slots[slot_i].last)
	_again_btn.text = "Repartir"
	if GameState.auto_relaunch(slot_i) and GameState.live_block_reason(dest, slot_i) == "":
		_relaunch_t = 4.0
	_result.visible = true


# ---------- boucle ----------

func _process(delta: float) -> void:
	if sim == null:
		return
	if _post_mat != null:
		_post_mat.set_shader_parameter("warp", scene.warp)
		_post_mat.set_shader_parameter("hit", scene.hit)
	_flash.color.a = clampf(scene.flash * 0.7, 0.0, 0.8)
	if _relaunch_t >= 0.0:
		_relaunch_t -= delta
		_again_btn.text = "Relance dans %d s (toucher pour relancer)" % int(ceil(maxf(0.0, _relaunch_t)))
		if _relaunch_t <= 0.0:
			_relaunch_t = -1.0
			closed.emit(true)
	if not auto_mode or _busy or _fight != null or sim.over or _sheet.visible or _result.visible:
		_auto_t = 1.1
		return
	_auto_t -= delta
	if _auto_t > 0.0:
		return
	_auto_t = 1.1
	_auto_decide()


func _auto_decide() -> void:
	match sim.phase:
		"map": _choose_node(sim.auto_node())
		"event": _pick_option(sim.auto_option())
		"combat": _start_fight()
		"harvest": _harvest("min")
		"rest":
			if sim.auto_wants_rest():
				_rest()
			else:
				_skip_rest()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.pressed:
		return
	if ev.keycode == KEY_M:
		_toggle_sheet(not _sheet.visible)
	elif ev.keycode == KEY_ESCAPE and _sheet.visible:
		_toggle_sheet(false)
