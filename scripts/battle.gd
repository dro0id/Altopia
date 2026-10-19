extends RefCounted
## Combat automatique au tour par tour. Sans générateur aléatoire il est déterministe (aperçu) ; avec un générateur, les dégâts varient
## et les critiques sont tirés au sort (vrais combats).
## Une unité : {name, hp, max_hp, atk, def, spd}.

const Data = preload("res://scripts/game_data.gd")


static func make_unit(unit_name: String, hp: float, atk: float, def: float, spd: float,
		crit: float = 0.0, lifesteal: float = 0.0) -> Dictionary:
	return {"name": unit_name, "hp": hp, "max_hp": hp, "atk": atk, "def": def, "spd": spd,
		"crit": crit, "lifesteal": lifesteal}


static func _alive(units: Array) -> bool:
	for u in units:
		if u.hp > 0.0:
			return true
	return false


static func _first_alive(units: Array) -> Dictionary:
	for u in units:
		if u.hp > 0.0:
			return u
	return {}


static func simulate(allies: Array, enemies: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var a: Array = []
	var e: Array = []
	for i in allies.size():
		var u: Dictionary = allies[i].duplicate()
		u["idx"] = i
		a.append(u)
	for i in enemies.size():
		var u: Dictionary = enemies[i].duplicate()
		u["idx"] = i
		e.append(u)
	var log: Array[String] = []
	var events: Array = []    # chaque coup : {s: camp de l'attaquant (0 allié), a, t: indices, d: dégâts, ko}
	var rounds := 0
	while rounds < Data.BATTLE_MAX_ROUNDS and _alive(a) and _alive(e):
		rounds += 1
		var order: Array = []
		for i in a.size():
			order.append({"u": a[i], "foes": e, "side": 0, "i": i})
		for i in e.size():
			order.append({"u": e[i], "foes": a, "side": 1, "i": i})
		order.sort_custom(func(x, y):
			if x.u.spd != y.u.spd:
				return x.u.spd > y.u.spd
			if x.side != y.side:
				return x.side < y.side
			return x.i < y.i)
		for o in order:
			var u: Dictionary = o.u
			if u.hp <= 0.0:
				continue
			var target := _first_alive(o.foes)
			if target.is_empty():
				break
			var dmg := maxf(1.0, u.atk - target.def * 0.5)
			var crit_chance := clampf(u.get("crit", 0.0), 0.0, 0.8)
			if rng == null:
				dmg *= 1.0 + crit_chance * (Data.CRIT_MULT - 1.0)         # aperçu : critique moyen
			else:
				dmg *= 1.0 + rng.randf_range(-Data.BATTLE_VARIANCE, Data.BATTLE_VARIANCE)
				if rng.randf() < crit_chance:
					dmg *= Data.CRIT_MULT
			target.hp -= dmg
			var heal := 0.0
			if u.get("lifesteal", 0.0) > 0.0:
				heal = minf(u.max_hp - u.hp, dmg * u.lifesteal)
				u.hp += heal
			events.append({"s": o.side, "a": o.i, "t": target.idx, "d": dmg, "h": heal, "ko": target.hp <= 0.0})
			if log.size() < 10:
				log.append("%s frappe %s (-%d)%s" % [u.name, target.name, int(dmg),
					" — K.O." if target.hp <= 0.0 else ""])
	return {
		"win": _alive(a) and not _alive(e),
		"rounds": rounds, "allies": a, "enemies": e, "log": log, "events": events,
	}
