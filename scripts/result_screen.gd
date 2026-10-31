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
var _rewards: VBoxContainer
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
	cv.rarity = chest.rarity
	cv.open_at = 1.2
	box.add_child(cv)
	var rname: String = Data.RARITY_NAMES[chest.rarity]
	var rl := centered("Coffre %s" % rname.to_lower(), 28, Data.CHEST_COLORS[chest.rarity])
	rl.modulate.a = 0.0
	_rewards = VBoxContainer.new()
	_rewards.add_theme_constant_override("separation", 6)
	_rewards.modulate.a = 0.0
	box.add_child(_rewards)
	_reward_row("Crédits", "+ %s" % Data.fmt(chest.credits), UI.GOLD)
	_reward_row("Éclats de verre", "+ %d" % int(chest.shards), Color(0.5, 0.86, 1.0))
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
		var tw := create_tween().set_parallel(true)
		tw.tween_property(rl, "modulate:a", 1.0, 0.3)
		tw.tween_property(_rewards, "modulate:a", 1.0, 0.4)
		tw.tween_property(_buttons, "modulate:a", 1.0, 0.5))
	Sfx.play("win")


func _reward_row(name_text: String, value: String, col: Color) -> void:
	var h := HBoxContainer.new()
	_rewards.add_child(h)
	var a := UI.label(h, name_text, 24, Color(0.85, 0.92, 1.0))
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(h, value, 26, col)


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
