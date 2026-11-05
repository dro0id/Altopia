class_name Sector
extends RefCounted
## Secteurs générés à l'infini (maquettes FA à FC) : à partir de l'étage 41, chaque secteur de 10 étages
## est tiré d'une graine fixe (son numéro) : nom, couleurs du décor, règle, ennemis d'élite, gros boss titré.
## La difficulté de ces secteurs s'ajuste toute seule pour que le joueur gagne environ 85 % de ses tentatives
## (voir Game.record_generated) ; les récompenses suivent le même facteur.


const EVERY := 10                        # étages par secteur (comme les gros boss)
const BOSSES := ["titan", "sentinelle", "reine"]
const GEN_START := 41                     # premier étage généré (les étages 1 à 40 sont ceux de l'histoire)
const TARGET_WIN := 0.85
## Pas de la difficulté : ×1,04 par victoire, ×0,80 par défaite. Équilibre : 0,85·ln 1,04 + 0,15·ln 0,80 ≈ 0 (85 % de victoires).
const STEP_WIN := 1.04
const STEP_LOSS := 0.80
## Ennemis des secteurs générés : moins de PV et plus d'attaque, pour que les combats se décident vite.
const GEN_HP := 0.6
const GEN_ATK := 1.6
const GEN_BOSS_HP := 0.5                  # gros boss générés : PV divisés par deux en plus
const GROWTH_DAMP := 1.0                  # croissance des PV au-delà de l'étage 40 (1 = comme l'attaque)
const TIME_LIMIT := 180.0                 # au-delà, l'escouade se replie (un combat ne peut pas durer sans fin)
const MIN_FACTOR := 0.02
const MAX_FACTOR := 20.0
## Facteur de difficulté des secteurs générés (copié depuis la partie ; 1 = difficulté de référence).
static var factor := 1.0

const PLACES := ["Abîme", "Récif", "Forêt", "Gouffre", "Nébuleuse", "Faille", "Plaine", "Cathédrale", "Marais", "Jardin", "Mer", "Désert", "Dédale", "Couronne"]
const OF := ["de cendre", "d'ambre", "de prismes", "des échos", "de givre", "de verre noir", "des mites", "stellaire", "d'obsidienne", "des soupirs", "de rouille", "de lumière", "des brumes", "d'argent"]
const BOSS_TITLES := ["la Braise", "l'Écho d'or", "la Verte", "l'Insomnie", "le Givre", "la Couronne brisée", "l'Ancien", "la Rouille", "le Silence", "l'Éclat noir", "la Marée", "le Dernier phare"]

## Couleurs du décor : ciel haut, ciel bas, crêtes lointaines, crêtes proches, sol lointain, sol proche, lignes, planète.
const PALETTES := [
	["0a0302", "2a0f0a", "3d160c", "2a0f08", "1a0805", "3a1a10", "ff7a3a", "c4501c"],
	["0a0702", "2a1d05", "3d2a0a", "2a1d06", "1a1204", "3a2a10", "ffd166", "c49a2c"],
	["020a08", "071f1a", "0c3a30", "082a22", "05150f", "123a30", "7dffb0", "2c9c74"],
	["02040a", "0a1230", "142050", "0e1838", "081020", "182a50", "7fdcff", "3c78c8"],
	["07020a", "1d0a2a", "301445", "220e33", "12081c", "2c1645", "c084ff", "7a3fb5"],
	["0a0204", "2a0a12", "45101e", "330c16", "1c060c", "40121e", "ff6b8a", "b8304e"],
	["06080a", "1a2028", "2a3440", "1e262f", "10141a", "2a323e", "d6e2ff", "8090b0"],
	["020806", "0a2018", "103a2a", "0a2a1e", "061510", "123a28", "b6ff5a", "5a9c2c"],
]

## Règles de secteur : identifiant, glyphe, texte, couleur.
const RULES := [
	["vents", "☄", "Vents solaires : pouvoirs rechargés 15 % plus vite", "ffb142"],
	["blindes", "◈", "Ennemis blindés : DÉF +30 %", "4fa8ff"],
	["gravite", "≋", "Gravité lourde : tout le monde attaque 10 % plus lentement", "7dffb0"],
	["essaim", "✶", "Essaim : un ennemi de plus par vague", "ff9b6b"],
	["aubaine", "¢", "Aubaine : crédits +25 %, ennemis ATQ +10 %", "ffd166"],
	["cristaux", "◇", "Cristaux résonants : critique des héros +10 %", "c084ff"],
	["rage", "!", "Rage : ennemis ATQ +20 %, PV −10 %", "ff6b6b"],
]
const TRAITS := ["Blindé", "Rapide", "Régénérant", "Massif"]
const TRAIT_TEXT := {"Blindé": "DÉF +60 %", "Rapide": "attaque 25 % plus souvent", "Régénérant": "regagne des PV en continu", "Massif": "PV +30 %"}


## Échelle de puissance des ennemis d'un étage (identique à Data.stage_scale jusqu'à l'étage 40).
static func enemy_scale(stage: int, hp := false) -> float:
	var growth := 1.13
	if stage < GEN_START or not hp:
		return pow(growth, float(stage - 1))
	return pow(growth, float(GEN_START - 2) + float(stage - GEN_START + 1) * GROWTH_DAMP)


static func is_generated(stage: int) -> bool:
	return stage >= GEN_START


static func index_of(stage: int) -> int:
	return (stage - 1) / EVERY + 1


static func _rng(k: int, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("altopia-secteur-%d-%d" % [k, salt])
	return r


## Description complète du secteur d'un étage ({} pour les étages de l'histoire).
static func info(stage: int) -> Dictionary:
	if not is_generated(stage):
		return {}
	var k := index_of(stage)
	var r := _rng(k, 1)
	var name := "%s %s" % [PLACES[r.randi() % PLACES.size()], OF[r.randi() % OF.size()]]
	var pal: Array = PALETTES[r.randi() % PALETTES.size()]
	var rule: Array = RULES[r.randi() % RULES.size()]
	var boss_kind: String = BOSSES[r.randi() % BOSSES.size()]
	var title: String = BOSS_TITLES[r.randi() % BOSS_TITLES.size()]
	var trait_name: String = TRAITS[r.randi() % TRAITS.size()]
	var first := (k - 1) * EVERY + 1
	return {"index": k, "name": name, "palette": pal, "rule": rule[0], "rule_glyph": rule[1], "rule_text": rule[2], "rule_color": Color(rule[3]),
		"boss_kind": boss_kind, "boss_title": title, "boss_trait": trait_name, "from": first, "to": first + EVERY - 1,
		"elite_chance": clampf(0.12 + 0.01 * float(k - 5), 0.12, 0.35)}


## Trait d'élite d'un ennemi (ou "") : tiré pour chaque ennemi ordinaire des secteurs générés.
static func roll_elite(stage: int, rng: RandomNumberGenerator) -> String:
	var inf := info(stage)
	if inf.is_empty() or rng.randf() >= float(inf.elite_chance):
		return ""
	return TRAITS[rng.randi() % TRAITS.size()]


## Applique un trait (élite ou boss) à une unité ennemie.
static func apply_trait(u, trait_name: String, is_boss := false) -> void:
	match trait_name:
		"Blindé":
			u.def *= 1.6
		"Rapide":
			u.interval *= 0.75
		"Régénérant":
			u.regen = 0.004 if is_boss else 0.008
		"Massif":
			u.max_hp *= 1.3 if is_boss else 1.8
			u.hp = u.max_hp
