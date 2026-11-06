class_name Ship
extends RefCounted
## Le vaisseau l'Aurore (branche 5, maquettes IA à QC) : 10 salles, niveau 1 à 20, cinq versions (1–5, 6–10, 11–15, 16–19, 20).
## Ce fichier ne contient que les règles (chiffres et formules) ; l'état du joueur est dans ShipState.

const Data = preload("res://scripts/data.gd")

const MAX_LEVEL := 20
const UNLOCK_STAGE := 5                 # le vaisseau s'ouvre une fois le mini-boss de l'étage 5 vaincu
const ORDER := ["pont", "centrale", "raffinerie", "atelier", "antenne", "labo", "quartiers", "hangar", "serre", "observatoire"]

## Salles : nom, couleur, niveau du vaisseau qui l'ouvre, métiers idéaux, ressource produite.
const ROOMS := {
	"pont": {"name": "Pont de commandement", "short": "Pont", "color": Color("4fd8ff"), "unlock": 1, "jobs": ["Commandant en second", "Navigatrice"], "res": ""},
	"centrale": {"name": "Centrale", "short": "Centrale", "color": Color("ffd166"), "unlock": 1, "jobs": ["Ingénieur", "Mécano"], "res": ""},
	"raffinerie": {"name": "Raffinerie de verre", "short": "Raffinerie", "color": Color("7fdcff"), "unlock": 1, "jobs": ["Gardien", "Unité de combat", "Mécano"], "res": "shards"},
	"atelier": {"name": "Atelier", "short": "Atelier", "color": Color("ff9f6b"), "unlock": 3, "jobs": ["Ingénieur", "Mécano", "Artilleur"], "res": "item_tokens"},
	"antenne": {"name": "Antenne", "short": "Antenne", "color": Color("ff7ad9"), "unlock": 5, "jobs": ["Navigatrice", "Pilote", "Tireuse d'élite"], "res": "tokens"},
	"labo": {"name": "Labo", "short": "Labo", "color": Color("b388ff"), "unlock": 6, "jobs": ["Scientifique"], "res": ""},
	"quartiers": {"name": "Quartiers", "short": "Quartiers", "color": Color("7dffb0"), "unlock": 8, "jobs": ["Médecin", "Cheffe médecin"], "res": ""},
	"hangar": {"name": "Hangar", "short": "Hangar", "color": Color("4fd8ff"), "unlock": 10, "jobs": ["Pilote", "Navigatrice"], "res": ""},
	"serre": {"name": "Serre", "short": "Serre", "color": Color("9dff6b"), "unlock": 12, "jobs": ["Cheffe médecin", "Médecin", "Scientifique"], "res": "credits"},
	"observatoire": {"name": "Observatoire", "short": "Observatoire", "color": Color("e6d6ff"), "unlock": 14, "jobs": ["Navigatrice", "Scientifique", "Tireuse d'élite"], "res": ""},
}
const RES_NAMES := {"shards": "éclats", "item_tokens": "jetons d’objet", "tokens": "jetons de recrutement", "credits": "crédits"}

## Étage à atteindre pour monter le Pont (= le vaisseau) à chaque niveau.
const PONT_STAGE := [0, 5, 8, 11, 14, 17, 20, 24, 28, 32, 36, 40, 46, 52, 58, 64, 72, 80, 90, 100, 120]
## Durée d'un chantier pour atteindre chaque niveau (secondes) : 2 min au début, 16 h au niveau 20.
const BUILD_TIME := [0, 0, 120, 300, 600, 1200, 1800, 2700, 3600, 5400, 7200, 9000, 10800, 14400, 18000, 21600, 25200, 28800, 36000, 43200, 57600]

const TIERS := [
	{"from": 1, "to": 5, "name": "Aurore I", "sub": "coque d’origine", "color": Color("a9b6d6")},
	{"from": 6, "to": 10, "name": "Aurore II", "sub": "modulaire", "color": Color("4fd8ff")},
	{"from": 11, "to": 15, "name": "Aurore III", "sub": "étendue", "color": Color("9dff6b")},
	{"from": 16, "to": 19, "name": "Aurore IV", "sub": "vaisseau-amiral", "color": Color("ffd166")},
	{"from": 20, "to": 20, "name": "Aurore Éternelle", "sub": "★", "color": Color("e6d6ff")},
]

const WORKER_BONUS := 0.25              # un héros à son poste : +25 % ; au métier idéal : +50 %
const PONT_BONUS := 0.02                # +2 % de production partout par niveau du vaisseau
const RUSH_SECONDS := 600               # 1 cristal par tranche de 10 minutes restantes

## Recherches du Labo : bonus par rang, rang maximal = niveau du Labo (au plus 10).
const RESEARCH := {
	"blindage": {"name": "Blindage", "branch": "combat", "per": 0.03, "desc": "+3 % de PV par rang"},
	"armement": {"name": "Armement", "branch": "combat", "per": 0.03, "desc": "+3 % d’attaque par rang"},
	"reacteurs": {"name": "Réacteurs", "branch": "combat", "per": 0.02, "desc": "Pouvoirs rechargés 2 % plus vite par rang"},
	"briseur": {"name": "Briseur de boss", "branch": "combat", "per": 0.04, "desc": "+4 % de dégâts aux boss par rang", "labo": 4},
	"prospection": {"name": "Prospection", "branch": "butin", "per": 0.05, "desc": "+5 % de crédits par rang"},
	"tamisage": {"name": "Tamisage", "branch": "butin", "per": 0.05, "desc": "+5 % d’éclats dans les coffres par rang"},
	"rendement": {"name": "Rendement", "branch": "vaisseau", "per": 0.05, "desc": "+5 % de production du vaisseau par rang"},
	"logistique": {"name": "Logistique", "branch": "vaisseau", "per": 0.05, "desc": "Chantiers 5 % plus courts par rang", "labo": 3},
}
const RESEARCH_ORDER := ["blindage", "armement", "reacteurs", "briseur", "prospection", "tamisage", "rendement", "logistique"]
const RESEARCH_MAX := 10

## Navettes du Hangar et destinations d'expédition (maquettes LA à LE).
const SHUTTLES := {
	"colibri": {"name": "Colibri", "role": "Éclaireur", "color": Color("ff9f6b"), "time": 0.75, "loot": 1.0, "rare": 1.0, "hangar": 1},
	"martin": {"name": "Martin", "role": "Cargo", "color": Color("b388ff"), "time": 1.0, "loot": 1.5, "rare": 1.0, "hangar": 4},
	"sterne": {"name": "Sterne", "role": "Explorateur", "color": Color("7dffb0"), "time": 1.0, "loot": 1.0, "rare": 2.0, "hangar": 8},
}
const SHUTTLE_ORDER := ["colibri", "martin", "sterne"]
const DESTS := {
	"asteroides": {"name": "Champ d’astéroïdes", "sub": "Proche, sans danger", "hours": 1.0, "stage": 0},
	"epave": {"name": "Épave dérivante", "sub": "Une épave terrienne à fouiller", "hours": 4.0, "stage": 0},
	"echo": {"name": "Écho lointain", "sub": "Le signal capte quelqu’un, loin", "hours": 8.0, "stage": 20},
	"inconnu": {"name": "Secteur inconnu", "sub": "Au-delà de la Ceinture", "hours": 12.0, "stage": 50},
}
const DEST_ORDER := ["asteroides", "epave", "echo", "inconnu"]
const RARE_FIND := 0.15


static func tier_of(level: int) -> int:
	for i in TIERS.size():
		if level >= int(TIERS[i].from) and level <= int(TIERS[i].to):
			return i + 1
	return 1


static func tier_info(level: int) -> Dictionary:
	return TIERS[tier_of(level) - 1]


## Gains d'une minute de farm à cet étage (même formule que les gains hors ligne).
static func income_per_min(stage: int) -> float:
	var sc := Data.stage_scale(maxi(1, stage - 1))
	return (3.0 * sc * 3.4 * Data.WAVES_PER_STAGE + 25.0 * sc) * 0.6


## Coût d'amélioration d'une salle (ou du Pont) vers `to_level` : crédits, éclats, durée (secondes).
static func upgrade_cost(room: String, to_level: int, logistique := 0) -> Dictionary:
	var lv := clampi(to_level, 2, MAX_LEVEL)
	var k := 2.0 if room == "pont" else 1.0
	var credits: float = roundf(30.0 * income_per_min(PONT_STAGE[lv]) * k / 10.0) * 10.0
	var shards := int(round(4.0 * pow(float(lv), 1.6) * k))
	var t := float(BUILD_TIME[lv]) * (1.5 if room == "pont" else 1.0) * maxf(0.5, 1.0 - 0.05 * logistique)
	return {"credits": credits, "shards": shards, "time": int(t)}


## Production de base par heure d'une salle au niveau `lv` (ressource : RES de la salle).
static func base_rate(room: String, lv: int, best_stage: int = 1) -> float:
	if lv <= 0:
		return 0.0
	match room:
		"raffinerie":
			return 2.0 + 0.6 * lv
		"atelier":
			return 0.25 + 0.04 * lv
		"antenne":
			return 0.33 + 0.05 * lv
		"serre":
			return income_per_min(best_stage) * 60.0 * (0.15 + 0.015 * lv)
	return 0.0


## Autonomie (heures) : durée pendant laquelle les salles se remplissent et plafond des gains hors ligne.
static func autonomy_hours(centrale_lv: int) -> float:
	return 8.0 + 0.5 * maxf(0.0, float(centrale_lv - 1))


## Postes par salle selon le niveau du vaisseau.
static func posts(ship_level: int) -> int:
	return 1 + (1 if ship_level >= 8 else 0) + (1 if ship_level >= 14 else 0)


## Lits des Quartiers (héros à l'entraînement) et intervalle entre deux niveaux gagnés.
static func beds(lv: int) -> int:
	return mini(5, 1 + lv / 5) if lv > 0 else 0


static func train_hours(lv: int) -> float:
	return maxf(1.5, 6.0 - 0.25 * lv)


## Navettes disponibles selon le niveau du Hangar.
static func shuttles_for(hangar_lv: int) -> Array:
	return SHUTTLE_ORDER.filter(func(s): return hangar_lv >= int(SHUTTLES[s].hangar))


## Bonus de butin des secteurs générés (Observatoire).
static func observatory_bonus(lv: int) -> float:
	return 0.05 + 0.01 * lv if lv > 0 else 0.0


static func is_ideal(hero_id: String, room: String) -> bool:
	var h: Dictionary = Data.HEROES.get(hero_id, {})
	return ROOMS[room].jobs.has(String(h.get("job", "")))


static func worker_bonus(hero_id: String, room: String) -> float:
	return WORKER_BONUS * (2.0 if is_ideal(hero_id, room) else 1.0)


static func rush_cost(seconds: float) -> int:
	return maxi(1, int(ceil(seconds / RUSH_SECONDS)))


## Coût et durée d'un rang de recherche (rang visé `rank`, 1 à 10).
static func research_cost(id: String, rank: int, best_stage: int) -> Dictionary:
	var credits: float = roundf(20.0 * income_per_min(maxi(5, best_stage)) * pow(1.35, rank - 1) / 10.0) * 10.0
	return {"credits": credits, "shards": 8 * rank, "time": int(600.0 * pow(float(rank), 1.3))}


## Récompense d'une expédition (avant les bonus de navette).
static func dest_reward(dest: String, best_stage: int) -> Dictionary:
	match dest:
		"asteroides":
			return {"shards": 20 + best_stage / 4}
		"epave":
			return {"item_tokens": 3, "credits": roundf(income_per_min(best_stage) * 45.0)}
		"echo":
			return {"tokens": 2, "crystals": 5}
		"inconnu":
			return {"chest": "epique", "credits": roundf(income_per_min(best_stage) * 90.0)}
	return {}
