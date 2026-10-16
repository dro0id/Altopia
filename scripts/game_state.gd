extends Node
## Cerveau du jeu : ressources, équipage, gains hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed

const SAVE_PATH := "user://save.json"
const OFFLINE_CAP_SECONDS := 8 * 3600
const AUTOSAVE_EVERY := 10.0
const COST_GROWTH := 1.15
const SYNERGY_PAIR := 0.10   # +10 % par paire de rôles présents
const SYNERGY_FULL := 0.25   # +25 % si l'équipage est complet

## Rôles de l'équipage. base_rate = crédits/s par niveau, data_rate = données/s par niveau.
const CREW := {
	"pilot": {"name": "Pilote", "base_cost": 10.0, "base_rate": 1.0, "data_rate": 0.0},
	"engineer": {"name": "Ingénieur", "base_cost": 50.0, "base_rate": 4.0, "data_rate": 0.0},
	"scientist": {"name": "Scientifique", "base_cost": 120.0, "base_rate": 1.0, "data_rate": 0.5},
}
const PAIRS := [["pilot", "engineer"], ["engineer", "scientist"], ["scientist", "pilot"]]

var credits := 0.0
var data := 0.0
var levels := {"pilot": 0, "engineer": 0, "scientist": 0}
var last_seen := 0

var _autosave_timer := 0.0


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	_tick(delta)
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_EVERY:
		_autosave_timer = 0.0
		save_game()


func _notification(what: int) -> void:
	# Sauvegarde quand l'appli est fermée ou mise en arrière-plan (Android).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func _tick(seconds: float) -> void:
	credits += credits_per_sec() * seconds
	data += data_per_sec() * seconds
	changed.emit()


func synergy_multiplier() -> float:
	var mult := 1.0
	for pair in PAIRS:
		if levels[pair[0]] > 0 and levels[pair[1]] > 0:
			mult += SYNERGY_PAIR
	if is_crew_complete():
		mult += SYNERGY_FULL
	return mult


func is_crew_complete() -> bool:
	for id in CREW:
		if levels[id] <= 0:
			return false
	return true


func credits_per_sec() -> float:
	var total := 0.0
	for id in CREW:
		total += CREW[id].base_rate * levels[id]
	return total * synergy_multiplier()


func data_per_sec() -> float:
	var total := 0.0
	for id in CREW:
		total += CREW[id].data_rate * levels[id]
	return total * synergy_multiplier()


func cost_of(id: String) -> float:
	return ceil(CREW[id].base_cost * pow(COST_GROWTH, levels[id]))


func can_buy(id: String) -> bool:
	return credits >= cost_of(id)


func buy(id: String) -> void:
	if not can_buy(id):
		return
	credits -= cost_of(id)
	levels[id] += 1
	changed.emit()


## --- Sauvegarde ---

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	f.store_string(JSON.stringify({
		"credits": credits, "data": data, "levels": levels, "last_seen": last_seen,
	}))


## Charge la sauvegarde et applique les gains hors-ligne.
## Retourne un dictionnaire {seconds, credits, data} (vide si rien à signaler).
var last_offline_report := {}

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		last_seen = int(Time.get_unix_time_from_system())
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	credits = float(parsed.get("credits", 0.0))
	data = float(parsed.get("data", 0.0))
	var saved_levels: Dictionary = parsed.get("levels", {})
	for id in levels:
		levels[id] = int(saved_levels.get(id, 0))
	last_seen = int(parsed.get("last_seen", 0))

	var now := int(Time.get_unix_time_from_system())
	var away := clampi(now - last_seen, 0, OFFLINE_CAP_SECONDS)
	if away > 60:
		var before_c := credits
		var before_d := data
		_tick(away)
		last_offline_report = {
			"seconds": away,
			"credits": credits - before_c,
			"data": data - before_d,
		}
