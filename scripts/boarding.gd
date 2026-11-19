class_name Boarding
extends RefCounted
## Abordage (maquette WM) : une fois par jour, un essaim de mites de verre monte à bord de l'Aurore.
## Quatre vagues ; chaque vague assaille quelques salles. Une salle se défend avec les héros à son poste,
## et l'escouade peut renforcer une salle par vague. Une salle perdue s'arrête une heure ; une salle tenue
## rapporte une récompense. Rien n'est détruit.

const WAVES := 4
const WAVE_TIME := 20.0          # secondes par vague
const LOST_SECONDS := 3600

var day := -1                    # jour de l'abordage (une fois par jour)
var wave := 0                    # 0 = pas commencé, 1..WAVES en cours, WAVES + 1 = terminé
var t := 0.0                     # temps écoulé dans la vague
var assaults: Array = []         # [{room, attack, progress}]
var deployed := ""               # salle renforcée par l'escouade pendant cette vague
var held := 0
var lost := 0
var history: Array = []          # [{wave, room, held}]
var rng := RandomNumberGenerator.new()


static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


## L'abordage du jour est-il disponible ? (Aurore débloquée, mission ouverte, pas encore joué aujourd'hui.)
static func available(g: Node) -> bool:
	return g.ship.unlocked and g.mission_open() and int(g.boarding_day) != today() and _targets(g.ship).size() >= 2


## Salles que l'essaim peut viser : celles construites.
static func _targets(ship: ShipState) -> Array:
	return Ship.ORDER.filter(func(r): return ship.room_level(r) > 0)


## Défense d'une salle : les héros à son poste (niveau, plus si le poste est idéal), et l'escouade si elle y est.
func defense(g: Node, room: String) -> float:
	var d := 0.0
	for h in g.ship.posts.get(room, []):
		d += float(g.levels.get(h, 1)) * (1.5 if Ship.is_ideal(String(h), room) else 1.0)
	if deployed == room:
		for h in g.squad_ids():
			d += float(g.levels.get(h, 1)) * 1.2
	return d


func start(g: Node, seed := -1) -> void:
	day = today()
	rng.seed = seed if seed >= 0 else day * 31337 + 7
	wave = 0
	held = 0
	lost = 0
	history = []
	next_wave(g)


func next_wave(g: Node) -> void:
	wave += 1
	t = 0.0
	deployed = ""
	assaults = []
	if wave > WAVES:
		return
	var pool := _targets(g.ship)
	var n := mini(pool.size(), 1 + (wave + 1) / 2)          # 1, 2, 2, 3 salles
	var lv := float(maxi(1, int(g.squad_avg_level())))
	for i in n:
		var r: String = pool.pop_at(rng.randi() % pool.size())
		# l'essaim grossit à chaque vague ; une salle bien gardée tient seule
		var attack := lv * (0.8 + 0.35 * wave) * rng.randf_range(0.85, 1.15)
		assaults.append({"room": r, "attack": attack, "progress": 0.0})


## Avance la vague ; à la fin du temps, chaque salle assaillie est tenue ou perdue. Renvoie vrai à la fin d'une vague.
func step(g: Node, dt: float) -> bool:
	if wave < 1 or wave > WAVES:
		return false
	t += dt
	for a in assaults:
		var d := maxf(1.0, defense(g, String(a.room)))
		a.progress = clampf(t / WAVE_TIME * float(a.attack) / d, 0.0, 1.5)
	if t < WAVE_TIME:
		return false
	resolve(g)
	return true


func resolve(g: Node) -> void:
	for a in assaults:
		var r := String(a.room)
		var ok := float(a.attack) <= defense(g, r)
		if ok:
			held += 1
		else:
			lost += 1
			g.ship.blocked[r] = ShipState.now() + LOST_SECONDS
		history.append({"wave": wave, "room": r, "held": ok})


func done() -> bool:
	return wave > WAVES


## Récompense : par salle tenue, des éclats ; un jeton d'objet toutes les trois salles tenues.
func reward() -> Dictionary:
	return {"shards": held * (6 + WAVES), "item_tokens": held / 3}


func deploy(room: String) -> void:
	for a in assaults:
		if String(a.room) == room:
			deployed = room
