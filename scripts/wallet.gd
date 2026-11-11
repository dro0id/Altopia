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


static func raw(k: String) -> float:
	match k:
		"coin": return float(Game.credits)
		"shard": return float(Game.shards)
		"crystal": return float(Game.crystals)
		"token": return float(Game.tokens)
		"itoken": return float(Game.item_tokens)
		"wild": return float(Game.wild)
	return 0.0


static func value(k: String) -> String:
	return UI.num(raw(k))


var _shown := {}      # valeurs affichées : le compteur défile jusqu'à la nouvelle valeur (maquette E4)


func _process(d: float) -> void:
	for k in _shown:
		var t := raw(k)
		var v: float = _shown[k]
		if v != t:
			v = t if Game.reduce_shake else lerpf(v, t, minf(1.0, d * 7.0))
			if absf(t - v) < maxf(1.0, absf(t) * 0.002):
				v = t
			_shown[k] = v
	refresh()


## Point d'arrivée d'un gain qui vole vers sa pastille (coordonnées globales), ou null.
func target_of(k: String):
	if _chips.has(k) and (_chips[k] as Control).visible:
		var c: Control = _chips[k]
		return c.global_position + Vector2(32, c.size.y * 0.5)
	return null


func refresh() -> void:
	var x := 0.0
	var right := position.x + size.x
	var total := 0.0
	for k in keys():
		var c: HudButton = _chips[k]
		if k != "+" and not _shown.has(k):
			_shown[k] = raw(k)
		var t: String = UI.num(roundf(_shown[k])) if k != "+" else "+"
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
	layer.process_mode = Node.PROCESS_MODE_ALWAYS      # les fenêtres mettent le jeu en pause : sans ça, l'appui pour fermer n'arrive jamais
	var opened := Time.get_ticks_msec()
	layer.gui_input.connect(func(ev: InputEvent):
		# l'appui qui a ouvert le panneau ne doit pas le refermer aussitôt
		if M3.is_tap(ev) and Time.get_ticks_msec() - opened > 250:
			layer.queue_free())
	host.add_child(layer)
	var lh := 120.0
	var box := Control.new()
	box.position = Vector2(24, 104 + UI.TOP)
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


const RES_KEY := {"credits": "coin", "shards": "shard", "crystals": "crystal", "tokens": "token", "item_tokens": "itoken"}


## Le gain vole vers sa pastille (maquette E4) : quelques éclats partent de `from` (global) et rejoignent la monnaie.
## `res` : nom de ressource du jeu (credits, shards…) ou clé de pastille. Sans porte-monnaie à l'écran, rien ne se passe.
static func fly(tree: SceneTree, from: Vector2, res: String) -> void:
	var k := String(RES_KEY.get(res, res))
	if Game.reduce_shake:
		return
	var ws := tree.root.find_children("*", "Wallet", true, false)
	if ws.is_empty():
		return
	var w: Wallet = ws[ws.size() - 1]
	var to = w.target_of(k)
	if to == null:
		to = w.target_of("+")
	if to == null:
		return
	var col := {"coin": UI.GOLD, "shard": Color("7fdcff"), "crystal": Color("ff7ad9"), "token": Color("b388ff"), "itoken": Color("ffb142")}.get(k, UI.GOLD) as Color
	for i in 7:
		var p := Control.new()
		p.size = Vector2(18, 18)
		p.z_index = 4096
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.draw.connect(func():
			p.draw_circle(Vector2(9, 9), 9, Color(col, 0.35))
			p.draw_circle(Vector2(9, 9), 6, col))
		tree.root.add_child(p)
		var start: Vector2 = from + Vector2(randf_range(-40, 40), randf_range(-24, 24)) - Vector2(9, 9)
		p.global_position = start
		var mid: Vector2 = start.lerp(to, 0.5) + Vector2(randf_range(-80, 80), -120)
		var tw := p.create_tween()
		tw.tween_interval(i * 0.04)
		tw.tween_method(func(t: float):
			p.global_position = start.lerp(mid, t).lerp(mid.lerp(to - Vector2(9, 9), t), t)
			p.scale = Vector2.ONE * lerpf(1.0, 0.6, t), 0.0, 1.0, 0.55).set_ease(Tween.EASE_IN)
		tw.tween_callback(p.queue_free)
