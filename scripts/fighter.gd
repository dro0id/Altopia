class_name Fighter
extends Node2D
## Un combattant à l'écran : dessine son unité (héros ou ennemi) avec les animations pilotées par les événements du combat.

const Data = preload("res://scripts/data.gd")

var unit: BattleSim.Unit
var home := Vector2.ZERO
var t := 0.0
var atk_t := 1.0            # 0 -> 1 pendant l'attaque
var atk_len := 0.45
var cast_t := 1.0
var hurt_t := 1.0
var dead_t := 0.0
var lunge := 0.0            # avance de mêlée
var appear := 0.0
var flip := 1.0
var scale_k := 1.0


func setup(u: BattleSim.Unit, pos: Vector2) -> void:
	unit = u
	home = pos
	position = pos
	flip = 1.0 if u.side == 0 else -1.0       # sens de la mêlée : l'escouade avance vers le haut, les ennemis vers le bas
	var depth := 0.62 + 0.38 * clampf((pos.y - 110.0) / 430.0, 0.0, 1.0)
	scale_k = depth * (1.7 if u.boss else (1.25 if u.kind == "mite" else 1.4) if u.side == 1 else 1.05)
	t = randf() * 4.0


func play_attack(melee: bool) -> void:
	atk_t = 0.0
	atk_len = 0.5 if melee else 0.4
	lunge = 34.0 if melee else 0.0


func play_cast() -> void:
	cast_t = 0.0


func play_hurt() -> void:
	hurt_t = 0.0


func _process(delta: float) -> void:
	t += delta
	atk_t = minf(1.0, atk_t + delta / atk_len)
	cast_t = minf(1.0, cast_t + delta / 0.7)
	hurt_t = minf(1.0, hurt_t + delta / 0.25)
	appear = minf(1.0, appear + delta * 3.0)
	if unit != null and not unit.alive:
		dead_t = minf(1.0, dead_t + delta * 2.2)
	var off := sin(PI * atk_t) * lunge * (1.0 if atk_t < 1.0 else 0.0)
	position = home + Vector2(0, -off * flip)
	var sc := scale_k * (0.6 + 0.4 * appear)
	scale = Vector2(sc, sc)
	var flash := 1.0 + 1.1 * (1.0 - hurt_t)
	modulate = Color(flash, flash, flash, 1.0 - dead_t * 0.9) if unit.alive else Color(1, 1, 1, 1.0 - dead_t)
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var p := {
		"t": t, "atk": atk_t if atk_t < 1.0 else 0.0, "cast": (sin(PI * cast_t) if cast_t < 1.0 else 0.0),
		"hurt": 1.0 - hurt_t, "dead": dead_t, "stun": unit.alive and unit.stun_t > 0.0,
	}
	if unit.side == 0:
		Art.draw_hero_back(self, unit.data, p)
	else:
		Art.draw_enemy_front(self, unit.kind, p)
	# barre de vie (dessinée à l'endroit, malgré le retournement)
	if unit.alive:
		var w := 62.0
		var top := -165.0 if unit.side == 0 else (-62.0 if unit.kind == "mite" else -118.0)
		if unit.kind == "titan":
			top = -150.0
		draw_set_transform(Vector2(0, top), 0.0, Vector2.ONE)
		draw_rect(Rect2(-w * 0.5 - 1, -1, w + 2, 9), Color(0, 0, 0, 0.7))
		var col := Color(0.35, 0.9, 0.5) if unit.side == 0 else Color(1.0, 0.4, 0.35)
		draw_rect(Rect2(-w * 0.5, 0, w * unit.hp_frac(), 7), col)
		if unit.shield > 0.0:
			draw_rect(Rect2(-w * 0.5, -4, w * minf(1.0, unit.shield / unit.max_hp), 3), Color(0.5, 0.85, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
