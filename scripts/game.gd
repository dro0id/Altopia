extends Node
## État de la partie (autoload « Game ») : niveaux des héros, crédits, éclats, étage atteint, étoiles, coffres, sauvegarde, gains hors ligne.

const Data = preload("res://scripts/data.gd")

signal changed

const SAVE_VERSION := 4
const AUTOSAVE_EVERY := 10.0

var save_path := "user://save.json"
var credits := 0.0
var shards := 0                 # éclats de verre (paliers d'évolution, plus tard)
var levels := {}                # héros -> niveau
var stage := 1                  # étage en cours
var best_stage := 1             # étage le plus haut débloqué
var stars := {}                 # étage -> meilleures étoiles (1 à 3)
var pity := {"leg": 0, "ult": 0}
var perseverance := 0          # défaites d'affilée : +5 % de statistiques chacune, remis à zéro à la victoire
var boosts: Array = []         # renforts actifs jusqu'au prochain boss
var evolved := {}              # héros -> palier d'évolution (0 à 2)
var pending_chest := {}        # coffre gagné mais pas encore ouvert à l'écran
var owned := {}                # héros possédés (id -> true)
var hero_stars := {}           # héros -> étoiles (1 à 5)
var fragments := {}            # héros -> fragments pour la prochaine étoile
var squad: Array = []          # les 5 héros au combat, un par emplacement (0 = première ligne au centre)
var tokens := 0                # jetons de recrutement (gagnés en jeu)
var crystals := 0              # cristaux d'Altopia (monnaie de la boutique)
var recruit_pity := {"rare": 0, "epic": 0}
var pulls := 0                 # nombre total de tirages
var auto_cast := true
var speed := 1.0
var sfx_on := true
var music_on := true
var tutorial_done := false
var intro_seen := false
var last_seen := 0
var last_free_chest := 0
var offline_report := {}        # {seconds, credits} calculé au chargement
var rng := RandomNumberGenerator.new()
var _timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	reset()
	load_game()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= AUTOSAVE_EVERY:
		_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func reset() -> void:
	credits = 0.0
	shards = 0
	levels = {}
	for id in Data.ALL_HEROES:
		levels[id] = 1
		hero_stars[id] = 1
		fragments[id] = 0
	owned = {}
	for id in Data.STARTER:
		owned[id] = true
	squad = Data.STARTER.duplicate()
	tokens = 6                  # deux tirages offerts pour découvrir le recrutement
	crystals = 0
	recruit_pity = {"rare": 0, "epic": 0}
	pulls = 0
	stage = 1
	best_stage = 1
	stars = {}
	pity = {"leg": 0, "ult": 0}
	perseverance = 0
	boosts = []
	evolved = {}
	pending_chest = {}
	auto_cast = true
	speed = 1.0
	sfx_on = true
	music_on = true
	tutorial_done = false
	intro_seen = false
	last_free_chest = 0
	offline_report = {}


func team() -> Array:
	var out: Array = []
	var mods: Dictionary = synergy().mods
	for id in squad:
		if id == "" or id == null:
			continue
		out.append({"id": id, "level": int(levels[id]), "evo": tier(id), "bonus": 1.0 + Data.PERSEVERANCE_STEP * perseverance, "stars": int(hero_stars[id]), "mods": mods})
	return out


## Héros réellement présents dans l'escouade (sans emplacement vide).
func squad_ids() -> Array:
	var out: Array = []
	for id in squad:
		if id != "" and id != null:
			out.append(id)
	return out


func synergy() -> Dictionary:
	return Data.synergies(squad_ids())


func squad_avg_level() -> float:
	var ids := squad_ids()
	var t := 0.0
	for id in ids:
		t += float(levels[id])
	return t / maxf(1.0, float(ids.size()))


func power() -> float:
	return Data.team_power(levels, squad_ids())


func is_owned(id: String) -> bool:
	return owned.has(id)


## Complète les emplacements vides avec des héros possédés qui ne sont pas encore dans l'escouade.
func _normalize_squad() -> void:
	for i in Data.SQUAD_SIZE:
		if squad[i] == "":
			for id in Data.ALL_HEROES:
				if owned.has(id) and not squad.has(id):
					squad[i] = id
					break


## Met un héros possédé dans un emplacement ; s'il est déjà dans l'escouade, les deux emplacements s'échangent.
func set_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= Data.SQUAD_SIZE or not is_owned(id):
		return false
	var other := squad.find(id)
	if other >= 0 and other != slot:
		squad[other] = squad[slot]
	squad[slot] = id
	changed.emit()
	return true


func star_cost(id: String) -> int:
	return Data.star_cost(int(hero_stars[id]))


func can_star_up(id: String) -> bool:
	return is_owned(id) and int(hero_stars[id]) < Data.MAX_STARS and int(fragments[id]) >= star_cost(id)


func star_up(id: String) -> bool:
	if not can_star_up(id):
		return false
	fragments[id] = int(fragments[id]) - star_cost(id)
	hero_stars[id] = int(hero_stars[id]) + 1
	changed.emit()
	return true


## Recrutement : `count` tirages (1 ou 10). Renvoie la liste des résultats {id, rarity, new, fragments}, vide si pas assez de jetons.
func recruit(count: int) -> Array:
	var cost: int = Data.RECRUIT_COST_10 if count == 10 else Data.RECRUIT_COST * count
	if tokens < cost:
		return []
	tokens -= cost
	var out: Array = []
	for i in count:
		var rarity := Data.roll_recruit(rng, recruit_pity)
		var pool := Data.heroes_of_rarity(rarity)
		var id: String = pool[rng.randi() % pool.size()]
		var is_new := not is_owned(id)
		var frag := 0
		if is_new:
			owned[id] = true
		else:
			frag = int(Data.DUP_FRAGMENTS[rarity])
			fragments[id] = int(fragments[id]) + frag
		pulls += 1
		out.append({"id": id, "rarity": rarity, "new": is_new, "fragments": frag})
	changed.emit()
	return out


## Achat en boutique avec des cristaux. Renvoie un texte de résultat, vide si l'achat est impossible.
func buy(item_id: String) -> String:
	for it in Data.SHOP_ITEMS:
		if it.id != item_id:
			continue
		if crystals < int(it.cost):
			return ""
		if it.has("free_chest") and free_chest_remaining() <= 0.0:
			return ""
		crystals -= int(it.cost)
		if it.has("tokens"):
			tokens += int(it.tokens)
			return "+ %d jetons de recrutement" % int(it.tokens)
		if it.has("chest"):
			var c := open_chest(String(it.chest), maxi(1, best_stage - 1))
			return "Coffre %s : + %s crédits, + %d éclats" % [String(Data.RARITY_NAMES[c.rarity]).to_lower(), Data.fmt(c.credits), int(c.shards)]
		if it.has("free_chest"):
			last_free_chest = 0
			return "Le coffre gratuit est prêt"
	return ""


func add_credits(v: float) -> void:
	credits += v
	changed.emit()


func level_cost(id: String) -> int:
	return Data.level_cost(int(levels[id]))


func tier(id: String) -> int:
	return int(evolved.get(id, 0))


func at_cap(id: String) -> bool:
	return int(levels[id]) >= Data.level_cap(tier(id))


func can_level(id: String) -> bool:
	return not at_cap(id) and credits >= level_cost(id)


## Un héros au niveau maximal de son palier doit évoluer pour continuer.
func can_evolve(id: String) -> bool:
	return at_cap(id) and tier(id) < Data.EVO_LEVELS.size()


func evolve_cost(id: String) -> Dictionary:
	return Data.evolve_cost(int(levels[id]), tier(id))


func can_afford_evolve(id: String) -> bool:
	var c := evolve_cost(id)
	return can_evolve(id) and credits >= c.credits and shards >= c.shards


func evolve(id: String) -> bool:
	if not can_afford_evolve(id):
		return false
	var c := evolve_cost(id)
	credits -= c.credits
	shards -= int(c.shards)
	evolved[id] = tier(id) + 1
	changed.emit()
	return true


func level_up(id: String) -> bool:
	var c := level_cost(id)
	if at_cap(id) or credits < c:
		return false
	credits -= c
	levels[id] = int(levels[id]) + 1
	changed.emit()
	return true


## Hero dont l'amélioration apporte le plus de puissance par crédit dépensé (étiquette « Meilleur achat »).
func best_buy() -> String:
	var best := ""
	var best_ratio := -1.0
	for id in squad_ids():
		if at_cap(id):
			continue
		var h: Dictionary = Data.HEROES[id]
		var lv := int(levels[id])
		var gain: float = (h.hp * 0.25 + h.atk * 6.0 + h.def * 3.0) * (Data.hero_mult(lv + 1) - Data.hero_mult(lv))
		var ratio: float = gain / float(Data.level_cost(lv))
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	return best


# ---------------------------------------------------------------- étages

func is_frontier() -> bool:
	return stage >= best_stage


## Étage vaincu : enregistre les étoiles, débloque le suivant. Renvoie le coffre obtenu {rarity, credits, shards}.
## Avec `defer`, le butin du coffre n'est versé qu'à l'ouverture (voir claim_pending) : l'écran de résultat l'affiche après l'animation.
func stage_cleared(star_count: int, combo: int = 1, defer: bool = false) -> Dictionary:
	stars[stage] = maxi(int(stars.get(stage, 0)), star_count)
	perseverance = 0
	var loot := Data.combo_loot(combo)
	claim_pending()    # un coffre oublié est toujours versé avant le suivant
	var chest := open_chest(Data.roll_chest(stage, star_count, rng, pity), stage, loot, defer)
	if Data.boss_type(stage) == "big":
		chest["crystals"] = int(Data.BIG_BOSS_CRYSTALS[clampi(star_count, 1, 3)])
		if defer:
			pending_chest = chest
		else:
			crystals += int(chest.crystals)
	if Data.is_boss_stage(stage):
		boosts = []
	if stage >= best_stage:
		best_stage = stage + 1
	changed.emit()
	return chest


func open_chest(rarity: String, at_stage: int, loot_bonus: float = 0.0, defer: bool = false) -> Dictionary:
	var rw := Data.chest_rewards(at_stage, rarity)
	var cr: float = round(rw.credits * (1.0 + loot_bonus))
	var chest := {"rarity": rarity, "credits": cr, "shards": rw.shards, "combo_bonus": loot_bonus, "tokens": int(Data.CHEST_TOKENS[rarity]), "crystals": 0}
	if defer:
		pending_chest = chest
	else:
		_pay(chest)
	changed.emit()
	return chest


func _pay(chest: Dictionary) -> void:
	credits += float(chest.credits)
	shards += int(chest.shards)
	tokens += int(chest.get("tokens", 0))
	crystals += int(chest.get("crystals", 0))


## Verse le coffre en attente (à l'ouverture, ou à la fermeture de l'écran si on le quitte avant).
func claim_pending() -> void:
	if pending_chest.is_empty():
		return
	_pay(pending_chest)
	pending_chest = {}
	changed.emit()


## Défaite : un cran de persévérance en plus.
func defeated() -> void:
	perseverance = mini(Data.PERSEVERANCE_MAX, perseverance + 1)
	changed.emit()


func perseverance_pct() -> int:
	return int(round(perseverance * Data.PERSEVERANCE_STEP * 100.0))


## Trois renforts distincts tirés au hasard.
func offer_boosts() -> Array:
	var pool: Array = Data.BOOST_IDS.duplicate()
	var out: Array = []
	for i in 3:
		var k := rng.randi() % pool.size()
		out.append(pool[k])
		pool.remove_at(k)
	return out


func add_boost(id: String) -> void:
	boosts.append(id)
	changed.emit()


func go_to(n: int) -> void:
	stage = clampi(n, 1, best_stage)
	changed.emit()


func advance() -> void:
	go_to(stage + 1)


## Défaite : on redescend d'un étage.
func retreat() -> void:
	stage = maxi(1, stage - 1)
	changed.emit()


# ---------------------------------------------------------------- hors ligne et coffre gratuit

## Crédits par minute hors ligne : équivalent du butin d'un étage déjà maîtrisé, à raison d'un combat par minute.
func offline_rate_per_minute() -> float:
	var s := maxi(1, best_stage - 1)
	var sc := Data.stage_scale(s)
	return (3.0 * sc * 3.4 * Data.WAVES_PER_STAGE + 25.0 * sc) * 0.6


func compute_offline(away_seconds: float) -> Dictionary:
	var capped := minf(away_seconds, Data.OFFLINE_CAP_HOURS * 3600.0)
	var gain := offline_rate_per_minute() * capped / 60.0
	return {"seconds": capped, "credits": gain}


func free_chest_remaining() -> float:
	var now := int(Time.get_unix_time_from_system())
	return maxf(0.0, last_free_chest + Data.FREE_CHEST_HOURS * 3600.0 - now)


func free_chest_ready() -> bool:
	return free_chest_remaining() <= 0.0


func claim_free_chest() -> Dictionary:
	if not free_chest_ready():
		return {}
	last_free_chest = int(Time.get_unix_time_from_system())
	var rarity := "normal" if rng.randf() < 0.3 else "commun"
	return open_chest(rarity, maxi(1, best_stage - 1))


# ---------------------------------------------------------------- sauvegarde

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	var star_save := {}
	for k in stars:
		star_save[str(k)] = stars[k]
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION, "credits": credits, "shards": shards, "levels": levels, "stage": stage, "best": best_stage,
		"stars": star_save, "pity": pity, "auto": auto_cast, "speed": speed, "sfx": sfx_on, "music": music_on,
		"tutorial": tutorial_done, "intro": intro_seen, "last_seen": last_seen, "free_chest": last_free_chest,
		"perseverance": perseverance, "boosts": boosts, "evolved": evolved, "pending": pending_chest,
		"owned": owned.keys(), "hero_stars": hero_stars, "fragments": fragments, "squad": squad, "tokens": tokens, "crystals": crystals,
		"recruit_pity": recruit_pity, "pulls": pulls,
	}))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var ver := int(parsed.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		return false
	credits = float(parsed.get("credits", 0.0))
	shards = int(parsed.get("shards", 0))
	var saved: Dictionary = parsed.get("levels", {})
	for id in Data.ALL_HEROES:
		levels[id] = maxi(1, int(saved.get(id, 1)))
	best_stage = maxi(1, int(parsed.get("best", 1)))
	stage = clampi(int(parsed.get("stage", 1)), 1, best_stage)
	stars = {}
	var star_save: Dictionary = parsed.get("stars", {})
	for k in star_save:
		stars[int(k)] = clampi(int(star_save[k]), 1, 3)
	var pt: Dictionary = parsed.get("pity", {})
	pity = {"leg": int(pt.get("leg", 0)), "ult": int(pt.get("ult", 0))}
	auto_cast = bool(parsed.get("auto", true))
	speed = clampf(float(parsed.get("speed", 1.0)), 1.0, 3.0)
	sfx_on = bool(parsed.get("sfx", true))
	music_on = bool(parsed.get("music", true))
	tutorial_done = bool(parsed.get("tutorial", ver == 1))
	intro_seen = bool(parsed.get("intro", ver == 1))
	last_seen = int(parsed.get("last_seen", 0))
	last_free_chest = int(parsed.get("free_chest", 0))
	perseverance = clampi(int(parsed.get("perseverance", 0)), 0, Data.PERSEVERANCE_MAX)
	boosts = []
	for b in parsed.get("boosts", []):
		if Data.BOOSTS.has(String(b)):
			boosts.append(String(b))
	evolved = {}
	pending_chest = {}
	var pc: Dictionary = parsed.get("pending", {})
	var pending_load := pc
	var ev: Dictionary = parsed.get("evolved", {})
	for id in Data.ALL_HEROES:
		evolved[id] = clampi(int(ev.get(id, 0)), 0, 2)
	# collection : les anciennes sauvegardes (avant la branche 3) n'ont que les cinq héros de départ
	if parsed.has("owned"):
		owned = {}
		for id in parsed.owned:
			if Data.HEROES.has(String(id)):
				owned[String(id)] = true
		var hs: Dictionary = parsed.get("hero_stars", {})
		var fr: Dictionary = parsed.get("fragments", {})
		for id in Data.ALL_HEROES:
			hero_stars[id] = clampi(int(hs.get(id, 1)), 1, Data.MAX_STARS)
			fragments[id] = maxi(0, int(fr.get(id, 0)))
		squad = []
		for id in parsed.get("squad", []):
			squad.append(String(id) if owned.has(String(id)) else "")
		while squad.size() < Data.SQUAD_SIZE:
			squad.append("")
		squad = squad.slice(0, Data.SQUAD_SIZE)
		var seen := {}
		for i in squad.size():
			if squad[i] != "" and seen.has(squad[i]):
				squad[i] = ""
			seen[squad[i]] = true
		tokens = maxi(0, int(parsed.get("tokens", 0)))
		crystals = maxi(0, int(parsed.get("crystals", 0)))
		var rp: Dictionary = parsed.get("recruit_pity", {})
		recruit_pity = {"rare": int(rp.get("rare", 0)), "epic": int(rp.get("epic", 0))}
		pulls = maxi(0, int(parsed.get("pulls", 0)))
	else:
		tokens = 6                       # cadeau de bienvenue pour les parties existantes
	if squad_ids().is_empty():
		squad = Data.STARTER.duplicate()
		for id in squad:
			owned[id] = true
	_normalize_squad()
	if pending_load.has("credits"):
		_pay(pending_load)                    # un coffre non ouvert avant la fermeture est versé au rechargement
	var away := maxi(0, int(Time.get_unix_time_from_system()) - last_seen)
	if last_seen > 0 and away > 60:
		offline_report = compute_offline(float(away))
		credits += float(offline_report.credits)
	return true
