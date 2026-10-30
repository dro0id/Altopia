class_name Fighter
extends Node2D
## Un combattant à l'écran : dessine son unité (héros ou ennemi) et pilote son animation (préparation, frappe, recul, pas, chute).

const Data = preload("res://scripts/data.gd")

var unit: BattleSim.Unit
var home := Vector2.ZERO
var t := 0.0
var atk_t := 1.0            # 0 -> 1 pendant l'attaque
var atk_len := 0.55
var cast_t := 1.0
var hurt_t := 1.0
var dead_t := 0.0
var lunge := 0.0            # avance de mêlée
var appear := 0.0
var flip := 1.0             # 1 : l'escouade avance vers le haut ; -1 : les ennemis avancent vers le bas
var scale_k := 1.0
var stride := 0.0           # phase de marche
var move := 0.0             # 0..1, intensité du déplacement (jambes)
var _last_off := 0.0
var _hit_dir := 0.0


func setup(u: BattleSim.Unit, pos: Vector2) -> void:
	unit = u
	home = pos
	position = pos
	flip = 1.0 if u.side == 0 else -1.0
	var depth := 0.62 + 0.38 * clampf((pos.y - 110.0) / 430.0, 0.0, 1.0)
	scale_k = depth * (1.7 if u.boss else (1.25 if u.kind == "mite" else 1.4) if u.side == 1 else 1.05)
	t = randf() * 4.0
	if u.side == 1:
		appear = -randf() * 0.25      # les ennemis arrivent en décalé


func play_attack(melee: bool) -> void:
	atk_t = 0.0
	atk_len = 0.62 if melee else 0.5
	lunge = 38.0 if melee else 0.0


func play_cast() -> void:
	cast_t = 0.0


func play_hurt() -> void:
	hurt_t = 0.0


## Profil d'avance de mêlée : léger recul (préparation), détente rapide, retour en douceur.
func _lunge_curve(a: float) -> float:
	if a < 0.3:
		return -0.22 * smoothstep(0.0, 0.3, a)
	if a < 0.5:
		return lerpf(-0.22, 1.0, smoothstep(0.3, 0.5, a))
	return 1.0 - smoothstep(0.5, 1.0, a)


func _process(delta: float) -> void:
	t += delta
	atk_t = minf(1.0, atk_t + delta / atk_len)
	cast_t = minf(1.0, cast_t + delta / 0.7)
	hurt_t = minf(1.0, hurt_t + delta / 0.3)
	appear = minf(1.0, appear + delta * 1.8)
	if unit != null and not unit.alive:
		dead_t = minf(1.0, dead_t + delta * 1.6)
	var off := _lunge_curve(atk_t) * lunge if atk_t < 1.0 else 0.0
	var vel := absf(off - _last_off) / maxf(delta, 0.001)
	_last_off = off
	move = lerpf(move, clampf(vel / 140.0, 0.0, 1.0), 0.25)
	stride += vel * delta * 0.22
	# entrée en scène : les ennemis tombent du haut en rebondissant, l'escouade fait un petit saut
	var a := clampf(appear, 0.0, 1.0)
	var drop := 0.0
	if appear < 1.0:
		drop = -(1.0 - a) * (1.0 - a) * (220.0 if flip < 0.0 else 40.0) - (absf(sin(a * PI * 2.0)) * 10.0 * (1.0 - a))
	# recul quand on est touché
	var hk := 1.0 - hurt_t
	var knock := hk * hk * 9.0 * flip
	position = home + Vector2(sin(t * 60.0) * hk * 2.0, -off * flip + drop + knock)
	var sc := scale_k
	var squash := 0.12 * hk + (0.06 * sin(PI * clampf(appear, 0.0, 1.0)) if appear < 1.0 else 0.0)
	scale = Vector2(sc * (1.0 + squash), sc * (1.0 - squash))
	var flash := 1.0 + 1.1 * hk
	modulate = Color(flash, flash, flash, 1.0 - dead_t * 0.9) if unit.alive else Color(1, 1, 1, 1.0 - dead_t)
	if appear < 0.0:
		modulate.a = 0.0
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var p := {
		"t": t, "atk": atk_t if atk_t < 1.0 else 0.0, "cast": (sin(PI * cast_t) if cast_t < 1.0 else 0.0),
		"hurt": 1.0 - hurt_t, "dead": dead_t, "stun": unit.alive and unit.stun_t > 0.0,
		"stride": stride, "move": move, "melee": lunge > 0.0,
	}
	if unit.side == 0:
		Art.draw_hero_back(self, unit.data, p)
	else:
		Art.draw_enemy_front(self, unit.kind, p)
	# barre de vie
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
