class_name Wallet
extends Control
## Porte-monnaie de la barre du haut (maquette I3) : crédits, éclats, cristaux, toujours dans cet ordre.
## La monnaie de l'écran est cerclée d'or ; un écran peut ajouter la sienne en dernier (jetons au Recrutement).

const KEYS := ["coin", "shard", "crystal"]
const GAP := 8.0

var _chips := {}
var _extra := ""
var ring := ""
var max_w := 0.0       # largeur permise : au-delà, les crédits puis les éclats se masquent (jamais la monnaie cerclée)


## `ring` : monnaie cerclée ; `extra` : monnaie propre à l'écran, ajoutée à droite (et cerclée).
static func make(ring_key := "", extra := "") -> Wallet:
	var w := Wallet.new()
	w.ring = extra if extra != "" else ring_key
	w._extra = extra
	w.mouse_filter = Control.MOUSE_FILTER_PASS
	for k in w.keys():
		if k == "+":
			continue
		var c := M3.cur_chip(k, "")
		c.ring = k == w.ring
		c.tappable = true
		c.role = "chip"
		c.pressed.connect(func(): w._explain([c.icon]))
		w.add_child(c)
		w._chips[k] = c
	var plus := M3.cur_chip("", "+")
	plus.tappable = true
	plus.role = "chip"
	plus.size = Vector2(56, 64)
	plus.pressed.connect(func(): w._explain(["coin", "shard", "crystal", "token", "itoken", "wild"]))
	w.add_child(plus)
	w._chips["+"] = plus
	w.refresh()
	return w


func keys() -> Array:
	return KEYS + ([_extra] if _extra != "" else []) + ["+"]


## Change la monnaie propre à l'écran (jetons de héros ou d'objet au Recrutement).
func set_extra(k: String) -> void:
	if k == _extra or not _chips.has(_extra):
		return
	var c: HudButton = _chips[_extra]
	_chips.erase(_extra)
	_extra = k
	ring = k
	c.icon = k
	_chips[k] = c
	refresh()


static func value(k: String) -> String:
	match k:
		"coin": return UI.num(Game.credits)
		"shard": return UI.num(Game.shards)
		"crystal": return UI.num(Game.crystals)
		"token": return UI.num(Game.tokens)
		"itoken": return UI.num(Game.item_tokens)
		"wild": return UI.num(Game.wild)
	return ""


func _process(_d: float) -> void:
	refresh()


func refresh() -> void:
	var x := 0.0
	var right := position.x + size.x
	var total := 0.0
	for k in keys():
		var c: HudButton = _chips[k]
		var t := value(k) if k != "+" else "+"
		if k != "+" and (c.text != t or c.size.x == 0.0):
			c.set_texts(t)
			c.fit_chip()
		c.size.y = 64.0
		c.visible = true
		total += c.size.x + GAP
	for k in keys():
		if max_w <= 0.0 or total - GAP <= max_w or k == ring or k == "+":
			break
		_chips[k].visible = false
		total -= _chips[k].size.x + GAP
	for k in keys():
		var c: HudButton = _chips[k]
		if not c.visible:
			continue
		c.position = Vector2(x, 0)
		x += c.size.x + GAP
	var w := maxf(0.0, x - GAP)
	if not is_equal_approx(w, size.x):
		size = Vector2(w, 64.0)
		if right > 0.0 and get_parent() != null:
			position.x = right - w          # garde le bord droit en place


## Ce que fait chaque monnaie et où en gagner (maquette I3 : toucher une pastille explique la monnaie).
const INFO := {
	"coin": ["Crédits", "Font monter les héros et paient les chantiers. Combat, Serre et gains hors ligne."],
	"shard": ["Éclats", "Paient les chantiers et les recherches du vaisseau. Raffinerie, boss et recyclage d’objets."],
	"crystal": ["Cristaux", "Accélèrent les chantiers et achètent en Boutique. Coffres, fins de chapitre et Boutique."],
	"token": ["Jetons", "Ouvrent le Recrutement de héros. Antenne, coffres et Boutique."],
	"itoken": ["Jetons d’objet", "Ouvrent les caisses d’objets. Atelier, coffres et Boutique."],
	"wild": ["Doublons au choix", "Comptent comme doublon de n’importe quel héros pour monter en étoile. Coffres et expéditions."],
}


func _explain(keys_: Array) -> void:
	var host: Node = get_viewport()
	var layer := Control.new()
	layer.size = Vector2(720, UI.H)
	layer.z_index = 4096
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.gui_input.connect(func(ev: InputEvent):
		if M3.is_tap(ev):
			layer.queue_free())
	host.add_child(layer)
	var lh := 120.0
	var box := Control.new()
	box.position = Vector2(24, 104)
	box.size = Vector2(672, 40 + lh * keys_.size())
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		M3.dialog(box, Rect2(Vector2.ZERO, box.size))
		var y := 20.0
		for k in keys_:
			var ic := "copies" if k == "wild" else String(k)
			var chip := HudButton.new()
			chip.icon = ic
			chip.draw_icon(box, Vector2(52, y + 34))
			M3.text(box, Vector2(84, y + 44), String(INFO[k][0]), 28, UI.TEXT, true, 380)
			M3.text(box, Vector2(84, y + 44), value(k), 28, UI.GOLD, true, 560, HORIZONTAL_ALIGNMENT_RIGHT)
			var ph := M3.para(box, Vector2(84, y + 80), String(INFO[k][1]), 22, UI.MUTED, 560, 1.3)
			chip.free()
			y += maxf(lh, 56.0 + ph + 8.0)
		if absf(box.size.y - (y + 20.0)) > 1.0:
			box.size.y = y + 20.0
			box.queue_redraw())
	layer.add_child(box)
