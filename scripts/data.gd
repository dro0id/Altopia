extends RefCounted
## Données statiques : héros, ennemis, formules. Aucun état ici (voir game.gd pour la partie en cours).

const ROLE_NAMES := {"tank": "Rempart", "dps": "Dégâts", "healer": "Soutien", "control": "Contrôle"}
const RARITY_COLORS := {"common": Color("b8c4e0"), "rare": Color("59a6ff"), "epic": Color("c76bff")}
const SPECIES_NAMES := {"human": "Humain", "robot": "Robot", "alien": "Extraterrestre"}

## hp, atk, def au niveau 1 ; interval = secondes entre deux attaques ; look = apparence 2D (voir art.gd).
const HEROES := {
	"mara": {
		"name": "Mara Voss", "job": "Ingénieur", "species": "human", "role": "tank", "rarity": "rare", "ranged": false,
		"hp": 260.0, "atk": 15.0, "def": 14.0, "interval": 1.25,
		"skill": {"name": "Bouclier magnétique", "kind": "shield", "cd": 11.0, "desc": "Protège toute l'escouade pendant 6 s."},
		"look": {"suit": Color("e8822a"), "accent": Color("fff2d8"), "skin": Color("d9a07a"), "hair": Color("7a2b1c"), "style": 2, "weapon": "shield", "eye": Color("3a2a22")},
	},
	"kai": {
		"name": "Kaï Renn", "job": "Pilote", "species": "human", "role": "dps", "rarity": "common", "ranged": true,
		"hp": 130.0, "atk": 26.0, "def": 6.0, "interval": 1.0,
		"skill": {"name": "Salve de missiles", "kind": "volley", "cd": 9.0, "desc": "Frappe tous les ennemis."},
		"look": {"suit": Color("3a6ee8"), "accent": Color("bfe3ff"), "skin": Color("e6bd98"), "hair": Color("2b2640"), "style": 1, "weapon": "blaster", "eye": Color("1f2a44")},
	},
	"zyra": {
		"name": "Zyra", "job": "Pilote", "species": "alien", "role": "dps", "rarity": "epic", "ranged": true,
		"hp": 110.0, "atk": 34.0, "def": 5.0, "interval": 1.5,
		"skill": {"name": "Tir perforant", "kind": "pierce", "cd": 10.0, "desc": "Un tir dévastateur sur l'ennemi le plus solide."},
		"look": {"suit": Color("1fa890"), "accent": Color("d4fff4"), "skin": Color("9b6bd6"), "hair": Color("000000"), "style": 0, "weapon": "sniper", "eye": Color("ffd24a")},
	},
	"t9": {
		"name": "T-9", "job": "Scientifique", "species": "robot", "role": "healer", "rarity": "rare", "ranged": true,
		"hp": 150.0, "atk": 14.0, "def": 8.0, "interval": 1.4,
		"skill": {"name": "Nano-réparation", "kind": "repair", "cd": 12.0, "desc": "Soigne toute l'escouade."},
		"look": {"suit": Color("cfd8e6"), "accent": Color("5cf29a"), "skin": Color("8a94a6"), "hair": Color("000000"), "style": 0, "weapon": "tablet", "eye": Color("5cf29a")},
	},
	"oru": {
		"name": "Oru", "job": "Scientifique", "species": "alien", "role": "control", "rarity": "common", "ranged": true,
		"hp": 125.0, "atk": 17.0, "def": 6.0, "interval": 1.3,
		"skill": {"name": "Onde gravitationnelle", "kind": "gravity", "cd": 13.0, "desc": "Étourdit tous les ennemis 2 s."},
		"look": {"suit": Color("7a4fc9"), "accent": Color("ffd9fb"), "skin": Color("5fd0c8"), "hair": Color("000000"), "style": 0, "weapon": "orb", "eye": Color("ffb43a")},
	},
}
const HERO_ORDER := ["mara", "kai", "zyra", "t9", "oru"]

## Ennemis : multiplicateurs appliqués aux statistiques de base de l'étage.
const ENEMIES := {
	"mite": {"name": "Mite de roche", "hp": 0.6, "atk": 0.9, "def": 0.5, "interval": 1.0, "ranged": false, "gold": 1.0},
	"drone": {"name": "Drone foreur", "hp": 1.0, "atk": 1.0, "def": 1.0, "interval": 1.5, "ranged": true, "gold": 1.5},
	"gunner": {"name": "Canonnier", "hp": 0.8, "atk": 1.7, "def": 0.8, "interval": 2.0, "ranged": true, "gold": 2.0},
	"foreur": {"name": "Foreur éclaté", "hp": 11.0, "atk": 1.7, "def": 1.5, "interval": 1.6, "ranged": false, "gold": 12.0},
	"titan": {"name": "Gardien de verre", "hp": 40.0, "atk": 2.6, "def": 2.0, "interval": 1.6, "ranged": false, "gold": 30.0},
}
const BOSS_KINDS := ["foreur", "titan"]

const ENEMY_HP := 62.0
const ENEMY_ATK := 8.0
const ENEMY_DEF := 3.0
const STAGE_GROWTH := 1.13       # puissance des ennemis par étage
const LEVEL_GROWTH := 1.14       # puissance d'un héros par niveau
const COST_BASE := 30.0
const COST_GROWTH := 1.17
const WAVES_PER_STAGE := 3
const MINI_BOSS_EVERY := 5       # mini-boss aux étages 5, 15, 25...
const BIG_BOSS_EVERY := 10       # gros boss aux étages 10, 20, 30...
const OFFLINE_CAP_HOURS := 8.0


static func stage_scale(stage: int) -> float:
	return pow(STAGE_GROWTH, float(stage - 1))


static func hero_mult(level: int) -> float:
	return pow(LEVEL_GROWTH, float(level - 1))


static func level_cost(level: int) -> int:
	return int(round(COST_BASE * pow(COST_GROWTH, float(level - 1))))


## "" (étage normal), "mini" (tous les 5) ou "big" (tous les 10).
static func boss_type(stage: int) -> String:
	if stage % BIG_BOSS_EVERY == 0:
		return "big"
	if stage % MINI_BOSS_EVERY == 0:
		return "mini"
	return ""


static func is_boss_stage(stage: int) -> bool:
	return boss_type(stage) != ""


## Puissance d'une escouade : somme pondérée des statistiques, pour comparer à la puissance recommandée.
static func team_power(levels: Dictionary) -> float:
	var p := 0.0
	for id in HERO_ORDER:
		var h: Dictionary = HEROES[id]
		var m := hero_mult(int(levels.get(id, 1)))
		p += (h.hp * 0.25 + h.atk * 6.0 + h.def * 3.0) * m
	return p


## Niveau moyen d'escouade recommandé pour un étage (ajusté sur les simulations de tools/calibrate.gd).
static func recommended_level(stage: int) -> int:
	var lv := 0.65 * float(stage) - 3.4
	match boss_type(stage):
		"mini":
			lv += 1.0
		"big":
			lv += 4.5 + 0.1 * float(stage)
	return maxi(1, int(round(lv)))


static func recommended_power(stage: int) -> float:
	var lv := {}
	for id in HERO_ORDER:
		lv[id] = recommended_level(stage)
	return team_power(lv)


## Étoiles : 3 si personne ne tombe, 2 si un héros tombe, 1 sinon.
static func stars_for(fallen: int) -> int:
	return 3 if fallen == 0 else (2 if fallen == 1 else 1)


# ---------------------------------------------------------------- coffres

const RARITIES := ["commun", "normal", "rare", "epique", "legendaire", "ultime"]
const RARITY_NAMES := {"commun": "Commun", "normal": "Normal", "rare": "Rare", "epique": "Épique", "legendaire": "Légendaire", "ultime": "Ultime"}
const CHEST_COLORS := {
	"commun": Color("e0a82e"), "normal": Color("5be08a"), "rare": Color("4fa8ff"),
	"epique": Color("c084ff"), "legendaire": Color("ffa23a"), "ultime": Color("ff3b3b"),
}
const CHEST_CREDITS := {"commun": 1.5, "normal": 3.0, "rare": 7.0, "epique": 16.0, "legendaire": 38.0, "ultime": 100.0}
const CHEST_SHARDS := {"commun": 2, "normal": 4, "rare": 8, "epique": 18, "legendaire": 40, "ultime": 120}
const EPIC_CHANCE := {1: 0.10, 2: 0.10, 3: 0.20}
const LEGENDARY_CHANCE := 0.03
const ULTIMATE_CHANCE := 0.005
const LEGENDARY_PITY := 2        # garanti au 2e gros boss en 3 étoiles sans légendaire
const ULTIMATE_PITY := 10        # garanti au 10e gros boss en 3 étoiles sans ultime
const FREE_CHEST_HOURS := 4.0


## Tire la rareté du coffre d'un étage vaincu. `pity` = {"leg": n, "ult": n} (gros boss en 3 étoiles sans légendaire / sans ultime) ; modifié sur place.
static func roll_chest(stage: int, stars: int, rng: RandomNumberGenerator, pity: Dictionary) -> String:
	match boss_type(stage):
		"":
			return "normal" if stars >= 3 else "commun"
		"mini":
			return "rare"
	var r := rng.randf()
	var out := "rare"
	if stars >= 3:
		var leg_miss := int(pity.get("leg", 0))
		var ult_miss := int(pity.get("ult", 0))
		if ult_miss >= ULTIMATE_PITY - 1 or r < ULTIMATE_CHANCE:
			out = "ultime"
		elif leg_miss >= LEGENDARY_PITY - 1 or r < ULTIMATE_CHANCE + LEGENDARY_CHANCE:
			out = "legendaire"
		elif r < ULTIMATE_CHANCE + LEGENDARY_CHANCE + EPIC_CHANCE[3]:
			out = "epique"
		pity["leg"] = 0 if out in ["legendaire", "ultime"] else leg_miss + 1
		pity["ult"] = 0 if out == "ultime" else ult_miss + 1
	elif r < EPIC_CHANCE[stars]:
		out = "epique"
	return out


static func chest_rewards(stage: int, rarity: String) -> Dictionary:
	return {"credits": round(12.0 * stage_scale(stage) * CHEST_CREDITS[rarity]), "shards": CHEST_SHARDS[rarity]}


static func chapter_of(stage: int) -> int:
	return (stage - 1) / 10 + 1


static func fmt(v: float) -> String:
	if v >= 1.0e9:
		return "%.2fG" % (v / 1.0e9)
	if v >= 1.0e6:
		return "%.2fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.1fK" % (v / 1.0e3)
	return str(int(v))
