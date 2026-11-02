class_name RecruitScreen
extends Overlay
## Recrutement : un ou dix tirages avec des jetons de recrutement ; les taux et les garanties sont affichés.

var _tokens_label: Label
var _one: Button
var _ten: Button
var _info: Label
var _results: VBoxContainer
var _busy := false


func _init() -> void:
	super._init(660.0)
	var head := HBoxContainer.new()
	box.add_child(head)
	var t := UI.label(head, "Recrutement", 34, UI.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var x := UI.button(head, "Fermer", 22, "ghost")
	x.pressed.connect(close)
	_tokens_label = UI.label(box, "", 28, Color.WHITE)
	var rates := PanelContainer.new()
	rates.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.14, 0.26, 0.98), UI.LINE, 12, 12))
	box.add_child(rates)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 2)
	rates.add_child(rv)
	UI.label(rv, "Taux de recrutement", 22, UI.ACCENT)
	for r in ["common", "rare", "epic"]:
		var h := HBoxContainer.new()
		rv.add_child(h)
		var l := UI.label(h, Data.RARITY_NAMES_HERO[r], 22, Data.RARITY_COLORS[r])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.label(h, "%s %%" % str(snappedf(float(Data.RECRUIT_RATES[r]) * 100.0, 0.1)).trim_suffix(".0"), 22, Color.WHITE)
	_info = UI.label(rv, "", 18, UI.MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results = VBoxContainer.new()
	_results.add_theme_constant_override("separation", 6)
	_results.custom_minimum_size = Vector2(0, 360)
	box.add_child(_results)
	_one = UI.button(box, "", 26, "gold")
	_one.custom_minimum_size = Vector2(0, 68)
	_one.pressed.connect(func(): _pull(1))
	_ten = UI.button(box, "", 26, "gold")
	_ten.custom_minimum_size = Vector2(0, 68)
	_ten.pressed.connect(func(): _pull(10))
	UI.label(box, "Des jetons s'obtiennent dans les coffres, le coffre gratuit et la boutique.", 17, UI.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_refresh()


func _refresh() -> void:
	_tokens_label.text = "Jetons de recrutement : %d" % Game.tokens
	_one.text = "Recruter ×1 · %d jetons" % Data.RECRUIT_COST
	_ten.text = "Recruter ×10 · %d jetons" % Data.RECRUIT_COST_10
	_one.disabled = _busy or Game.tokens < Data.RECRUIT_COST
	_ten.disabled = _busy or Game.tokens < Data.RECRUIT_COST_10
	var p: Dictionary = Game.recruit_pity
	_info.text = "Héros rare ou mieux garanti dans %d tirages, épique dans %d." % [maxi(1, Data.PITY_RARE - int(p.rare)), maxi(1, Data.PITY_EPIC - int(p.epic))]


func _pull(count: int) -> void:
	if _busy:
		return
	var res: Array = Game.recruit(count)
	if res.is_empty():
		return
	_busy = true
	for c in _results.get_children():
		c.queue_free()
	Game.save_game()
	_refresh()
	var shown := res.slice(0, 7) if count > 1 else res
	# on révèle les héros un à un ; pour dix tirages on montre les meilleurs et le résumé
	var order: Array = res.duplicate()
	if count > 1:
		order.sort_custom(func(a, b): return Data.RARITIES_HERO.find(a.rarity) > Data.RARITIES_HERO.find(b.rarity))
		shown = order.slice(0, 6)
	var delay := 0.0
	for r in shown:
		var row := _result_row(r)
		row.modulate.a = 0.0
		_results.add_child(row)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			Sfx.play("star" if r.rarity != "epic" else "chest", -2.0, 0.9 + 0.15 * float(Data.RARITIES_HERO.find(r.rarity))))
		tw.tween_property(row, "modulate:a", 1.0, 0.25)
		delay += 0.45
	if count > 1:
		var news := 0
		var frags := 0
		for r in res:
			if r.new:
				news += 1
			frags += int(r.fragments)
		var sm := UI.label(_results, "Total : %d nouveau(x), + %d fragments" % [news, frags], 22, UI.GREEN)
		sm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sm.modulate.a = 0.0
		var tw2 := create_tween()
		tw2.tween_interval(delay)
		tw2.tween_property(sm, "modulate:a", 1.0, 0.3)
	var done := create_tween()
	done.tween_interval(delay + 0.3)
	done.tween_callback(func():
		_busy = false
		_refresh())


func _result_row(r: Dictionary) -> Control:
	var h: Dictionary = Data.HEROES[r.id]
	var rc: Color = Data.RARITY_COLORS[r.rarity]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.13, 0.23, 0.98), rc, 12, 6))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	p.add_child(hb)
	var ic := HeroIcon.new()
	ic.hero = h
	ic.custom_minimum_size = Vector2(66, 66)
	hb.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	hb.add_child(v)
	UI.label(v, h.name, 26, rc)
	UI.label(v, "%s · %s" % [Data.RARITY_NAMES_HERO[r.rarity], Data.ROLE_NAMES[h.role]], 18, UI.MUTED)
	var tag := UI.label(hb, "NOUVEAU !" if r.new else "+ %d fragments" % int(r.fragments), 24, UI.GREEN if r.new else UI.GOLD)
	tag.custom_minimum_size = Vector2(190, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return p
