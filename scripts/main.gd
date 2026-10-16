extends Control
## Interface du prototype, construite entièrement en code.

var _credits_label: Label
var _data_label: Label
var _rate_label: Label
var _synergy_label: Label
var _buttons := {}


func _ready() -> void:
	_build_ui()
	GameState.changed.connect(_refresh)
	_refresh()
	if not GameState.last_offline_report.is_empty():
		_show_offline_report(GameState.last_offline_report)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ALTOPIA"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_credits_label = _make_label(box, 36)
	_data_label = _make_label(box, 30)
	_rate_label = _make_label(box, 24)
	_synergy_label = _make_label(box, 24)

	for id in GameState.CREW:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 110)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(GameState.buy.bind(id))
		box.add_child(b)
		_buttons[id] = b


func _make_label(parent: Node, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	return l


func _refresh() -> void:
	_credits_label.text = "Crédits : %s" % _fmt(GameState.credits)
	_data_label.text = "Données : %s" % _fmt(GameState.data)
	_rate_label.text = "+%s crédits/s   +%s données/s" % [
		_fmt(GameState.credits_per_sec()), _fmt(GameState.data_per_sec())]
	_synergy_label.text = "Synergie d'équipage : x%.2f" % GameState.synergy_multiplier()
	for id in _buttons:
		var b: Button = _buttons[id]
		b.text = "%s (niv. %d) — %s crédits" % [
			GameState.CREW[id].name, GameState.levels[id], _fmt(GameState.cost_of(id))]
		b.disabled = not GameState.can_buy(id)


func _show_offline_report(r: Dictionary) -> void:
	var d := AcceptDialog.new()
	d.title = "Bon retour, Commandant !"
	d.dialog_text = "Pendant votre absence (%d min) :\n+%s crédits\n+%s données" % [
		int(r.seconds / 60.0), _fmt(r.credits), _fmt(r.data)]
	add_child(d)
	d.popup_centered(Vector2i(560, 280))


func _fmt(n: float) -> String:
	if n >= 1.0e9:
		return "%.2fB" % (n / 1.0e9)
	if n >= 1.0e6:
		return "%.2fM" % (n / 1.0e6)
	if n >= 1.0e3:
		return "%.2fK" % (n / 1.0e3)
	return "%.1f" % n if n < 100.0 else "%d" % int(n)
