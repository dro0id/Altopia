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
	"dax": {
		"name": "Dax Moreau", "job": "Pilote", "species": "human", "role": "dps", "rarity": "common", "ranged": true,
		"hp": 125.0, "atk": 24.0, "def": 6.0, "interval": 0.95,
		"skill": {"name": "Tir de barrage", "kind": "volley", "cd": 9.0, "desc": "Frappe tous les ennemis."},
		"look": {"suit": Color("d6453a"), "accent": Color("ffd9c8"), "skin": Color("e2b08a"), "hair": Color("3a2418"), "style": 0, "weapon": "blaster", "eye": Color("2a1c18")},
	},
	"pim": {
		"name": "Pim", "job": "Mécano", "species": "robot", "role": "tank", "rarity": "common", "ranged": false,
		"hp": 240.0, "atk": 13.0, "def": 13.0, "interval": 1.3,
		"skill": {"name": "Blindage", "kind": "shield", "cd": 11.0, "desc": "Protège toute l'escouade pendant 6 s."},
		"look": {"suit": Color("8fa3b8"), "accent": Color("ffb347"), "skin": Color("9aa6b2"), "hair": Color("000000"), "style": 0, "weapon": "shield", "eye": Color("ffb347")},
	},
	"neelo": {
		"name": "Neelo", "job": "Médecin", "species": "alien", "role": "healer", "rarity": "common", "ranged": true,
		"hp": 145.0, "atk": 14.0, "def": 7.0, "interval": 1.4,
		"skill": {"name": "Spores apaisantes", "kind": "repair", "cd": 12.0, "desc": "Soigne toute l'escouade."},
		"look": {"suit": Color("3fae6a"), "accent": Color("eaffd9"), "skin": Color("7fd1a0"), "hair": Color("000000"), "style": 0, "weapon": "tablet", "eye": Color("1a3d2a")},
	},
	"vance": {
		"name": "Vance Holt", "job": "Commandant en second", "species": "human", "role": "tank", "rarity": "rare", "ranged": false,
		"hp": 280.0, "atk": 16.0, "def": 16.0, "interval": 1.25,
		"skill": {"name": "Rempart de commandement", "kind": "shield", "cd": 11.0, "desc": "Protège toute l'escouade pendant 6 s."},
		"look": {"suit": Color("3b4a8a"), "accent": Color("e0e6ff"), "skin": Color("d4a080"), "hair": Color("7a7a80"), "style": 1, "weapon": "shield", "eye": Color("202840")},
	},
	"sora": {
		"name": "Sora Ito", "job": "Tireuse d'élite", "species": "human", "role": "dps", "rarity": "rare", "ranged": true,
		"hp": 115.0, "atk": 33.0, "def": 5.0, "interval": 1.5,
		"skill": {"name": "Tir de précision", "kind": "pierce", "cd": 10.0, "desc": "Un tir dévastateur sur l'ennemi le plus solide."},
		"look": {"suit": Color("2a8f8f"), "accent": Color("d0fff8"), "skin": Color("e8c2a0"), "hair": Color("1a1a24"), "style": 2, "weapon": "sniper", "eye": Color("164040")},
	},
	"brix": {
		"name": "Brix", "job": "Artilleur", "species": "robot", "role": "dps", "rarity": "rare", "ranged": true,
		"hp": 135.0, "atk": 29.0, "def": 7.0, "interval": 1.05,
		"skill": {"name": "Salve à fragmentation", "kind": "volley", "cd": 9.0, "desc": "Frappe tous les ennemis."},
		"look": {"suit": Color("b8602a"), "accent": Color("fff0c0"), "skin": Color("8a8f98"), "hair": Color("000000"), "style": 0, "weapon": "blaster", "eye": Color("ff7a3a")},
	},
	"lumi": {
		"name": "Lumi", "job": "Navigatrice", "species": "alien", "role": "control", "rarity": "rare", "ranged": true,
		"hp": 130.0, "atk": 19.0, "def": 6.0, "interval": 1.3,
		"skill": {"name": "Puits de lumière", "kind": "gravity", "cd": 13.0, "desc": "Étourdit tous les ennemis 2 s."},
		"look": {"suit": Color("c04a9a"), "accent": Color("ffe0f4"), "skin": Color("8ae0f0"), "hair": Color("000000"), "style": 0, "weapon": "orb", "eye": Color("3a1030")},
	},
	"aria": {
		"name": "Aria Quill", "job": "Cheffe médecin", "species": "human", "role": "healer", "rarity": "epic", "ranged": true,
		"hp": 170.0, "atk": 16.0, "def": 9.0, "interval": 1.35,
		"skill": {"name": "Régénération de masse", "kind": "repair", "cd": 11.0, "desc": "Soigne toute l'escouade."},
		"look": {"suit": Color("f0f0f8"), "accent": Color("ff6a8a"), "skin": Color("d9a07a"), "hair": Color("c04040"), "style": 2, "weapon": "tablet", "eye": Color("402030")},
	},
	"gorn": {
		"name": "Gorn", "job": "Gardien", "species": "alien", "role": "tank", "rarity": "epic", "ranged": false,
		"hp": 330.0, "atk": 18.0, "def": 18.0, "interval": 1.3,
		"skill": {"name": "Carapace cristalline", "kind": "shield", "cd": 12.0, "desc": "Protège toute l'escouade pendant 6 s."},
		"look": {"suit": Color("6a5acd"), "accent": Color("c8f0ff"), "skin": Color("5a9a8a"), "hair": Color("000000"), "style": 0, "weapon": "shield", "eye": Color("ffd24a")},
	},
	"omega": {
		"name": "Oméga-7", "job": "Unité de combat", "species": "robot", "role": "dps", "rarity": "epic", "ranged": true,
		"hp": 140.0, "atk": 38.0, "def": 8.0, "interval": 1.5,
		"skill": {"name": "Lance d'ion", "kind": "pierce", "cd": 10.0, "desc": "Un tir dévastateur sur l'ennemi le plus solide."},
		"look": {"suit": Color("222838"), "accent": Color("55ffc8"), "skin": Color("3a4250"), "hair": Color("000000"), "style": 0, "weapon": "sniper", "eye": Color("55ffc8")},
	},
}
const STARTER := ["mara", "kai", "zyra", "t9", "oru"]     # escouade de départ, dans l'ordre des emplacements
## Collection complète : 15 héros, rangés par rareté puis par rôle.
const ALL_HEROES := ["kai", "oru", "dax", "pim", "neelo", "mara", "t9", "vance", "sora", "brix", "lumi", "zyra", "aria", "gorn", "omega"]
const HERO_ORDER := ALL_HEROES
const SQUAD_SIZE := 5
const RARITY_NAMES_HERO := {"common": "Commun", "rare": "Rare", "epic": "Épique"}
const RARITIES_HERO := ["common", "rare", "epic"]

## Ennemis : multiplicateurs appliqués aux statistiques de base de l'étage.
const ENEMIES := {
	"mite": {"name": "Mite de roche", "hp": 0.6, "atk": 0.9, "def": 0.5, "interval": 1.0, "ranged": false, "gold": 1.0},
	"drone": {"name": "Drone foreur", "hp": 1.0, "atk": 1.0, "def": 1.0, "interval": 1.5, "ranged": true, "gold": 1.5},
	"gunner": {"name": "Canonnier", "hp": 0.8, "atk": 1.7, "def": 0.8, "interval": 2.0, "ranged": true, "gold": 2.0},
	"foreur": {"name": "Foreur éclaté", "hp": 16.0, "atk": 2.0, "def": 1.5, "interval": 1.6, "ranged": false, "gold": 12.0},
	"titan": {"name": "Gardien de verre", "hp": 140.0, "atk": 3.6, "def": 2.0, "interval": 1.6, "ranged": false, "gold": 30.0},
	"sentinelle": {"name": "Sentinelle prismatique", "hp": 110.0, "atk": 3.0, "def": 2.0, "interval": 2.0, "ranged": true, "gold": 30.0},
	"reine": {"name": "Reine des mites", "hp": 120.0, "atk": 3.2, "def": 1.5, "interval": 1.4, "ranged": false, "gold": 30.0},
}
const BOSS_KINDS := ["foreur", "titan", "sentinelle", "reine"]
const BIG_BOSSES := ["titan", "sentinelle", "reine"]   # un gros boss différent tous les 10 étages, en boucle

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


## Type de gros boss d'un étage multiple de 10 (Gardien de verre, Sentinelle prismatique, Reine des mites, puis on recommence).
static func big_boss_kind(stage: int) -> String:
	return BIG_BOSSES[(stage / BIG_BOSS_EVERY - 1) % BIG_BOSSES.size()]


static func boss_kind(stage: int) -> String:
	match boss_type(stage):
		"mini":
			return "foreur"
		"big":
			return big_boss_kind(stage)
	return ""


static func boss_name(stage: int) -> String:
	var k := boss_kind(stage)
	return ENEMIES[k].name if k != "" else ""


static func is_boss_stage(stage: int) -> bool:
	return boss_type(stage) != ""


## Puissance d'une escouade : somme pondérée des statistiques, pour comparer à la puissance recommandée.
static func team_power(levels: Dictionary, ids: Array = STARTER) -> float:
	var p := 0.0
	for id in ids:
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
			lv += 5.5 + 0.12 * float(stage)
	return maxi(1, int(round(lv)))


static func recommended_power(stage: int) -> float:
	var lv := {}
	for id in STARTER:
		lv[id] = recommended_level(stage)
	return team_power(lv, STARTER)


## Étoiles : 3 si personne ne tombe, 2 si un héros tombe, 1 sinon.
static func stars_for(fallen: int) -> int:
	return 3 if fallen == 0 else (2 if fallen == 1 else 1)


# ---------------------------------------------------------------- branche 3 : collection, recrutement, étoiles, synergies

const RECRUIT_COST := 3                       # jetons de recrutement pour un tirage
const RECRUIT_COST_10 := 27                   # dix tirages (un tirage offert)
const RECRUIT_RATES := {"common": 0.70, "rare": 0.25, "epic": 0.05}
const PITY_RARE := 10                          # un héros rare ou mieux garanti au plus tard au 10e tirage
const PITY_EPIC := 30                          # un héros épique garanti au plus tard au 30e tirage
const DUP_FRAGMENTS := {"common": 10, "rare": 6, "epic": 4}   # fragments gagnés quand on tire un héros déjà possédé
const STAR_COSTS := [10, 20, 40, 80]           # fragments pour passer de 1 à 2 étoiles, puis 3, 4, 5
const MAX_STARS := 5
const STAR_STAT := 0.12                        # +12 % de statistiques et de puissance de pouvoir par étoile
const CHEST_TOKENS := {"commun": 0, "normal": 1, "rare": 3, "epique": 5, "legendaire": 10, "ultime": 25}
const BIG_BOSS_CRYSTALS := {1: 5, 2: 5, 3: 10}  # cristaux gagnés en battant un gros boss (selon les étoiles)

# boutique : prix en cristaux d'Altopia (monnaie premium ; l'achat de cristaux contre argent réel viendra avec la publication)
const SHOP_ITEMS := [
	{"id": "token1", "name": "1 jeton de recrutement", "desc": "Un tirage de héros.", "cost": 10, "tokens": 1},
	{"id": "token10", "name": "10 jetons de recrutement", "desc": "Trois tirages de plus.", "cost": 90, "tokens": 10},
	{"id": "chest_rare", "name": "Coffre rare", "desc": "Crédits et éclats de verre.", "cost": 40, "chest": "rare"},
	{"id": "chest_epic", "name": "Coffre épique", "desc": "Beaucoup de crédits et d'éclats.", "cost": 120, "chest": "epique"},
	{"id": "free_chest", "name": "Coffre gratuit immédiat", "desc": "Supprime l'attente de 4 h.", "cost": 20, "free_chest": true},
]


static func star_mult(star_count: int) -> float:
	return 1.0 + STAR_STAT * float(maxi(0, star_count - 1))


static func star_cost(star_count: int) -> int:
	return STAR_COSTS[clampi(star_count - 1, 0, STAR_COSTS.size() - 1)]


## Tire la rareté d'un recrutement. `pity` = {"rare": n, "epic": n} : tirages depuis le dernier héros rare ou mieux / épique ; modifié sur place.
static func roll_recruit(rng: RandomNumberGenerator, pity: Dictionary) -> String:
	var rare_miss := int(pity.get("rare", 0))
	var epic_miss := int(pity.get("epic", 0))
	var r := rng.randf()
	var out := "common"
	if epic_miss >= PITY_EPIC - 1 or r < float(RECRUIT_RATES.epic):
		out = "epic"
	elif rare_miss >= PITY_RARE - 1 or r < float(RECRUIT_RATES.epic) + float(RECRUIT_RATES.rare):
		out = "rare"
	pity["rare"] = 0 if out != "common" else rare_miss + 1
	pity["epic"] = 0 if out == "epic" else epic_miss + 1
	return out


static func heroes_of_rarity(rarity: String) -> Array:
	var out: Array = []
	for id in ALL_HEROES:
		if HEROES[id].rarity == rarity:
			out.append(id)
	return out


## Synergies d'une escouade (liste d'identifiants) : multiplicateurs PV / ATQ / DÉF / puissance des pouvoirs et description des bonus actifs.
static func synergies(ids: Array) -> Dictionary:
	var mods := {"hp": 1.0, "atk": 1.0, "def": 1.0, "skill": 1.0}
	var list: Array = []
	var species := {}
	var roles := {}
	for id in ids:
		if id == null or not HEROES.has(id):
			continue
		var h: Dictionary = HEROES[id]
		species[h.species] = int(species.get(h.species, 0)) + 1
		roles[h.role] = int(roles.get(h.role, 0)) + 1
	var tier_bonus := {2: 0.06, 3: 0.12, 4: 0.20, 5: 0.20}
	var stat_of := {"human": "atk", "robot": "def", "alien": "hp"}
	var stat_name := {"atk": "ATQ", "def": "DÉF", "hp": "PV"}
	for sp in species:
		var n: int = species[sp]
		if n >= 2:
			var b: float = tier_bonus[mini(n, 5)]
			mods[stat_of[sp]] *= 1.0 + b
			list.append({"name": "%s ×%d" % [SPECIES_NAMES[sp], n], "desc": "+%d %% %s" % [int(round(b * 100.0)), stat_name[stat_of[sp]]]})
	if int(roles.get("tank", 0)) >= 1 and int(roles.get("healer", 0)) >= 1:
		mods.hp *= 1.10
		list.append({"name": "Rempart + Soutien", "desc": "+10 % PV"})
	if int(roles.get("dps", 0)) >= 2:
		mods.atk *= 1.08
		list.append({"name": "Double dégâts", "desc": "+8 % ATQ"})
	if int(roles.get("control", 0)) >= 1:
		mods.skill *= 1.10
		list.append({"name": "Contrôle", "desc": "+10 % puissance des pouvoirs"})
	return {"mods": mods, "list": list}


# ---------------------------------------------------------------- branche 1b : renforts, persévérance, paliers, combos

const BOOSTS := {
	"tir": {"name": "Tir accéléré", "desc": "+20 % de vitesse d'attaque", "color": Color("ffb142")},
	"bouclier": {"name": "Bouclier de départ", "desc": "Chaque combat commence avec un bouclier de 20 % des PV", "color": Color("4fd8ff")},
	"pouvoirs": {"name": "Pouvoirs rapides", "desc": "Recharge des pouvoirs réduite de 25 %", "color": Color("b88cff")},
	"vitalite": {"name": "Vitalité", "desc": "+20 % de PV pour toute l'escouade", "color": Color("7dffb0")},
	"butin": {"name": "Butin doré", "desc": "+25 % de crédits sur les ennemis vaincus", "color": Color("ffd166")},
}
const BOOST_IDS := ["tir", "bouclier", "pouvoirs", "vitalite", "butin"]
const PERSEVERANCE_STEP := 0.05          # +5 % de statistiques par défaite
const PERSEVERANCE_MAX := 6              # jusqu'à +30 %
const EVO_LEVELS := [10, 20]             # niveaux où il faut évoluer pour continuer
const EVO_SKILL_MULT := [1.0, 1.4, 1.8]  # puissance du pouvoir selon le palier
const EVO_STAT_MULT := [1.0, 1.1, 1.2]   # statistiques selon le palier
const EVO_SHARDS := [3, 8]               # éclats de verre demandés pour chaque palier
const COMBO_WINDOW := 3.0                # deux pouvoirs à moins de 3 s forment un combo


## Niveau maximal d'un héros selon son palier d'évolution (le dernier palier lève la limite).
static func level_cap(tier: int) -> int:
	return EVO_LEVELS[tier] if tier < EVO_LEVELS.size() else 999


static func evolve_cost(level: int, tier: int) -> Dictionary:
	return {"credits": 4 * level_cost(level), "shards": EVO_SHARDS[mini(tier, EVO_SHARDS.size() - 1)]}


## Bonus de dégâts d'un enchaînement de `n` pouvoirs rapprochés : +10 % par pouvoir au-delà du premier, plafonné à +50 %.
static func combo_mult(n: int) -> float:
	return 1.0 + minf(0.5, 0.1 * float(maxi(0, n - 1)))


## Bonus de crédits du coffre selon le meilleur combo de l'étage : +5 % par combo, plafonné à +25 %.
static func combo_loot(n: int) -> float:
	return minf(0.25, 0.05 * float(maxi(0, n - 1)))


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
