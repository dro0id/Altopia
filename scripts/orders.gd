class_name Orders
extends RefCounted
## Ordres de l'Amirauté (maquette WJ) : trois ordres du jour, renouvelés chaque jour (UTC),
## et la solde de la semaine, qui paie des paliers à 3, 6, 9, 12 et 15 ordres remplis.
## Tout se gagne en jouant : les ordres comptent des gestes ordinaires (récolter, lancer un pouvoir…).

## Modèles d'ordres : type d'action suivie, objectif, récompense (ressources qui ne dépendent pas du secteur).
const POOL := [
	{"id": "harvest3", "text": "Récolter trois salles", "kind": "harvest", "goal": 3, "reward": {"shards": 15}},
	{"id": "harvest6", "text": "Récolter six salles", "kind": "harvest", "goal": 6, "reward": {"item_tokens": 2}},
	{"id": "cast10", "text": "Lancer 10 pouvoirs à la main", "kind": "cast", "goal": 10, "reward": {"tokens": 1}},
	{"id": "cast20", "text": "Lancer 20 pouvoirs à la main", "kind": "cast", "goal": 20, "reward": {"tokens": 2}},
	{"id": "clear5", "text": "Vaincre 5 secteurs", "kind": "clear", "goal": 5, "reward": {"shards": 20}},
	{"id": "clear10", "text": "Vaincre 10 secteurs", "kind": "clear", "goal": 10, "reward": {"crystals": 3}},
	{"id": "boss1", "text": "Vaincre un boss", "kind": "boss", "goal": 1, "reward": {"shards": 20}},
	{"id": "interrupt1", "text": "Interrompre ou parer un boss", "kind": "interrupt", "goal": 1, "reward": {"crystals": 2}},
	{"id": "upgrade1", "text": "Lancer un chantier sur l'Aurore", "kind": "upgrade", "goal": 1, "reward": {"shards": 10}},
	{"id": "recruit1", "text": "Recruter une fois", "kind": "recruit", "goal": 1, "reward": {"item_tokens": 1}},
	{"id": "equip2", "text": "Équiper deux objets", "kind": "equip", "goal": 2, "reward": {"shards": 10}},
	{"id": "target3", "text": "Désigner 3 cibles en combat", "kind": "target", "goal": 3, "reward": {"tokens": 1}},
]
## Paliers de la solde : ordres remplis dans la semaine → récompense.
const WEEK := [
	{"at": 3, "reward": {"crystals": 5}},
	{"at": 6, "reward": {"tokens": 3}},
	{"at": 9, "reward": {"copies": 5}},
	{"at": 12, "reward": {"crystals": 10}},
	{"at": 15, "reward": {"crystals": 15, "item_tokens": 6}},
]
const PER_DAY := 3

var day := -1
var list: Array = []          # [{id, progress, claimed}]
var week := -1
var week_done := 0            # ordres remplis et réclamés cette semaine
var week_claimed: Array = []  # paliers déjà versés (valeurs de « at »)


static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


## Semaine commençant le lundi (le 1er janvier 1970 était un jeudi).
static func week_of(d: int) -> int:
	return int(floor(float(d + 3) / 7.0))


static func template(id: String) -> Dictionary:
	for t in POOL:
		if String(t.id) == id:
			return t
	return {}


## Renouvelle les ordres du jour et la solde si le jour ou la semaine ont changé. Renvoie vrai si quelque chose a changé.
func refresh(d: int = -1) -> bool:
	if d < 0:
		d = today()
	var moved := false
	if week_of(d) != week:
		week = week_of(d)
		week_done = 0
		week_claimed = []
		moved = true
	if d != day:
		day = d
		list = []
		# trois types d'action différents, tirés au sort à partir du jour (même tirage pour une même date)
		var rng := RandomNumberGenerator.new()
		rng.seed = d * 7919 + 13
		var pool := POOL.duplicate()
		var kinds := []
		while list.size() < PER_DAY and not pool.is_empty():
			var t: Dictionary = pool.pop_at(rng.randi() % pool.size())
			if kinds.has(t.kind):
				continue
			kinds.append(t.kind)
			list.append({"id": t.id, "progress": 0, "claimed": false})
		moved = true
	return moved


## Une action a eu lieu : les ordres du jour de ce type avancent.
func track(kind: String, n: int = 1) -> void:
	refresh()
	for o in list:
		var t := template(String(o.id))
		if not t.is_empty() and String(t.kind) == kind and not bool(o.claimed):
			o.progress = mini(int(t.goal), int(o.progress) + n)


func is_done(o: Dictionary) -> bool:
	var t := template(String(o.id))
	return not t.is_empty() and int(o.progress) >= int(t.goal)


## Ordres remplis et pas encore réclamés.
func claimable() -> int:
	var n := 0
	for o in list:
		if is_done(o) and not bool(o.claimed):
			n += 1
	return n


## Paliers de la solde atteints et pas encore versés.
func week_claimable() -> Array:
	var out := []
	for w in WEEK:
		if week_done >= int(w.at) and not week_claimed.has(int(w.at)):
			out.append(w)
	return out


## Réclame l'ordre i : verse la récompense ; la solde avance. Renvoie la récompense, vide si impossible.
func claim(i: int, game: Node) -> Dictionary:
	if i < 0 or i >= list.size():
		return {}
	var o: Dictionary = list[i]
	if bool(o.claimed) or not is_done(o):
		return {}
	o.claimed = true
	var rw: Dictionary = template(String(o.id)).reward
	give(rw, game)
	week_done += 1
	# les paliers atteints sont versés tout de suite
	for w in week_claimable():
		week_claimed.append(int(w.at))
		give(w.reward, game)
	return rw


static func give(rw: Dictionary, game: Node) -> void:
	game.shards += int(rw.get("shards", 0))
	game.tokens += int(rw.get("tokens", 0))
	game.item_tokens += int(rw.get("item_tokens", 0))
	game.crystals += int(rw.get("crystals", 0))
	game.wild += int(rw.get("copies", 0))


## Récompense en clair (« 15 éclats », « 1 jeton »…).
static func reward_text(rw: Dictionary) -> String:
	var parts := []
	for k in [["shards", "éclat", "éclats"], ["tokens", "jeton", "jetons"], ["item_tokens", "jeton d'objet", "jetons d'objet"], ["crystals", "cristal", "cristaux"], ["copies", "doublon au choix", "doublons au choix"]]:
		var v := int(rw.get(k[0], 0))
		if v > 0:
			parts.append("%d %s" % [v, k[1] if v == 1 else k[2]])
	return " + ".join(parts)


func to_dict() -> Dictionary:
	return {"day": day, "list": list, "week": week, "week_done": week_done, "week_claimed": week_claimed}


static func from_dict(d: Dictionary) -> Orders:
	var o := Orders.new()
	o.day = int(d.get("day", -1))
	o.week = int(d.get("week", -1))
	o.week_done = int(d.get("week_done", 0))
	for x in d.get("week_claimed", []):
		o.week_claimed.append(int(x))
	for x in d.get("list", []):
		if x is Dictionary and not template(String(x.get("id", ""))).is_empty():
			o.list.append({"id": String(x.id), "progress": int(x.get("progress", 0)), "claimed": bool(x.get("claimed", false))})
	return o
