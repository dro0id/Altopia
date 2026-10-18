extends Node
## Cerveau du jeu : Capitaine (le joueur), équipage aux postes, équipement, combats,
## expéditions, améliorations, hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed
signal battle_finished(slot_i: int)
signal anomaly_finished

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
var upgrade_levels := {"laser": 0, "solar": 0, "scanner": 0, "engines": 0, "docks": 0}
var room_levels := {}             # niveau de chaque salle de la Base (1 au départ)
var room_crew := {}               # salle -> équipier qui y travaille ("" = personne)
var atelier_slot := ""            # emplacement visé par l'Atelier ("" = au hasard)
var atelier_focus := ""           # bonus visé par l'Atelier ("" = au hasard)
var goals_claimed: Array = []
var research_levels := {}
var research_active: Array = []   # [{id, remaining, total}] : recherches en cours
var research_queue: Array = []    # ids en attente (déjà payées)
var research_done_log: Array = [] # noms terminés depuis le dernier rapport
var crystals := 0                 # monnaie spéciale : non obtenable en jeu pour le moment (achat prévu plus tard)
var premium_unlocks := {}         # déblocages payés en Cristaux : "lab_slot", "lab_auto"
var research_auto := false        # lance tout seul la recherche abordable la plus courte quand un poste se libère
var anomaly_charges := float(Data.ANOMALY_CHARGES_MAX)
var anomaly_regen_acc := 0.0       # secondes écoulées dans la tranche de recharge en cours
var anomaly_max := 0              # plus haute faille réussie
var anomaly_best := {}            # faille -> meilleur nombre de tours
var last_anomaly := {}            # dernier combat d'anomalie (pour l'animer)
var afk_wins := 0                 # compteurs d'équilibrage (non sauvegardés)
var afk_defeats := 0
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
var _afk_loot_clock := 0.0      # avancement du prochain objet fabriqué par l'Atelier (0 à 1)
var prestige_earned := 0          # éclats gagnés au total (la refonte ne rapporte que du nouveau)
var prestige_count := 0           # refontes de la Base effectuées
var prestige_points := 0          # éclats non dépensés
var prestige_perks := {}          # bonus permanents : id -> niveau
var craft_log: Array = []         # derniers objets fabriqués : {id, name, rarity, ilvl, kept}
var prestige_best := 0            # meilleure somme de niveaux de salles au moment d'une refonte
var crafted_total := 0           # objets fabriqués par l'Atelier depuis le début
var last_crafted := {}          # dernier objet fabriqué (avec "kept" : gardé ou recyclé automatiquement)
var _skip_research := false     # le calcul d'absence fait avancer les recherches séparément
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
	for rid in Data.ROOM_ORDER:
		room_levels[rid] = 1
		room_crew[rid] = ""
	atelier_slot = ""
	atelier_focus = ""
	crafted_total = 0
	craft_log = []
	prestige_best = 0
	prestige_count = 0
	prestige_earned = 0
	prestige_points = 0
	prestige_perks = {}
	goals_claimed = []
	research_levels = {}
	for rid in Data.RESEARCH_ORDER:
		research_levels[rid] = 0
	research_active = []
	research_queue = []
	research_done_log = []
	research_auto = false
	crystals = 0
	premium_unlocks = {}
	anomaly_charges = float(Data.ANOMALY_CHARGES_MAX)
	anomaly_regen_acc = 0.0
	anomaly_max = 0
	anomaly_best = {}
	last_anomaly = {}
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
	auto_rooms()
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

## Niveau de puissance du Capitaine : un niveau affiché en vaut CAPTAIN_LEVEL_SPAN. C'est lui qui règle les stats et les plafonds liés au niveau.
func captain_p() -> int:
	return Data.CAPTAIN_LEVEL_SPAN * (captain.level - 1) + 1


func captain_train_cost() -> float:
	var g: float = Data.CAPTAIN_TRAIN_GROWTH
	var span_sum: float = (pow(g, Data.CAPTAIN_LEVEL_SPAN) - 1.0) / (g - 1.0)     # somme des coûts des niveaux de puissance du niveau
	return ceil(Data.CAPTAIN_TRAIN_BASE * span_sum * pow(g, captain_p() - 1))


func captain_maxed() -> bool:
	return captain.level >= Data.CAPTAIN_MAX_LEVEL


func train_captain() -> bool:
	var cost := captain_train_cost()
	if captain_maxed() or res["credits"] < cost:
		return false
	res["credits"] -= cost
	captain.level += 1
	changed.emit()
	return true


## Ajoute de l'XP au Capitaine ; retourne le nombre de niveaux gagnés.
func gain_captain_xp(amount: int) -> int:
	var gained := 0
	if captain_maxed():
		captain.xp = 0
		return 0
	captain.xp += amount
	while not captain_maxed() and captain.xp >= Data.captain_xp_needed(captain.level):
		captain.xp -= Data.captain_xp_needed(captain.level)
		captain.level += 1
		gained += 1
	if captain_maxed():
		captain.xp = 0
	return gained


func _captain_for_save() -> Dictionary:
	var out := captain.duplicate(true)
	out["span"] = Data.CAPTAIN_LEVEL_SPAN
	return out


func cycle_look(part: String) -> void:
	var count: int = Data.LOOK_STYLES if part == "style" else Data.LOOK_SUITS.size()
	captain.look[part] = (captain.look[part] + 1) % count
	changed.emit()


## Stats du Capitaine pour un vaisseau : base + équipement + équipage, puis bonus en %.
func captain_stats(slot_i: int = 0) -> Dictionary:
	var m: float = 1.0 + Data.CAPTAIN_LEVEL_BONUS * (captain_p() - 1)
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

func make_item(slot: String, rarity: String, ilvl: int, with_affixes: bool = true, forced_affix: String = "") -> Dictionary:
	var names: Array = Data.EQUIP[slot].names
	var nm: String = names[rng.randi() % names.size()]
	if rarity == "epic" or rarity == "legendary":
		nm += " " + Data.EPITHETS[rng.randi() % Data.EPITHETS.size()]
	var item := {"id": next_item_id, "slot": slot, "rarity": rarity, "ilvl": ilvl, "name": nm, "affixes": []}
	next_item_id += 1
	if with_affixes:
		var pool: Array = Data.AFFIX_ORDER.duplicate()
		var n: int = int(Data.ITEM_RARITY[rarity].affixes)
		if forced_affix != "" and n > 0 and pool.has(forced_affix):     # bonus visé à l'Atelier : garanti
			item.affixes.append({"k": forced_affix, "v": _affix_value(forced_affix, ilvl)})
			pool.erase(forced_affix)
			n -= 1
		for i in n:
			var k: String = pool[rng.randi() % pool.size()]
			pool.erase(k)
			item.affixes.append({"k": k, "v": _affix_value(k, ilvl)})
	return item


func _affix_value(k: String, ilvl: int) -> float:
	var a: Dictionary = Data.AFFIXES[k]
	var v: float = lerpf(a.min, a.max, rng.randf()) * (1.0 + Data.ITEM_ILVL_AFFIX * (ilvl - 1))
	return snappedf(v, 0.1)


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


## Niveau d'AFK : équipage au travail dans les salles + niveaux de salles + améliorations de vaisseau.
func afk_level() -> int:
	var n := 0
	for id in stationed_ids():
		n += heroes[id].level
	for rid in Data.ROOM_ORDER:
		if room_worker(rid) != "":
			n += int((room_level(rid) - 1) / 2)
	for id in ["laser", "solar", "scanner", "engines"]:
		n += upgrade_levels[id]
	return n


## Puissance de fabrication de l'Atelier : le niveau d'AFK, plus l'apport de l'Atelier lui-même.
func craft_power() -> int:
	return afk_level() + int(Data.ATELIER_QUALITY_PER_LEVEL * (room_level("atelier") - 1)) + int(perk_level("craft") * Data.PRESTIGE_PERKS["craft"].gain)


## Niveau des objets de l'Atelier : monte avec la puissance de fabrication, mais reste borné par le niveau du Capitaine.
func loot_level() -> int:
	var by_power := 3 + int(craft_power() / Data.AFK_ILVL_DIV)
	return mini(by_power, 3 + int(float(captain_p()) * Data.AFK_ILVL_CAP_RATIO))


## Poids de tirage de chaque rareté : la puissance de fabrication fait monter les raretés élevées.
func drop_weights(tier: int) -> Dictionary:
	var out := {}
	var lvl := float(craft_power())
	for i in Data.ITEM_RARITY_ORDER.size():
		var r: String = Data.ITEM_RARITY_ORDER[i]
		var w: float = Data.ITEM_RARITY[r].weight
		if i >= 2:
			w *= 1.0 + 0.25 * (tier - 1)
		w *= 1.0 + lvl * Data.AFK_RARITY_RATE * Data.AFK_RARITY_RANK_FACTOR[i]
		out[r] = w
	return out


## Fabrique un objet pour le Capitaine : rareté et niveau selon la puissance de fabrication, emplacement et bonus
## selon les ordres de l'Atelier. Retourne {} s'il est recyclé.
func roll_afk_drop() -> Dictionary:
	var weights := drop_weights(1)
	var total := 0.0
	for r in weights:
		total += weights[r]
	var roll := rng.randf() * total
	var rarity := "common"
	for r in Data.ITEM_RARITY_ORDER:
		roll -= weights[r]
		if roll < 0.0:
			rarity = r
			break
	var slot: String = atelier_slot if Data.EQUIP.has(atelier_slot) else Data.EQUIP_SLOTS[rng.randi() % Data.EQUIP_SLOTS.size()]
	var made := make_item(slot, rarity, loot_level(), true, atelier_focus)
	var kept := _receive(made)
	crafted_total += 1
	last_crafted = made.duplicate()
	last_crafted["kept"] = not kept.is_empty()
	craft_log.push_front({"id": made.id, "name": made.name, "rarity": made.rarity, "ilvl": made.ilvl, "kept": not kept.is_empty()})
	if craft_log.size() > 5:
		craft_log.resize(5)
	return kept


## --- Refonte de la Base (prestige) ---

func perk_level(id: String) -> int:
	return int(prestige_perks.get(id, 0))


## Multiplicateur d'un bonus permanent de pourcentage (Rendement, Formation, Fabrication).
func perk_mult(id: String) -> float:
	return 1.0 + Data.PRESTIGE_PERKS[id].gain * perk_level(id)


func perk_cost(id: String) -> int:
	return int(ceil(pow(Data.PRESTIGE_COST_GROWTH, perk_level(id))))


func perk_maxed(id: String) -> bool:
	return perk_level(id) >= Data.PRESTIGE_PERK_MAX


func buy_perk(id: String) -> bool:
	if not Data.PRESTIGE_PERKS.has(id) or perk_maxed(id) or prestige_points < perk_cost(id):
		return false
	prestige_points -= perk_cost(id)
	prestige_perks[id] = perk_level(id) + 1
	changed.emit()
	return true


## Puissance de la Base : somme des niveaux de salle. C'est ce que la refonte remet à zéro, donc ce qu'elle récompense.
func base_power() -> int:
	var n := 0
	for rid in Data.ROOM_ORDER:
		n += room_level(rid)
	return n


## Éclats promis : la valeur de la Base moins ce qui a déjà été gagné. Refaire la même Base ne rapporte rien.
func prestige_gain() -> int:
	return maxi(0, int(floor(pow(float(base_power()) / Data.PRESTIGE_DIV, Data.PRESTIGE_POW))) - prestige_earned)


## Niveau maximal des salles : monte à chaque refonte.
func room_max_level() -> int:
	return Data.ROOM_MAX_LEVEL + Data.PRESTIGE_ROOM_CAP_PER_RANK * prestige_count


## Effet d'un équipier dans une salle (hid == "" : salle vide), au niveau `lvl` de la salle (-1 : le niveau actuel).
## Retourne {"value", "unit"} : la ressource principale par heure pour une salle de production, sinon l'effet propre de la salle.
func room_metric(rid: String, hid: String, lvl: int = -1) -> Dictionary:
	var level := room_level(rid) if lvl < 0 else lvl
	var lf := 1.0 + Data.ROOM_LEVEL_GAIN * (level - 1)
	var m := 0.0 if hid == "" else room_hero_mult(rid, hid)
	var boost := 0.0 if hid == "" else 1.0 + m / Data.ROOM_CREW_REF
	match rid:
		"atelier":
			var f := 1.0
			if atelier_slot != "":
				f *= Data.ATELIER_TARGET_FACTOR
			if atelier_focus != "":
				f *= Data.ATELIER_TARGET_FACTOR
			var v := 0.0 if hid == "" else Data.ATELIER_BASE_PER_HOUR * perk_mult("atelier") * lf * boost * f * (1.0 + (equipped_bonus("drop_pct") + research_bonus("loot_pct")) / 100.0)
			return {"value": v, "unit": "objet/h"}
		"quartiers":
			return {"value": Data.QUARTERS_XP_GAIN * (level - 1) * boost * 100.0, "unit": "% d'XP"}
		"soute":
			return {"value": Data.SOUTE_HOURS_GAIN * (level - 1) * boost, "unit": "h de coffre"}
	var prod: Dictionary = Data.ROOMS[rid].prod
	var main := "credits"
	for r in prod:
		if r != "credits":
			main = r
	var syn := synergy_multiplier()
	var pm := (1.0 + research_bonus("prod_pct") / 100.0) * perk_mult("prod")
	var amount: float = prod[main] * m * lf * syn * pm * (credit_mult() if main == "credits" else 1.0)
	var short := {"credits": "cr", "minerals": "min", "energy": "én", "data": "don"}
	return {"value": amount, "unit": "%s/h" % short[main], "res": main}


## Crédits par heure d'une salle de production, pour estimer le retour sur investissement d'une amélioration.
func room_credits_per_hour(rid: String, hid: String, lvl: int = -1) -> float:
	if hid == "" or not Data.ROOMS[rid].prod.has("credits"):
		return 0.0
	var level := room_level(rid) if lvl < 0 else lvl
	var lf := 1.0 + Data.ROOM_LEVEL_GAIN * (level - 1)
	return Data.ROOMS[rid].prod.credits * room_hero_mult(rid, hid) * lf * synergy_multiplier() * credit_mult() * (1.0 + research_bonus("prod_pct") / 100.0) * perk_mult("prod")


## Niveau auquel les salles repartent après une refonte (bonus « Fondations »).
func prestige_start_level() -> int:
	return mini(room_max_level(), 1 + int(Data.PRESTIGE_PERKS["found"].gain * perk_level("found")))


## Raison pour laquelle la refonte n'est pas possible ("" si elle l'est).
func prestige_block_reason() -> String:
	if base_power() < Data.PRESTIGE_MIN_POWER:
		return "Niveaux de salles cumulés %d requis" % Data.PRESTIGE_MIN_POWER
	if prestige_gain() < 1:
		return "Monte tes salles plus haut pour gagner des éclats"
	return ""


## Refonte : les salles, les améliorations du vaisseau (sauf les docks) et les ressources sont remises à zéro.
## L'équipage, le Capitaine, l'équipement, les recherches et les objectifs sont conservés.
func do_prestige() -> int:
	if prestige_block_reason() != "":
		return 0
	var gain := prestige_gain()
	for i in slots.size():
		recall(i)        # les expéditions en cours sont rappelées (sans gain)
	prestige_points += gain
	prestige_earned += gain
	prestige_best = maxi(prestige_best, base_power())
	prestige_count += 1
	for rid in Data.ROOM_ORDER:
		room_levels[rid] = prestige_start_level()
	for id in upgrade_levels:
		if id != "docks":
			upgrade_levels[id] = 0
	for id in res:
		res[id] = 0.0
	res["credits"] = Data.START_CREDITS
	_afk_loot_clock = 0.0
	changed.emit()
	return gain


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
		_autoplace_room(id)
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
	if not heroes.has(id):
		return false
	var cost := train_cost(id)
	if res["credits"] < cost:
		return false
	res["credits"] -= cost
	heroes[id].level += 1
	changed.emit()
	return true


## Ajoute de l'XP à une carte d'équipage ; retourne le nombre de niveaux gagnés.
func gain_xp(id: String, amount: float) -> int:
	var h: Dictionary = heroes[id]
	var gained := 0
	h.xp += amount
	while h.xp >= Data.xp_needed(h.level):
		h.xp -= Data.xp_needed(h.level)
		h.level += 1
		gained += 1
	return gained


## --- La Base : l'équipage au travail dans les salles (le jeu AFK, même hors ligne) ---

## Les équipiers qui travaillent dans une salle de la Base.
func stationed_ids() -> Array:
	var out: Array = []
	for rid in Data.ROOM_ORDER:
		var w := room_worker(rid)
		if w != "" and heroes.has(w) and not out.has(w):
			out.append(w)
	return out


func room_level(id: String) -> int:
	return int(room_levels.get(id, 1))


func room_level_factor(id: String) -> float:
	return 1.0 + Data.ROOM_LEVEL_GAIN * (room_level(id) - 1)


func room_worker(id: String) -> String:
	return String(room_crew.get(id, ""))


func hero_room(hero_id: String) -> String:
	for rid in Data.ROOM_ORDER:
		if room_worker(rid) == hero_id:
			return rid
	return ""


## Force d'un équipier dans une salle : sa force de travail, +25 % si sa classe correspond, +50 % si c'est sa spécialité.
func room_hero_mult(room_id: String, hero_id: String) -> float:
	var m := crew_prod_mult(hero_id)
	if Data.HEROES[hero_id]["class"] == Data.ROOMS[room_id].affinity:
		m *= 1.0 + Data.ROOM_AFFINITY_BONUS
	if Data.HEROES[hero_id].get("specialty", "") == room_id:
		m *= 1.0 + Data.ROOM_SPECIALTY_BONUS
	return m


## Effet d'une salle à effet (Atelier, Quartiers, Soute) : nul sans équipier, croît avec sa force de travail.
func room_crew_boost(room_id: String) -> float:
	var w := room_worker(room_id)
	if w == "" or not heroes.has(w):
		return 0.0
	return 1.0 + room_hero_mult(room_id, w) / Data.ROOM_CREW_REF


func room_maxed(id: String) -> bool:
	return room_level(id) >= room_max_level()


func room_upgrade_cost(id: String) -> Dictionary:
	var base: Dictionary = Data.ROOMS[id].cost
	var out := {}
	for r in base:
		out[r] = ceil(base[r] * pow(Data.ROOM_COST_GROWTH, room_level(id) - 1))
	return out


func buy_room_upgrade(id: String) -> bool:
	if not Data.ROOMS.has(id) or room_maxed(id):
		return false
	var cost := room_upgrade_cost(id)
	if not can_afford(cost):
		return false
	pay(cost)
	room_levels[id] = room_level(id) + 1
	changed.emit()
	return true


## Place (ou retire, avec "") un équipier dans une salle ; un équipier ne travaille que dans une salle.
func set_room_crew(room_id: String, hero_id: String) -> bool:
	if not Data.ROOMS.has(room_id) or (hero_id != "" and not heroes.has(hero_id)):
		return false
	if hero_id != "":
		for rid in Data.ROOM_ORDER:
			if room_worker(rid) == hero_id:
				room_crew[rid] = ""
	room_crew[room_id] = hero_id
	changed.emit()
	return true


## Placement automatique : les salles de production d'abord, chacune reçoit le meilleur équipier disponible.
func auto_rooms() -> void:
	for rid in Data.ROOM_ORDER:
		room_crew[rid] = ""
	var free: Array = hero_order.duplicate()
	for rid in Data.ROOM_ORDER:
		var best := ""
		var best_m := -1.0
		for id in free:
			var m := room_hero_mult(rid, id)
			if m > best_m:
				best = id
				best_m = m
		if best != "":
			room_crew[rid] = best
			free.erase(best)
	changed.emit()


func stationed_levels() -> Dictionary:
	var out := {}
	for c in Data.CREW_ORDER:
		out[c] = 0
	for id in stationed_ids():
		out[Data.HEROES[id]["class"]] += heroes[id].level
	return out


## Synergie des classes présentes dans la Base : paires +10 %, les 3 classes +25 %.
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


## Production par seconde de toutes les ressources (équipage au travail dans les salles + capteurs de bord).
func production_per_sec() -> Dictionary:
	var out := {"credits": 0.0, "data": Data.BASE_DATA_RATE, "minerals": 0.0, "energy": 0.0}
	var syn := synergy_multiplier()
	for rid in Data.ROOM_ORDER:
		var w := room_worker(rid)
		if w == "" or not heroes.has(w):
			continue
		var prod: Dictionary = Data.ROOMS[rid].prod
		var m := room_hero_mult(rid, w) * room_level_factor(rid) * syn / 3600.0
		for r in prod:
			out[r] += prod[r] * m
	out.credits *= credit_mult()
	var pm := (1.0 + research_bonus("prod_pct") / 100.0) * perk_mult("prod")
	for r in out:
		out[r] *= pm
	return out


func credit_mult() -> float:
	return 1.0 + equipped_bonus("credits_pct") / 100.0


func credits_per_sec() -> float:
	return production_per_sec().credits


func data_per_sec() -> float:
	return production_per_sec().data


## Rendement des gains quand le joueur est absent : 50 % fixe, 70 % avec le déblocage en Cristaux.
func offline_efficiency() -> float:
	return Data.OFFLINE_PREMIUM_EFFICIENCY if premium_unlocked("offline_boost") else Data.OFFLINE_BASE_EFFICIENCY


## Durée maximale comptabilisée hors ligne : les Ingénieurs l'allongent.
func offline_cap_seconds() -> float:
	var hours: float = Data.OFFLINE_BASE_HOURS + Data.OFFLINE_HOURS_PER_ENGINEER_LEVEL * stationed_levels()["engineer"] + research_bonus("offline_hours")
	hours += Data.SOUTE_HOURS_GAIN * (room_level("soute") - 1) * room_crew_boost("soute")
	return minf(hours, Data.OFFLINE_MAX_HOURS) * 3600.0


## --- Laboratoire ---

func research_level(id: String) -> int:
	return int(research_levels.get(id, 0))


## Somme des effets de toutes les recherches pour une clé d'effet.
func research_bonus(key: String) -> float:
	var total := 0.0
	for id in Data.RESEARCH_ORDER:
		var r: Dictionary = Data.RESEARCH[id]
		if r.effect.key == key:
			total += float(r.effect.per) * research_level(id)
	return total


func research_slots() -> int:
	return Data.RESEARCH_BASE_SLOTS + int(research_bonus("research_slots")) + (1 if premium_unlocked("lab_slot") else 0)


func premium_unlocked(id: String) -> bool:
	return bool(premium_unlocks.get(id, false))


## Achat d'un déblocage en Cristaux. Aucun moyen d'en gagner en jeu pour l'instant (PREMIUM_OBTAINABLE) : les tests ou un futur achat les créditent.
func buy_premium(id: String) -> bool:
	if not Data.PREMIUM_UNLOCKS.has(id) or premium_unlocked(id):
		return false
	var cost: int = Data.PREMIUM_UNLOCKS[id].cost
	if crystals < cost:
		return false
	crystals -= cost
	premium_unlocks[id] = true
	changed.emit()
	return true


func research_maxed(id: String) -> bool:
	return research_level(id) >= Data.RESEARCH[id].max


func research_cost(id: String) -> Dictionary:
	var r: Dictionary = Data.RESEARCH[id]
	var out := {}
	for res_id in r.cost:
		out[res_id] = ceil(Data.research_curve(r.cost[res_id], research_level(id), r.max))
	return out


func research_duration(id: String) -> float:
	var r: Dictionary = Data.RESEARCH[id]
	var base: float = Data.research_curve(r.time, research_level(id), r.max)
	var speed := maxf(Data.RESEARCH_SPEED_MIN, 1.0 - research_bonus("research_speed") / 100.0)
	return maxf(5.0, round(base * speed))


func research_is_busy(id: String) -> bool:
	if research_queue.has(id):
		return true
	for a in research_active:
		if a.id == id:
			return true
	return false


## "" si la recherche peut être lancée (ressources mises à part), sinon la raison.
func research_block_reason(id: String) -> String:
	if research_maxed(id):
		return "Niveau maximum"
	if research_is_busy(id):
		return "Déjà en cours ou en file"
	var req: Dictionary = Data.RESEARCH[id].requires
	for rid in req:
		if research_level(rid) < req[rid]:
			return "Requiert %s niv. %d" % [Data.RESEARCH[rid].name, req[rid]]
	if research_active.size() >= research_slots() and research_queue.size() >= Data.RESEARCH_QUEUE_MAX:
		return "File d'attente pleine"
	return ""


## Lance la recherche (ou la met en file si tous les postes sont pris). Le coût est payé tout de suite.
func start_research(id: String) -> bool:
	if research_block_reason(id) != "":
		return false
	var cost := research_cost(id)
	if not can_afford(cost):
		return false
	pay(cost)
	if research_active.size() < research_slots():
		_begin_research(id)
	else:
		research_queue.append(id)
	changed.emit()
	return true


func _begin_research(id: String) -> void:
	var d := research_duration(id)
	research_active.append({"id": id, "remaining": d, "total": d, "boosts": 0})


## Annule une recherche en file (remboursée en entier) ou en cours (partiellement).
func cancel_research(id: String) -> bool:
	var cost := research_cost(id)
	if research_queue.has(id):
		research_queue.erase(id)
		for r in cost:
			add_res(r, cost[r])
		changed.emit()
		return true
	for i in research_active.size():
		if research_active[i].id == id:
			research_active.remove_at(i)
			for r in cost:
				add_res(r, floor(cost[r] * Data.RESEARCH_CANCEL_REFUND))
			_promote_queue()
			changed.emit()
			return true
	return false


func _research_levels_total() -> int:
	var n := 0
	for id in Data.RESEARCH_ORDER:
		n += research_level(id)
	return n


## Temps retiré par une accélération (en secondes) ; 0 si impossible.
func research_boost_seconds(id: String) -> float:
	for a in research_active:
		if a.id == id and int(a.get("boosts", 0)) < Data.RESEARCH_BOOST_MAX:
			return minf(a.remaining, a.total * Data.RESEARCH_BOOST_FRACTION)
	return 0.0


func research_boost_cost(id: String) -> float:
	var minutes := research_boost_seconds(id) / 60.0
	var rate := Data.RESEARCH_BOOST_ENERGY_BASE + Data.RESEARCH_BOOST_ENERGY_PER_LEVEL * _research_levels_total()
	return ceil(minutes * rate)


## Accélère une recherche en cours contre de l'énergie (25 % de sa durée, 2 fois au plus).
func boost_research(id: String) -> bool:
	var secs := research_boost_seconds(id)
	var cost := research_boost_cost(id)
	if secs <= 0.0 or res["energy"] < cost:
		return false
	res["energy"] -= cost
	for a in research_active:
		if a.id == id:
			a.remaining -= secs
			a["boosts"] = int(a.get("boosts", 0)) + 1
	_advance_research(0.0)
	changed.emit()
	return true


func _promote_queue() -> void:
	while research_active.size() < research_slots() and not research_queue.is_empty():
		_begin_research(research_queue.pop_front())
	# recherche automatique : un poste libre et rien en file -> la recherche abordable la plus courte
	while research_auto and research_active.size() < research_slots():
		var pick := _auto_research_pick()
		if pick == "":
			break
		pay(research_cost(pick))
		_begin_research(pick)


func _auto_research_pick() -> String:
	var best := ""
	var best_t := 1e30
	for id in Data.RESEARCH_ORDER:
		if research_block_reason(id) != "" or not can_afford(research_cost(id)):
			continue
		var t := research_duration(id)
		if t < best_t:
			best = id
			best_t = t
	return best


func set_research_auto(v: bool) -> void:
	if v and not premium_unlocked("lab_auto"):
		return           # la recherche automatique se débloque avec des Cristaux
	research_auto = v
	_promote_queue()
	changed.emit()


## Fait avancer les recherches de `seconds` (exact, même sur de longues absences).
func _advance_research(seconds: float) -> void:
	var t := seconds
	var guard := 0
	while guard < 1000:
		guard += 1
		_promote_queue()
		if research_active.is_empty():
			return
		var step := t
		for a in research_active:
			step = minf(step, a.remaining)
		for a in research_active:
			a.remaining -= step
		t -= step
		var finished := research_active.filter(func(a): return a.remaining <= 0.0001)
		if finished.is_empty():
			return
		research_active = research_active.filter(func(a): return a.remaining > 0.0001)
		for a in finished:
			research_levels[a.id] = research_level(a.id) + 1
			research_done_log.append("%s niv. %d" % [Data.RESEARCH[a.id].name, research_level(a.id)])



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


## Une nouvelle recrue prend la salle vide où elle travaille le mieux (elle ne remplace jamais personne).
func _autoplace_room(id: String) -> void:
	var best := ""
	var best_m := -1.0
	for rid in Data.ROOM_ORDER:
		if room_worker(rid) != "":
			continue
		var m := room_hero_mult(rid, id)
		if m > best_m:
			best = rid
			best_m = m
	if best != "":
		room_crew[best] = id


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
		"room_levels":
			var n := 0
			for rid in Data.ROOM_ORDER:
				n += room_level(rid)
			return float(n)
		"prestige_count": return float(prestige_count)
		"perk_levels":
			var n := 0
			for k in prestige_perks:
				n += int(prestige_perks[k])
			return float(n)
		"prestige_earned": return float(prestige_earned)
		"afk_level": return float(afk_level())
		"atelier_level": return float(room_level("atelier"))
		"crafted": return float(crafted_total)
		"rooms_min":
			var lo := 999
			for rid in Data.ROOM_ORDER:
				lo = mini(lo, room_level(rid))
			return float(lo)
		"legendary_item":
			for it in items:
				if it.rarity == "legendary":
					return 1.0
			return 0.0
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


## Récompense d'objectif : un objet de la rareté donnée, au niveau de fabrication de l'Atelier, sur un emplacement au hasard.
func _goal_item(rarity: String) -> void:
	var slot: String = Data.EQUIP_SLOTS[rng.randi() % Data.EQUIP_SLOTS.size()]
	var made := make_item(slot, rarity, loot_level() + 2, true)
	last_crafted = made.duplicate()
	last_crafted["kept"] = not _receive(made).is_empty()


func goal_ready(g: Dictionary) -> bool:
	return not g.is_empty() and goal_progress(g) >= float(g.target)


func claim_goal() -> bool:
	var g := next_goal()
	if not goal_ready(g):
		return false
	_give_goal_reward(g)
	goals_claimed.append(g.id)
	changed.emit()
	return true


func _give_goal_reward(g: Dictionary) -> void:
	for r in g.reward:
		if r == "item":
			_goal_item(String(g.reward[r]))
		elif r == "shards":
			prestige_points += int(g.reward[r])      # (hors prestige_earned : ça ne réduit pas les éclats des prochaines refontes)
		else:
			add_res(r, g.reward[r])


## Premier objectif de refonte non récupéré ({} si tous faits).
func next_prestige_goal() -> Dictionary:
	for g in Data.PRESTIGE_GOALS:
		if not goals_claimed.has(g.id):
			return g
	return {}


func claim_prestige_goal() -> bool:
	var g := next_prestige_goal()
	if not goal_ready(g):
		return false
	_give_goal_reward(g)
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
	# les bonus de vitesse s'additionnent et ne dépassent jamais ×2,5 : la fréquence des expéditions reste bornée
	var speed: float = 1.0 + Data.ENGINE_SPEED * upgrade_levels["engines"] \
		+ Data.ROLE_SPEED * Data.role_scale(squad_role_level(slot_i, dest)) + research_bonus("speed_pct") / 100.0
	return maxf(base * Data.MIN_DURATION_RATIO, base / speed)


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
	var role_mult: float = 1.0 + Data.ROLE_GAIN * Data.role_scale(squad_role_level(slot_i, dest))
	for r in Data.DEST[dest].rewards:
		out[r] = Data.DEST[dest].rewards[r] * Data.EXPEDITION_REWARD_MULT * role_mult * upgrade_multiplier(r) * synergy_multiplier() * (1.0 + research_bonus("reward_pct") / 100.0)
	return out


func enemy_level(dest: String) -> int:
	return mini(1 + int(pow(float(dest_wins[dest]) / Data.ENEMY_WINS_REF, Data.ENEMY_WINS_EXP)), Data.ENEMY_LEVEL_MAX)


func make_enemies(dest: String) -> Array:
	var e: Dictionary = Data.DEST[dest].enemy
	var m: float = 1.0 + Data.ENEMY_SCALE * (enemy_level(dest) - 1)
	var out: Array = []
	for i in e.count:
		out.append(Battle.make_unit("%s %d" % [e.name, i + 1], e.hp * m, e.atk * m, e.def * m, e.spd))
	return out


## Le combattant du vaisseau : le Capitaine (vaisseau 1, avec 35 % des stats de son équipage) ou l'équipage seul (vaisseau 2).
func make_allies(slot_i: int) -> Array:
	if slot_i == 0:
		return [captain_unit()]
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
	var xp_gain := 0
	if battle.win:
		afk_wins += times
		dest_wins[dest] += times
		if slot_i == 0:      # le Capitaine, à bord du vaisseau 1, progresse en expédition
			xp_gain = int(round(captain_run_xp(1.0) * Data.EXPEDITION_CAPTAIN_XP_RATIO)) * times
			levels_gained += gain_captain_xp(xp_gain)
	else:
		afk_defeats += times
		dest_wins[dest] = maxi(0, int(dest_wins[dest]) - Data.ENEMY_DEFEAT_LOSS * mini(times, 5))   # les ennemis s'adaptent
		for r in rewards:
			rewards[r] *= Data.LOSS_REWARD
	for r in rewards:
		rewards[r] *= _gain_scale * (credit_mult() if r == "credits" else 1.0) * times
		add_res(r, rewards[r])
	expeditions_done += times
	var head := "Victoire en %d tours" % battle.rounds if battle.win else "Défaite (butin réduit)"
	slot.last = "%s — %s : %s" % [head, Data.DEST[dest].name, Data.fmt_amounts(rewards)]
	if xp_gain > 0:
		slot.last += "  |  Capitaine +%s XP" % Data.fmt(xp_gain)
	if levels_gained > 0:
		slot.last += "  |  %d niveau(x) gagné(s) !" % levels_gained
	slot.log = battle.log
	var ally: Dictionary = battle.allies[0]
	slot.battle = {
		"win": battle.win, "dest": dest, "events": battle.events, "loot": {},
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
		var guard := 0
		while slot.dest != "" and t > 0.0 and guard < 200:
			guard += 1
			if slot.remaining > t:
				slot.remaining -= t
				t = 0.0
			else:
				t -= slot.remaining
				_complete(i)


## Le travail aux postes (AFK) : XP de l'équipage et butin pour le Capitaine.
func crew_xp_per_sec(id: String) -> float:
	var lv: int = heroes[id].level
	var hours: float = Data.AFK_XP_HOURS_BASE + Data.AFK_XP_HOURS_PER_LEVEL * lv + Data.AFK_XP_HOURS_QUAD * lv * lv
	return float(Data.xp_needed(lv)) / (hours * 3600.0)


## Cadence de l'Atelier (objets par heure) : niveau de salle, équipier, ciblage et bonus de butin.
func afk_drops_per_hour() -> float:
	if room_crew_boost("atelier") <= 0.0:
		return 0.0       # sans équipier, l'Atelier ne fabrique rien
	var f := 1.0
	if atelier_slot != "":
		f *= Data.ATELIER_TARGET_FACTOR
	if atelier_focus != "":
		f *= Data.ATELIER_TARGET_FACTOR
	return Data.ATELIER_BASE_PER_HOUR * perk_mult("atelier") * room_level_factor("atelier") * room_crew_boost("atelier") * f \
		* (1.0 + (equipped_bonus("drop_pct") + research_bonus("loot_pct")) / 100.0)


## Avancement du prochain objet de l'Atelier (0 à 1) et temps restant estimé en secondes.
func atelier_progress() -> float:
	return clampf(_afk_loot_clock, 0.0, 1.0)


func atelier_next_in() -> float:
	return (1.0 - atelier_progress()) / maxf(0.001, afk_drops_per_hour()) * 3600.0


## XP des équipiers au travail : les Quartiers l'augmentent.
func crew_xp_mult() -> float:
	return (1.0 + Data.QUARTERS_XP_GAIN * (room_level("quartiers") - 1) * room_crew_boost("quartiers")) * perk_mult("xp")


func _afk_work(seconds: float) -> void:
	var xm := crew_xp_mult()
	for id in stationed_ids():
		gain_xp(id, crew_xp_per_sec(id) * seconds * _gain_scale * xm)
	_afk_loot_clock += seconds * _gain_scale / 3600.0 * afk_drops_per_hour()
	var guard := 0
	while _afk_loot_clock >= 1.0 and guard < 400:
		guard += 1
		_afk_loot_clock -= 1.0
		roll_afk_drop()


## Fait avancer le jeu de `seconds` secondes (production de l'équipage + expéditions).
func tick(seconds: float) -> void:
	var prod := production_per_sec()
	for r in prod:
		add_res(r, prod[r] * seconds * _gain_scale)
	if not _offline_calc:
		_advance_expeditions(seconds)      # les expéditions se jouent en direct : elles se mettent en pause hors ligne
	_afk_work(seconds)
	if not _skip_research:
		_advance_research(seconds)
		_regen_anomaly(seconds)
	changed.emit()


## Simule une absence : durée plafonnée par les Ingénieurs, gains au rendement hors ligne.
func simulate_offline(away: float) -> Dictionary:
	var secs := minf(away, offline_cap_seconds())
	var before := res.duplicate()
	var done_before := expeditions_done
	var crew_before := {}
	for id in stationed_ids():
		crew_before[id] = int(heroes[id].level)
	var crafted_before := crafted_total
	_loot_log = []
	_recycled_credits = 0.0
	_gain_scale = offline_efficiency()
	_offline_calc = true
	_skip_research = true
	research_done_log = []
	tick(secs)
	_skip_research = false
	_offline_calc = false
	_gain_scale = 1.0
	_advance_research(away)       # les recherches vont jusqu'au bout, sans plafond de durée
	_regen_anomaly(away)          # les charges d'anomalie aussi
	var gains := {}
	for id in res:
		gains[id] = res[id] - before[id]
	var best := {}
	for it in _loot_log:
		if best.is_empty() or item_power(it) > item_power(best):
			best = it
	var crew := []
	for id in crew_before:
		var h: Dictionary = heroes[id]
		crew.append({"id": id, "from": crew_before[id], "to": int(h.level), "frac": float(h.xp) / float(Data.xp_needed(h.level))})
	return {
		"seconds": secs, "away": away, "gains": gains, "expeditions": expeditions_done - done_before,
		"efficiency": offline_efficiency(), "loot_kept": _loot_log.size(), "loot_best": best,
		"recycled": _recycled_credits, "research_done": research_done_log.duplicate(),
		"crew": crew, "crafted": crafted_total - crafted_before, "charges_full": anomaly_charges >= float(Data.ANOMALY_CHARGES_MAX) - 0.01,
		"charges": int(anomaly_charges),
	}


## --- Anomalies : le contenu actif du Capitaine ---

func anomaly_enemy_level(n: int) -> int:
	return 1 + int(round(Data.ANOMALY_ENEMY_LEVEL_PER_FAILLE * (n - 1)))


func make_anomaly_enemies(n: int) -> Array:
	var m: float = 1.0 + Data.ENEMY_SCALE * (anomaly_enemy_level(n) - 1)
	var b: Dictionary = Data.ANOMALY_BASE
	return [
		Battle.make_unit("Sentinelle de faille 1", b.hp * m, b.atk * m, b.def * m, b.spd),
		Battle.make_unit("Sentinelle de faille 2", b.hp * m, b.atk * m, b.def * m, b.spd),
		Battle.make_unit("Gardien de faille", b.hp * m * Data.ANOMALY_BOSS_HP, b.atk * m * Data.ANOMALY_BOSS_ATK, b.def * m, b.spd + 1.0),
	]


func captain_unit() -> Dictionary:
	var s := captain_stats(0)
	return Battle.make_unit(captain.name, s.hp, s.atk, s.def, s.spd, s.crit, s.lifesteal)


func anomaly_preview(n: int) -> Dictionary:
	return Battle.simulate([captain_unit()], make_anomaly_enemies(n))


## XP de base d'une victoire du Capitaine : l'ancienne formule xp_needed(p) / (3 + p/2,5) évaluée au niveau de puissance moyen p du
## niveau (une victoire rapporte donc autant qu'avant), multipliée par `diff` (difficulté de l'activité). Les expéditions n'en donnent qu'une fraction.
func captain_run_xp(diff: float) -> float:
	var p_mid: float = float(captain_p()) + float(Data.CAPTAIN_LEVEL_SPAN - 1) / 2.0      # milieu des niveaux de puissance du niveau
	var runs_per_level: float = 3.0 + p_mid / 2.5
	return Data.XP_PER_LEVEL * p_mid / runs_per_level * diff * (1.0 + equipped_bonus("xp_pct") / 100.0)



## Anomalie : modulée de x0,5 à x1 selon la difficulté de la faille par rapport au niveau du Capitaine.
func anomaly_xp(n: int, first: bool) -> int:
	if captain_maxed():
		return 0         # niveau maximum : plus d'XP à gagner
	var diff := clampf(Data.ANOMALY_REF_LEVEL_PER_FAILLE * n / float(captain_p()), 0.5, 1.0)
	return maxi(1, int(round(captain_run_xp(diff))))


func anomaly_credits(n: int) -> float:
	return ceil(Data.ANOMALY_CREDITS * (1.0 + Data.ENEMY_SCALE * (anomaly_enemy_level(n) - 1)) * credit_mult())


## Failles accessibles : de 1 à la plus haute réussie + 1.
func anomaly_unlocked_max() -> int:
	return anomaly_max + 1


## La réserve se recharge d'un point entier à chaque tranche de ANOMALY_REGEN_SECONDS.
func _regen_anomaly(seconds: float) -> void:
	if anomaly_charges >= float(Data.ANOMALY_CHARGES_MAX):
		anomaly_regen_acc = 0.0
		return
	anomaly_regen_acc += seconds
	var n := int(floor(anomaly_regen_acc / Data.ANOMALY_REGEN_SECONDS))
	if n > 0:
		anomaly_charges = minf(float(Data.ANOMALY_CHARGES_MAX), floorf(anomaly_charges) + float(n))
		anomaly_regen_acc -= float(n) * Data.ANOMALY_REGEN_SECONDS
	if anomaly_charges >= float(Data.ANOMALY_CHARGES_MAX):
		anomaly_regen_acc = 0.0


## Entrées en faille possibles avec la réserve actuelle.
func anomaly_runs_available() -> int:
	return int(floor(anomaly_charges / Data.ANOMALY_COST))


## Secondes avant de pouvoir entrer dans une faille (0 si c'est déjà possible).
func anomaly_next_run_in() -> float:
	if anomaly_charges >= Data.ANOMALY_COST:
		return 0.0
	var missing := ceilf(Data.ANOMALY_COST - anomaly_charges)
	return (missing - 1.0) * Data.ANOMALY_REGEN_SECONDS + (Data.ANOMALY_REGEN_SECONDS - anomaly_regen_acc)


## Seconde avant la prochaine charge (0 si pleines).
func anomaly_next_charge_in() -> float:
	if anomaly_charges >= Data.ANOMALY_CHARGES_MAX:
		return 0.0
	return Data.ANOMALY_REGEN_SECONDS - anomaly_regen_acc


## Entre dans la faille n : un combat du Capitaine seul. Une défaite rend la charge.
func enter_anomaly(n: int) -> bool:
	if n < 1 or n > anomaly_unlocked_max() or anomaly_charges < Data.ANOMALY_COST:
		return false
	anomaly_charges -= Data.ANOMALY_COST
	var b := Battle.simulate([captain_unit()], make_anomaly_enemies(n))
	var first: bool = n > anomaly_max
	var xp := 0
	var credits := 0.0
	var levels := 0
	var record := false
	var found := {}
	if b.win:
		xp = anomaly_xp(n, first)
		levels = gain_captain_xp(xp)
		credits = anomaly_credits(n)
		var prev: int = int(anomaly_best.get(n, 0))
		if prev > 0 and b.rounds < prev:
			record = true
			credits = ceil(credits * (1.0 + Data.ANOMALY_RECORD_BONUS))
		if prev == 0 or b.rounds < prev:
			anomaly_best[n] = b.rounds
		add_res("credits", credits)
		if first:
			anomaly_max = n
			for r in Data.ANOMALY_FIRST_RES:
				found[r] = ceil(Data.ANOMALY_FIRST_RES[r] * (1.0 + 0.1 * n))
				add_res(r, found[r])
	else:
		anomaly_charges += Data.ANOMALY_COST
	var kind: String = Data.DEST_ORDER[(n - 1) % Data.DEST_ORDER.size()]
	last_anomaly = {
		"n": n, "win": b.win, "rounds": b.rounds, "xp": xp, "levels": levels, "credits": credits, "record": record,
		"first": first, "found": found, "events": b.events,
		"allies": [{"id": "captain", "name": captain.name, "max_hp": b.allies[0].max_hp, "look": captain.look.duplicate(), "crew": squad_ids(0)}],
		"enemies": b.enemies.map(func(u): return {"name": u.name, "max_hp": u.max_hp, "kind": kind}),
	}
	anomaly_finished.emit()
	changed.emit()
	return true


## --- Sauvegarde ---

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION,
		"res": res, "data_total": data_total, "captain": _captain_for_save(),
		"items": items, "equipped": equipped, "next_item_id": next_item_id, "auto_recycle": auto_recycle,
		"heroes": heroes, "hero_order": hero_order, "recruits": recruits,
		"upgrades": upgrade_levels, "goals": goals_claimed,
		"base": {"levels": room_levels, "crew": room_crew, "slot": atelier_slot, "focus": atelier_focus, "crafted": crafted_total, "log": craft_log,
			"prestige": {"best": prestige_best, "count": prestige_count, "earned": prestige_earned, "points": prestige_points, "perks": prestige_perks}}, "premium": {"crystals": crystals, "unlocks": premium_unlocks}, "research": {"levels": research_levels, "active": research_active, "queue": research_queue, "auto": research_auto},
		"anomaly": {"max": anomaly_max, "best": anomaly_best, "charges": anomaly_charges, "regen": anomaly_regen_acc, "cost_scale": 10}, "slots": _slots_for_save(), "dest_wins": dest_wins,
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
	var cap_level := int(cap.get("level", 1))
	var cap_xp := int(cap.get("xp", 0))
	if not cap.has("span"):         # ancienne sauvegarde : niveaux non compressés
		var k: int = Data.CAPTAIN_LEVEL_SPAN
		var old_level := cap_level
		cap_level = 1 + (old_level - 1) / k
		for p in range(k * (cap_level - 1) + 1, old_level):      # les niveaux de puissance restants deviennent de l'XP
			cap_xp += Data.xp_needed(p)
	captain = {
		"name": String(cap.get("name", "Capitaine")), "level": mini(cap_level, Data.CAPTAIN_MAX_LEVEL), "xp": 0 if cap_level >= Data.CAPTAIN_MAX_LEVEL else cap_xp,
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
			heroes[id] = {"level": int(h.get("level", 1)), "xp": float(h.get("xp", 0.0)), "stars": int(h.get("stars", 0))}
			hero_order.append(id)
	recruits = int(parsed.get("recruits", 0))
	var saved_up: Dictionary = parsed.get("upgrades", {})
	for id in upgrade_levels:
		upgrade_levels[id] = int(saved_up.get(id, 0))
	var saved_rs: Dictionary = parsed.get("research", {})
	var saved_levels: Dictionary = saved_rs.get("levels", {})
	for rid in Data.RESEARCH_ORDER:
		research_levels[rid] = clampi(int(saved_levels.get(rid, 0)), 0, Data.RESEARCH[rid].max)
	research_active = []
	for a in saved_rs.get("active", []):
		if Data.RESEARCH.has(String(a.get("id", ""))):
			research_active.append({"id": String(a.id), "remaining": float(a.get("remaining", 0.0)), "total": float(a.get("total", 1.0)), "boosts": int(a.get("boosts", 0))})
	var saved_pm: Dictionary = parsed.get("base", {}).get("premium", parsed.get("premium", {}))
	crystals = int(saved_pm.get("crystals", 0))
	premium_unlocks = {}
	for k in saved_pm.get("unlocks", {}):
		if Data.PREMIUM_UNLOCKS.has(k) and bool(saved_pm.unlocks[k]):
			premium_unlocks[k] = true
	# anciennes sauvegardes : ceux qui avaient déjà le 3e poste ou la recherche automatique les gardent
	if int(saved_levels.get("labo_annexe", 0)) >= 2:
		premium_unlocks["lab_slot"] = true
	if bool(saved_rs.get("auto", false)):
		premium_unlocks["lab_auto"] = true
	research_auto = bool(saved_rs.get("auto", false)) and premium_unlocked("lab_auto")
	research_queue = []
	for rid in saved_rs.get("queue", []):
		if Data.RESEARCH.has(String(rid)):
			research_queue.append(String(rid))
	var saved_base: Dictionary = parsed.get("base", {})
	if saved_base.is_empty():          # ancienne sauvegarde : les postes deviennent des salles, placement automatique
		for rid in Data.ROOM_ORDER:
			room_levels[rid] = 1 + int(saved_up.get("st_" + Data.ROOMS[rid].affinity, 0))
		atelier_slot = ""
		atelier_focus = ""
		auto_rooms()
	else:
		var sl: Dictionary = saved_base.get("levels", {})
		var sc: Dictionary = saved_base.get("crew", {})
		for rid in Data.ROOM_ORDER:
			room_levels[rid] = clampi(int(sl.get(rid, 1)), 1, 999)
			var hid := String(sc.get(rid, ""))
			room_crew[rid] = hid if heroes.has(hid) else ""
		atelier_slot = String(saved_base.get("slot", ""))
		if not Data.EQUIP.has(atelier_slot):
			atelier_slot = ""
		atelier_focus = String(saved_base.get("focus", ""))
		if not Data.AFFIXES.has(atelier_focus):
			atelier_focus = ""
	crafted_total = int(parsed.get("base", {}).get("crafted", 0))
	craft_log = []
	for e in parsed.get("base", {}).get("log", []):
		if Data.ITEM_RARITY.has(String(e.get("rarity", ""))):
			craft_log.append({"id": int(e.get("id", 0)), "name": String(e.get("name", "")), "rarity": String(e.rarity), "ilvl": int(e.get("ilvl", 1)), "kept": bool(e.get("kept", false))})
	var saved_pr: Dictionary = parsed.get("base", {}).get("prestige", {})
	prestige_count = int(saved_pr.get("count", 0))
	prestige_best = int(saved_pr.get("best", 0))
	prestige_earned = int(saved_pr.get("earned", 0))
	prestige_points = int(saved_pr.get("points", 0))
	prestige_perks = {}
	for k in saved_pr.get("perks", {}):
		if Data.PRESTIGE_PERKS.has(k):
			prestige_perks[k] = clampi(int(saved_pr.perks[k]), 0, Data.PRESTIGE_PERK_MAX)
	var saved_an: Dictionary = parsed.get("anomaly", {})
	anomaly_max = int(saved_an.get("max", 0))
	var saved_charges := float(saved_an.get("charges", Data.ANOMALY_CHARGES_MAX))
	if saved_an.has("charges") and not saved_an.has("cost_scale"):
		saved_charges *= 10.0          # ancienne sauvegarde : 1 charge = 1 entrée, maintenant 10 charges = 1 entrée
	anomaly_charges = clampf(saved_charges, 0.0, float(Data.ANOMALY_CHARGES_MAX))
	anomaly_regen_acc = clampf(float(saved_an.get("regen", 0.0)), 0.0, Data.ANOMALY_REGEN_SECONDS)
	anomaly_best = {}
	for k in saved_an.get("best", {}):
		anomaly_best[int(k)] = int(saved_an.best[k])
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
	elif away > 0:
		_advance_research(float(away))
		_regen_anomaly(float(away))
	return true
