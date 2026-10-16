extends Node
## Cerveau du jeu : ressources, équipage, expéditions, améliorations, hors-ligne, sauvegarde.
## Enregistré en autoload sous le nom "GameState" (voir project.godot).

signal changed

const Data = preload("res://scripts/game_data.gd")

const SAVE_PATH := "user://save.json"
const AUTOSAVE_EVERY := 10.0

var res := {"credits": 0.0, "data": 0.0, "minerals": 0.0, "energy": 0.0}
var data_total := 0.0          # données cumulées (débloquent les destinations)
var crew_levels := {"pilot": 0, "engineer": 0, "scientist": 0}
var upgrade_levels := {"laser": 0, "solar": 0, "scanner": 0, "engines": 0, "docks": 0}
## Un emplacement de vaisseau : dest "" = libre.
var slots: Array = []
var last_seen := 0
var expeditions_done := 0
var last_offline_report := {}

var _autosave_timer := 0.0


func _ready() -> void:
	reset()
	load_game()


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
	for id in crew_levels:
		crew_levels[id] = 0
	for id in upgrade_levels:
		upgrade_levels[id] = 0
	slots = []
	for i in Data.MAX_SLOTS:
		slots.append(_new_slot())
	expeditions_done = 0
	last_offline_report = {}


func _new_slot() -> Dictionary:
	return {"dest": "", "remaining": 0.0, "auto": true, "last": ""}


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


## --- Équipage ---

func crew_cost(id: String) -> float:
	return ceil(Data.CREW[id].base_cost * pow(Data.CREW_COST_GROWTH, crew_levels[id]))


func buy_crew(id: String) -> bool:
	var cost: float = crew_cost(id)
	if res["credits"] < cost:
		return false
	res["credits"] -= cost
	crew_levels[id] += 1
	changed.emit()
	return true


func is_crew_complete() -> bool:
	for id in Data.CREW_ORDER:
		if crew_levels[id] <= 0:
			return false
	return true


func synergy_multiplier() -> float:
	var mult: float = 1.0
	for pair in Data.PAIRS:
		if crew_levels[pair[0]] > 0 and crew_levels[pair[1]] > 0:
			mult += Data.SYNERGY_PAIR
	if is_crew_complete():
		mult += Data.SYNERGY_FULL
	return mult


func credits_per_sec() -> float:
	var total: float = 0.0
	for id in Data.CREW_ORDER:
		total += Data.CREW[id].rate * crew_levels[id]
	return total * synergy_multiplier()


func data_per_sec() -> float:
	var total: float = 0.0
	for id in Data.CREW_ORDER:
		total += Data.CREW[id].data_rate * crew_levels[id]
	return total * synergy_multiplier()


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


func role_level(dest: String) -> int:
	return crew_levels[Data.DEST[dest].role]


## Retourne "" si le lancement est possible, sinon la raison du blocage.
func launch_block_reason(dest: String) -> String:
	if not is_unlocked(dest):
		return "Débloqué à %s données" % Data.fmt(Data.DEST[dest].unlock_data)
	if role_level(dest) <= 0:
		return "Recrutez : %s" % Data.CREW[Data.DEST[dest].role].name
	return ""


func duration_of(dest: String) -> float:
	var base: float = Data.DEST[dest].duration
	var speed: float = (1.0 + Data.ENGINE_SPEED * upgrade_levels["engines"]) \
		* (1.0 + Data.ROLE_SPEED * role_level(dest))
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


func rewards_of(dest: String) -> Dictionary:
	var out := {}
	var role_mult: float = 1.0 + Data.ROLE_GAIN * role_level(dest)
	for r in Data.DEST[dest].rewards:
		out[r] = Data.DEST[dest].rewards[r] * role_mult * upgrade_multiplier(r) * synergy_multiplier()
	return out


func launch(slot_i: int, dest: String) -> bool:
	if slot_i < 0 or slot_i >= slot_count():
		return false
	var slot: Dictionary = slots[slot_i]
	if slot.dest != "" or launch_block_reason(dest) != "":
		return false
	slot.dest = dest
	slot.remaining = duration_of(dest)
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


func _complete(slot: Dictionary) -> void:
	var dest: String = slot.dest
	var rewards: Dictionary = rewards_of(dest)
	for r in rewards:
		add_res(r, rewards[r])
	expeditions_done += 1
	slot.last = "%s : %s" % [Data.DEST[dest].name, Data.fmt_amounts(rewards)]
	if slot.auto and launch_block_reason(dest) == "":
		slot.remaining = duration_of(dest)
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
				_complete(slot)


## Fait avancer le jeu de `seconds` secondes (revenu passif + expéditions).
func tick(seconds: float) -> void:
	add_res("credits", credits_per_sec() * seconds)
	add_res("data", data_per_sec() * seconds)
	_advance_expeditions(seconds)
	changed.emit()


## --- Sauvegarde ---

func save_game() -> void:
	last_seen = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible")
		return
	f.store_string(JSON.stringify({
		"version": 2,
		"res": res, "data_total": data_total,
		"crew": crew_levels, "upgrades": upgrade_levels,
		"slots": slots, "done": expeditions_done, "last_seen": last_seen,
	}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		last_seen = int(Time.get_unix_time_from_system())
		res["credits"] = Data.START_CREDITS   # de quoi recruter le premier Pilote
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# Compatibilité avec la sauvegarde du prototype (credits/data/levels).
	var saved_res: Dictionary = parsed.get("res", {})
	if saved_res.is_empty():
		saved_res = {"credits": parsed.get("credits", 0.0), "data": parsed.get("data", 0.0)}
	for id in res:
		res[id] = float(saved_res.get(id, 0.0))
	data_total = float(parsed.get("data_total", res["data"]))
	var saved_crew: Dictionary = parsed.get("crew", parsed.get("levels", {}))
	for id in crew_levels:
		crew_levels[id] = int(saved_crew.get(id, 0))
	var saved_up: Dictionary = parsed.get("upgrades", {})
	for id in upgrade_levels:
		upgrade_levels[id] = int(saved_up.get(id, 0))
	var saved_slots: Array = parsed.get("slots", [])
	for i in mini(saved_slots.size(), slots.size()):
		var s: Dictionary = saved_slots[i]
		slots[i] = {
			"dest": String(s.get("dest", "")) if Data.DEST.has(String(s.get("dest", ""))) else "",
			"remaining": float(s.get("remaining", 0.0)),
			"auto": bool(s.get("auto", true)),
			"last": String(s.get("last", "")),
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
