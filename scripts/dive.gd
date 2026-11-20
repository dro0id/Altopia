class_name Dive
extends RefCounted

const Data = preload("res://scripts/data.gd")
## La Plongée (maquette WL) : une descente à embranchements sur 12 profondeurs, remise à zéro chaque semaine.
## On choisit sa route ; les PV ne remontent pas, un héros tombé reste à terre et un remplaçant descend.
## Les combats se jouent en automatique (BattleSim), leurs blessures sont reportées sur la descente.

const DEPTHS := 12
const KINDS := {
	"combat": {"name": "Combat", "glyph": "⚔"},
	"elite": {"name": "Élite", "glyph": "★"},
	"rencontre": {"name": "Rencontre", "glyph": "?"},
	"repos": {"name": "Repos", "glyph": "✚"},
	"cache": {"name": "Cache", "glyph": "◆"},
	"boss": {"name": "Boss", "glyph": "☠"},
}
const RELICS := {
	"prisme": {"name": "Prisme de rage", "desc": "ATK +15 %", "col": Color("b388ff")},
	"braise": {"name": "Braise vive", "desc": "dégâts aux boss +25 %", "col": Color("ff8a4a")},
	"onde": {"name": "Onde claire", "desc": "pouvoirs 20 % plus rapides", "col": Color("4fd8ff")},
	"carapace": {"name": "Carapace", "desc": "bouclier de 10 % au départ", "col": Color("ffd166")},
	"seve": {"name": "Sève", "desc": "soins +25 %", "col": Color("7dffb0")},
	"rempart": {"name": "Rempart", "desc": "DÉF +25 %", "col": Color("c8d4e6")},
	"coeur": {"name": "Cœur de verre", "desc": "+10 % PV après chaque combat", "col": Color("ff7ad9")},
	"filon": {"name": "Filon", "desc": "récompenses +30 %", "col": Color("ffb142")},
}
const REST_HEAL := 0.4

var week := -1
var rows: Array = []          # profondeur -> [{kind, col, links: [colonnes de la profondeur suivante]}]
var depth := 0                # dernière profondeur franchie (0 = au départ)
var pos := -1                 # colonne du nœud franchi
var path: Array = []          # colonnes franchies, profondeur par profondeur
var hp := {}                  # héros -> PV restants (part)
var fallen: Array = []
var relics: Array = []
var offer: Array = []         # reliques proposées après une élite (une parmi trois)
var done := false
var earned := {}              # récompenses versées pendant la descente


static func this_week() -> int:
	return int((Time.get_unix_time_from_system() + 3 * 86400.0) / 604800.0)   # semaine qui commence le lundi


## Nouvelle descente pour la semaine : la carte est la même pour une semaine donnée.
func reset(w: int) -> void:
	week = w
	depth = 0
	pos = -1
	path = []
	hp = {}
	fallen = []
	relics = []
	offer = []
	done = false
	earned = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 7919 + 17
	rows = []
	for d in DEPTHS:
		var n := 1 if d == 0 or d == DEPTHS - 1 else (2 if rng.randf() < 0.45 else 3)
		var cols: Array = [1] if n == 1 else ([0, 2] if n == 2 else [0, 1, 2])
		var row := []
		for c in cols:
			row.append({"kind": _roll_kind(d, rng), "col": c, "links": []})
		rows.append(row)
	# chaque nœud mène aux nœuds voisins de la profondeur suivante (au moins un)
	for d in DEPTHS - 1:
		for nd in rows[d]:
			for nx in rows[d + 1]:
				if absi(int(nd.col) - int(nx.col)) <= 1:
					nd.links.append(int(nx.col))
			# élaguer : une route sur deux environ, pour que le choix compte
			var keep: Array = nd.links.duplicate()
			while keep.size() > 1 and rng.randf() < 0.55:
				keep.remove_at(rng.randi() % keep.size())
			nd.links = keep
			if nd.links.is_empty():
				nd.links.append(int(rows[d + 1][0].col))
		# et chaque nœud suivant est atteignable
		for nx in rows[d + 1]:
			var reached := false
			for nd in rows[d]:
				if (nd.links as Array).has(int(nx.col)):
					reached = true
			if not reached:
				var near: Dictionary = rows[d][0]
				for nd in rows[d]:
					if absi(int(nd.col) - int(nx.col)) < absi(int(near.col) - int(nx.col)):
						near = nd
				near.links.append(int(nx.col))


static func _roll_kind(d: int, rng: RandomNumberGenerator) -> String:
	if d == 0:
		return "combat"
	if d == DEPTHS - 1:
		return "boss"
	var r := rng.randf()
	if d >= 3 and r < 0.18:
		return "elite"
	if r < 0.30:
		return "rencontre"
	if r < 0.40 and d >= 2:
		return "repos"
	if r < 0.50:
		return "cache"
	return "combat"


## Nœud à la profondeur d (index 0) et colonne c.
func node(d: int, c: int) -> Dictionary:
	if d < 0 or d >= rows.size():
		return {}
	for nd in rows[d]:
		if int(nd.col) == c:
			return nd
	return {}


## Colonnes atteignables à la profondeur suivante.
func next_cols() -> Array:
	if done or not offer.is_empty():
		return []
	if depth == 0:
		return rows[0].map(func(nd): return int(nd.col))
	return (node(depth - 1, pos).get("links", []) as Array).duplicate()


## Héros qui descendent : l'escouade, puis les remplaçants (les plus hauts niveaux) à la place des tombés.
func team_ids(g: Node) -> Array:
	var out: Array = []
	for id in g.squad_ids():
		if not fallen.has(id):
			out.append(id)
	var bench: Array = Data.ALL_HEROES.filter(func(id): return g.is_owned(id) and not fallen.has(id) and not out.has(id))
	bench.sort_custom(func(a, b): return int(g.levels[a]) > int(g.levels[b]))
	while out.size() < Data.SQUAD_SIZE and not bench.is_empty():
		out.append(bench.pop_front())
	return out


func hp_of(id: String) -> float:
	return float(hp.get(id, 1.0))


## Étage simulé à une profondeur : un peu sous le record, et de plus en plus dur.
static func stage_for(g: Node, d: int, kind: String) -> int:
	var base := maxi(3, int(g.best_stage) - 8)
	var s := base + d / 2
	if kind == "elite":
		s += 2
	elif kind == "boss":
		s += 4
	return s


## Récompense d'un nœud franchi.
func reward_for(g: Node, d: int, kind: String) -> Dictionary:
	var k := 1.3 if relics.has("filon") else 1.0
	var st := stage_for(g, d, kind)
	match kind:
		"boss":
			return {"credits": roundf(120.0 * Data.stage_scale(st) * k), "crystals": 20, "tokens": 1, "shards": int(30 * k)}
		"elite":
			return {"credits": roundf(40.0 * Data.stage_scale(st) * k), "shards": int((6 + d) * k)}
		"cache":
			return {"credits": roundf(30.0 * Data.stage_scale(st) * k), "shards": int((4 + d) * k), "item_tokens": 1 if d >= 6 else 0}
		"combat":
			return {"credits": roundf(20.0 * Data.stage_scale(st) * k), "shards": int((2 + d / 2) * k)}
	return {}


func _give(g: Node, rw: Dictionary) -> void:
	for key in rw:
		if key == "credits":
			g.credits += float(rw[key])
		else:
			g.set(key, int(g.get(key)) + int(rw[key]))
		earned[key] = earned.get(key, 0) + rw[key]


## Avance sur le nœud (d = depth, colonne c). Renvoie un rapport {kind, ok, text, fell, rw}.
func enter(g: Node, c: int, seed: int = 0) -> Dictionary:
	if not next_cols().has(c):
		return {}
	var d := depth
	var nd := node(d, c)
	var kind := String(nd.kind)
	var out := {"kind": kind, "ok": true, "text": "", "fell": [], "rw": {}}
	match kind:
		"combat", "elite", "boss":
			var sim := prepare(g, d, kind, seed)
			if sim == null:
				out.ok = false
				return out
			sim.run(300.0)
			return resolve(g, c, sim, sim.state == "clear", seed)
		"repos":
			for id in team_ids(g):
				hp[id] = minf(1.0, hp_of(id) + REST_HEAL)
			out.text = "Repos : l’escouade récupère 40 % de PV"
		"rencontre":
			var rng := RandomNumberGenerator.new()
			rng.seed = week * 31 + d * 7 + c
			var r := rng.randf()
			if r < 0.3:
				var pick: Array = _roll_offer(week + d)
				relics.append(String(pick[0]))
				out.text = "Une épave : relique « %s »" % RELICS[pick[0]].name
			elif r < 0.6:
				for id in team_ids(g):
					hp[id] = minf(1.0, hp_of(id) + 0.25)
				out.text = "Une source de verre tiède : +25 % de PV"
			elif r < 0.8:
				out.rw = {"shards": 8 + d}
				out.text = "Un éclat oublié : +%d éclats" % (8 + d)
			else:
				for id in team_ids(g):
					hp[id] = maxf(0.05, hp_of(id) - 0.15)
				out.text = "Un éboulis : −15 % de PV"
	var rw: Dictionary = out.rw if not (out.rw as Dictionary).is_empty() else reward_for(g, d, kind)
	_give(g, rw)
	out.rw = rw
	depth = d + 1
	pos = c
	path.append(c)
	return out


## Le combat d'un nœud est-il un combat ? (il se joue alors à l'écran, voir main.gd)
func is_fight(c: int) -> bool:
	return String(node(depth, c).get("kind", "")) in ["combat", "elite", "boss"]


## Combat d'un nœud prêt à jouer : PV de la descente et reliques appliqués.
func prepare(g: Node, d: int, kind: String, seed: int = 0) -> BattleSim:
	var ids := team_ids(g)
	if ids.is_empty():
		return null
	var sim := BattleSim.new(g.team_of(ids), stage_for(g, d, kind), seed + week * 101 + d)
	for u in sim.allies():
		u.hp = u.max_hp * hp_of(u.id)
		if relics.has("prisme"):
			u.atk *= 1.15
		if relics.has("braise"):
			u.boss_dmg += 0.25
		if relics.has("onde"):
			u.skill_max *= 0.8
		if relics.has("carapace"):
			u.shield = maxf(u.shield, u.max_hp * 0.1)
			u.shield_t = maxf(u.shield_t, 8.0)
		if relics.has("seve"):
			u.heal_mult *= 1.25
		if relics.has("rempart"):
			u.def *= 1.25
	return sim


## Blessures d'un combat reportées sur la descente ; renvoie les héros tombés.
func wounds(sim: BattleSim, won: bool) -> Array:
	var fell := []
	for u in sim.allies():
		if not u.alive:
			fallen.append(u.id)
			hp.erase(u.id)
			fell.append(u.id)
		else:
			hp[u.id] = clampf(u.hp / u.max_hp + (0.1 if relics.has("coeur") and won else 0.0), 0.05, 1.0)
	return fell


## Fin d'un combat de nœud (colonne c), joué à l'écran ou en automatique : rapport comme enter().
func resolve(g: Node, c: int, sim: BattleSim, won: bool, seed: int = 0) -> Dictionary:
	var d := depth
	var kind := String(node(d, c).get("kind", "combat"))
	var fell := wounds(sim, won)
	var out := {"kind": kind, "ok": won, "text": "", "fell": fell, "rw": {}}
	var names := ", ".join(fell.map(func(i): return String(Data.HEROES[i].name).split(" ")[0]))
	if not won:
		out.text = "L’escouade est repoussée" + (" · %s à terre" % names if not fell.is_empty() else "") + " : les remplaçants reprendront ce nœud."
		return out
	out.text = "Victoire" + (" · %s tombe" % names if not fell.is_empty() else "")
	if kind == "elite":
		offer = _roll_offer(seed + d)
	if kind == "boss":
		done = true
	var rw := reward_for(g, d, kind)
	_give(g, rw)
	out.rw = rw
	depth = d + 1
	pos = c
	path.append(c)
	return out


func _roll_offer(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 13 + week
	var pool: Array = RELICS.keys().filter(func(k): return not relics.has(k))
	var out := []
	while out.size() < 3 and not pool.is_empty():
		out.append(pool.pop_at(rng.randi() % pool.size()))
	return out


func take_relic(id: String) -> void:
	if offer.has(id):
		relics.append(id)
		offer = []


## Plus personne pour descendre : la descente s'arrête là.
func stuck(g: Node) -> bool:
	return not done and team_ids(g).is_empty()


func to_dict() -> Dictionary:
	return {"week": week, "rows": rows, "depth": depth, "pos": pos, "path": path, "hp": hp, "fallen": fallen, "relics": relics, "offer": offer, "done": done, "earned": earned}


static func from_dict(d: Dictionary) -> Dive:
	var v := Dive.new()
	v.week = int(d.get("week", -1))
	v.rows = Array(d.get("rows", []))
	for row in v.rows:
		for nd in row:
			nd.col = int(nd.col)
			nd.links = (nd.links as Array).map(func(x): return int(x))
	v.depth = int(d.get("depth", 0))
	v.pos = int(d.get("pos", -1))
	v.path = Array(d.get("path", [])).map(func(x): return int(x))
	v.hp = d.get("hp", {})
	v.fallen = Array(d.get("fallen", []))
	v.relics = Array(d.get("relics", []))
	v.offer = Array(d.get("offer", []))
	v.done = bool(d.get("done", false))
	v.earned = d.get("earned", {})
	return v
