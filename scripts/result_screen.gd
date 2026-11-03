class_name ResultScreen
extends Overlay

## Étage vaincu : étoiles, coffre qui s'ouvre, butin, puis « Monter » ou « Rejouer ».

signal next_pressed
signal replay_pressed
signal map_pressed

var _stars_node: Control
var _t := 0.0
var _star_count := 3
var _stars_shown := 0
var _rewards: HBoxContainer
var _hint: Label
var _tiles: Array = []
var _combo_text := ""
var _buttons: VBoxContainer


func _init(stage: int, star_count: int, chest: Dictionary, next_label: String) -> void:
	super._init(660.0)
	_star_count = star_count
	var bt: String = Data.boss_type(stage)
	var title := "GROS BOSS VAINCU" if bt == "big" else ("MINI-BOSS VAINCU" if bt == "mini" else "ÉTAGE VAINCU")
	centered(title, 40, UI.GREEN)
	centered("Étage %d" % stage, 24, UI.MUTED)
	_stars_node = Control.new()
	_stars_node.custom_minimum_size = Vector2(0, 80)
	_stars_node.draw.connect(_draw_stars)
	box.add_child(_stars_node)
	var note := "Aucun héros tombé" if star_count == 3 else ("Un héros est tombé" if star_count == 2 else "Plusieurs héros sont tombés")
	centered(note, 20, UI.MUTED)
	var cv := ChestView.new()
	cv.setup(chest.rarity)
	box.add_child(cv)
	var rname: String = Data.RARITY_NAMES[chest.rarity]
	var rcol: Color = Data.CHEST_COLORS[chest.rarity]
	var rl := centered("COFFRE %s" % rname.to_upper(), 26, rcol)
	_hint = centered("Touche le coffre pour l'ouvrir", 20, UI.MUTED)
	cv.armed_changed.connect(func(): _hint.visible = false)
	if bt == "big":
		var pr := HBoxContainer.new()
		box.add_child(pr)
		var pl := UI.label(pr, "Garantie légendaire", 20, Color.WHITE)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.label(pr, "%d / %d gros boss" % [mini(int(Game.pity.get("leg", 0)), Data.LEGENDARY_PITY), Data.LEGENDARY_PITY], 18, UI.MUTED)
		var bars := HBoxContainer.new()
		bars.add_theme_constant_override("separation", 4)
		box.add_child(bars)
		for i in Data.LEGENDARY_PITY:
			var seg := ColorRect.new()
			seg.custom_minimum_size = Vector2(0, 10)
			seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			seg.color = Data.CHEST_COLORS["legendaire"] if i < int(Game.pity.get("leg", 0)) else Color(0.11, 0.16, 0.32)
			bars.add_child(seg)
	# le butin reste caché (« ? ») jusqu'à l'ouverture
	_rewards = HBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 8)
	box.add_child(_rewards)
	_tiles.append(_tile("Crédits", "+%s" % Data.fmt(chest.credits), UI.GOLD))
	_tiles.append(_tile("Éclats", "+%d" % int(chest.shards), Color(0.5, 0.86, 1.0)))
	_tiles.append(_tile("Jetons", "+%d" % int(chest.get("tokens", 0)), Color(0.75, 0.6, 1.0)))
	_tiles.append(_tile("Cristaux", "+%d" % int(chest.get("crystals", 0)), Color(1.0, 0.48, 0.85)))
	if chest.get("combo_bonus", 0.0) > 0.0:
		_combo_text = "Bonus de combo : + %d %% de crédits" % int(round(chest.combo_bonus * 100.0))
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	_buttons.modulate.a = 0.0
	box.add_child(_buttons)
	var nb := UI.button(_buttons, next_label, 28, "main")
	nb.custom_minimum_size = Vector2(0, 68)
	nb.pressed.connect(func():
		next_pressed.emit()
		close())
	var rb := UI.button(_buttons, "Rejouer cet étage", 22, "ghost")
	rb.custom_minimum_size = Vector2(0, 56)
	rb.pressed.connect(func():
		replay_pressed.emit()
		close())
	var mb := UI.button(_buttons, "Carte des étages", 22, "ghost")
	mb.custom_minimum_size = Vector2(0, 56)
	mb.pressed.connect(func():
		map_pressed.emit()
		close())
	cv.opened.connect(func():
		Game.claim_pending()
		_reveal()
		var tw := create_tween()
		tw.tween_property(_buttons, "modulate:a", 1.0, 0.5))
	Sfx.play("win")


func close() -> void:
	Game.claim_pending()    # si on quitte l'écran avant l'ouverture, le butin est quand même versé
	super.close()


## Une case de butin : « ? » tant que le coffre est fermé.
func _tile(title: String, value: String, col: Color) -> Dictionary:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.08, 0.18, 0.95), Color(0.3, 0.4, 0.6, 0.6), 12, 8))
	_rewards.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var val := UI.label(v, "?", 30, Color(0.3, 0.38, 0.55))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nm := UI.label(v, title, 17, UI.MUTED)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return {"panel": p, "val": val, "text": value, "col": col}


func _reveal() -> void:
	var i := 0
	for tl in _tiles:
		var d: float = 0.12 * i
		i += 1
		var val: Label = tl.val
		var pnl: PanelContainer = tl.panel
		var tw := create_tween()
		tw.tween_interval(d)
		tw.tween_callback(func():
			val.text = tl.text
			val.add_theme_color_override("font_color", tl.col)
			pnl.pivot_offset = pnl.size * 0.5
			pnl.scale = Vector2(1.18, 1.18)
			Sfx.play("coin", -8.0, 1.0 + 0.1 * i))
		tw.tween_property(pnl, "scale", Vector2.ONE, 0.25)
	if _combo_text != "":
		var cl := centered(_combo_text, 20, UI.GREEN)
		box.move_child(cl, _rewards.get_index() + 1)


func _process(delta: float) -> void:
	_t += delta
	var shown := int(floor((_t - 0.3) / 0.35)) + 1
	while _stars_shown < mini(shown, 3):
		_stars_shown += 1
		if _stars_shown <= _star_count:
			Sfx.play("star", -4.0, 1.0 + 0.15 * _stars_shown)
	_stars_node.queue_redraw()


func _draw_stars() -> void:
	var cx := _stars_node.size.x * 0.5
	for i in 3:
		var appear := clampf((_t - 0.3 - i * 0.35) / 0.3, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var pop := 1.0 + 0.4 * sin(appear * PI)
		var col := UI.GOLD if i < _star_count else Color(0.17, 0.23, 0.42)
		Art.star(_stars_node, Vector2(cx + (i - 1) * 96.0, 40.0), 36.0 * pop * appear, col, 0.0)
