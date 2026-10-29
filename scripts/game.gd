extends Node
## État de la partie (autoload « Game ») : niveaux des héros, crédits, secteur atteint, sauvegarde, gains hors ligne.

const Data = preload("res://scripts/data.gd")

signal changed

const SAVE_VERSION := 1
const AUTOSAVE_EVERY := 10.0

var save_path := "user://save.json"
var credits := 0.0
var levels := {}              # héros -> niveau
var stage := 1                # secteur en cours
var best_stage := 1           # meilleur secteur atteint
var auto_cast := true
var speed := 1.0
var last_seen := 0
var offline_report := {}      # {seconds, credits} calculé au chargement
var _timer := 0.0


func _ready() -> void:
	reset()
	if not load_game():
		pass


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
	levels = {}
	for id in Data.HERO_ORDER:
		levels[id] = 1
	stage = 1
	best_stage = 1
	auto_cast = true
	speed = 1.0
	offline_report = {}


func team() -> Array:
	var out: Array = []
	for id in Data.HERO_ORDER:
		out.append({"id": id, "level": int(levels[id])})
	return out


func add_credits(v: float) -> void:
	credits += v
	changed.emit()


func level_cost(id: String) -> int:
	return Data.level_cost(int(levels[id]))


func can_level(id: String) -> bool:
	return credits >= level_cost(id)


func level_up(id: String) -> bool:
	var c := level_cost(id)
	if credits < c:
		return false
	credits -= c
	levels[id] = int(levels[id]) + 1
	changed.emit()
	return true


func stage_cleared() -> void:
	best_stage = maxi(best_stage, stage + 1)
	stage += 1
	changed.emit()


func retreat() -> void:
	stage = maxi(1, stage - 1)
	changed.emit()


## Crédits par minute hors ligne : équivalent du butin d'un secteur déjà maîtrisé (le précédent le plus loin), au rythme d'un combat par minute.
func offline_rate_per_minute() -> float:
	var s := maxi(1, best_stage - 1)
	var sc := Data.stage_scale(s)
	return (3.0 * sc * 3.4 * Data.WAVES_PER_STAGE + 25.0 * sc) * 0.6


func compute_offline(away_seconds: float) -> Dictionary:
	var capped := minf(away_seconds, Data.OFFLINE_CAP_HOURS * 3600.0)
	var gain := offline_rate_per_minute() * capped / 60.0
	return {"seconds": capped, "credits": gain}


func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	f.store_string(JSON.stringify({
		"version": SAVE_VERSION, "credits": credits, "levels": levels, "stage": stage, "best": best_stage,
		"auto": auto_cast, "speed": speed, "last_seen": last_seen,
	}))


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != SAVE_VERSION:
		return false
	credits = float(parsed.get("credits", 0.0))
	var saved: Dictionary = parsed.get("levels", {})
	for id in Data.HERO_ORDER:
		levels[id] = maxi(1, int(saved.get(id, 1)))
	best_stage = maxi(1, int(parsed.get("best", 1)))
	stage = clampi(int(parsed.get("stage", 1)), 1, best_stage)
	auto_cast = bool(parsed.get("auto", true))
	speed = clampf(float(parsed.get("speed", 1.0)), 1.0, 3.0)
	last_seen = int(parsed.get("last_seen", 0))
	var away := maxi(0, int(Time.get_unix_time_from_system()) - last_seen)
	if last_seen > 0 and away > 60:
		offline_report = compute_offline(float(away))
		credits += float(offline_report.credits)
	return true
