extends Node
## Cerveau du jeu : héros (RPG), escouades, combats, expéditions, améliorations, hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed

const Data = preload("res://scripts/game_data.gd")
const Battle = preload("res://scripts/battle.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3
const AUTOSAVE_EVERY := 10.0

var save_path := SAVE_PATH
var rng := RandomNumberGenerator.new()

var res := {"credits": 0.0, "data": 0.0, "minerals": 0.0, "energy": 0.0}
var data_total := 0.0          # données cumulées (débloquent les destinations)
## Collection : id du héros -> {level, xp, stars}. hero_order = ordre d'obtention.
var heroes := {}
var hero_order: Array = []
var recruits := 0
var upgrade_levels := {"laser": 0, "solar": 0, "scanner": 0, "engines": 0, "docks": 0}
## Un emplacement de vaisseau : dest "" = libre ; squad = SQUAD_SIZE ids de héros ("" = vide).
var slots: Array = []
var dest_wins := {}
var last_seen := 0
var expeditions_done := 0
var last_offline_report := {}
var last_recruit := {}

var _autosave_timer := 0.0


func _ready() -> void:
	rng.randomize()
	reset()
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	tick(delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_EVERY:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	# Sauvegarde quand l'appli est fermée ou mise en arrière-plan (Android).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func reset() -> void:
	for id in res:
		res[id] = 0.0
	data_total = 0.0
	heroes = {}
	hero_order = []
	recruits = 0
	for id in upgrade_levels:
		upgrade_levels[id] = 0
	slots = []
	for i in Data.MAX_SLOTS:
		slots.append(_new_slot())
	dest_wins = {}
	for d in Data.DEST_ORDER:
		dest_wins[d] = 0
	expeditions_done = 0
	last_offline_report = {}
	last_recruit = {}


func new_game() -> void:
	reset()
	for id in Data.STARTER_HEROES:
		give_hero(id)
	auto_squad(0)
	res["credits"] = Data.START_CREDITS
	last_seen = int(Time.get_unix_time_from_system())
	changed.emit()


func _new_slot() -> Dictionary:
	var squad: Array = []
	for i in Data.SQUAD_SIZE:
		squad.append("")
	return {"dest": "", "remaining": 0.0, "auto": true, "squad": squad, "last": "", "log": []}


## --- Ressources ---

func add_res(id: String, amount: float) -> void:
	res[id] += amount
	if id == "data":
		data_total += amount


func can_afford(cost: Dictionary) -> bool:
	for id in cost:
		if res[id] < cost[id]:
			return false
	return true


func pay(cost: Dictionary) -> void:
	for id in cost:
		res[id] -= cost[id]


## --- Héros (RPG) ---

func give_hero(id: String, level: int = 1, stars: int = 0) -> void:
	if heroes.has(id):
		return
	heroes[id] = {"level": level, "xp": 0, "stars": stars}
	hero_order.append(id)


func hero_power(id: String) -> float:
	var h: Dictionary = heroes[id]
	var s := Data.hero_stats(id, h.level, h.stars)
	return s.hp * 0.2 + s.atk * 2.0 + s.def * 1.0


func recruit_cost() -> float:
	return ceil(Data.RECRUIT_BASE * pow(Data.RECRUIT_GROWTH, recruits))


func _roll_hero() -> String:
	var total := 0.0
	for r in Data.RARITY:
		total += Data.RARITY[r].weight
	var roll := rng.randf() * total
	var rarity := "common"
	for r in Data.RARITY_ORDER:
		roll -= Data.RARITY[r].weight
		if roll < 0.0:
			rarity = r
			break
	var pool: Array = []
	for id in Data.HERO_ORDER:
		if Data.HEROES[id].rarity == rarity:
			pool.append(id)
	return pool[rng.randi() % pool.size()]


## Recrutement aléatoire. Un doublon donne une étoile (stats +20 %).
func recruit() -> Dictionary:
	var cost := recruit_cost()
	if res["credits"] < cost:
		return {}
	res["credits"] -= cost
	recruits += 1
	var id := _roll_hero()
	var result := {"id": id, "new": not heroes.has(id), "maxed": false}
	if result.new:
		give_hero(id)
		_autoplace(id)
	elif heroes[id].stars < Data.MAX_STARS:
		heroes[id].stars += 1
	else:
		result.maxed = true
		add_res("credits", cost * 0.5)    # remboursement partiel d'un doublon au maximum
	last_recruit = result
	changed.emit()
	return result


func train_cost(id: String) -> float:
	return ceil(Data.TRAIN_BASE * pow(Data.TRAIN_GROWTH, heroes[id].level - 1))


func train(id: String) -> bool:
	if not heroes.has(id) or heroes[id].level >= Data.MAX_LEVEL:
		return false
	var cost := train_cost(id)
	if res["credits"] < cost:
		return false
	res["credits"] -= cost
	heroes[id].level += 1
	changed.emit()
	return true


## Ajoute de l'XP ; retourne le nombre de niveaux gagnés.
func gain_xp(id: String, amount: int) -> int:
	var h: Dictionary = heroes[id]
	var gained := 0
	h.xp += amount
	while h.level < Data.MAX_LEVEL and h.xp >= Data.xp_needed(h.level):
		h.xp -= Data.xp_needed(h.level)
		h.level += 1
		gained += 1
	if h.level >= Data.MAX_LEVEL:
		h.xp = 0
	return gained


## Somme des niveaux de héros possédés d'une classe (alimente revenus et synergies).
func class_levels() -> Dictionary:
	var out := {}
	for c in Data.CREW_ORDER:
		out[c] = 0
	for id in heroes:
		out[Data.HEROES[id]["class"]] += heroes[id].level
	return out


func is_crew_complete() -> bool:
	var lv := class_levels()
	for c in Data.CREW_ORDER:
		if lv[c] <= 0:
			return false
	return true


func synergy_multiplier() -> float:
	var lv := class_levels()
	var mult: float = 1.0
	for pair in Data.PAIRS:
		if lv[pair[0]] > 0 and lv[pair[1]] > 0:
			mult += Data.SYNERGY_PAIR
	if is_crew_complete():
		mult += Data.SYNERGY_FULL
	return mult


func credits_per_sec() -> float:
	var lv := class_levels()
	var total: float = 0.0
	for c in Data.CREW_ORDER:
		total += Data.CREW[c].rate * lv[c]
	return total * synergy_multiplier()


func data_per_sec() -> float:
	var lv := class_levels()
	var total: float = 0.0
	for c in Data.CREW_ORDER:
		total += Data.CREW[c].data_rate * lv[c]
	return Data.BASE_DATA_RATE + total * synergy_multiplier()


## --- Escouades ---

func hero_slot(id: String) -> int:
	for i in slots.size():
		if id in slots[i].squad:
			return i
	return -1


func squad_ids(slot_i: int) -> Array:
	var out: Array = []
	for id in slots[slot_i].squad:
		if id != "":
			out.append(id)
	return out


## Place un héros ("" = retirer) dans une case de l'escouade ; un héros ne peut servir qu'une fois.
func set_squad_member(slot_i: int, idx: int, id: String) -> bool:
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "" or idx < 0 or idx >= Data.SQUAD_SIZE:
		return false
	if id != "" and not heroes.has(id):
		return false
	if id != "":
		for s in slots:
			if s.dest != "" and id in s.squad:
				return false          # déjà en mission dans un autre vaisseau
			for k in s.squad.size():
				if s.squad[k] == id:
					s.squad[k] = ""
	slot.squad[idx] = id
	changed.emit()
	return true


## Place un nouveau héros dans la première case libre d'un vaisseau au repos.
func _autoplace(id: String) -> void:
	for i in slot_count():
		var slot: Dictionary = slots[i]
		if slot.dest != "":
			continue
		for k in Data.SQUAD_SIZE:
			if slot.squad[k] == "":
				slot.squad[k] = id
				return


## Compose la meilleure escouade possible : un héros de chaque classe d'abord, puis les plus forts.
func auto_squad(slot_i: int) -> void:
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "":
		return
	var pool: Array = []
	for id in hero_order:
		var s := hero_slot(id)
		if s == -1 or s == slot_i:
			pool.append(id)
	pool.sort_custom(func(a, b): return hero_power(a) > hero_power(b))
	var picked: Array = []
	for c in Data.CREW_ORDER:
		for id in pool:
			if Data.HEROES[id]["class"] == c:
				picked.append(id)
				break
	for id in pool:
		if picked.size() >= Data.SQUAD_SIZE:
			break
		if not (id in picked):
			picked.append(id)
	for k in Data.SQUAD_SIZE:
		slot.squad[k] = picked[k] if k < picked.size() else ""
	changed.emit()


func squad_role_level(slot_i: int, dest: String) -> int:
	var role: String = Data.DEST[dest].role
	var total := 0
	for id in squad_ids(slot_i):
		if Data.HEROES[id]["class"] == role:
			total += heroes[id].level
	return total


## --- Améliorations du vaisseau ---

func upgrade_cost(id: String) -> Dictionary:
	var u: Dictionary = Data.UPGRADES[id]
	var cost := {}
	for r in u.base:
		cost[r] = ceil(u.base[r] * pow(u.growth, upgrade_levels[id]))
	return cost


func upgrade_maxed(id: String) -> bool:
	return upgrade_levels[id] >= Data.UPGRADES[id].max


func buy_upgrade(id: String) -> bool:
	if upgrade_maxed(id):
		return false
	var cost: Dictionary = upgrade_cost(id)
	if not can_afford(cost):
		return false
	pay(cost)
	upgrade_levels[id] += 1
	changed.emit()
	return true


func slot_count() -> int:
	return 1 + upgrade_levels["docks"]


## --- Expéditions ---

func is_unlocked(dest: String) -> bool:
	return data_total >= Data.DEST[dest].unlock_data


## Retourne "" si le lancement est possible, sinon la raison du blocage.
func launch_block_reason(dest: String, slot_i: int) -> String:
	if not is_unlocked(dest):
		return "Débloqué à %s données" % Data.fmt(Data.DEST[dest].unlock_data)
	if squad_ids(slot_i).is_empty():
		return "Composez une escouade"
	if squad_role_level(slot_i, dest) <= 0:
		return "Il faut un %s dans l'escouade" % Data.CREW[Data.DEST[dest].role].name
	return ""


func duration_of(dest: String, slot_i: int) -> float:
	var base: float = Data.DEST[dest].duration
	var speed: float = (1.0 + Data.ENGINE_SPEED * upgrade_levels["engines"]) \
		* (1.0 + Data.ROLE_SPEED * squad_role_level(slot_i, dest))
	return maxf(1.0, base / speed)


func upgrade_multiplier(resource: String) -> float:
	var key := ""
	match resource:
		"minerals": key = "laser"
		"energy": key = "solar"
		"data": key = "scanner"
	if key == "":
		return 1.0
	return 1.0 + Data.UPGRADE_GAIN * upgrade_levels[key]


func rewards_of(dest: String, slot_i: int) -> Dictionary:
	var out := {}
	var role_mult: float = 1.0 + Data.ROLE_GAIN * squad_role_level(slot_i, dest)
	for r in Data.DEST[dest].rewards:
		out[r] = Data.DEST[dest].rewards[r] * role_mult * upgrade_multiplier(r) * synergy_multiplier()
	return out


func enemy_level(dest: String) -> int:
	return 1 + dest_wins[dest] / Data.ENEMY_LEVEL_STEP


func make_enemies(dest: String) -> Array:
	var e: Dictionary = Data.DEST[dest].enemy
	var m: float = 1.0 + Data.ENEMY_SCALE * (enemy_level(dest) - 1)
	var out: Array = []
	for i in e.count:
		out.append(Battle.make_unit("%s %d" % [e.name, i + 1], e.hp * m, e.atk * m, e.def * m, e.spd))
	return out


func make_allies(slot_i: int) -> Array:
	var out: Array = []
	for id in squad_ids(slot_i):
		var h: Dictionary = heroes[id]
		var s := Data.hero_stats(id, h.level, h.stars)
		out.append(Battle.make_unit(Data.HEROES[id].name, s.hp, s.atk, s.def, s.spd))
	return out


## Aperçu : l'escouade battrait-elle les ennemis actuels de cette destination ?
func preview_battle(dest: String, slot_i: int) -> Dictionary:
	return Battle.simulate(make_allies(slot_i), make_enemies(dest))


func launch(slot_i: int, dest: String) -> bool:
	if slot_i < 0 or slot_i >= slot_count():
		return false
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "" or launch_block_reason(dest, slot_i) != "":
		return false
	slot.dest = dest
	slot.remaining = duration_of(dest, slot_i)
	changed.emit()
	return true


func recall(slot_i: int) -> void:
	var slot: Dictionary = slots[slot_i]
	slot.dest = ""
	slot.remaining = 0.0
	changed.emit()


func set_auto(slot_i: int, value: bool) -> void:
	slots[slot_i].auto = value
	changed.emit()


func _complete(slot_i: int) -> void:
	var slot: Dictionary = slots[slot_i]
	var dest: String = slot.dest
	var battle := preview_battle(dest, slot_i)
	var rewards: Dictionary = rewards_of(dest, slot_i)
	var levels_gained := 0
	if battle.win:
		dest_wins[dest] += 1
		for id in squad_ids(slot_i):
			levels_gained += gain_xp(id, Data.DEST[dest].xp)
	else:
		for r in rewards:
			rewards[r] *= Data.LOSS_REWARD
	for r in rewards:
		add_res(r, rewards[r])
	expeditions_done += 1
	var head := "Victoire en %d tours" % battle.rounds if battle.win else "Défaite (butin réduit)"
	slot.last = "%s — %s : %s" % [head, Data.DEST[dest].name, Data.fmt_amounts(rewards)]
	if levels_gained > 0:
		slot.last += "  |  %d niveau(x) gagné(s) !" % levels_gained
	slot.log = battle.log
	if slot.auto and launch_block_reason(dest, slot_i) == "":
		slot.remaining = duration_of(dest, slot_i)
	else:
		slot.dest = ""
		slot.remaining = 0.0


func _advance_expeditions(seconds: float) -> void:
	for i in slot_count():
		var slot: Dictionary = slots[i]
		var t := seconds
		while slot.dest != "" and t > 0.0:
			if slot.remaining > t:
				slot.remaining -= t
				t = 0.0
			else:
				t -= slot.remaining
				_complete(i)


## Fait avancer le jeu de `seconds` secondes (revenu passif + expéditions).
func tick(seconds: float) -> void:
	add_res("credits", credits_per_sec() * seconds)
	add_res("data", data_per_sec() * seconds)
	_advance_expeditions(seconds)
	changed.emit()


## --- Sauvegarde ---

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"res": res, "data_total": data_total,
		"heroes": heroes, "hero_order": hero_order, "recruits": recruits,
		"upgrades": upgrade_levels, "slots": slots, "dest_wins": dest_wins,
		"done": expeditions_done, "last_seen": last_seen,
	}))


## Retourne false si aucune sauvegarde compatible n'existe (nouvelle partie).
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) < SAVE_VERSION:
		return false      # sauvegarde du prototype : on repart de zéro
	var saved_res: Dictionary = parsed.get("res", {})
	for id in res:
		res[id] = float(saved_res.get(id, 0.0))
	data_total = float(parsed.get("data_total", 0.0))
	var saved_heroes: Dictionary = parsed.get("heroes", {})
	heroes = {}
	hero_order = []
	for id in parsed.get("hero_order", []):
		if Data.HEROES.has(id) and saved_heroes.has(id):
			var h: Dictionary = saved_heroes[id]
			heroes[id] = {"level": int(h.get("level", 1)), "xp": int(h.get("xp", 0)), "stars": int(h.get("stars", 0))}
			hero_order.append(id)
	recruits = int(parsed.get("recruits", 0))
	var saved_up: Dictionary = parsed.get("upgrades", {})
	for id in upgrade_levels:
		upgrade_levels[id] = int(saved_up.get(id, 0))
	var saved_wins: Dictionary = parsed.get("dest_wins", {})
	for d in Data.DEST_ORDER:
		dest_wins[d] = int(saved_wins.get(d, 0))
	var saved_slots: Array = parsed.get("slots", [])
	for i in mini(saved_slots.size(), slots.size()):
		var s: Dictionary = saved_slots[i]
		var dest := String(s.get("dest", ""))
		var squad: Array = []
		var saved_squad: Array = s.get("squad", [])
		for k in Data.SQUAD_SIZE:
			var hid := String(saved_squad[k]) if k < saved_squad.size() else ""
			squad.append(hid if heroes.has(hid) else "")
		slots[i] = {
			"dest": dest if Data.DEST.has(dest) else "",
			"remaining": float(s.get("remaining", 0.0)),
			"auto": bool(s.get("auto", true)),
			"squad": squad, "last": String(s.get("last", "")), "log": [],
		}
	expeditions_done = int(parsed.get("done", 0))
	last_seen = int(parsed.get("last_seen", 0))

	var now := int(Time.get_unix_time_from_system())
	var away := clampi(now - last_seen, 0, Data.OFFLINE_CAP_SECONDS)
	if away > 60:
		var before := res.duplicate()
		var done_before := expeditions_done
		tick(away)
		var gains := {}
		for id in res:
			gains[id] = res[id] - before[id]
		last_offline_report = {
			"seconds": away, "gains": gains, "expeditions": expeditions_done - done_before,
		}
	return true
