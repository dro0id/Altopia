extends RefCounted
## Données statiques du jeu (rôles, destinations, améliorations) et petits utilitaires.

const RES_ORDER := ["credits", "data", "minerals", "energy"]
const RES_NAMES := {
	"credits": "Crédits", "data": "Données", "minerals": "Minerais", "energy": "Énergie",
}

const CREW_ORDER := ["pilot", "engineer", "scientist"]
## rate = crédits/s par niveau ; data_rate = données/s par niveau.
const CREW := {
	"pilot": {"name": "Pilote", "desc": "Explore vite les astéroïdes", "base_cost": 10.0, "rate": 1.0, "data_rate": 0.0},
	"engineer": {"name": "Ingénieur", "desc": "Maîtrise les étoiles", "base_cost": 50.0, "rate": 4.0, "data_rate": 0.0},
	"scientist": {"name": "Scientifique", "desc": "Étudie les planètes", "base_cost": 120.0, "rate": 1.0, "data_rate": 0.5},
}

const DEST_ORDER := ["asteroids", "star", "planet"]
const DEST := {
	"asteroids": {
		"name": "Champ d'astéroïdes", "role": "pilot", "duration": 20.0, "unlock_data": 0.0,
		"rewards": {"minerals": 5.0, "credits": 10.0, "data": 1.0},
	},
	"star": {
		"name": "Étoile naine", "role": "engineer", "duration": 45.0, "unlock_data": 25.0,
		"rewards": {"energy": 8.0, "credits": 20.0, "data": 3.0},
	},
	"planet": {
		"name": "Planète inconnue", "role": "scientist", "duration": 90.0, "unlock_data": 100.0,
		"rewards": {"data": 12.0, "credits": 60.0, "minerals": 3.0, "energy": 2.0},
	},
}

const UPGRADE_ORDER := ["laser", "solar", "scanner", "engines", "docks"]
## cost = base * growth^niveau (arrondi au supérieur). bonus = effet par niveau.
const UPGRADES := {
	"laser": {"name": "Laser de minage", "desc": "+25 % minerais par niveau", "max": 20, "growth": 1.6,
		"base": {"credits": 100.0, "minerals": 10.0}},
	"solar": {"name": "Collecteur solaire", "desc": "+25 % énergie par niveau", "max": 20, "growth": 1.6,
		"base": {"credits": 150.0, "energy": 10.0}},
	"scanner": {"name": "Scanner", "desc": "+25 % données par niveau", "max": 20, "growth": 1.6,
		"base": {"credits": 200.0, "minerals": 15.0}},
	"engines": {"name": "Moteurs", "desc": "-10 % de durée par niveau", "max": 20, "growth": 1.7,
		"base": {"credits": 120.0, "minerals": 8.0, "energy": 5.0}},
	"docks": {"name": "Baie d'amarrage", "desc": "Débloque un 2e vaisseau", "max": 1, "growth": 1.0,
		"base": {"credits": 500.0, "minerals": 30.0, "energy": 20.0}},
}

const CREW_COST_GROWTH := 1.15
const SYNERGY_PAIR := 0.10
const SYNERGY_FULL := 0.25
const PAIRS := [["pilot", "engineer"], ["engineer", "scientist"], ["scientist", "pilot"]]
const ROLE_GAIN := 0.15          # +15 % de gains par niveau du rôle requis
const ROLE_SPEED := 0.03         # -3 % de durée par niveau du rôle requis
const UPGRADE_GAIN := 0.25
const ENGINE_SPEED := 0.10
const START_CREDITS := 10.0
const MAX_SLOTS := 2
const OFFLINE_CAP_SECONDS := 8 * 3600


static func fmt(n: float) -> String:
	if n >= 1.0e9:
		return "%.2fB" % (n / 1.0e9)
	if n >= 1.0e6:
		return "%.2fM" % (n / 1.0e6)
	if n >= 1.0e4:
		return "%.1fK" % (n / 1.0e3)
	if n >= 100.0 or absf(n - roundf(n)) < 0.05:
		return "%d" % int(roundf(n))
	return "%.1f" % n


static func fmt_time(seconds: float) -> String:
	var s := int(ceil(seconds))
	if s >= 3600:
		return "%dh%02d" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%dm%02d" % [s / 60, s % 60]
	return "%ds" % s


static func fmt_amounts(d: Dictionary) -> String:
	var parts: Array[String] = []
	for id in RES_ORDER:
		if d.has(id) and d[id] > 0.0:
			parts.append("+%s %s" % [fmt(d[id]), String(RES_NAMES[id]).to_lower()])
	return "  ".join(parts)
