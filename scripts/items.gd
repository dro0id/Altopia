class_name Items
extends RefCounted
## Équipement (branche 4) : quatre emplacements par héros, objets tirés au sort avec bonus simples, ensembles, puissance.
## Un objet est un dictionnaire : id, slot, rarity, name, level, scale, subs [{k, v}], set, on (héros qui le porte), bound (héros auquel il est lié), moves, locked.

const Data = preload("res://scripts/data.gd")

const SLOTS := ["arme", "armure", "module", "relique"]
const SLOT_NAMES := {"arme": "Arme", "armure": "Armure", "module": "Module", "relique": "Relique"}
const SLOT_UNLOCK := {"arme": 1, "armure": 5, "module": 10, "relique": 15}     # niveau du héros qui débloque l'emplacement
const RARITIES := ["commun", "normal", "rare", "epique", "legendaire", "ultime"]
const PCT := {"commun": 0.06, "normal": 0.09, "rare": 0.13, "epique": 0.18, "legendaire": 0.25, "ultime": 0.34}   # part de la statistique de référence
const BONUS_COUNT := {"commun": 0, "normal": 1, "rare": 2, "epique": 3, "legendaire": 3, "ultime": 3}
const MAX_LEVEL := {"commun": 5, "normal": 8, "rare": 12, "epique": 16, "legendaire": 20, "ultime": 24}
const RECYCLE_SHARDS := {"commun": 1, "normal": 2, "rare": 4, "epique": 8, "legendaire": 20, "ultime": 60}
const REF := {"hp": 170.0, "atk": 28.0, "def": 9.0}                          # statistiques moyennes d'un héros de base
const INVENTORY_MAX := 60
const REBIND_COST := 400
const UPGRADE_BASE := 30.0
const PITY_BOSSES := 3                                                      # un objet légendaire au plus tard au 3e gros boss

const NAMES := {
	"arme": ["Pistolet de service", "Carabine de patrouille", "Pistolet à plasma", "Fusil d'assaut mk II", "Lance d'ion prototype", "Canon du Gardien"],
	"armure": ["Gilet pare-éclats", "Plastron composite", "Armure de rempart", "Cuirasse cristalline", "Égide prismatique", "Carapace du Gardien"],
	"module": ["Puce basique", "Module de visée", "Noyau de pouvoir", "Résonateur", "Cœur prismatique", "Matrice de verre"],
	"relique": ["Éclat terni", "Cristal de veille", "Cœur de glace", "Larme de verre", "Cœur de verre", "Étoile brisée"],
}
## Chances d'objet (rareté, poids) selon la rareté du coffre.
const DROPS := {
	"commun": [["commun", 80], ["normal", 20]],
	"normal": [["commun", 50], ["normal", 40], ["rare", 10]],
	"rare": [["normal", 20], ["rare", 60], ["epique", 20]],
	"epique": [["rare", 50], ["epique", 40], ["legendaire", 10]],
	"legendaire": [["epique", 60], ["legendaire", 35], ["ultime", 5]],
	"ultime": [["legendaire", 60], ["ultime", 40]],
}
## Bonus secondaires : clé -> [nom, valeur de base en %, poids de puissance par point].
const BONUS := {
	"crit": ["Critique", 1.0, 60.0],
	"speed": ["Vitesse d'attaque", 1.5, 50.0],
	"boss": ["Dégâts aux boss", 1.5, 35.0],
	"heal": ["Soins", 1.5, 25.0],
	"cdr": ["Recharge des pouvoirs", 1.2, 45.0],
}
const SETS := {
	"prisme": {"name": "Prisme", "color": Color("b388ff"), "b2": "+6 % ATQ", "b4": "+10 % critique et +5 % dégâts aux boss"},
	"bastion": {"name": "Bastion", "color": Color("4fa8ff"), "b2": "+8 % PV", "b4": "+12 % DÉF et bouclier de départ"},
	"sillage": {"name": "Sillage", "color": Color("7dffb0"), "b2": "+5 % vitesse d'attaque", "b4": "Pouvoirs rechargés 10 % plus vite"},
}


static func rarity_index(r: String) -> int:
	return RARITIES.find(r)


## Fait croître les valeurs avec la profondeur : un héros à son niveau conseillé gagne autant à chaque étage.
static func stage_scale(stage: int) -> float:
	return maxf(1.0, Data.hero_mult(Data.recommended_level(maxi(1, stage))))


static func roll_rarity(chest_rarity: String, rng: RandomNumberGenerator) -> String:
	var table: Array = DROPS.get(chest_rarity, DROPS.commun)
	var total := 0.0
	for e in table:
		total += float(e[1])
	var r := rng.randf() * total
	for e in table:
		r -= float(e[1])
		if r <= 0.0:
			return e[0]
	return table[0][0]


static func roll(rng: RandomNumberGenerator, rarity: String, stage: int, slot: String = "", full_bonus := false) -> Dictionary:
	if slot == "":
		slot = SLOTS[rng.randi() % SLOTS.size()]
	var ri := rarity_index(rarity)
	var item := {"slot": slot, "rarity": rarity, "name": NAMES[slot][ri], "level": 1, "scale": stage_scale(stage), "subs": [], "set": "", "on": "", "bound": "", "moves": 0, "locked": false}
	var keys: Array = BONUS.keys()
	for i in int(BONUS_COUNT[rarity]):
		var k: String = keys.pop_at(rng.randi() % keys.size())
		var f := rng.randf_range(0.6, 1.0) if not full_bonus else rng.randf_range(0.85, 1.0)
		item.subs.append({"k": k, "v": snappedf(float(BONUS[k][1]) * (1.0 + 0.9 * ri) * f, 0.5)})
	if ri >= 2:
		item.set = SETS.keys()[rng.randi() % SETS.size()]
	return item


## Statistiques propres à l'objet (valeur principale selon le niveau, bonus secondaires).
static func stats(item: Dictionary) -> Dictionary:
	var out := {"hp": 0.0, "atk": 0.0, "def": 0.0, "skill": 0.0, "crit": 0.0, "speed": 0.0, "boss": 0.0, "heal": 0.0, "cdr": 0.0}
	var p: float = float(PCT[item.rarity]) * float(item.scale) * (1.0 + 0.08 * float(int(item.level) - 1))
	match item.slot:
		"arme":
			out.atk = REF.atk * p
		"armure":
			out.hp = REF.hp * p * 0.7
			out.def = REF.def * p * 0.8
		"module":
			out.skill = float(PCT[item.rarity]) * 0.6 * (1.0 + 0.05 * float(int(item.level) - 1))
		"relique":
			out.hp = REF.hp * p * 0.9
	for s in item.subs:
		out[s.k] += float(s.v) / 100.0 * (1.0 + 0.04 * float(int(item.level) - 1))
	var ri := rarity_index(item.rarity)
	if ri >= 4:
		out.skill += 0.06 if ri == 4 else 0.10          # effet de pouvoir des légendaires et ultimes
	if ri >= 5:
		out.cdr += 0.05
	return out


## Puissance d'un objet : même formule que la puissance d'une escouade, plus le poids des bonus.
static func power(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var s := stats(item)
	var p: float = s.hp * 0.25 + s.atk * 6.0 + s.def * 3.0 + s.skill * 800.0
	for k in BONUS:
		p += float(s[k]) * 100.0 * float(BONUS[k][2]) * 0.1 * float(item.scale)
	return round(p)


## Texte de la valeur principale (« +41 ATQ »).
static func main_text(item: Dictionary) -> String:
	var s := stats(item)
	match item.slot:
		"arme":
			return "+%d ATQ" % int(round(s.atk))
		"armure":
			return "+%d PV · +%d DÉF" % [int(round(s.hp)), int(round(s.def))]
		"module":
			return "+%d %% pouvoir" % int(round((s.skill - (0.06 if rarity_index(item.rarity) == 4 else (0.10 if rarity_index(item.rarity) >= 5 else 0.0))) * 100.0))
	return "+%d PV" % int(round(s.hp))


static func sub_lines(item: Dictionary) -> Array:
	var out: Array = []
	for s in item.subs:
		out.append("+%s %% %s" % [_num(float(s.v)), String(BONUS[s.k][0]).to_lower()])
	return out


static func summary(item: Dictionary) -> String:
	var parts: Array = [main_text(item)]
	parts.append_array(sub_lines(item))
	return " · ".join(parts)


static func _num(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


static func max_level(item: Dictionary) -> int:
	return int(MAX_LEVEL[item.rarity])


static func upgrade_cost(item: Dictionary) -> int:
	var ri := rarity_index(item.rarity)
	return int(round(UPGRADE_BASE * pow(1.4, float(int(item.level))) * (1.0 + 0.1 * ri) * minf(float(item.scale), 40.0) * 0.12 + 40.0))


static func recycle_credits(item: Dictionary) -> int:
	return int(round(40.0 * (1 + rarity_index(item.rarity)) * float(item.level) * 0.5))


static func fuse_cost(result_rarity: String) -> int:
	return 200 * rarity_index(result_rarity)


## Totaux d'un héros : objets portés + bonus d'ensemble. `list` = objets portés par ce héros.
static func totals(list: Array) -> Dictionary:
	var t := {"hp": 0.0, "atk": 0.0, "def": 0.0, "skill": 0.0, "crit": 0.0, "speed": 0.0, "boss": 0.0, "heal": 0.0, "cdr": 0.0, "atk_pct": 0.0, "hp_pct": 0.0, "def_pct": 0.0, "shield0": 0.0}
	var sets := {}
	for it in list:
		var s := stats(it)
		for k in s:
			t[k] += float(s[k])
		if it.set != "":
			sets[it.set] = int(sets.get(it.set, 0)) + 1
	for sid in sets:
		var n: int = sets[sid]
		if n >= 2:
			match sid:
				"prisme":
					t.atk_pct += 0.06
				"bastion":
					t.hp_pct += 0.08
				"sillage":
					t.speed += 0.05
		if n >= 4:
			match sid:
				"prisme":
					t.crit += 0.10
					t.boss += 0.05
				"bastion":
					t.def_pct += 0.12
					t.shield0 += 0.15
				"sillage":
					t.cdr += 0.10
	return t


static func set_counts(list: Array) -> Dictionary:
	var sets := {}
	for it in list:
		if it.set != "":
			sets[it.set] = int(sets.get(it.set, 0)) + 1
	return sets
