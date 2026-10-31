class_name BattleSim
extends RefCounted
## Simulation du combat automatique : aucun dessin ici (voir battle.gd). On avance avec step(dt) et on lit `events` pour animer.
## Déterministe pour une graine donnée, donc testable en ligne de commande.

const Data = preload("res://scripts/data.gd")

class Unit:
	var side := 0                # 0 = escouade du joueur, 1 = ennemis
	var slot := 0
	var id := ""                 # identifiant du héros ou du type d'ennemi
	var name := ""
	var role := ""
	var kind := ""               # type d'ennemi (mite, drone...) ou "" pour un héros
	var level := 1
	var max_hp := 1.0
	var hp := 1.0
	var atk := 1.0
	var def := 0.0
	var interval := 1.0
	var cd := 0.0
	var skill_kind := ""
	var skill_cd := 0.0
	var skill_max := 10.0
	var shield := 0.0
	var shield_t := 0.0
	var stun_t := 0.0
	var alive := true
	var ranged := false
	var boss := false
	var phase2 := false          # le gros boss passe en phase 2 sous 50 % de PV
	var warned := false          # avertissement du coup puissant déjà émis
	var gold := 0.0
	var data: Dictionary = {}

	func hp_frac() -> float:
		return clampf(hp / max_hp, 0.0, 1.0)


var units: Array[Unit] = []
var events: Array = []
var pending: Array = []
var stage := 1
var wave := 0
var waves_total := Data.WAVES_PER_STAGE
var state := "fighting"          # fighting | clear | defeat
var time := 0.0
var credits := 0.0               # butin gagné pendant ce combat
var fallen := 0                  # héros tombés pendant l'étage
var stars := 0                   # étoiles à la victoire (voir Data.stars_for)
var clear_bonus := 0.0
var auto_cast := true
var rng := RandomNumberGenerator.new()
var _wave_timer := 0.0


func _init(team: Array, p_stage: int, p_seed: int = 1) -> void:
	stage = p_stage
	rng.seed = p_seed + p_stage * 1009
	var slot := 0
	for e in team:
		var u := _make_hero(String(e.id), int(e.level), slot)
		units.append(u)
		slot += 1
	_spawn_wave()


func allies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == 0:
			out.append(u)
	return out


func enemies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == 1 and u.alive:
			out.append(u)
	return out


func _alive(side: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.side == side and u.alive:
			out.append(u)
	return out


func _make_hero(id: String, level: int, slot: int) -> Unit:
	var h: Dictionary = Data.HEROES[id]
	var m := Data.hero_mult(level)
	var u := Unit.new()
	u.side = 0
	u.slot = slot
	u.id = id
	u.name = h.name
	u.role = h.role
	u.level = level
	u.max_hp = h.hp * m
	u.hp = u.max_hp
	u.atk = h.atk * m
	u.def = h.def * m
	u.interval = h.interval
	u.ranged = h.ranged
	u.skill_kind = h.skill.kind
	u.skill_max = h.skill.cd
	u.skill_cd = h.skill.cd * 0.5
	u.cd = 0.4 + 0.15 * slot
	u.data = h
	return u


func _make_enemy(kind: String, slot: int, boss: bool) -> Unit:
	var e: Dictionary = Data.ENEMIES[kind]
	var s := Data.stage_scale(stage)
	var u := Unit.new()
	u.side = 1
	u.slot = slot
	u.id = kind
	u.kind = kind
	u.name = e.name
	u.role = "boss" if boss else "enemy"
	u.boss = boss
	var boss_k := 1.0 + (0.035 * stage if kind == "titan" else (0.015 * stage if kind == "foreur" else 0.0))   # les boss durcissent avec la profondeur
	u.max_hp = Data.ENEMY_HP * s * e.hp * boss_k
	u.hp = u.max_hp
	u.atk = Data.ENEMY_ATK * s * e.atk
	u.def = (Data.ENEMY_DEF + stage * 0.6) * e.def
	u.interval = e.interval
	u.ranged = e.ranged
	u.gold = 3.0 * s * e.gold
	u.cd = 0.6 + 0.2 * slot
	if boss:
		u.skill_kind = "slam"
		u.skill_max = 7.0
		u.skill_cd = 5.0
	u.data = e
	return u


## Composition des vagues : plus de monstres et d'ennemis solides au fil des vagues, un boss à la fin des secteurs multiples de 5.
func _wave_kinds() -> Array:
	var w := wave
	var kinds: Array = []
	var last := w == waves_total
	if last and Data.boss_type(stage) == "big":
		return ["titan", "drone", "drone"]
	if last and Data.boss_type(stage) == "mini":
		return ["foreur", "mite", "mite"]
	match w:
		1:
			kinds = ["mite", "mite", "mite"]
		2:
			kinds = ["mite", "drone", "drone"]
		_:
			kinds = ["drone", "drone", "gunner"]
	if stage >= 6:
		kinds.append("mite" if w == 1 else "drone")
	if stage >= 12:
		kinds.append("gunner")
	return kinds


func _spawn_wave() -> void:
	wave += 1
	var kinds := _wave_kinds()
	var slot := 0
	for k in kinds:
		var u := _make_enemy(String(k), slot, Data.BOSS_KINDS.has(k))
		units.append(u)
		events.append({"type": "spawn", "unit": u})
		slot += 1
	events.append({"type": "wave", "wave": wave, "total": waves_total, "boss": kinds.has("titan") or kinds.has("foreur"), "boss_type": Data.boss_type(stage) if wave == waves_total else ""})


func cast(slot: int) -> bool:
	for u in units:
		if u.side == 0 and u.slot == slot:
			return _cast(u)
	return false


func _cast(u: Unit) -> bool:
	if not u.alive or u.stun_t > 0.0 or u.skill_cd > 0.0 or state != "fighting":
		return false
	u.skill_cd = u.skill_max
	u.warned = false
	match u.skill_kind:
		"shield":
			for a in _alive(0):
				a.shield = u.atk * 3.5
				a.shield_t = 6.0
			events.append({"type": "cast", "unit": u, "kind": "shield"})
		"volley":
			var i := 0
			for e in _alive(1):
				pending.append({"t": 0.45 + i * 0.1, "kind": "hit", "src": u, "dst": e, "dmg": u.atk * 2.4, "fx": "missile"})
				i += 1
			events.append({"type": "cast", "unit": u, "kind": "volley", "targets": _alive(1)})
		"pierce":
			var best: Unit = null
			for e in _alive(1):
				if best == null or e.hp > best.hp:
					best = e
			if best != null:
				pending.append({"t": 0.4, "kind": "hit", "src": u, "dst": best, "dmg": u.atk * 6.0, "fx": "pierce"})
				events.append({"type": "cast", "unit": u, "kind": "pierce", "target": best})
		"repair":
			for a in _alive(0):
				_heal(a, u.atk * 2.4)
			events.append({"type": "cast", "unit": u, "kind": "repair"})
		"gravity":
			for e in _alive(1):
				e.stun_t = 2.0
				pending.append({"t": 0.3, "kind": "hit", "src": u, "dst": e, "dmg": u.atk * 1.3, "fx": "gravity"})
			events.append({"type": "cast", "unit": u, "kind": "gravity"})
		"slam":
			for a in _alive(0):
				var k := 1.2 if u.kind == "foreur" else (1.9 if u.phase2 else 1.6)
				pending.append({"t": 0.55, "kind": "hit", "src": u, "dst": a, "dmg": u.atk * k, "fx": "slam"})
			events.append({"type": "cast", "unit": u, "kind": "slam"})
	return true


func _heal(a: Unit, amount: float) -> void:
	var before := a.hp
	a.hp = minf(a.max_hp, a.hp + amount)
	events.append({"type": "heal", "unit": a, "amount": a.hp - before})


func _pick_target(u: Unit) -> Unit:
	var foes := _alive(1 - u.side)
	if foes.is_empty():
		return null
	if u.side == 0:
		return foes[0]                       # on vise l'ennemi le plus proche : la première place vivante
	if rng.randf() < 0.6:
		return foes[0]
	return foes[rng.randi() % foes.size()]


func _apply_hit(p: Dictionary) -> void:
	var dst: Unit = p.dst
	if not dst.alive:
		return
	var dmg: float = p.dmg * 100.0 / (100.0 + dst.def)
	if dst.shield > 0.0:
		var absorbed := minf(dst.shield, dmg)
		dst.shield -= absorbed
		dmg -= absorbed
	dst.hp -= dmg
	events.append({"type": "hit", "unit": dst, "amount": dmg, "fx": p.get("fx", "")})
	if dst.hp <= 0.0:
		dst.alive = false
		dst.hp = 0.0
		events.append({"type": "death", "unit": dst})
		if dst.side == 1:
			credits += dst.gold
		else:
			fallen += 1
	elif dst.kind == "titan" and not dst.phase2 and dst.hp <= dst.max_hp * 0.5:
		_enter_phase2(dst)


## Phase 2 du gros boss : plus rapide et plus fort, et deux mites arrivent en renfort.
func _enter_phase2(b: Unit) -> void:
	b.phase2 = true
	b.atk *= 1.35
	b.interval *= 0.8
	b.skill_max *= 0.75
	events.append({"type": "phase", "unit": b})
	for i in 2:
		var m := _make_enemy("mite", 4 + i, false)
		units.append(m)
		events.append({"type": "spawn", "unit": m})


func _act(u: Unit) -> void:
	if u.role == "healer":
		var low: Unit = null
		for a in _alive(0):
			if a.hp_frac() < 0.75 and (low == null or a.hp_frac() < low.hp_frac()):
				low = a
		if low != null:
			_heal(low, u.atk * 2.0)
			events.append({"type": "attack", "src": u, "dst": low, "ranged": true, "delay": 0.2, "heal": true})
			return
	var t := _pick_target(u)
	if t == null:
		return
	var delay := 0.35 if u.ranged else 0.14
	var dmg := u.atk * rng.randf_range(0.92, 1.08)
	pending.append({"t": delay, "kind": "hit", "src": u, "dst": t, "dmg": dmg, "fx": ""})
	events.append({"type": "attack", "src": u, "dst": t, "ranged": u.ranged, "delay": delay})


func step(dt: float) -> void:
	if state != "fighting":
		return
	time += dt
	if _wave_timer > 0.0:
		_wave_timer -= dt
		if _wave_timer <= 0.0:
			_spawn_wave()
		return
	for u in units:
		if not u.alive:
			continue
		u.skill_cd = maxf(0.0, u.skill_cd - dt)
		u.cd = maxf(0.0, u.cd - dt)
		u.stun_t = maxf(0.0, u.stun_t - dt)
		if u.shield_t > 0.0:
			u.shield_t -= dt
			if u.shield_t <= 0.0:
				u.shield = 0.0
		if u.stun_t > 0.0:
			continue
		if u.side == 1 and u.boss and u.skill_cd <= 0.9 and u.skill_cd > 0.0 and not u.warned:
			u.warned = true
			events.append({"type": "warn", "unit": u})
		if u.side == 1 and u.boss and u.skill_cd <= 0.0:
			_cast(u)
		elif u.side == 0 and auto_cast and u.skill_cd <= 0.0:
			_cast(u)
		if u.cd <= 0.0 and u.alive:
			u.cd = u.interval
			_act(u)
	var i := 0
	while i < pending.size():
		pending[i].t -= dt
		if pending[i].t <= 0.0:
			_apply_hit(pending[i])
			pending.remove_at(i)
		else:
			i += 1
	if _alive(0).is_empty():
		state = "defeat"
		events.append({"type": "defeat"})
		return
	if _alive(1).is_empty() and pending.is_empty():
		if wave < waves_total:
			_wave_timer = 1.0
		else:
			clear_bonus = 25.0 * Data.stage_scale(stage)
			credits += clear_bonus
			stars = Data.stars_for(fallen)
			state = "clear"
			events.append({"type": "clear", "credits": credits, "stars": stars})


## Combat sans dessin, jusqu'à la fin ou jusqu'à max_seconds (pour les tests et l'équilibrage).
func run(max_seconds: float = 300.0) -> String:
	var dt := 0.05
	while state == "fighting" and time < max_seconds:
		step(dt)
		events.clear()
	return state
