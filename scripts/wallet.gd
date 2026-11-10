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
		var c := M3.cur_chip(k, "")
		c.ring = k == w.ring
		w.add_child(c)
		w._chips[k] = c
	w.refresh()
	return w


func keys() -> Array:
	return KEYS + ([_extra] if _extra != "" else [])


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
	return ""


func _process(_d: float) -> void:
	refresh()


func refresh() -> void:
	var x := 0.0
	var right := position.x + size.x
	var total := 0.0
	for k in keys():
		var c: HudButton = _chips[k]
		var t := value(k)
		if c.text != t or c.size.x == 0.0:
			c.set_texts(t)
			c.fit_chip()
		c.size.y = 64.0
		c.visible = true
		total += c.size.x + GAP
	for k in keys():
		if max_w <= 0.0 or total - GAP <= max_w or k == ring:
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
