class_name DragScroll
extends Node
## Défilement au doigt d'un ScrollContainer, même quand le doigt commence sur un bouton (les boutons « mangent » le geste sinon).
## Un appui court reste un clic ; au-delà de quelques pixels c'est un défilement, avec un peu d'inertie, et les boutons ne se déclenchent pas.

const THRESHOLD := 14.0

var sc: ScrollContainer
var _down := false
var _moved := false
var _start := Vector2.ZERO
var _scroll0 := 0
var _last_y := 0.0
var _last_t := 0.0
var _vel := 0.0


static func attach(target: ScrollContainer) -> void:
	var d := DragScroll.new()
	d.sc = target
	target.add_child(d)


func _input(ev: InputEvent) -> void:
	if sc == null or not sc.is_visible_in_tree():
		return
	var kind := ""
	var pos := Vector2.ZERO
	if ev is InputEventMouseButton and not UI.emulated(ev) and ev.button_index == MOUSE_BUTTON_LEFT:
		kind = "down" if ev.pressed else "up"
		pos = ev.position
	elif ev is InputEventScreenTouch:
		kind = "down" if ev.pressed else "up"
		pos = ev.position
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		kind = "move"
		pos = ev.position
	elif ev is InputEventScreenDrag:
		kind = "move"
		pos = ev.position
	else:
		return
	match kind:
		"down":
			if not _down and sc.get_global_rect().has_point(pos):
				_down = true
				_moved = false
				_start = pos
				_scroll0 = sc.scroll_vertical
				_last_y = pos.y
				_last_t = Time.get_ticks_msec() / 1000.0
				_vel = 0.0
		"move":
			if _down:
				var dy := pos.y - _start.y
				if not _moved and absf(dy) > THRESHOLD:
					_moved = true
					_cancel_presses(sc)
				if _moved:
					sc.scroll_vertical = int(_scroll0 - dy)
					var now := Time.get_ticks_msec() / 1000.0
					if now > _last_t:
						_vel = lerpf(_vel, (pos.y - _last_y) / (now - _last_t), 0.4)
					_last_y = pos.y
					_last_t = now
					get_viewport().set_input_as_handled()
		"up":
			if _down:
				_down = false
				if _moved:
					get_viewport().set_input_as_handled()
				else:
					_vel = 0.0
				_moved = false


func _process(delta: float) -> void:
	# inertie après le lâcher
	if not _down and absf(_vel) > 20.0 and sc != null:
		sc.scroll_vertical = int(sc.scroll_vertical - _vel * delta)
		_vel *= pow(0.05, delta)
	elif not _down:
		_vel = 0.0


## Annule l'appui en cours sur les boutons de la liste (un défilement ne doit rien acheter).
func _cancel_presses(node: Node) -> void:
	for c in node.get_children():
		if c is BaseButton:
			var was: bool = c.disabled
			c.disabled = true
			c.disabled = was
		_cancel_presses(c)
