extends Node
## Cerveau du jeu : Capitaine (le joueur), équipage aux postes, équipement, combats,
## expéditions, améliorations, hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed
signal battle_finished(slot_i: int)

const Data = preload("res://scripts/game_data.gd")
const Battle = preload("res://scripts/battle.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 4
const AUTOSAVE_EVERY := 10.0

var save_path := SAVE_PATH
var rng := RandomNumberGenerator.new()

var res := {"credits": 0.0, "data": 0.0, "minerals": 0.0, "energy": 0.0}
var data_total := 0.0          # données cumulées (débloquent les destinations)

## Le joueur : un personnage unique.
var captain := {}
## Équipement : objets possédés (dictionnaires) et objet équipé par emplacement (id, -1 = aucun).
var items: Array = []
var equipped := {}
var next_item_id := 1

## L'équipage : cartes à collectionner (id -> {level, xp, stars}), placées aux postes des vaisseaux.
var heroes := {}
var hero_order: Array = []
var recruits := 0
var upgrade_levels := {"laser": 0, "solar": 0, "scanner": 0, "engines": 0, "docks": 0}
## Un emplacement de vaisseau : dest "" = libre ; squad = un poste par classe (ids, "" = vide).
## Vaisseau 0 = vaisseau amiral (avec le Capitaine) ; vaisseau 1 = drone (équipage seul).
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
	captain = {"name": "Capitaine", "level": 1, "xp": 0, "look": {"suit": 0, "hair": 0, "style": 0}}
	items = []
	equipped = {}
	for s in Data.EQUIP_SLOTS:
		equipped[s] = -1
	next_item_id = 1
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
	for s in Data.EQUIP_SLOTS:
		var it := make_item(s, "common", 1)
		items.append(it)
		equipped[s] = it.id
	res["credits"] = Data.START_CREDITS
	last_seen = int(Time.get_unix_time_from_system())
	changed.emit()


func _new_slot() -> Dictionary:
	var squad: Array = []
	for i in Data.CREW_ORDER.size():
		squad.append("")
	return {"dest": "", "remaining": 0.0, "auto": true, "squad": squad, "last": "", "log": [], "battle": {}}


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


## --- Capitaine ---

func captain_train_cost() -> float:
	return ceil(Data.CAPTAIN_TRAIN_BASE * pow(Data.CAPTAIN_TRAIN_GROWTH, captain.level - 1))


func train_captain() -> bool:
	if captain.level >= Data.CAPTAIN_MAX_LEVEL:
		return false
	var cost := captain_train_cost()
	if res["credits"] < cost:
		return false
	res["credits"] -= cost
	captain.level += 1
	changed.emit()
	return true


## Ajoute de l'XP au Capitaine ; retourne le nombre de niveaux gagnés.
func gain_captain_xp(amount: int) -> int:
	var gained := 0
	captain.xp += amount
	while captain.level < Data.CAPTAIN_MAX_LEVEL and captain.xp >= Data.xp_needed(captain.level):
		captain.xp -= Data.xp_needed(captain.level)
		captain.level += 1
		gained += 1
	if captain.level >= Data.CAPTAIN_MAX_LEVEL:
		captain.xp = 0
	return gained


func cycle_look(part: String) -> void:
	var count: int = Data.LOOK_STYLES if part == "style" else Data.LOOK_SUITS.size()
	captain.look[part] = (captain.look[part] + 1) % count
	changed.emit()


## Stats du Capitaine pour un vaisseau : base + équipement + bonus de l'équipage aux postes.
func captain_stats(slot_i: int = 0) -> Dictionary:
	var m: float = 1.0 + Data.CAPTAIN_LEVEL_BONUS * (captain.level - 1)
	var base := {"hp": Data.CAPTAIN_BASE.hp * m, "atk": Data.CAPTAIN_BASE.atk * m,
		"def": Data.CAPTAIN_BASE.def * m, "spd": Data.CAPTAIN_BASE.spd}
	var gear := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	for slot in Data.EQUIP_SLOTS:
		var it := equipped_item(slot)
		if not it.is_empty():
			var st := item_stats(it)
			for k in st:
				gear[k] += st[k]
	var crew := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	for id in squad_ids(slot_i):
		var h: Dictionary = heroes[id]
		var st := Data.hero_stats(id, h.level, h.stars)
		crew.hp += st.hp * Data.CREW_STAT_SHARE
		crew.atk += st.atk * Data.CREW_STAT_SHARE
		crew.def += st.def * Data.CREW_STAT_SHARE
		crew.spd += st.spd * Data.CREW_SPD_SHARE
	var total := {}
	for k in base:
		total[k] = base[k] + gear[k] + crew[k]
	total["base"] = base
	total["gear"] = gear
	total["crew"] = crew
	return total


## Drone (vaisseau 2) : l'équipage seul, sans Capitaine, avec des stats réduites.
func drone_stats(slot_i: int) -> Dictionary:
	var out := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	for id in squad_ids(slot_i):
		var h: Dictionary = heroes[id]
		var st := Data.hero_stats(id, h.level, h.stars)
		out.hp += st.hp * Data.DRONE_ATK_SHARE
		out.atk += st.atk * Data.DRONE_ATK_SHARE
		out.def += st.def * Data.DRONE_DEF_SHARE
		out.spd = maxf(out.spd, st.spd)
	return out


## --- Équipement ---

func make_item(slot: String, rarity: String, tier: int) -> Dictionary:
	var names: Array = Data.EQUIP[slot].names
	var item := {"id": next_item_id, "slot": slot, "rarity": rarity, "tier": tier,
		"level": 1, "xp": 0, "name": names[rng.randi() % names.size()]}
	next_item_id += 1
	return item


func item_stats(item: Dictionary) -> Dictionary:
	var base := Data.item_base(item.slot, item.tier)
	var m: float = Data.RARITY_ITEM_MULT[item.rarity] * (1.0 + Data.ITEM_LEVEL_BONUS * (item.level - 1))
	var out := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	for k in base:
		out[k] = base[k] * m
	return out


func item_power(item: Dictionary) -> float:
	var s := item_stats(item)
	return s.atk * 2.0 + s.hp * 0.2 + s.def * 1.0 + s.spd * 1.5


func item_by_id(id: int) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}


func equipped_item(slot: String) -> Dictionary:
	return item_by_id(equipped[slot])


func equip(id: int) -> bool:
	var it := item_by_id(id)
	if it.is_empty():
		return false
	equipped[it.slot] = id
	changed.emit()
	return true


func unequip(slot: String) -> void:
	equipped[slot] = -1
	changed.emit()


func scrap_value(item: Dictionary) -> float:
	return ceil(15.0 * item.tier * Data.RARITY_ITEM_MULT[item.rarity] * item.level)


## Recycle un objet non équipé en crédits.
func scrap(id: int) -> bool:
	var it := item_by_id(id)
	if it.is_empty() or equipped[it.slot] == id:
		return false
	add_res("credits", scrap_value(it))
	items.erase(it)
	changed.emit()
	return true


func auto_equip() -> void:
	for slot in Data.EQUIP_SLOTS:
		var best := {}
		for it in items:
			if it.slot == slot and (best.is_empty() or item_power(it) > item_power(best)):
				best = it
		equipped[slot] = best.id if not best.is_empty() else -1
	changed.emit()


func add_item(item: Dictionary) -> void:
	items.append(item)
	while items.size() > Data.INVENTORY_MAX:
		# inventaire plein : on recycle le moins bon objet non équipé (jamais le nouveau).
		var worst := {}
		for it in items:
			if it.id == item.id or equipped[it.slot] == it.id:
				continue
			if worst.is_empty() or item_power(it) < item_power(worst):
				worst = it
		if worst.is_empty():
			break
		add_res("credits", scrap_value(worst))
		items.erase(worst)


## Tire un objet de butin (ou {} si pas de chance). Les tiers élevés donnent de meilleures raretés.
func roll_drop(tier: int) -> Dictionary:
	if rng.randf() > Data.DROP_CHANCE:
		return {}
	var w_epic := 5.0 + 5.0 * (tier - 1)
	var w_rare := 25.0 + 5.0 * (tier - 1)
	var w_common := 100.0 - w_epic - w_rare
	var roll := rng.randf() * 100.0
	var rarity := "common"
	if roll < w_epic:
		rarity = "epic"
	elif roll < w_epic + w_rare:
		rarity = "rare"
	var slot: String = Data.EQUIP_SLOTS[rng.randi() % Data.EQUIP_SLOTS.size()]
	var item := make_item(slot, rarity, tier)
	add_item(item)
	return item


## L'équipement équipé gagne de l'XP à chaque victoire ; retourne les niveaux gagnés.
func _gear_xp() -> int:
	var gained := 0
	for slot in Data.EQUIP_SLOTS:
		var it := equipped_item(slot)
		if it.is_empty():
			continue
		var max_level: int = Data.ITEM_MAX_LEVEL[it.rarity]
		if it.level >= max_level:
			continue
		it.xp += Data.ITEM_XP_PER_WIN
		while it.level < max_level and it.xp >= Data.item_xp_needed(it.level):
			it.xp -= Data.item_xp_needed(it.level)
			it.level += 1
			gained += 1
	return gained


## --- Équipage (cartes) ---

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


## Ajoute de l'XP à une carte d'équipage ; retourne le nombre de niveaux gagnés.
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


## Somme des niveaux d'équipage possédés d'une classe (alimente revenus et synergies).
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


## --- Postes ---

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


## Place une carte d'équipage ("" = retirer) à son poste. Un poste = une classe ;
## une carte ne sert qu'à un seul poste.
func set_squad_member(slot_i: int, idx: int, id: String) -> bool:
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "" or idx < 0 or idx >= Data.CREW_ORDER.size():
		return false
	if id != "":
		if not heroes.has(id) or Data.HEROES[id]["class"] != Data.CREW_ORDER[idx]:
			return false
		for s in slots:
			if s.dest != "" and id in s.squad:
				return false          # déjà en mission dans un autre vaisseau
			for k in s.squad.size():
				if s.squad[k] == id:
					s.squad[k] = ""
	slot.squad[idx] = id
	changed.emit()
	return true


## Place un nouvel équipier au poste de sa classe s'il est libre (vaisseau au repos).
func _autoplace(id: String) -> void:
	var idx: int = Data.CREW_ORDER.find(Data.HEROES[id]["class"])
	for i in slot_count():
		var slot: Dictionary = slots[i]
		if slot.dest == "" and slot.squad[idx] == "":
			slot.squad[idx] = id
			return


## Place la meilleure carte disponible à chaque poste du vaisseau.
func auto_squad(slot_i: int) -> void:
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "":
		return
	for idx in Data.CREW_ORDER.size():
		var best := ""
		for id in hero_order:
			if Data.HEROES[id]["class"] != Data.CREW_ORDER[idx]:
				continue
			var s := hero_slot(id)
			if s != -1 and s != slot_i:
				continue
			if best == "" or hero_power(id) > hero_power(best):
				best = id
		slot.squad[idx] = best
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


## Réservé aux tests : débloque directement le 2e vaisseau.
func docks_for_test() -> void:
	upgrade_levels["docks"] = 1


func slot_count() -> int:
	return 1 + upgrade_levels["docks"]


## --- Expéditions ---

func is_unlocked(dest: String) -> bool:
	return data_total >= Data.DEST[dest].unlock_data


func dest_tier(dest: String) -> int:
	return Data.DEST_ORDER.find(dest) + 1


## Retourne "" si le lancement est possible, sinon la raison du blocage.
func launch_block_reason(dest: String, slot_i: int) -> String:
	if not is_unlocked(dest):
		return "Débloqué à %s données" % Data.fmt(Data.DEST[dest].unlock_data)
	if squad_role_level(slot_i, dest) <= 0:
		return "Placez un %s à son poste" % Data.CREW[Data.DEST[dest].role].name
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


## Le combattant du vaisseau : le Capitaine (amiral) ou le drone (vaisseau 2).
func make_allies(slot_i: int) -> Array:
	if slot_i == 0:
		var s := captain_stats(0)
		return [Battle.make_unit(captain.name, s.hp, s.atk, s.def, s.spd)]
	var d := drone_stats(slot_i)
	return [Battle.make_unit("Drone", maxf(1.0, d.hp), d.atk, d.def, d.spd)]


## Aperçu : le vaisseau battrait-il les ennemis actuels de cette destination ?
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
	var loot := {}
	if battle.win:
		dest_wins[dest] += 1
		var xp: int = Data.DEST[dest].xp
		for id in squad_ids(slot_i):
			levels_gained += gain_xp(id, xp)
		if slot_i == 0:
			levels_gained += gain_captain_xp(xp)
			levels_gained += _gear_xp()
			loot = roll_drop(dest_tier(dest))
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
	if not loot.is_empty():
		slot.last += "  |  Butin : %s (%s)" % [loot.name, Data.RARITY[loot.rarity].name]
	slot.log = battle.log
	var ally: Dictionary = battle.allies[0]
	slot.battle = {
		"win": battle.win, "dest": dest, "events": battle.events,
		"allies": [{"id": "captain" if slot_i == 0 else "drone", "name": ally.name, "max_hp": ally.max_hp,
			"look": captain.look.duplicate(), "crew": squad_ids(slot_i)}],
		"enemies": battle.enemies.map(func(u): return {"name": u.name, "max_hp": u.max_hp, "kind": dest}),
	}
	battle_finished.emit(slot_i)
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
		"res": res, "data_total": data_total, "captain": captain,
		"items": items, "equipped": equipped, "next_item_id": next_item_id,
		"heroes": heroes, "hero_order": hero_order, "recruits": recruits,
		"upgrades": upgrade_levels, "slots": _slots_for_save(), "dest_wins": dest_wins,
		"done": expeditions_done, "last_seen": last_seen,
	}))


## Les combats rejouables (volumineux) ne sont pas sauvegardés.
func _slots_for_save() -> Array:
	var out: Array = []
	for s in slots:
		var c: Dictionary = s.duplicate()
		c.erase("battle")
		c.erase("log")
		out.append(c)
	return out


## Retourne false si aucune sauvegarde compatible n'existe (nouvelle partie).
func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) < SAVE_VERSION:
		return false      # sauvegarde d'une version précédente : on repart de zéro
	var saved_res: Dictionary = parsed.get("res", {})
	for id in res:
		res[id] = float(saved_res.get(id, 0.0))
	data_total = float(parsed.get("data_total", 0.0))
	var cap: Dictionary = parsed.get("captain", {})
	var look: Dictionary = cap.get("look", {})
	captain = {
		"name": String(cap.get("name", "Capitaine")), "level": int(cap.get("level", 1)), "xp": int(cap.get("xp", 0)),
		"look": {"suit": int(look.get("suit", 0)), "hair": int(look.get("hair", 0)), "style": int(look.get("style", 0))},
	}
	items = []
	for it in parsed.get("items", []):
		if Data.EQUIP.has(String(it.get("slot", ""))) and Data.RARITY.has(String(it.get("rarity", ""))):
			items.append({"id": int(it.id), "slot": String(it.slot), "rarity": String(it.rarity), "tier": int(it.tier),
				"level": int(it.level), "xp": int(it.xp), "name": String(it.name)})
	next_item_id = int(parsed.get("next_item_id", 1))
	var saved_eq: Dictionary = parsed.get("equipped", {})
	for s in Data.EQUIP_SLOTS:
		equipped[s] = int(saved_eq.get(s, -1))
		if item_by_id(equipped[s]).is_empty():
			equipped[s] = -1
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
		for k in Data.CREW_ORDER.size():
			var hid := String(saved_squad[k]) if k < saved_squad.size() else ""
			squad.append(hid if heroes.has(hid) and Data.HEROES[hid]["class"] == Data.CREW_ORDER[k] else "")
		slots[i] = {
			"dest": dest if Data.DEST.has(dest) else "",
			"remaining": float(s.get("remaining", 0.0)),
			"auto": bool(s.get("auto", true)),
			"squad": squad, "last": String(s.get("last", "")), "log": [], "battle": {},
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
