extends Node
## État de la partie (autoload « Game ») : niveaux des héros, crédits, éclats, étage atteint, étoiles, coffres, sauvegarde, gains hors ligne.

const Data = preload("res://scripts/data.gd")

signal changed

const SAVE_VERSION := 3
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
	for id in Data.HERO_ORDER:
		levels[id] = 1
	stage = 1
	best_stage = 1
	stars = {}
	pity = {"leg": 0, "ult": 0}
	perseverance = 0
	boosts = []
	evolved = {}
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
	for id in Data.HERO_ORDER:
		out.append({"id": id, "level": int(levels[id]), "evo": tier(id), "bonus": 1.0 + Data.PERSEVERANCE_STEP * perseverance})
	return out


func power() -> float:
	return Data.team_power(levels)


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
	for id in Data.HERO_ORDER:
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
func stage_cleared(star_count: int, combo: int = 1) -> Dictionary:
	stars[stage] = maxi(int(stars.get(stage, 0)), star_count)
	perseverance = 0
	var loot := Data.combo_loot(combo)
	var chest := open_chest(Data.roll_chest(stage, star_count, rng, pity), stage, loot)
	if Data.is_boss_stage(stage):
		boosts = []
	if stage >= best_stage:
		best_stage = stage + 1
	changed.emit()
	return chest


func open_chest(rarity: String, at_stage: int, loot_bonus: float = 0.0) -> Dictionary:
	var rw := Data.chest_rewards(at_stage, rarity)
	var cr: float = round(rw.credits * (1.0 + loot_bonus))
	credits += cr
	shards += int(rw.shards)
	changed.emit()
	return {"rarity": rarity, "credits": cr, "shards": rw.shards, "combo_bonus": loot_bonus}


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
		"perseverance": perseverance, "boosts": boosts, "evolved": evolved,
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
	for id in Data.HERO_ORDER:
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
	var ev: Dictionary = parsed.get("evolved", {})
	for id in Data.HERO_ORDER:
		evolved[id] = clampi(int(ev.get(id, 0)), 0, 2)
	var away := maxi(0, int(Time.get_unix_time_from_system()) - last_seen)
	if last_seen > 0 and away > 60:
		offline_report = compute_offline(float(away))
		credits += float(offline_report.credits)
	return true
