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
	var evo := 0                 # palier d'évolution du héros
	var skill_mod := 1.0         # synergies et étoiles : puissance du pouvoir
	var phase2 := false          # le gros boss passe en phase 2 sous 50 % de PV
	var warned := false          # avertissement du coup puissant déjà émis
	var gold := 0.0
	var crit := 0.0              # équipement : chance de coup critique
	var boss_dmg := 0.0          # équipement : dégâts supplémentaires aux boss
	var heal_mult := 1.0         # équipement : soins
	var regen := 0.0             # PV rendus par seconde (part des PV max) : élites et boss Régénérants
	var elite := ""              # trait d'élite (secteurs générés)
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
var combo := 0                   # enchaînement de pouvoirs en cours
var max_combo := 0
var gold_mult := 1.0
var _last_cast := -100.0
var clear_bonus := 0.0
var auto_cast := true
var timed_out := false           # secteurs générés : combat trop long, l'escouade se replie
var rng := RandomNumberGenerator.new()
var _wave_timer := 0.0


func _init(team: Array, p_stage: int, p_seed: int = 1, boosts: Array = []) -> void:
	stage = p_stage
	rng.seed = p_seed + p_stage * 1009
	var slot := 0
	for e in team:
		var u := _make_hero(String(e.id), int(e.level), slot, float(e.get("bonus", 1.0)), int(e.get("evo", 0)), int(e.get("stars", 1)), e.get("mods", {}), e.get("eq", {}))
		var sb: Dictionary = e.get("ship", {})
		if not sb.is_empty():
			# recherches du Labo (vaisseau) : PV, attaque, recharge des pouvoirs, dégâts aux boss
			u.max_hp *= 1.0 + float(sb.get("hp", 0.0))
			u.hp = u.max_hp
			u.atk *= 1.0 + float(sb.get("atk", 0.0))
			u.skill_max *= 1.0 - minf(0.5, float(sb.get("cdr", 0.0)))
			u.skill_cd = minf(u.skill_cd, u.skill_max)
			u.boss_dmg += float(sb.get("boss", 0.0))
		units.append(u)
		slot += 1
	_apply_boosts(boosts)
	_apply_sector_heroes()
	_spawn_wave()


## Règle du secteur généré qui touche l'escouade.
func _apply_sector_heroes() -> void:
	var sec := Sector.info(stage)
	if sec.is_empty():
		return
	for u in units:
		if u.side != 0:
			continue
		match String(sec.rule):
			"vents":
				u.skill_max *= 0.85
				u.skill_cd *= 0.85
			"gravite":
				u.interval *= 1.1
			"cristaux":
				u.crit += 0.10


## Renforts choisis (peuvent se cumuler).
func _apply_boosts(boosts: Array) -> void:
	var n := {}
	for b in boosts:
		n[b] = int(n.get(b, 0)) + 1
	for u in units:
		if u.side != 0:
			continue
		if n.has("tir"):
			u.interval *= pow(0.8, n.tir)
		if n.has("pouvoirs"):
			u.skill_max *= pow(0.75, n.pouvoirs)
			u.skill_cd *= pow(0.75, n.pouvoirs)
		if n.has("vitalite"):
			u.max_hp *= pow(1.2, n.vitalite)
			u.hp = u.max_hp
		if n.has("bouclier"):
			u.shield = u.max_hp * 0.2 * n.bouclier
			u.shield_t = 6.0
	if n.has("butin"):
		gold_mult = pow(1.25, n.butin)


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


func _make_hero(id: String, level: int, slot: int, bonus: float = 1.0, evo: int = 0, star_count: int = 1, mods: Dictionary = {}, eq: Dictionary = {}) -> Unit:
	var h: Dictionary = Data.HEROES[id]
	var m: float = Data.hero_mult(level) * bonus * Data.EVO_STAT_MULT[evo] * Data.star_mult(star_count)
	var u := Unit.new()
	u.side = 0
	u.slot = slot
	u.id = id
	u.name = h.name
	u.role = h.role
	u.level = level
	u.evo = evo
	u.max_hp = h.hp * m * float(mods.get("hp", 1.0))
	u.hp = u.max_hp
	u.atk = h.atk * m * float(mods.get("atk", 1.0))
	u.def = h.def * m * float(mods.get("def", 1.0))
	u.skill_mod = float(mods.get("skill", 1.0))
	u.interval = h.interval
	u.ranged = h.ranged
	u.skill_kind = h.skill.kind
	u.skill_max = h.skill.cd
	u.skill_cd = h.skill.cd * 0.5
	u.cd = 0.4 + 0.15 * slot
	# équipement : valeurs fixes en plus, pourcentages d'ensemble, critique, vitesse, soins, recharge
	if not eq.is_empty():
		u.max_hp = (u.max_hp + float(eq.hp)) * (1.0 + float(eq.hp_pct))
		u.hp = u.max_hp
		u.atk = (u.atk + float(eq.atk)) * (1.0 + float(eq.atk_pct))
		u.def = (u.def + float(eq.def)) * (1.0 + float(eq.def_pct))
		u.skill_mod += float(eq.skill)
		u.crit = float(eq.crit)
		u.boss_dmg = float(eq.boss)
		u.heal_mult = 1.0 + float(eq.heal)
		u.interval = h.interval / (1.0 + float(eq.speed))
		u.skill_max = h.skill.cd * (1.0 - minf(0.5, float(eq.cdr)))
		u.skill_cd = u.skill_max * 0.5
		if float(eq.shield0) > 0.0:
			u.shield = u.max_hp * float(eq.shield0)
			u.shield_t = 6.0
	u.data = h
	return u


func _make_enemy(kind: String, slot: int, boss: bool) -> Unit:
	var e: Dictionary = Data.ENEMIES[kind]
	var s := Sector.enemy_scale(stage)
	var u := Unit.new()
	u.side = 1
	u.slot = slot
	u.id = kind
	u.kind = kind
	u.name = e.name
	u.role = "boss" if boss else "enemy"
	u.boss = boss
	# les boss durcissent avec la profondeur, jusqu'à l'étage 40 ; au-delà, c'est la difficulté adaptative qui règle
	var depth := float(mini(stage, Sector.GEN_START - 1))
	var boss_k := 1.0 + (0.035 * depth if kind in Data.BIG_BOSSES else (0.015 * depth if kind == "foreur" else 0.0))
	var big := kind in Data.BIG_BOSSES
	var gen := Sector.is_generated(stage)
	var gk := Sector.factor if gen else 1.0     # difficulté adaptative des secteurs générés
	var gk_hp := gk
	var gk_atk := gk
	u.max_hp = Data.ENEMY_HP * Sector.enemy_scale(stage, true) * e.hp * boss_k * gk_hp * (Sector.GEN_HP * (Sector.GEN_BOSS_HP if big else 1.0) if gen else 1.0) * (Data.BIG_BOSS_HP if big else 1.0)
	u.hp = u.max_hp
	u.atk = Data.ENEMY_ATK * s * e.atk * gk_atk * (Sector.GEN_ATK if gen else 1.0) * (Data.BIG_BOSS_ATK * (1.0 + Data.BIG_BOSS_ATK_GROWTH * maxf(0.0, float(stage - 10)) / 10.0) if big else (Data.MINI_BOSS_ATK if kind == "foreur" else 1.0))
	u.def = (Data.ENEMY_DEF + stage * 0.6) * e.def
	u.interval = e.interval
	u.ranged = e.ranged
	u.gold = 3.0 * s * e.gold
	u.cd = 0.6 + 0.2 * slot
	if boss:
		u.skill_kind = {"foreur": "slam", "titan": "slam", "sentinelle": "prism", "reine": "swarm"}[kind]
		u.skill_max = {"prism": 7.5, "swarm": 9.0}.get(u.skill_kind, 7.0)
		u.skill_cd = 5.0
	u.data = e
	var sec := Sector.info(stage)
	if not sec.is_empty():
		match String(sec.rule):
			"blindes":
				u.def *= 1.3
			"gravite":
				u.interval *= 1.1
			"aubaine":
				u.atk *= 1.1
				u.gold *= 1.25
			"rage":
				u.atk *= 1.2
				u.max_hp *= 0.9
				u.hp = u.max_hp
		if boss and big:
			Sector.apply_trait(u, String(sec.boss_trait), true)
		elif not boss:
			u.elite = Sector.roll_elite(stage, rng)
			if u.elite != "":
				Sector.apply_trait(u, u.elite)
				u.gold *= 2.0
	return u


## Composition des vagues : plus de monstres et d'ennemis solides au fil des vagues, un boss à la fin des étages 5 (mini-boss) et 10 (gros boss).
func _wave_kinds() -> Array:
	var w := wave
	var kinds: Array = []
	var last := w == waves_total
	if last and Data.boss_type(stage) == "big":
		match Data.big_boss_kind(stage):
			"sentinelle":
				return ["sentinelle", "drone", "gunner"]
			"reine":
				return ["reine", "mite", "mite"]
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
	var sec := Sector.info(stage)
	if not sec.is_empty() and String(sec.rule) == "essaim":
		kinds.append("mite" if w == 1 else "drone")
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
	events.append({"type": "wave", "wave": wave, "total": waves_total, "boss": kinds.has("titan") or kinds.has("foreur") or kinds.has("sentinelle") or kinds.has("reine"), "boss_type": Data.boss_type(stage) if wave == waves_total else "", "boss_name": Data.boss_name(stage) if wave == waves_total else ""})


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
	var k := 1.0
	if u.side == 0:
		combo = combo + 1 if time - _last_cast <= Data.COMBO_WINDOW else 1
		_last_cast = time
		max_combo = maxi(max_combo, combo)
		k = Data.combo_mult(combo) * Data.EVO_SKILL_MULT[u.evo] * u.skill_mod
		if combo >= 2:
			events.append({"type": "combo", "n": combo, "mult": Data.combo_mult(combo)})
	match u.skill_kind:
		"shield":
			for a in _alive(0):
				a.shield = u.atk * 3.5 * k
				a.shield_t = 6.0
			events.append({"type": "cast", "unit": u, "kind": "shield"})
		"volley":
			var i := 0
			for e in _alive(1):
				pending.append({"t": 0.45 + i * 0.1, "kind": "hit", "src": u, "dst": e, "dmg": u.atk * 2.4 * k, "fx": "missile"})
				i += 1
			events.append({"type": "cast", "unit": u, "kind": "volley", "targets": _alive(1)})
		"pierce":
			var best: Unit = null
			for e in _alive(1):
				if best == null or e.hp > best.hp:
					best = e
			if best != null:
				pending.append({"t": 0.4, "kind": "hit", "src": u, "dst": best, "dmg": u.atk * 6.0 * k, "fx": "pierce"})
				events.append({"type": "cast", "unit": u, "kind": "pierce", "target": best})
		"repair":
			for a in _alive(0):
				_heal(a, u.atk * 2.4 * k * u.heal_mult)
			events.append({"type": "cast", "unit": u, "kind": "repair"})
		"gravity":
			for e in _alive(1):
				e.stun_t = 2.0 + 0.5 * u.evo
				pending.append({"t": 0.3, "kind": "hit", "src": u, "dst": e, "dmg": u.atk * 1.3 * k, "fx": "gravity"})
			events.append({"type": "cast", "unit": u, "kind": "gravity"})
		"prism":
			# la Sentinelle tire un faisceau sur chaque héros, plus un tir lourd sur le plus fragile
			var weakest: Unit = null
			for a in _alive(0):
				pending.append({"t": 0.5, "kind": "hit", "src": u, "dst": a, "dmg": u.atk * (1.1 if not u.phase2 else 1.4), "fx": "slam"})
				if weakest == null or a.hp_frac() < weakest.hp_frac():
					weakest = a
			if weakest != null:
				pending.append({"t": 0.75, "kind": "hit", "src": u, "dst": weakest, "dmg": u.atk * 2.0, "fx": "pierce"})
			events.append({"type": "cast", "unit": u, "kind": "prism", "targets": _alive(0)})
		"swarm":
			# la Reine appelle des mites en renfort (jamais plus de huit ennemis à l'écran)
			var added := 0
			for i in (3 if u.phase2 else 2):
				if _alive(1).size() < 8:
					var m := _make_enemy("mite", 3 + added, false)
					units.append(m)
					events.append({"type": "spawn", "unit": m})
					added += 1
			events.append({"type": "cast", "unit": u, "kind": "swarm"})
		"slam":
			for a in _alive(0):
				var sk := 1.2 if u.kind == "foreur" else (1.9 if u.phase2 else 1.6)
				pending.append({"t": 0.55, "kind": "hit", "src": u, "dst": a, "dmg": u.atk * sk, "fx": "slam"})
			events.append({"type": "cast", "unit": u, "kind": "slam"})
	return true


## Déclenche tout de suite le pouvoir d'un ennemi (pour les tests).
func cast_enemy(u: Unit) -> bool:
	u.skill_cd = 0.0
	return _cast(u)


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
			credits += dst.gold * gold_mult
		else:
			fallen += 1
	elif dst.kind in Data.BIG_BOSSES and not dst.phase2 and dst.hp <= dst.max_hp * 0.5:
		_enter_phase2(dst)


## Phase 2 du gros boss : plus rapide et plus fort, et deux mites arrivent en renfort.
func _enter_phase2(b: Unit) -> void:
	b.phase2 = true
	b.atk *= 1.35
	b.interval *= 0.8
	b.skill_max *= 0.75
	events.append({"type": "phase", "unit": b})
	var helper := "drone" if b.kind == "sentinelle" else "mite"
	for i in 2:
		var m := _make_enemy(helper, 4 + i, false)
		units.append(m)
		events.append({"type": "spawn", "unit": m})


func _act(u: Unit) -> void:
	if u.role == "healer":
		var low: Unit = null
		for a in _alive(0):
			if a.hp_frac() < 0.75 and (low == null or a.hp_frac() < low.hp_frac()):
				low = a
		if low != null:
			_heal(low, u.atk * 2.0 * u.heal_mult)
			events.append({"type": "attack", "src": u, "dst": low, "ranged": true, "delay": 0.2, "heal": true})
			return
	var t := _pick_target(u)
	if t == null:
		return
	var delay := 0.35 if u.ranged else 0.14
	var dmg := u.atk * rng.randf_range(0.92, 1.08)
	if u.crit > 0.0 and rng.randf() < u.crit:
		dmg *= 1.5
	if u.boss_dmg > 0.0 and t.boss:
		dmg *= 1.0 + u.boss_dmg
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
		if u.regen > 0.0 and u.hp < u.max_hp:
			u.hp = minf(u.max_hp, u.hp + u.max_hp * u.regen * dt)
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
	if Sector.is_generated(stage) and time >= Sector.TIME_LIMIT:
		timed_out = true
		state = "defeat"
		events.append({"type": "defeat", "timeout": true})
		return
	if _alive(1).is_empty() and pending.is_empty():
		if wave < waves_total:
			_wave_timer = 1.0
		else:
			clear_bonus = 25.0 * Data.stage_scale(stage)
			credits += clear_bonus
			stars = Data.stars_for(fallen)
			state = "clear"
			events.append({"type": "clear", "credits": credits, "stars": stars, "combo": max_combo})


## Combat sans dessin, jusqu'à la fin ou jusqu'à max_seconds (pour les tests et l'équilibrage).
func run(max_seconds: float = 300.0) -> String:
	var dt := 0.05
	while state == "fighting" and time < max_seconds:
		step(dt)
		events.clear()
	return state
