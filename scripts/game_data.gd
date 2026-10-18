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
	"common": {"name": "Commun", "color": Color(0.72, 0.77, 0.88), "weight": 70, "prod": 1.0},
	"rare": {"name": "Rare", "color": Color(0.35, 0.65, 1.0), "weight": 25, "prod": 1.4},
	"epic": {"name": "Épique", "color": Color(0.78, 0.42, 1.0), "weight": 5, "prod": 2.0},
}
const RARITY_ORDER := ["epic", "rare", "common"]

## Héros recrutables : stats de base au niveau 1, 0 étoile.
const HERO_ORDER := ["rex", "nova", "zara", "bolt", "tess", "gorn", "lumi", "quark", "elara"]
const HEROES := {
	"rex": {"name": "Rex", "class": "pilot", "rarity": "common", "specialty": "mine", "hp": 100.0, "atk": 14.0, "def": 6.0, "spd": 12.0},
	"nova": {"name": "Nova", "class": "pilot", "rarity": "rare", "specialty": "quartiers", "hp": 110.0, "atk": 18.0, "def": 7.0, "spd": 15.0},
	"zara": {"name": "Zara", "class": "pilot", "rarity": "epic", "specialty": "mine", "hp": 120.0, "atk": 24.0, "def": 9.0, "spd": 18.0},
	"bolt": {"name": "Bolt", "class": "engineer", "rarity": "common", "specialty": "centrale", "hp": 130.0, "atk": 10.0, "def": 10.0, "spd": 8.0},
	"tess": {"name": "Tess", "class": "engineer", "rarity": "rare", "specialty": "atelier", "hp": 140.0, "atk": 12.0, "def": 13.0, "spd": 9.0},
	"gorn": {"name": "Gorn", "class": "engineer", "rarity": "epic", "specialty": "atelier", "hp": 170.0, "atk": 15.0, "def": 17.0, "spd": 8.0},
	"lumi": {"name": "Lumi", "class": "scientist", "rarity": "common", "specialty": "labo", "hp": 90.0, "atk": 16.0, "def": 4.0, "spd": 10.0},
	"quark": {"name": "Quark", "class": "scientist", "rarity": "rare", "specialty": "soute", "hp": 95.0, "atk": 20.0, "def": 5.0, "spd": 11.0},
	"elara": {"name": "Elara", "class": "scientist", "rarity": "epic", "specialty": "labo", "hp": 105.0, "atk": 27.0, "def": 6.0, "spd": 13.0},
}
const STARTER_HEROES := ["rex", "bolt"]

## --- Capitaine (le joueur) ---
const CAPTAIN_BASE := {"hp": 120.0, "atk": 14.0, "def": 6.0, "spd": 10.0}
const CAPTAIN_MAX_LEVEL := 50    # règle : rien ne fait dépasser le niveau 50 (la puissance vient ensuite de l'équipement)
## Les niveaux du Capitaine sont espacés : un niveau vaut CAPTAIN_LEVEL_SPAN « niveaux de puissance » (le niveau 50 correspond
## à peu près à l'ancien niveau 240). La courbe de puissance, donc la difficulté, ne change pas : seul le nombre de niveaux est compressé.
const CAPTAIN_LEVEL_SPAN := 5
const CAPTAIN_LEVEL_BONUS := 0.15   # par niveau de puissance (x CAPTAIN_LEVEL_SPAN par niveau affiché)
const CAPTAIN_TRAIN_BASE := 40.0
const CAPTAIN_TRAIN_GROWTH := 1.4
const CREW_STAT_SHARE := 0.35    # part des stats de l'équipage ajoutée au Capitaine
const CREW_SPD_SHARE := 0.20
const DRONE_ATK_SHARE := 1.0     # vaisseau AFK : l'équipage combat seul, le Capitaine n'y participe pas
const DRONE_DEF_SHARE := 0.7
const LOOK_SUITS := [Color(0.35, 0.75, 1.0), Color(1.0, 0.55, 0.25), Color(0.5, 0.9, 0.55),
	Color(0.78, 0.5, 1.0), Color(1.0, 0.4, 0.45), Color(0.92, 0.94, 1.0)]
const LOOK_HAIRS := [Color(0.18, 0.12, 0.1), Color(0.95, 0.8, 0.35), Color(0.9, 0.35, 0.35),
	Color(0.35, 0.55, 0.95), Color(0.85, 0.85, 0.9), Color(0.3, 0.75, 0.5)]
const LOOK_STYLES := 3

## --- Équipement du Capitaine : du vrai loot RPG ---
const EQUIP_SLOTS := ["weapon", "helmet", "suit", "gloves", "boots", "module"]
const EQUIP := {
	"weapon": {"name": "Arme", "names": ["Laser", "Blaster", "Rayon ionique", "Canon à plasma"]},
	"helmet": {"name": "Casque", "names": ["Casque", "Heaume", "Visière tactique", "Masque pressurisé"]},
	"suit": {"name": "Combinaison", "names": ["Combinaison", "Armure", "Exo-squelette", "Scaphandre"]},
	"gloves": {"name": "Gants", "names": ["Gants", "Gantelets", "Poignes assistées"]},
	"boots": {"name": "Bottes", "names": ["Bottes", "Jambières", "Bottes magnétiques"]},
	"module": {"name": "Module", "names": ["Propulseur", "Bouclier", "Capteur", "Réacteur"]},
}
## Stats plates de base par emplacement (avant rareté et niveau d'objet).
const ITEM_BASE := {
	"weapon": {"atk": 8.0},
	"helmet": {"hp": 22.0, "def": 2.5},
	"suit": {"hp": 34.0, "def": 4.0},
	"gloves": {"atk": 3.5, "hp": 10.0},
	"boots": {"spd": 2.0, "def": 2.0},
	"module": {"atk": 2.5, "def": 1.5, "hp": 12.0, "spd": 1.0},
}
const ITEM_RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]
const ITEM_RARITY := {
	"common": {"name": "Commun", "color": Color(0.72, 0.77, 0.88), "mult": 1.0, "affixes": 0, "weight": 60.0},
	"uncommon": {"name": "Peu commun", "color": Color(0.45, 0.9, 0.5), "mult": 1.25, "affixes": 1, "weight": 25.0},
	"rare": {"name": "Rare", "color": Color(0.35, 0.65, 1.0), "mult": 1.6, "affixes": 2, "weight": 11.0},
	"epic": {"name": "Épique", "color": Color(0.78, 0.42, 1.0), "mult": 2.1, "affixes": 3, "weight": 1.5},
	"legendary": {"name": "Légendaire", "color": Color(1.0, 0.65, 0.15), "mult": 2.8, "affixes": 4, "weight": 0.08},
}
## Bonus aléatoires (affixes) : valeur tirée entre min et max, puis augmentée avec le niveau d'objet.
const AFFIX_ORDER := ["atk_pct", "hp_pct", "def_pct", "spd", "crit", "lifesteal", "xp_pct", "credits_pct", "drop_pct"]
const AFFIXES := {
	"atk_pct": {"name": "Attaque", "unit": "%", "min": 3.0, "max": 7.0},
	"hp_pct": {"name": "PV", "unit": "%", "min": 4.0, "max": 9.0},
	"def_pct": {"name": "Défense", "unit": "%", "min": 3.0, "max": 7.0},
	"spd": {"name": "Vitesse", "unit": "", "min": 1.0, "max": 3.0},
	"crit": {"name": "Critique", "unit": "%", "min": 2.0, "max": 6.0},
	"lifesteal": {"name": "Vol de vie", "unit": "%", "min": 2.0, "max": 5.0},
	"xp_pct": {"name": "XP gagnée", "unit": "%", "min": 4.0, "max": 10.0},
	"credits_pct": {"name": "Crédits", "unit": "%", "min": 5.0, "max": 12.0},
	"drop_pct": {"name": "Butin", "unit": "%", "min": 4.0, "max": 10.0},
}
## Poids de chaque affixe pour comparer deux objets (puissance).
const AFFIX_POWER := {"atk_pct": 3.0, "hp_pct": 2.0, "def_pct": 2.0, "spd": 3.0, "crit": 4.0, "lifesteal": 3.0,
	"xp_pct": 0.5, "credits_pct": 0.5, "drop_pct": 0.5}
const EPITHETS := ["du Cratère Ardent", "de l'Aube Stellaire", "du Vide", "de Helios", "du Trou Noir", "des Anciens"]
const ITEM_ILVL_BONUS := 0.10    # +10 % de stats par niveau d'objet
const ITEM_ILVL_AFFIX := 0.04    # les affixes montent aussi avec le niveau d'objet
const CRIT_MULT := 1.5           # un coup critique fait x1,5 (moyenne déterministe dans les combats)
## AFK : le travail aux postes fabrique le butin du Capitaine et fait gagner de l'XP à l'équipage (hors ligne compris).
const AFK_XP_HOURS_BASE := 1.0      # heures de travail pour passer du niveau L à L+1 : base + par_niveau x L
const AFK_XP_HOURS_PER_LEVEL := 0.25
const AFK_XP_HOURS_QUAD := 0.002     # + quad x L² : la montée de l'équipage ralentit de plus en plus (boucle sur un an)
## Niveau d'AFK = niveaux de l'équipage aux postes + améliorations de postes et de vaisseau. Plus il est haut,
## plus le butin du Capitaine est puissant : rareté (poids ci-dessous par rang de rareté) et niveau d'objet.
const AFK_RARITY_RATE := 0.003
const AFK_RARITY_RANK_FACTOR := [0.0, 0.0, 1.0, 2.0, 2.5]
const AFK_ILVL_DIV := 17.5
const AFK_ILVL_CAP_RATIO := 0.7     # l'Atelier ne dépasse jamais 70 % du niveau du Capitaine : l'AFK aide, il ne remplace pas le RPG
const INVENTORY_MAX := 60
const AUTO_RECYCLE_MAX := 2      # 0 = communs, 1 = jusqu'à peu commun, 2 = jusqu'à rare ; -1 = désactivé

## --- Équipage AFK : production et bonus hors ligne ---
## Production par heure et par niveau d'équipier placé à son poste (même hors ligne).
const CREW_PROD := {
	"pilot": {"minerals": 30.0, "credits": 100.0},
	"engineer": {"energy": 20.0, "credits": 100.0},
	"scientist": {"data": 15.0, "credits": 100.0},
}
const OFFLINE_BASE_EFFICIENCY := 0.5      # rendement hors ligne : 50 %, fixe
const OFFLINE_PREMIUM_EFFICIENCY := 0.7   # 70 % avec le déblocage en Cristaux
const OFFLINE_BASE_HOURS := 4.0           # durée hors ligne comptabilisée
const OFFLINE_HOURS_PER_ENGINEER_LEVEL := 0.1
const OFFLINE_MAX_HOURS := 24.0

const SQUAD_SIZE := 3
const MAX_LEVEL := 999           # pas de plafond pratique
const MAX_STARS := 5
const LEVEL_BONUS := 0.15        # +15 % de stats par niveau
const STAR_BONUS := 0.20         # +20 % de stats par étoile (doublon)
const RECRUIT_BASE := 50.0
const RECRUIT_GROWTH := 1.2
const TRAIN_BASE := 30.0
const TRAIN_GROWTH := 1.38
const LOSS_REWARD := 0.25        # part du butin conservée en cas de défaite
## Niveau des ennemis AFK = 1 + (victoires / ENEMY_WINS_REF) ^ ENEMY_WINS_EXP : il ne monte que sur victoire et ralentit,
## comme la progression de l'équipage (la défaite ne le fait jamais monter).
const ENEMY_WINS_REF := 40.0
const ENEMY_WINS_EXP := 0.8
const ENEMY_DEFEAT_LOSS := 4      # chaque défaite retire 4 victoires du compteur : les ennemis s'adaptent, et un joueur qui pousse gagne environ 80 % du temps
const ENEMY_LEVEL_MAX := 250
const ENEMY_SCALE := 0.12
const BATTLE_MAX_ROUNDS := 60

const DEST_ORDER := ["asteroids", "star", "planet"]
const DEST := {
	"asteroids": {
		"name": "Champ d'astéroïdes", "role": "pilot", "duration": 20.0, "unlock_data": 0.0,
		"enemy": {"kind": "asteroids", "name": "Foreur rebelle", "count": 2, "hp": 120.0, "atk": 18.0, "def": 6.0, "spd": 9.0},
		"rewards": {"minerals": 5.0, "credits": 6.0, "data": 3.0},
	},
	"star": {
		"name": "Étoile naine", "role": "engineer", "duration": 45.0, "unlock_data": 25.0,
		"enemy": {"kind": "star", "name": "Sentinelle solaire", "count": 2, "hp": 220.0, "atk": 26.0, "def": 12.0, "spd": 10.0},
		"rewards": {"energy": 8.0, "credits": 12.0, "data": 6.0},
	},
	"planet": {
		"name": "Planète inconnue", "role": "scientist", "duration": 90.0, "unlock_data": 100.0,
		"enemy": {"kind": "planet", "name": "Créature xéno", "count": 3, "hp": 300.0, "atk": 34.0, "def": 16.0, "spd": 11.0},
		"rewards": {"data": 16.0, "credits": 36.0, "minerals": 3.0, "energy": 2.0},
	},
}

const UPGRADE_ORDER := ["laser", "solar", "scanner", "engines", "docks"]
const PROD_LEVEL_EXP := 0.7     # la production d'un équipier croît moins vite que son niveau
## cost = base * growth^niveau (arrondi au supérieur). bonus = effet par niveau.
const UPGRADES := {
	"laser": {"name": "Laser de minage", "desc": "+25 % minerais par niveau", "max": 20, "growth": 1.85,
		"base": {"credits": 100.0, "minerals": 10.0}},
	"solar": {"name": "Collecteur solaire", "desc": "+25 % énergie par niveau", "max": 20, "growth": 1.85,
		"base": {"credits": 150.0, "energy": 10.0}},
	"scanner": {"name": "Scanner", "desc": "+25 % données par niveau", "max": 20, "growth": 1.85,
		"base": {"credits": 200.0, "minerals": 15.0}},
	"engines": {"name": "Moteurs", "desc": "-5 % de durée par niveau", "max": 20, "growth": 1.85,
		"base": {"credits": 120.0, "minerals": 8.0, "energy": 5.0}},
	"docks": {"name": "Baie d'amarrage", "desc": "Débloque un 2e vaisseau", "max": 1, "growth": 1.0,
		"base": {"credits": 500.0, "minerals": 30.0, "energy": 20.0}},
}

## Objectifs : un palier à atteindre, une récompense à récupérer. Ils donnent un but à chaque retour.
## kind : captain_level, crew_count, data_total, expeditions, epic_item, room_levels, docks, crew_level_sum,
## afk_level, atelier_level, crafted, rooms_min, legendary_item. Récompense "item" : un objet de cette rareté.
const GOALS := [
	{"id": "g1", "name": "Capitaine niveau 2", "kind": "captain_level", "target": 2, "reward": {"credits": 400.0}},
	{"id": "g2", "name": "Posséder 4 cartes d'équipage", "kind": "crew_count", "target": 4, "reward": {"credits": 600.0, "minerals": 30.0}},
	{"id": "g3", "name": "Accumuler 100 données", "kind": "data_total", "target": 100, "reward": {"credits": 800.0, "energy": 40.0}},
	{"id": "g4", "name": "Améliorer la Base (niveaux de salles cumulés : 12)", "kind": "room_levels", "target": 12, "reward": {"credits": 1200.0, "data": 20.0}},
	{"id": "g5", "name": "Lancer 25 expéditions", "kind": "expeditions", "target": 25, "reward": {"credits": 1500.0, "minerals": 60.0}},
	{"id": "g6", "name": "Débloquer le 2e vaisseau", "kind": "docks", "target": 1, "reward": {"credits": 2500.0, "energy": 80.0}},
	{"id": "g7", "name": "Capitaine niveau 4", "kind": "captain_level", "target": 4, "reward": {"credits": 5000.0, "data": 80.0}},
	{"id": "g8", "name": "Obtenir un objet épique", "kind": "epic_item", "target": 1, "reward": {"credits": 6000.0, "minerals": 150.0}},
	{"id": "g9", "name": "Accumuler 1 500 données", "kind": "data_total", "target": 1500, "reward": {"credits": 12000.0, "energy": 200.0}},
	{"id": "g10", "name": "Équipage : niveaux cumulés 40", "kind": "crew_level_sum", "target": 40, "reward": {"credits": 20000.0, "minerals": 300.0}},
	{"id": "g11", "name": "Base : niveaux de salles cumulés 60", "kind": "room_levels", "target": 60, "reward": {"credits": 40000.0, "data": 400.0}},
	{"id": "g12", "name": "Capitaine niveau 7", "kind": "captain_level", "target": 7, "reward": {"credits": 80000.0, "energy": 500.0}},
	{"id": "g13", "name": "Niveau d'AFK 400", "kind": "afk_level", "target": 400, "reward": {"credits": 150000.0, "item": "epic"}},
	{"id": "g14", "name": "Atelier niveau 8", "kind": "atelier_level", "target": 8, "reward": {"credits": 250000.0, "item": "epic"}},
	{"id": "g15", "name": "Fabriquer 1 500 objets à l'Atelier", "kind": "crafted", "target": 1500, "reward": {"credits": 400000.0, "data": 800.0}},
	{"id": "g16", "name": "Niveau d'AFK 900", "kind": "afk_level", "target": 900, "reward": {"credits": 1.5e6, "item": "legendary"}},
	{"id": "g17", "name": "Toutes les salles niveau 10", "kind": "rooms_min", "target": 10, "reward": {"credits": 3.0e6, "item": "epic"}},
	{"id": "g18", "name": "Fabriquer 15 000 objets à l'Atelier", "kind": "crafted", "target": 15000, "reward": {"credits": 6.0e6, "item": "legendary"}},
	{"id": "g19", "name": "Niveau d'AFK 1500", "kind": "afk_level", "target": 1500, "reward": {"credits": 2.0e7, "item": "legendary"}},
	{"id": "g20", "name": "Toutes les salles niveau 18", "kind": "rooms_min", "target": 18, "reward": {"credits": 5.0e7, "item": "legendary"}},
	{"id": "g21", "name": "Niveau d'AFK 2200", "kind": "afk_level", "target": 2200, "reward": {"credits": 2.0e8, "item": "legendary"}},
	{"id": "g22", "name": "Toutes les salles niveau 24", "kind": "rooms_min", "target": 24, "reward": {"credits": 5.0e8, "item": "legendary"}},
]

## Objectifs de refonte : une chaîne à part, accessible dès la première refonte (la chaîne principale peut encore être en cours).
## kind : prestige_count, perk_levels (niveaux de bonus cumulés), prestige_earned (éclats gagnés au total). Récompense "shards" : éclats.
const PRESTIGE_GOALS := [
	{"id": "pg1", "name": "Réaliser une refonte de la Base", "kind": "prestige_count", "target": 1, "reward": {"shards": 3, "item": "epic"}},
	{"id": "pg2", "name": "Bonus permanents : 10 niveaux cumulés", "kind": "perk_levels", "target": 10, "reward": {"shards": 4, "item": "epic"}},
	{"id": "pg3", "name": "Réaliser 3 refontes", "kind": "prestige_count", "target": 3, "reward": {"shards": 8, "item": "legendary"}},
	{"id": "pg4", "name": "Bonus permanents : 30 niveaux cumulés", "kind": "perk_levels", "target": 30, "reward": {"shards": 10, "item": "legendary"}},
	{"id": "pg5", "name": "Réaliser 5 refontes", "kind": "prestige_count", "target": 5, "reward": {"shards": 15, "item": "legendary"}},
	{"id": "pg6", "name": "Gagner 150 éclats par des refontes", "kind": "prestige_earned", "target": 150, "reward": {"shards": 20, "item": "legendary"}},
]

const SYNERGY_PAIR := 0.10
const SYNERGY_FULL := 0.25
const PAIRS := [["pilot", "engineer"], ["engineer", "scientist"], ["scientist", "pilot"]]
## Expéditions : jeu en direct (Capitaine + équipage), en pause hors ligne.
const EXPEDITION_REWARD_MULT := 12.0
const EXPEDITION_CAPTAIN_XP_RATIO := 0.05   # part de l'XP d'une victoire d'anomalie gagnée par victoire d'expédition
const ROLE_GAIN := 0.15          # gains : +15 % par « niveau effectif » du rôle requis (voir role_scale)
const ROLE_SPEED := 0.015        # -1,5 % de durée par niveau du rôle requis
const UPGRADE_GAIN := 0.25
const ENGINE_SPEED := 0.05
const MIN_DURATION_RATIO := 0.4   # une expédition dure au moins 40 % de sa durée de base
const START_CREDITS := 100.0
const BASE_DATA_RATE := 0.1      # données/s des capteurs de bord, même sans Scientifique
const MAX_SLOTS := 2


## Stats d'un héros selon son niveau et ses étoiles.
static func hero_stats(id: String, level: int, stars: int) -> Dictionary:
	var h: Dictionary = HEROES[id]
	var m: float = (1.0 + LEVEL_BONUS * (level - 1)) * (1.0 + STAR_BONUS * stars)
	return {"hp": h.hp * m, "atk": h.atk * m, "def": h.def * m, "spd": h.spd}


const XP_PER_LEVEL := 6500.0     # XP pour passer du niveau L à L+1 : XP_PER_LEVEL x L (courbe douce, sans plafond)


## XP pour passer du niveau L à L+1 du Capitaine : la somme de celle des CAPTAIN_LEVEL_SPAN niveaux de puissance qu'il contient.
static func captain_xp_needed(level: int) -> int:
	var k := CAPTAIN_LEVEL_SPAN
	return int(XP_PER_LEVEL * k * (k * (level - 1) + (k + 1) / 2.0))


static func xp_needed(level: int) -> int:
	return int(XP_PER_LEVEL * level)


static func fmt(n: float) -> String:
	if n >= 1.0e18:
		return "%.2fQi" % (n / 1.0e18)
	if n >= 1.0e15:
		return "%.2fQa" % (n / 1.0e15)
	if n >= 1.0e12:
		return "%.2fT" % (n / 1.0e12)
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
	if d.has("shards"):
		parts.append("+%d éclats" % int(d["shards"]))
	if d.has("item"):
		parts.append("+ 1 objet %s" % String(ITEM_RARITY[d["item"]].name).to_lower())
	return "  ".join(parts)


## --- Laboratoire : recherches en temps réel (c'est elles qui font durer le jeu) ---
## Règles : toujours une recherche courte disponible, plusieurs recherches en parallèle, tout se termine
## même hors ligne, une file d'attente payée d'avance, annulation remboursée.
const RESEARCH_BASE_SLOTS := 1
## Monnaie spéciale (« Cristaux ») : impossible à obtenir en jeu pour le moment, prévue pour un achat plus tard.
## Elle débloque le 3e poste de recherche et la recherche automatique. Tant que PREMIUM_OBTAINABLE est faux, l'interface les montre verrouillés.
const PREMIUM_NAME := "Cristaux"
const PREMIUM_OBTAINABLE := false
const PREMIUM_UNLOCKS := {
	"lab_slot": {"name": "3e poste de recherche", "cost": 300},
	"lab_auto": {"name": "Recherche automatique", "cost": 150},
	"offline_boost": {"name": "Rendement hors ligne 70 %", "cost": 200},
}
const RESEARCH_QUEUE_MAX := 5
## Accélération : retire 25 % de la durée totale d'une recherche, 2 fois au plus (le rythme reste prévisible).
const RESEARCH_BOOST_FRACTION := 0.25
const RESEARCH_BOOST_MAX := 2
const RESEARCH_BOOST_ENERGY_BASE := 20.0      # énergie par minute retirée, + la même chose par niveau de recherche accompli
const RESEARCH_BOOST_ENERGY_PER_LEVEL := 4.0
const RESEARCH_CANCEL_REFUND := 0.7           # part remboursée d'une recherche en cours qu'on annule
const RESEARCH_SPEED_MIN := 0.4               # les durées ne descendent pas sous 40 %

## Pour chaque ressource et pour la durée : [valeur au niveau 1, valeur au dernier niveau] (progression géométrique).
const RESEARCH_ORDER := ["calibrage", "cartographie", "entrainement", "propulsion", "protocoles", "soute", "butin",
	"labo_vitesse", "labo_annexe",
	"calibrage_ii", "cartographie_ii", "entrainement_ii", "propulsion_ii", "butin_ii",
	"calibrage_iii", "cartographie_iii", "entrainement_iii", "propulsion_iii", "butin_iii",
	"calibrage_iv", "cartographie_iv", "propulsion_iv", "butin_iv"]
const RESEARCH := {
	"calibrage": {"name": "Calibrage des systèmes", "icon": "module", "color": Color(1.0, 0.82, 0.35), "max": 25,
		"effect": {"key": "prod_pct", "per": 2.0, "unit": "% de production"},
		"cost": {"credits": [150.0, 400000.0]}, "time": [30.0, 172800.0], "requires": {}},
	"cartographie": {"name": "Cartographie stellaire", "icon": "exp", "color": Color(0.5, 0.95, 1.0), "max": 20,
		"effect": {"key": "reward_pct", "per": 3.0, "unit": "% de gains d'expédition"},
		"cost": {"data": [15.0, 6000000.0]}, "time": [60.0, 691200.0], "requires": {}},
	"entrainement": {"name": "Entraînement accéléré", "icon": "captain", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "xp_pct", "per": 4.0, "unit": "% d'XP gagnée"},
		"cost": {"credits": [120.0, 150000.0], "data": [10.0, 3000000.0]}, "time": [240.0, 518400.0], "requires": {}},
	"propulsion": {"name": "Propulsion ionique", "icon": "ship", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "speed_pct", "per": 3.0, "unit": "% de vitesse d'expédition"},
		"cost": {"energy": [12.0, 3000000.0]}, "time": [120.0, 864000.0], "requires": {"calibrage": 3}},
	"protocoles": {"name": "Protocoles de récupération", "icon": "data", "color": Color(0.75, 0.55, 1.0), "max": 15,
		"effect": {"key": "offline_hours", "per": 0.5, "unit": " h de coffre hors ligne"},
		"cost": {"data": [25.0, 9000000.0], "credits": [100.0, 200000.0]}, "time": [300.0, 1209600.0], "requires": {"calibrage": 4}},
	"soute": {"name": "Soute étendue", "icon": "chest", "color": Color(0.8, 0.7, 0.62), "max": 20,
		"effect": {"key": "offline_hours", "per": 1.0, "unit": " h de coffre hors ligne"},
		"cost": {"minerals": [20.0, 7500000.0]}, "time": [600.0, 1555200.0], "requires": {"protocoles": 2}},
	"butin": {"name": "Détecteur de butin", "icon": "star", "color": Color(1.0, 0.61, 0.93), "max": 10,
		"effect": {"key": "loot_pct", "per": 3.0, "unit": "% de chance de butin"},
		"cost": {"minerals": [30.0, 4500000.0], "energy": [15.0, 2250000.0]}, "time": [900.0, 1036800.0], "requires": {"cartographie": 3}},
	"labo_vitesse": {"name": "Automatisation du labo", "icon": "hourglass", "color": Color(0.5, 0.95, 1.0), "max": 10,
		"effect": {"key": "research_speed", "per": 3.0, "unit": "% de durée des recherches en moins"},
		"cost": {"data": [40.0, 12000000.0], "energy": [20.0, 6000000.0]}, "time": [1800.0, 1728000.0], "requires": {"calibrage": 8}},
	"labo_annexe": {"name": "Laboratoire annexe", "icon": "scientist", "color": Color(0.5, 1.0, 0.6), "max": 1,
		"effect": {"key": "research_slots", "per": 1.0, "unit": " poste de recherche en plus"},
		"cost": {"credits": [20000.0, 2000000.0], "minerals": [200.0, 4500000.0]}, "time": [14400.0, 518400.0], "requires": {"calibrage": 6, "cartographie": 4}},
	"calibrage_ii": {"name": "Calibrage des systèmes II", "icon": "module", "color": Color(1.0, 0.82, 0.35), "max": 25,
		"effect": {"key": "prod_pct", "per": 3.0, "unit": "% de production"},
		"cost": {"credits": [100000.0, 2400000.0]}, "time": [17280.0, 345600.0], "requires": {"calibrage": 25}},
	"calibrage_iii": {"name": "Calibrage des systèmes III", "icon": "module", "color": Color(1.0, 0.82, 0.35), "max": 25,
		"effect": {"key": "prod_pct", "per": 4.0, "unit": "% de production"},
		"cost": {"credits": [600000.0, 12000000.0]}, "time": [34560.0, 518400.0], "requires": {"calibrage_ii": 25}},
	"cartographie_ii": {"name": "Cartographie stellaire II", "icon": "exp", "color": Color(0.5, 0.95, 1.0), "max": 20,
		"effect": {"key": "reward_pct", "per": 4.5, "unit": "% de gains d'expédition"},
		"cost": {"data": [1500000.0, 36000000.0]}, "time": [69120.0, 1382400.0], "requires": {"cartographie": 20}},
	"cartographie_iii": {"name": "Cartographie stellaire III", "icon": "exp", "color": Color(0.5, 0.95, 1.0), "max": 20,
		"effect": {"key": "reward_pct", "per": 6.0, "unit": "% de gains d'expédition"},
		"cost": {"data": [9000000.0, 180000000.0]}, "time": [138240.0, 2073600.0], "requires": {"cartographie_ii": 20}},
	"entrainement_ii": {"name": "Entraînement accéléré II", "icon": "captain", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "xp_pct", "per": 6.0, "unit": "% d'XP gagnée"},
		"cost": {"credits": [37500.0, 900000.0], "data": [750000.0, 18000000.0]}, "time": [51840.0, 1036800.0], "requires": {"entrainement": 15}},
	"entrainement_iii": {"name": "Entraînement accéléré III", "icon": "captain", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "xp_pct", "per": 8.0, "unit": "% d'XP gagnée"},
		"cost": {"credits": [225000.0, 4500000.0], "data": [4500000.0, 90000000.0]}, "time": [103680.0, 1555200.0], "requires": {"entrainement_ii": 15}},
	"propulsion_ii": {"name": "Propulsion ionique II", "icon": "ship", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "speed_pct", "per": 4.5, "unit": "% de vitesse d'expédition"},
		"cost": {"energy": [750000.0, 18000000.0]}, "time": [86400.0, 1728000.0], "requires": {"propulsion": 15}},
	"propulsion_iii": {"name": "Propulsion ionique III", "icon": "ship", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "speed_pct", "per": 6.0, "unit": "% de vitesse d'expédition"},
		"cost": {"energy": [4500000.0, 90000000.0]}, "time": [172800.0, 2592000.0], "requires": {"propulsion_ii": 15}},
	"butin_ii": {"name": "Détecteur de butin II", "icon": "star", "color": Color(1.0, 0.61, 0.93), "max": 10,
		"effect": {"key": "loot_pct", "per": 4.5, "unit": "% de chance de butin"},
		"cost": {"minerals": [1125000.0, 27000000.0], "energy": [562500.0, 13500000.0]}, "time": [103680.0, 2073600.0], "requires": {"butin": 10}},
	"butin_iii": {"name": "Détecteur de butin III", "icon": "star", "color": Color(1.0, 0.61, 0.93), "max": 10,
		"effect": {"key": "loot_pct", "per": 6.0, "unit": "% de chance de butin"},
		"cost": {"minerals": [6750000.0, 135000000.0], "energy": [3375000.0, 67500000.0]}, "time": [207360.0, 3110400.0], "requires": {"butin_ii": 10}},
	"calibrage_iv": {"name": "Calibrage des systèmes IV", "icon": "module", "color": Color(1.0, 0.82, 0.35), "max": 25,
		"effect": {"key": "prod_pct", "per": 5.0, "unit": "% de production"},
		"cost": {"credits": [3000000.0, 60000000.0]}, "time": [69120.0, 1036800.0], "requires": {"calibrage_iii": 25}},
	"cartographie_iv": {"name": "Cartographie stellaire IV", "icon": "exp", "color": Color(0.5, 0.95, 1.0), "max": 20,
		"effect": {"key": "reward_pct", "per": 7.5, "unit": "% de gains d'expédition"},
		"cost": {"data": [45000000.0, 900000000.0]}, "time": [276480.0, 4147200.0], "requires": {"cartographie_iii": 20}},
	"propulsion_iv": {"name": "Propulsion ionique IV", "icon": "ship", "color": Color(0.43, 1.0, 0.61), "max": 15,
		"effect": {"key": "speed_pct", "per": 7.5, "unit": "% de vitesse d'expédition"},
		"cost": {"energy": [22500000.0, 450000000.0]}, "time": [345600.0, 5184000.0], "requires": {"propulsion_iii": 15}},
	"butin_iv": {"name": "Détecteur de butin IV", "icon": "star", "color": Color(1.0, 0.61, 0.93), "max": 10,
		"effect": {"key": "loot_pct", "per": 7.5, "unit": "% de chance de butin"},
		"cost": {"minerals": [33750000.0, 675000000.0], "energy": [16875000.0, 337500000.0]}, "time": [414720.0, 6220800.0], "requires": {"butin_iii": 10}},
}


## Niveau effectif d'un rôle : croît moins vite que la somme des niveaux (sinon les hauts niveaux explosent).
static func role_scale(level: int) -> float:
	return pow(float(level), 0.7)


## Interpolation géométrique entre le niveau 1 et le dernier niveau (lvl = niveau déjà atteint, 0 = premier).
static func research_curve(range_: Array, lvl: int, max_lvl: int) -> float:
	if max_lvl <= 1:
		return range_[0]
	return range_[0] * pow(range_[1] / range_[0], float(lvl) / float(max_lvl - 1))


## --- Anomalies : le contenu actif du Capitaine (XP, crédits, records) ---
## Une faille n : 2 sentinelles et 1 gardien, niveau d'ennemi 2 x n. Entrée = 1 charge (recharge lente, perdue jamais :
## une défaite rend la charge). L'XP du Capitaine ne vient que d'ici.
const ANOMALY_CHARGES_MAX := 100       # réserve de charges
const ANOMALY_COST := 10.0             # charges consommées par une entrée en faille (donc 10 entrées en réserve)
const ANOMALY_REGEN_SECONDS := 150.0   # +1 charge par tranche de 2 min 30 (24 charges par heure : une entrée toutes les 25 min)
const ANOMALY_ENEMY_LEVEL_PER_FAILLE := 2.0
const ANOMALY_BASE := {"hp": 70.0, "atk": 11.0, "def": 4.0, "spd": 11.0}
const ANOMALY_BOSS_HP := 2.2
const ANOMALY_BOSS_ATK := 1.4
const ANOMALY_REF_LEVEL_PER_FAILLE := 2.5
const ANOMALY_RECORD_BONUS := 0.5         # +50 % de crédits quand on bat son record de tours
const ANOMALY_CREDITS := 40.0
const ANOMALY_FIRST_RES := {"data": 30.0, "minerals": 15.0, "energy": 10.0}


## --- La Base : six salles où travaille l'équipage (le jeu AFK) ---
## Une salle = un niveau, un équipier (facultatif pour l'Atelier, les Quartiers, la Soute) et une production.
## Bonus d'équipier : affinité de classe (+25 %) et spécialité de la carte (+50 %), cumulables.
const ROOM_ORDER := ["mine", "centrale", "labo", "atelier", "quartiers", "soute"]
const ROOMS := {
	"mine": {"name": "Mine", "desc": "Minerais et crédits", "affinity": "pilot", "icon": "minerals", "color": Color(0.8, 0.7, 0.62),
		"prod": {"minerals": 17.0, "credits": 20.0}, "cost": {"credits": 300.0, "minerals": 15.0}},
	"centrale": {"name": "Centrale", "desc": "Énergie et crédits", "affinity": "engineer", "icon": "energy", "color": Color(0.75, 0.55, 1.0),
		"prod": {"energy": 11.0, "credits": 20.0}, "cost": {"credits": 300.0, "energy": 10.0}},
	"labo": {"name": "Laboratoire de données", "desc": "Données et crédits", "affinity": "scientist", "icon": "data", "color": Color(0.5, 0.95, 1.0),
		"prod": {"data": 8.5, "credits": 20.0}, "cost": {"credits": 300.0, "data": 8.0}},
	"atelier": {"name": "Atelier", "desc": "Fabrique les objets du Capitaine", "affinity": "engineer", "icon": "engineer", "color": Color(1.0, 0.65, 0.3),
		"prod": {"credits": 8.5}, "cost": {"credits": 350.0, "minerals": 20.0}},
	"quartiers": {"name": "Quartiers", "desc": "XP des équipiers au travail", "affinity": "pilot", "icon": "crew", "color": Color(0.43, 1.0, 0.61),
		"prod": {"credits": 8.5}, "cost": {"credits": 350.0, "data": 10.0}},
	"soute": {"name": "Soute", "desc": "Coffre hors ligne plus long et plus rentable", "affinity": "scientist", "icon": "chest", "color": Color(1.0, 0.82, 0.35),
		"prod": {"credits": 8.5}, "cost": {"credits": 350.0, "energy": 10.0}},
}
## --- Refonte de la Base (prestige) : on remet les salles à zéro pour des bonus permanents plus forts ---
const PRESTIGE_MIN_POWER := 90            # niveaux de salles cumulés minimum pour lancer une refonte
const PRESTIGE_ADVISED_POWER := 120       # valeur indicative à partir de laquelle la refonte vaut vraiment le coup
const PRESTIGE_DIV := 30.0                # éclats gagnés au total = (niveaux de salles cumulés / 30) ^ 2,5
const PRESTIGE_POW := 2.5
const PRESTIGE_ROOM_CAP_PER_RANK := 5     # niveau maximal des salles : +5 par refonte
const PRESTIGE_COST_GROWTH := 1.45        # coût d'un niveau de bonus : 1 éclat au départ, puis x1,45 par niveau
const PRESTIGE_PERK_MAX := 15
const PRESTIGE_PERK_ORDER := ["prod", "xp", "atelier", "craft", "found"]
const PRESTIGE_PERKS := {
	"prod": {"name": "Rendement", "desc": "+12 % de production des salles par niveau", "gain": 0.12, "icon": "credits"},
	"xp": {"name": "Formation", "desc": "+12 % d'XP de l'équipage par niveau", "gain": 0.12, "icon": "crew"},
	"atelier": {"name": "Fabrication", "desc": "+10 % de cadence de l'Atelier par niveau", "gain": 0.10, "icon": "engineer"},
	"craft": {"name": "Qualité", "desc": "+20 de puissance de fabrication par niveau", "gain": 20.0, "icon": "chest"},
	"found": {"name": "Fondations", "desc": "Les salles repartent 2 niveaux plus haut par niveau", "gain": 2.0, "icon": "base"},
}

const ROOM_MAX_LEVEL := 30
const ROOM_COST_GROWTH := 1.75
const ROOM_LEVEL_GAIN := 0.06          # +8 % de production / d'effet par niveau de salle
const ROOM_AFFINITY_BONUS := 0.25
const ROOM_SPECIALTY_BONUS := 0.5
const ROOM_CREW_REF := 30.0            # force d'équipier de référence pour les salles à effet (Atelier, Quartiers, Soute)

## Atelier : cadence de fabrication et ciblage. Cibler un emplacement et/ou un bonus coûte 15 % de cadence chacun.
const ATELIER_BASE_PER_HOUR := 0.8
const ATELIER_TARGET_FACTOR := 0.85
const ATELIER_QUALITY_PER_LEVEL := 3.0     # niveaux d'AFK équivalents par niveau d'Atelier
const QUARTERS_XP_GAIN := 0.03             # +3 % d'XP des équipiers par niveau de Quartiers
const SOUTE_HOURS_GAIN := 0.4              # +0,4 h de coffre par niveau de Soute
