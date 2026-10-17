extends Node
## Cerveau du jeu : Capitaine (le joueur), équipage aux postes, équipement, combats,
## expéditions, améliorations, hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed
signal battle_finished(slot_i: int)

const Data = preload("res://scripts/game_data.gd")
const Battle = preload("res://scripts/battle.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5
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
var auto_recycle := Data.AUTO_RECYCLE_MAX   # recycle les objets peu utiles dès qu'ils tombent (-1 = non)

## L'équipage : cartes à collectionner (id -> {level, xp, stars}), placées aux postes des vaisseaux.
var heroes := {}
var hero_order: Array = []
var recruits := 0
var upgrade_levels := {"laser": 0, "solar": 0, "scanner": 0, "engines": 0, "docks": 0, "st_pilot": 0, "st_engineer": 0, "st_scientist": 0}
var goals_claimed: Array = []
## Un emplacement de vaisseau : dest "" = libre ; squad = un poste par classe (ids, "" = vide).
## Vaisseau 0 = vaisseau amiral (avec le Capitaine) ; vaisseau 1 = drone (équipage seul).
var slots: Array = []
var dest_wins := {}
var last_seen := 0
var expeditions_done := 0
var last_offline_report := {}
var last_recruit := {}

var _autosave_timer := 0.0
var _gain_scale := 1.0          # rendement appliqué aux gains (hors ligne)
var _offline_calc := false      # calcul d'absence en cours : les cycles d'expédition sont regroupés
var _loot_log: Array = []       # objets gardés pendant un calcul hors ligne
var _recycled_credits := 0.0    # crédits obtenus par recyclage automatique


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
	auto_recycle = Data.AUTO_RECYCLE_MAX
	heroes = {}
	hero_order = []
	recruits = 0
	for id in upgrade_levels:
		upgrade_levels[id] = 0
	goals_claimed = []
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
	for s in ["weapon", "suit"]:
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


## Stats du Capitaine pour un vaisseau : base + équipement + équipage, puis bonus en %.
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
	total["hp"] *= 1.0 + equipped_bonus("hp_pct") / 100.0
	total["atk"] *= 1.0 + equipped_bonus("atk_pct") / 100.0
	total["def"] *= 1.0 + equipped_bonus("def_pct") / 100.0
	total["spd"] += equipped_bonus("spd")
	total["crit"] = equipped_bonus("crit") / 100.0
	total["lifesteal"] = equipped_bonus("lifesteal") / 100.0
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


## --- Équipement : du loot comme dans un vrai RPG ---

func make_item(slot: String, rarity: String, ilvl: int, with_affixes: bool = true) -> Dictionary:
	var names: Array = Data.EQUIP[slot].names
	var nm: String = names[rng.randi() % names.size()]
	if rarity == "epic" or rarity == "legendary":
		nm += " " + Data.EPITHETS[rng.randi() % Data.EPITHETS.size()]
	var item := {"id": next_item_id, "slot": slot, "rarity": rarity, "ilvl": ilvl, "name": nm, "affixes": []}
	next_item_id += 1
	if with_affixes:
		var pool: Array = Data.AFFIX_ORDER.duplicate()
		for i in int(Data.ITEM_RARITY[rarity].affixes):
			var k: String = pool[rng.randi() % pool.size()]
			pool.erase(k)
			var a: Dictionary = Data.AFFIXES[k]
			var v: float = lerpf(a.min, a.max, rng.randf()) * (1.0 + Data.ITEM_ILVL_AFFIX * (ilvl - 1))
			item.affixes.append({"k": k, "v": snappedf(v, 0.1)})
	return item


## Stats plates de l'objet (selon son emplacement, sa rareté et son niveau d'objet).
func item_stats(item: Dictionary) -> Dictionary:
	var base: Dictionary = Data.ITEM_BASE[item.slot]
	var m: float = Data.ITEM_RARITY[item.rarity].mult * (1.0 + Data.ITEM_ILVL_BONUS * (item.ilvl - 1))
	var out := {"hp": 0.0, "atk": 0.0, "def": 0.0, "spd": 0.0}
	for k in base:
		out[k] = base[k] * m
	return out


func item_power(item: Dictionary) -> float:
	var s := item_stats(item)
	var p: float = s.atk * 2.0 + s.hp * 0.2 + s.def + s.spd * 1.5
	for a in item.affixes:
		p += a.v * Data.AFFIX_POWER[a.k]
	return p


## Différence de puissance avec l'objet équipé au même emplacement (> 0 = amélioration).
func power_delta(item: Dictionary) -> float:
	var eq := equipped_item(item.slot)
	return item_power(item) - (item_power(eq) if not eq.is_empty() else 0.0)


func item_by_id(id: int) -> Dictionary:
	for it in items:
		if it.id == id:
			return it
	return {}


func equipped_item(slot: String) -> Dictionary:
	return item_by_id(equipped[slot])


## Somme d'un bonus (affixe) sur tout l'équipement porté.
func equipped_bonus(key: String) -> float:
	var total := 0.0
	for slot in Data.EQUIP_SLOTS:
		var it := equipped_item(slot)
		for a in it.get("affixes", []):
			if a.k == key:
				total += a.v
	return total


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
	return ceil(10.0 * item.ilvl * Data.ITEM_RARITY[item.rarity].mult)


## Recycle un objet non équipé en crédits.
func scrap(id: int) -> bool:
	var it := item_by_id(id)
	if it.is_empty() or equipped[it.slot] == id:
		return false
	add_res("credits", scrap_value(it))
	items.erase(it)
	changed.emit()
	return true


## Recycle tout objet non équipé qui n'améliore rien (jusqu'à Rare). Retourne les crédits gagnés.
func recycle_useless() -> float:
	var gained := 0.0
	for it in items.duplicate():
		if equipped[it.slot] == it.id:
			continue
		if Data.ITEM_RARITY_ORDER.find(it.rarity) > 2 or power_delta(it) > 0.0:
			continue
		gained += scrap_value(it)
		items.erase(it)
	add_res("credits", gained)
	changed.emit()
	return gained


## Équipe, pour chaque emplacement, l'objet le plus puissant possédé.
func auto_equip() -> void:
	for slot in Data.EQUIP_SLOTS:
		var best := {}
		for it in items:
			if it.slot == slot and (best.is_empty() or item_power(it) > item_power(best)):
				best = it
		equipped[slot] = best.id if not best.is_empty() else -1
	changed.emit()


func cycle_auto_recycle() -> void:
	auto_recycle = auto_recycle + 1 if auto_recycle < Data.AUTO_RECYCLE_MAX else -1
	changed.emit()


func auto_recycle_label() -> String:
	if auto_recycle < 0:
		return "désactivé"
	return "jusqu'à « %s »" % Data.ITEM_RARITY[Data.ITEM_RARITY_ORDER[auto_recycle]].name


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


## Reçoit un objet tombé : recyclé tout de suite s'il est peu utile (réglage), sinon gardé.
## Retourne l'objet gardé, ou {} s'il a été recyclé.
func _receive(item: Dictionary) -> Dictionary:
	var rank: int = Data.ITEM_RARITY_ORDER.find(item.rarity)
	if auto_recycle >= 0 and rank <= auto_recycle and power_delta(item) <= 0.0:
		var value := scrap_value(item)
		add_res("credits", value)
		_recycled_credits += value
		return {}
	add_item(item)
	_loot_log.append(item)
	return item


func loot_level(dest: String) -> int:
	return dest_tier(dest) * 4 + enemy_level(dest)


## Tire un objet de butin ou {} (pas de chance / recyclé). Les destinations élevées donnent mieux.
func roll_drop(dest: String) -> Dictionary:
	var tier := dest_tier(dest)
	if rng.randf() > Data.DROP_CHANCE * (1.0 + equipped_bonus("drop_pct") / 100.0):
		return {}
	var total := 0.0
	var weights := {}
	for r in Data.ITEM_RARITY_ORDER:
		var w: float = Data.ITEM_RARITY[r].weight
		if Data.ITEM_RARITY_ORDER.find(r) >= 2:
			w *= 1.0 + 0.25 * (tier - 1)
		weights[r] = w
		total += w
	var roll := rng.randf() * total
	var rarity := "common"
	for r in Data.ITEM_RARITY_ORDER:
		roll -= weights[r]
		if roll < 0.0:
			rarity = r
			break
	var slot: String = Data.EQUIP_SLOTS[rng.randi() % Data.EQUIP_SLOTS.size()]
	return _receive(make_item(slot, rarity, loot_level(dest)))


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


## --- L'équipage, c'est la partie AFK : production et bonus, même hors ligne ---

## Les équipiers placés à un poste d'un vaisseau actif.
func stationed_ids() -> Array:
	var out: Array = []
	for i in slot_count():
		out.append_array(squad_ids(i))
	return out


func stationed_levels() -> Dictionary:
	var out := {}
	for c in Data.CREW_ORDER:
		out[c] = 0
	for id in stationed_ids():
		out[Data.HEROES[id]["class"]] += heroes[id].level
	return out


## Synergie des classes présentes aux postes : paires +10 %, les 3 classes +25 %.
func synergy_multiplier() -> float:
	var lv := stationed_levels()
	var mult: float = 1.0
	var present := 0
	for c in Data.CREW_ORDER:
		if lv[c] > 0:
			present += 1
	for pair in Data.PAIRS:
		if lv[pair[0]] > 0 and lv[pair[1]] > 0:
			mult += Data.SYNERGY_PAIR
	if present == Data.CREW_ORDER.size():
		mult += Data.SYNERGY_FULL
	return mult


func crew_prod_mult(id: String) -> float:
	var h: Dictionary = heroes[id]
	return pow(float(h.level), Data.PROD_LEVEL_EXP) * Data.RARITY[Data.HEROES[id].rarity].prod * (1.0 + Data.STAR_BONUS * h.stars)


## Production par seconde de toutes les ressources (équipage aux postes + capteurs de bord).
func production_per_sec() -> Dictionary:
	var out := {"credits": 0.0, "data": Data.BASE_DATA_RATE, "minerals": 0.0, "energy": 0.0}
	var syn := synergy_multiplier()
	for id in stationed_ids():
		var cls: String = Data.HEROES[id]["class"]
		var prod: Dictionary = Data.CREW_PROD[cls]
		var station: float = 1.0 + Data.STATION_GAIN * upgrade_levels["st_" + cls]
		for r in prod:
			out[r] += prod[r] * crew_prod_mult(id) * syn * station / 3600.0
	out.credits *= credit_mult()
	return out


func credit_mult() -> float:
	return 1.0 + equipped_bonus("credits_pct") / 100.0


func credits_per_sec() -> float:
	return production_per_sec().credits


func data_per_sec() -> float:
	return production_per_sec().data


## Rendement des gains quand le joueur est absent : monte avec le niveau de l'équipage placé.
func offline_efficiency() -> float:
	var lv := stationed_levels()
	var total := 0
	for c in lv:
		total += lv[c]
	var eff: float = Data.OFFLINE_BASE_EFFICIENCY + Data.OFFLINE_EFF_PER_LEVEL * total + equipped_bonus("offline_pct") / 100.0
	return clampf(eff, Data.OFFLINE_BASE_EFFICIENCY, Data.OFFLINE_EFF_MAX)


## Durée maximale comptabilisée hors ligne : les Ingénieurs l'allongent.
func offline_cap_seconds() -> float:
	var hours: float = Data.OFFLINE_BASE_HOURS + Data.OFFLINE_HOURS_PER_ENGINEER_LEVEL * stationed_levels()["engineer"]
	return minf(hours, Data.OFFLINE_MAX_HOURS) * 3600.0


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


## --- Objectifs ---

func goal_progress(g: Dictionary) -> float:
	match String(g.kind):
		"captain_level": return float(captain.level)
		"crew_count": return float(hero_order.size())
		"data_total": return data_total
		"expeditions": return float(expeditions_done)
		"docks": return float(upgrade_levels["docks"])
		"epic_item":
			for it in items:
				if it.rarity == "epic" or it.rarity == "legendary":
					return 1.0
			return 0.0
		"station_levels":
			var n := 0
			for c in Data.CREW_ORDER:
				n += upgrade_levels["st_" + c]
			return float(n)
		"crew_level_sum":
			var n := 0
			for id in hero_order:
				n += heroes[id].level
			return float(n)
	return 0.0


## Premier objectif non récupéré ({} si tous faits).
func next_goal() -> Dictionary:
	for g in Data.GOALS:
		if not goals_claimed.has(g.id):
			return g
	return {}


func goal_ready(g: Dictionary) -> bool:
	return not g.is_empty() and goal_progress(g) >= float(g.target)


func claim_goal() -> bool:
	var g := next_goal()
	if not goal_ready(g):
		return false
	for r in g.reward:
		add_res(r, g.reward[r])
	goals_claimed.append(g.id)
	changed.emit()
	return true


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
	return maxf(Data.MIN_DURATION, base / speed)


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
	return mini(1 + dest_wins[dest] / Data.ENEMY_LEVEL_STEP, Data.ENEMY_LEVEL_MAX)


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
		return [Battle.make_unit(captain.name, s.hp, s.atk, s.def, s.spd, s.crit, s.lifesteal)]
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


## `times` > 1 : plusieurs expéditions identiques regroupées (calcul hors ligne) ; un seul combat est simulé.
func _complete(slot_i: int, times: int = 1) -> void:
	var slot: Dictionary = slots[slot_i]
	var dest: String = slot.dest
	var battle := preview_battle(dest, slot_i)
	var rewards: Dictionary = rewards_of(dest, slot_i)
	var levels_gained := 0
	var loot := {}
	if battle.win:
		dest_wins[dest] += times
		var xp := int(round(Data.DEST[dest].xp * (1.0 + equipped_bonus("xp_pct") / 100.0) * _gain_scale * times))
		for id in squad_ids(slot_i):
			levels_gained += gain_xp(id, xp)
		if slot_i == 0:
			levels_gained += gain_captain_xp(xp)
			for k in times:
				if _offline_calc and rng.randf() > _gain_scale:
					continue      # hors ligne, une partie du butin est perdue (rendement)
				var drop := roll_drop(dest)
				if not drop.is_empty():
					loot = drop
	else:
		for r in rewards:
			rewards[r] *= Data.LOSS_REWARD
	for r in rewards:
		rewards[r] *= _gain_scale * (credit_mult() if r == "credits" else 1.0) * times
		add_res(r, rewards[r])
	expeditions_done += times
	var head := "Victoire en %d tours" % battle.rounds if battle.win else "Défaite (butin réduit)"
	slot.last = "%s — %s : %s" % [head, Data.DEST[dest].name, Data.fmt_amounts(rewards)]
	if levels_gained > 0:
		slot.last += "  |  %d niveau(x) gagné(s) !" % levels_gained
	if not loot.is_empty():
		slot.last += "  |  Butin : %s (%s, niv. %d)" % [loot.name, Data.ITEM_RARITY[loot.rarity].name, loot.ilvl]
	slot.log = battle.log
	var ally: Dictionary = battle.allies[0]
	slot.battle = {
		"win": battle.win, "dest": dest, "events": battle.events, "loot": loot,
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
				var extra := 0
				var d := duration_of(slot.dest, i)
				# hors ligne : on regroupe les cycles (au plus ~40 combats simulés par poste)
				if _offline_calc and slot.auto and d > 0.0:
					var total := 1 + int(t / d)
					if total > Data.OFFLINE_BULK_MIN:
						extra = maxi(Data.OFFLINE_BULK_CHUNK, total / 40) - 1
						extra = mini(extra, total - 1)
				_complete(i, 1 + extra)
				t -= extra * d


## Fait avancer le jeu de `seconds` secondes (production de l'équipage + expéditions).
func tick(seconds: float) -> void:
	var prod := production_per_sec()
	for r in prod:
		add_res(r, prod[r] * seconds * _gain_scale)
	_advance_expeditions(seconds)
	changed.emit()


## Simule une absence : durée plafonnée par les Ingénieurs, gains au rendement hors ligne.
func simulate_offline(away: float) -> Dictionary:
	var secs := minf(away, offline_cap_seconds())
	var before := res.duplicate()
	var done_before := expeditions_done
	_loot_log = []
	_recycled_credits = 0.0
	_gain_scale = offline_efficiency()
	_offline_calc = true
	tick(secs)
	_offline_calc = false
	_gain_scale = 1.0
	var gains := {}
	for id in res:
		gains[id] = res[id] - before[id]
	var best := {}
	for it in _loot_log:
		if best.is_empty() or item_power(it) > item_power(best):
			best = it
	return {
		"seconds": secs, "away": away, "gains": gains, "expeditions": expeditions_done - done_before,
		"efficiency": offline_efficiency(), "loot_kept": _loot_log.size(), "loot_best": best,
		"recycled": _recycled_credits,
	}


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
		"items": items, "equipped": equipped, "next_item_id": next_item_id, "auto_recycle": auto_recycle,
		"heroes": heroes, "hero_order": hero_order, "recruits": recruits,
		"upgrades": upgrade_levels, "goals": goals_claimed, "slots": _slots_for_save(), "dest_wins": dest_wins,
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
		if not (Data.EQUIP.has(String(it.get("slot", ""))) and Data.ITEM_RARITY.has(String(it.get("rarity", "")))):
			continue
		var affixes: Array = []
		for a in it.get("affixes", []):
			if Data.AFFIXES.has(String(a.get("k", ""))):
				affixes.append({"k": String(a.k), "v": float(a.v)})
		items.append({"id": int(it.id), "slot": String(it.slot), "rarity": String(it.rarity),
			"ilvl": int(it.ilvl), "name": String(it.name), "affixes": affixes})
	next_item_id = int(parsed.get("next_item_id", 1))
	auto_recycle = clampi(int(parsed.get("auto_recycle", Data.AUTO_RECYCLE_MAX)), -1, Data.AUTO_RECYCLE_MAX)
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
	goals_claimed = []
	for gid in parsed.get("goals", []):
		goals_claimed.append(String(gid))
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
	var away := maxi(0, now - last_seen)
	if away > 60:
		last_offline_report = simulate_offline(float(away))
	return true
