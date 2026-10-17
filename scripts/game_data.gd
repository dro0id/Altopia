extends RefCounted
## Données statiques du jeu (rôles, destinations, améliorations) et petits utilitaires.

const RES_ORDER := ["credits", "data", "minerals", "energy"]
const RES_NAMES := {
	"credits": "Crédits", "data": "Données", "minerals": "Minerais", "energy": "Énergie",
}

## Classes de héros. rate = crédits/s par niveau de héros possédé ; data_rate = données/s.
const CREW_ORDER := ["pilot", "engineer", "scientist"]
const CREW := {
	"pilot": {"name": "Pilote", "desc": "Maître des astéroïdes", "rate": 0.5, "data_rate": 0.0, "color": Color(0.35, 0.85, 1.0)},
	"engineer": {"name": "Ingénieur", "desc": "Maître des étoiles", "rate": 1.0, "data_rate": 0.0, "color": Color(1.0, 0.62, 0.25)},
	"scientist": {"name": "Scientifique", "desc": "Maître des planètes", "rate": 0.5, "data_rate": 0.25, "color": Color(0.45, 0.95, 0.55)},
}

const RARITY := {
	"common": {"name": "Commun", "color": Color(0.72, 0.77, 0.88), "weight": 70},
	"rare": {"name": "Rare", "color": Color(0.35, 0.65, 1.0), "weight": 25},
	"epic": {"name": "Épique", "color": Color(0.78, 0.42, 1.0), "weight": 5},
}
const RARITY_ORDER := ["epic", "rare", "common"]

## Héros recrutables : stats de base au niveau 1, 0 étoile.
const HERO_ORDER := ["rex", "nova", "zara", "bolt", "tess", "gorn", "lumi", "quark", "elara"]
const HEROES := {
	"rex": {"name": "Rex", "class": "pilot", "rarity": "common", "hp": 100.0, "atk": 14.0, "def": 6.0, "spd": 12.0},
	"nova": {"name": "Nova", "class": "pilot", "rarity": "rare", "hp": 110.0, "atk": 18.0, "def": 7.0, "spd": 15.0},
	"zara": {"name": "Zara", "class": "pilot", "rarity": "epic", "hp": 120.0, "atk": 24.0, "def": 9.0, "spd": 18.0},
	"bolt": {"name": "Bolt", "class": "engineer", "rarity": "common", "hp": 130.0, "atk": 10.0, "def": 10.0, "spd": 8.0},
	"tess": {"name": "Tess", "class": "engineer", "rarity": "rare", "hp": 140.0, "atk": 12.0, "def": 13.0, "spd": 9.0},
	"gorn": {"name": "Gorn", "class": "engineer", "rarity": "epic", "hp": 170.0, "atk": 15.0, "def": 17.0, "spd": 8.0},
	"lumi": {"name": "Lumi", "class": "scientist", "rarity": "common", "hp": 90.0, "atk": 16.0, "def": 4.0, "spd": 10.0},
	"quark": {"name": "Quark", "class": "scientist", "rarity": "rare", "hp": 95.0, "atk": 20.0, "def": 5.0, "spd": 11.0},
	"elara": {"name": "Elara", "class": "scientist", "rarity": "epic", "hp": 105.0, "atk": 27.0, "def": 6.0, "spd": 13.0},
}
const STARTER_HEROES := ["rex", "bolt"]

const SQUAD_SIZE := 3
const MAX_LEVEL := 40
const MAX_STARS := 5
const LEVEL_BONUS := 0.15        # +15 % de stats par niveau
const STAR_BONUS := 0.20         # +20 % de stats par étoile (doublon)
const RECRUIT_BASE := 50.0
const RECRUIT_GROWTH := 1.2
const TRAIN_BASE := 30.0
const TRAIN_GROWTH := 1.25
const LOSS_REWARD := 0.25        # part du butin conservée en cas de défaite
const ENEMY_LEVEL_STEP := 4      # victoires nécessaires pour +1 niveau d'ennemis
const ENEMY_SCALE := 0.12
const BATTLE_MAX_ROUNDS := 60

const DEST_ORDER := ["asteroids", "star", "planet"]
const DEST := {
	"asteroids": {
		"name": "Champ d'astéroïdes", "role": "pilot", "duration": 20.0, "unlock_data": 0.0, "xp": 12,
		"enemy": {"name": "Foreur rebelle", "count": 2, "hp": 70.0, "atk": 9.0, "def": 3.0, "spd": 9.0},
		"rewards": {"minerals": 5.0, "credits": 10.0, "data": 3.0},
	},
	"star": {
		"name": "Étoile naine", "role": "engineer", "duration": 45.0, "unlock_data": 25.0, "xp": 30,
		"enemy": {"name": "Sentinelle solaire", "count": 2, "hp": 120.0, "atk": 14.0, "def": 7.0, "spd": 10.0},
		"rewards": {"energy": 8.0, "credits": 20.0, "data": 6.0},
	},
	"planet": {
		"name": "Planète inconnue", "role": "scientist", "duration": 90.0, "unlock_data": 100.0, "xp": 60,
		"enemy": {"name": "Créature xéno", "count": 3, "hp": 150.0, "atk": 18.0, "def": 8.0, "spd": 11.0},
		"rewards": {"data": 16.0, "credits": 60.0, "minerals": 3.0, "energy": 2.0},
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

const SYNERGY_PAIR := 0.10
const SYNERGY_FULL := 0.25
const PAIRS := [["pilot", "engineer"], ["engineer", "scientist"], ["scientist", "pilot"]]
const ROLE_GAIN := 0.15          # +15 % de gains par niveau du rôle requis
const ROLE_SPEED := 0.03         # -3 % de durée par niveau du rôle requis
const UPGRADE_GAIN := 0.25
const ENGINE_SPEED := 0.10
const START_CREDITS := 100.0
const BASE_DATA_RATE := 0.1      # données/s des capteurs de bord, même sans Scientifique
const MAX_SLOTS := 2
const OFFLINE_CAP_SECONDS := 8 * 3600


## Stats d'un héros selon son niveau et ses étoiles.
static func hero_stats(id: String, level: int, stars: int) -> Dictionary:
	var h: Dictionary = HEROES[id]
	var m: float = (1.0 + LEVEL_BONUS * (level - 1)) * (1.0 + STAR_BONUS * stars)
	return {"hp": h.hp * m, "atk": h.atk * m, "def": h.def * m, "spd": h.spd}


static func xp_needed(level: int) -> int:
	return int(20.0 * pow(level, 1.5))


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
