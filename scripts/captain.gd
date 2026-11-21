class_name Captain
extends RefCounted
## Grade et doctrine du Capitaine (maquette WN) : tout ce que fait le joueur rapporte de l'expérience de
## commandement ; un point par grade, à placer dans l'une des trois branches, redistribuable.

const BRANCHES := [
	{"id": "offensive", "name": "OFFENSIVE", "col": Color("ff6b6b"), "nodes": [
		{"id": "feu", "name": "Feu concentré", "desc": "+5 % sur la cible désignée"},
		{"id": "enchainement", "name": "Enchaînement", "desc": "combos : 4 s au lieu de 3"},
		{"id": "brise", "name": "Brise-garde", "desc": "boss exposé 1 s de plus"},
		{"id": "salve", "name": "Salve d’ouverture", "desc": "pouvoirs à 75 % au départ"},
	]},
	{"id": "defensive", "name": "DÉFENSIVE", "col": Color("4fd8ff"), "nodes": [
		{"id": "sangfroid", "name": "Sang-froid", "desc": "−5 % de dégâts subis"},
		{"id": "seconde", "name": "Seconde ligne", "desc": "+10 % PV des soutiens"},
		{"id": "parade", "name": "Parade ferme", "desc": "parade : soin de 5 %"},
		{"id": "carre", "name": "Dernier carré", "desc": "un héros survit à 1 PV"},
	]},
	{"id": "intendance", "name": "INTENDANCE", "col": Color("7dffb0"), "nodes": [
		{"id": "bonvent", "name": "Bon vent", "desc": "chantiers −5 %"},
		{"id": "soutes", "name": "Soutes pleines", "desc": "réserves +10 %"},
		{"id": "veille", "name": "Longue veille", "desc": "+1 h hors ligne"},
		{"id": "soude", "name": "Équipage soudé", "desc": "postes +5 %"},
	]},
]
## Expérience par geste.
const XP := {"clear": 8, "big_boss": 20, "harvest": 3, "order": 15, "event": 10, "boarding": 25}


## Expérience pour passer du grade g au suivant.
static func need(g: int) -> int:
	return 40 + 20 * g


static func grade_of(xp: int) -> int:
	var g := 1
	var left := xp
	while left >= need(g):
		left -= need(g)
		g += 1
	return g


## Progression dans le grade en cours : [gagné, nécessaire].
static func progress(xp: int) -> Array:
	var g := 1
	var left := xp
	while left >= need(g):
		left -= need(g)
		g += 1
	return [left, need(g)]


static func title(g: int) -> String:
	if g >= 30:
		return "Amiral"
	if g >= 10:
		return "Commodore"
	return "Capitaine"


static func points(g: int) -> int:
	return g - 1


static func node(id: String) -> Dictionary:
	for b in BRANCHES:
		for n in b.nodes:
			if String(n.id) == id:
				return n
	return {}


## Un nœud se prend dans l'ordre de sa branche, s'il reste un point.
static func can_take(id: String, doctrine: Array, g: int) -> bool:
	if doctrine.has(id) or doctrine.size() >= points(g):
		return false
	for b in BRANCHES:
		var ids: Array = b.nodes.map(func(n): return String(n.id))
		var i := ids.find(id)
		if i >= 0:
			return i == 0 or doctrine.has(ids[i - 1])
	return false


## Retirer un nœud retire aussi ceux qui le suivent dans sa branche (redistribuable).
static func drop(id: String, doctrine: Array) -> Array:
	var out := doctrine.duplicate()
	for b in BRANCHES:
		var ids: Array = b.nodes.map(func(n): return String(n.id))
		var i := ids.find(id)
		if i >= 0:
			for k in range(i, ids.size()):
				out.erase(ids[k])
	return out
