class_name ShipState
extends RefCounted
## État du vaisseau du joueur : niveaux des salles, réserves, chantiers, postes, recherches, entraînement, expéditions.
## Le temps réel fait tout avancer (même jeu fermé) ; `tick()` rattrape le temps écoulé.

const Data = preload("res://scripts/data.gd")

static var clock_offset := 0          # décalage d'horloge (tests et outils)

var unlocked := false
var level := 1                        # niveau du vaisseau = niveau du Pont
var rooms := {}                       # salle -> niveau (0 = pas encore ouverte)
var stock := {}                       # salle -> réserve produite (non récoltée)
var builds: Array = []                # chantiers {room, to, end}
var posts := {}                       # salle -> [héros]
var harvests := 0                     # récoltes faites (objectif du chapitre 1)
var research := {}                    # recherche -> rang
var research_job := {}                # {id, end}
var training := {}                    # héros -> secondes d'entraînement accumulées
var shuttles := {}                    # navette -> {dest, end, hero} (vide = à quai)
var last_tick := 0
var seen_tier := 1                    # dernière version du vaisseau présentée au joueur
var report := {}                      # gains pendant l'absence (écran de retour)


static func now() -> int:
	return int(Time.get_unix_time_from_system()) + clock_offset


func _init() -> void:
	for r in Ship.ORDER:
		rooms[r] = 0
		stock[r] = 0.0
		posts[r] = []
	last_tick = now()


## Les trois salles de départ (Pont, Centrale, Raffinerie) sont construites d'office ; les autres s'ouvrent à un
## niveau du vaisseau mais c'est au joueur de les construire (voir buildable et start_upgrade).
func open_rooms() -> void:
	for r in Ship.ORDER:
		if int(rooms[r]) == 0 and int(Ship.ROOMS[r].unlock) <= 1:
			rooms[r] = 1
	rooms["pont"] = level


## Salle ouverte par le niveau du vaisseau, pas encore construite.
func is_buildable(r: String) -> bool:
	return unlocked and room_level(r) == 0 and level >= int(Ship.ROOMS[r].unlock)


## Salles qu'on peut construire maintenant (sans chantier déjà lancé dessus).
func buildable() -> Array:
	return Ship.ORDER.filter(func(r): return is_buildable(r) and building(r).is_empty())


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	last_tick = now()
	open_rooms()


func tier() -> int:
	return Ship.tier_of(level)


func room_level(r: String) -> int:
	return int(rooms.get(r, 0))


func rank(id: String) -> int:
	return int(research.get(id, 0))


## Bonus de recherche (rang × bonus par rang).
func research_bonus(id: String) -> float:
	return float(Ship.RESEARCH[id].per) * rank(id)


# ---------------------------------------------------------------- production

func workers_bonus(r: String) -> float:
	var b := 0.0
	for h in posts.get(r, []):
		b += Ship.worker_bonus(String(h), r)
	return b


func production_mult(r: String) -> float:
	var pont_crew := workers_bonus("pont") * 0.4
	return (1.0 + Ship.PONT_BONUS * level + pont_crew) * (1.0 + workers_bonus(r)) * (1.0 + research_bonus("rendement"))


## Production par heure d'une salle (dans son unité : éclats, jetons, crédits).
func rate(r: String, best_stage: int) -> float:
	return Ship.base_rate(r, room_level(r), best_stage) * production_mult(r)


func autonomy_hours() -> float:
	return Ship.autonomy_hours(room_level("centrale")) * (1.0 + workers_bonus("centrale") * 0.4)


func capacity(r: String, best_stage: int) -> float:
	return rate(r, best_stage) * autonomy_hours()


func producers() -> Array:
	return Ship.ORDER.filter(func(r): return Ship.ROOMS[r].res != "" and room_level(r) > 0)


## Rattrape le temps écoulé : production, chantiers terminés, recherche, entraînement, expéditions.
## `game` fournit best_stage, les niveaux des héros et l'escouade. Renvoie ce qui s'est passé.
func tick(game: Node, t: int = -1) -> Dictionary:
	if t < 0:
		t = now()
	var out := {"stock": {}, "done": [], "research": "", "trained": {}, "shuttles": [], "lost": {}, "full": {}, "at": {}, "start": last_tick}
	if not unlocked:
		last_tick = t
		return out
	# découpe en étapes aux fins de chantier pour que les nouveaux niveaux produisent à partir de leur fin
	var cuts: Array = []
	for b in builds:
		if int(b.end) <= t:
			cuts.append(int(b.end))
	cuts.sort()
	cuts.append(t)
	var from := last_tick
	for c in cuts:
		if c > from:
			_produce(game, float(c - from), out)
			from = c
		_finish_builds(c, out)
	last_tick = maxi(last_tick, t)
	# recherche
	if not research_job.is_empty() and int(research_job.end) <= t:
		var id := String(research_job.id)
		research[id] = rank(id) + 1
		out.research = id
		out.at["research"] = int(research_job.end)
		research_job = {}
	# expéditions rentrées : signalées, récupérées depuis le Hangar
	for s in shuttles:
		var sh: Dictionary = shuttles[s]
		if not sh.is_empty() and int(sh.end) <= t and not sh.get("back", false):
			sh["back"] = true
			out.shuttles.append(s)
			out.at["shuttle_" + String(s)] = int(sh.end)
	return out


func _produce(game: Node, dt: float, out: Dictionary) -> void:
	for r in producers():
		var cap := capacity(r, int(game.best_stage))
		var before := float(stock.get(r, 0.0))
		var made := rate(r, int(game.best_stage)) * dt / 3600.0
		var after := minf(cap, before + made)
		after = maxf(after, before)
		# réserve pleine : ce qui n'a pas pu être produit (manque à gagner du rapport, maquette XJ)
		if before + made > cap and made > 0.0:
			out.lost[r] = float(out.lost.get(r, 0.0)) + before + made - maxf(cap, before)
			out.full[r] = float(out.full.get(r, 0.0)) + dt * clampf((before + made - maxf(cap, before)) / made, 0.0, 1.0)
		stock[r] = after
		out.stock[r] = float(out.stock.get(r, 0.0)) + (after - before)
	_train(game, dt, out)


func _finish_builds(t: int, out: Dictionary) -> void:
	for b in builds.duplicate():
		if int(b.end) <= t:
			var r := String(b.room)
			if r == "pont":
				level = maxi(level, int(b.to))
				open_rooms()
			else:
				rooms[r] = maxi(room_level(r), int(b.to))
			builds.erase(b)
			out.done.append({"room": r, "to": int(b.to), "end": int(b.end)})


## Entraînement des Quartiers : les héros au repos gagnent un niveau par intervalle, jusqu'au niveau moyen de l'escouade − 3.
func _train(game: Node, dt: float, out: Dictionary) -> void:
	var lv := room_level("quartiers")
	if lv <= 0:
		return
	var step := Ship.train_hours(lv) * 3600.0
	var target := int(game.squad_avg_level()) - 3
	for h in posts.get("quartiers", []):
		var hid := String(h)
		if int(game.levels.get(hid, 1)) >= target:
			training[hid] = 0.0
			continue
		var acc := float(training.get(hid, 0.0)) + dt
		while acc >= step and int(game.levels[hid]) < target:
			acc -= step
			game.levels[hid] = int(game.levels[hid]) + 1
			out.trained[hid] = int(out.trained.get(hid, 0)) + 1
		training[hid] = acc


# ---------------------------------------------------------------- récolte

## Récolte une salle : verse la partie entière de la réserve. Renvoie {res, amount}.
func collect(game: Node, r: String) -> Dictionary:
	var res := String(Ship.ROOMS[r].res)
	var s := float(stock.get(r, 0.0))
	var amount: float = floorf(s) if res != "credits" else roundf(s)
	if amount <= 0.0:
		return {}
	stock[r] = s - amount
	harvests += 1
	if "orders" in game:
		game.orders.track("harvest")
	match res:
		"shards":
			game.shards += int(amount)
		"item_tokens":
			game.item_tokens += int(amount)
		"tokens":
			game.tokens += int(amount)
		"credits":
			game.credits += amount
	return {"res": res, "amount": amount}


func ready_rooms() -> Array:
	return producers().filter(func(r): return floorf(float(stock.get(r, 0.0))) >= 1.0)


func collect_all(game: Node) -> Dictionary:
	var got := {}
	for r in ready_rooms():
		var c := collect(game, r)
		if not c.is_empty():
			got[c.res] = float(got.get(c.res, 0.0)) + float(c.amount)
	return got


# ---------------------------------------------------------------- chantiers

func max_builds() -> int:
	return 2 if level >= 5 else 1


func building(r: String) -> Dictionary:
	for b in builds:
		if String(b.room) == r:
			return b
	return {}


func max_room_level(r: String) -> int:
	return Ship.MAX_LEVEL if r == "pont" else level


## Peut-on améliorer cette salle ? "" si oui, sinon la raison (texte pour le joueur).
func upgrade_block(game: Node, r: String) -> String:
	var lv := room_level(r)
	if lv <= 0 and level < int(Ship.ROOMS[r].unlock):
		return "S’ouvre au niveau %d du vaisseau" % int(Ship.ROOMS[r].unlock)
	if lv >= Ship.MAX_LEVEL:
		return "Niveau maximum"
	if not building(r).is_empty():
		return "Chantier en cours"
	if r != "pont" and lv > 0 and lv >= level:
		return "Monte d’abord le Pont (niveau %d)" % (level + 1)
	if r == "pont" and int(game.best_stage) <= int(Ship.PONT_STAGE[lv + 1]) - 1:
		return "Secteur %d requis" % int(Ship.PONT_STAGE[lv + 1])
	# le Pont a son propre chantier ; les salles se partagent les autres
	var room_builds := builds.filter(func(b): return String(b.room) != "pont").size()
	if r != "pont" and room_builds >= max_builds():
		return "Un chantier à la fois" if max_builds() == 1 else "Deux chantiers à la fois"
	var c := cost_of(game, r)
	if float(game.credits) < float(c.credits) or int(game.shards) < int(c.shards):
		return "Pas assez de ressources"
	return ""


## Coût d'une amélioration pour cette partie : pendant le voyage (chapitre 1), l'Amirauté paie les crédits
## (il n'y a pas encore de combat pour en gagner) ; seuls les éclats de la Raffinerie sont demandés.
func cost_of(game: Node, r: String) -> Dictionary:
	var c := Ship.build_cost(r, rank("logistique")) if room_level(r) == 0 else Ship.upgrade_cost(r, room_level(r) + 1, rank("logistique"))
	if game.has_method("mission_open") and not game.mission_open():
		c.credits = 0
	return c


## Chantier conseillé sur l'accueil (maquette RC) : le Pont d'abord, sinon la salle la moins chère.
## Renvoie {room, ok} (ok : lançable tout de suite) ou {} s'il n'y a rien à proposer.
func advice(game: Node) -> Dictionary:
	var ready: Array = []
	var waiting: Array = []
	for r in Ship.ORDER:
		var b := upgrade_block(game, r)
		if b == "":
			ready.append(r)
		elif b == "Pas assez de ressources":
			waiting.append(r)
	var cost := func(r: String) -> float: return float(cost_of(game, r).credits)
	for lst in [ready, waiting]:
		if lst.is_empty():
			continue
		if lst.has("pont"):
			return {"room": "pont", "ok": lst == ready}
		lst.sort_custom(func(a, b): return cost.call(a) < cost.call(b))
		return {"room": lst[0], "ok": lst == ready}
	return {}


func start_upgrade(game: Node, r: String) -> bool:
	if upgrade_block(game, r) != "":
		return false
	var lv := room_level(r)
	var c := cost_of(game, r)
	game.credits -= float(c.credits)
	game.shards -= int(c.shards)
	builds.append({"room": r, "to": lv + 1, "end": now() + int(c.time)})
	if "orders" in game:
		game.orders.track("upgrade")
	return true


func remaining(end: int) -> int:
	return maxi(0, end - now())


## Termine tout de suite un chantier contre des cristaux.
func rush_build(game: Node, r: String) -> bool:
	var b := building(r)
	if b.is_empty():
		return false
	var cost := Ship.rush_cost(remaining(int(b.end)))
	if int(game.crystals) < cost:
		return false
	game.crystals -= cost
	b.end = now()
	tick(game)
	return true


# ---------------------------------------------------------------- postes

func max_posts(r: String) -> int:
	if r == "quartiers":
		return Ship.beds(room_level(r))
	return Ship.posts(level) if room_level(r) > 0 else 0


func post_of(hid: String) -> String:
	for r in posts:
		if posts[r].has(hid):
			return String(r)
	return ""


## Affecte un héros (hors escouade) à une salle ; il quitte son ancien poste.
func assign(game: Node, hid: String, r: String) -> bool:
	if game.squad_ids().has(hid) or not game.is_owned(hid):
		return false
	if posts[r].size() >= max_posts(r) and not posts[r].has(hid):
		return false
	unassign(hid)
	posts[r].append(hid)
	return true


func unassign(hid: String) -> void:
	for r in posts:
		posts[r].erase(hid)
	training.erase(hid)


## Un héros entré dans l'escouade quitte son poste.
func clean_posts(game: Node) -> void:
	for hid in game.squad_ids():
		unassign(String(hid))


# ---------------------------------------------------------------- recherche

func research_block(game: Node, id: String) -> String:
	var lab := room_level("labo")
	if lab <= 0:
		return "Labo fermé"
	if lab < int(Ship.RESEARCH[id].get("labo", 1)):
		return "Labo niveau %d" % int(Ship.RESEARCH[id].labo)
	if not research_job.is_empty():
		return "Une recherche à la fois"
	if rank(id) >= mini(Ship.research_max(id), lab):
		return ("Acquise" if Ship.research_max(id) == 1 else "Rang maximal") if rank(id) >= Ship.research_max(id) else "Améliore le Labo"
	var c := research_cost(game, id)
	if float(game.credits) < float(c.credits) or int(game.shards) < int(c.shards):
		return "Pas assez de ressources"
	return ""


func research_cost(game: Node, id: String) -> Dictionary:
	var c := Ship.research_cost(id, rank(id) + 1, int(game.best_stage))
	c.time = int(float(c.time) / (1.0 + workers_bonus("labo")))
	return c


func start_research(game: Node, id: String) -> bool:
	if research_block(game, id) != "":
		return false
	var c := research_cost(game, id)
	game.credits -= float(c.credits)
	game.shards -= int(c.shards)
	research_job = {"id": id, "end": now() + int(c.time)}
	return true


func rush_research(game: Node) -> bool:
	if research_job.is_empty():
		return false
	var cost := Ship.rush_cost(remaining(int(research_job.end)))
	if int(game.crystals) < cost:
		return false
	game.crystals -= cost
	research_job.end = now()
	tick(game)
	return true


# ---------------------------------------------------------------- expéditions

func fleet() -> Array:
	return Ship.shuttles_for(room_level("hangar"))


func shuttle_state(s: String) -> Dictionary:
	return shuttles.get(s, {})


func dest_open(game: Node, dest: String, s: String) -> bool:
	var need := int(Ship.DESTS[dest].stage)
	if s == "sterne":
		need = maxi(0, need - 10)
	return int(game.best_stage) > need


func expedition_hours(dest: String, s: String, pilot: String) -> float:
	var h := float(Ship.DESTS[dest].hours) * float(Ship.SHUTTLES[s].time)
	if pilot != "" and String(Data.HEROES.get(pilot, {}).get("job", "")) == "Pilote":
		h *= 0.75
	return h * (1.0 - minf(0.3, workers_bonus("hangar") * 0.2))


func launch(game: Node, s: String, dest: String, pilot: String) -> bool:
	if not fleet().has(s) or not shuttle_state(s).is_empty() or not dest_open(game, dest, s):
		return false
	if pilot != "" and (game.squad_ids().has(pilot) or not game.is_owned(pilot)):
		return false
	shuttles[s] = {"dest": dest, "hero": pilot, "end": now() + int(expedition_hours(dest, s, pilot) * 3600.0)}
	return true


## Récupère une navette rentrée : verse la récompense (bonus de navette), parfois une trouvaille rare.
func claim(game: Node, s: String) -> Dictionary:
	var sh := shuttle_state(s)
	if sh.is_empty() or int(sh.end) > now():
		return {}
	var info: Dictionary = Ship.SHUTTLES[s]
	var rw := Ship.dest_reward(String(sh.dest), int(game.best_stage))
	var loot := float(info.loot)
	var out := {"dest": sh.dest, "hero": sh.get("hero", "")}
	for k in rw:
		if k == "chest":
			var c: Dictionary = game.open_chest(String(rw.chest), int(game.best_stage))
			out["chest"] = c
		elif k == "credits":
			var v: float = roundf(float(rw[k]) * loot)
			game.credits += v
			out[k] = v
		else:
			var n := int(round(float(rw[k]) * loot))
			game.set(k, int(game.get(k)) + n)
			out[k] = n
	if game.rng.randf() < Ship.RARE_FIND * float(info.rare):
		game.wild += Data.EXPEDITION_COPIES
		out["copies"] = Data.EXPEDITION_COPIES
	shuttles.erase(s)
	return out


func rush_shuttle(game: Node, s: String) -> bool:
	var sh := shuttle_state(s)
	if sh.is_empty():
		return false
	var cost := Ship.rush_cost(remaining(int(sh.end)))
	if int(game.crystals) < cost:
		return false
	game.crystals -= cost
	sh.end = now()
	return true


# ---------------------------------------------------------------- sauvegarde

func to_dict() -> Dictionary:
	return {"unlocked": unlocked, "level": level, "rooms": rooms, "stock": stock, "builds": builds, "posts": posts, "research": research,
		"research_job": research_job, "training": training, "shuttles": shuttles, "last_tick": last_tick, "seen_tier": seen_tier, "harvests": harvests}


static func from_dict(d: Dictionary) -> ShipState:
	var s := ShipState.new()
	s.unlocked = bool(d.get("unlocked", false))
	s.harvests = int(d.get("harvests", 0))
	s.level = clampi(int(d.get("level", 1)), 1, Ship.MAX_LEVEL)
	for r in Ship.ORDER:
		s.rooms[r] = clampi(int(d.get("rooms", {}).get(r, 0)), 0, Ship.MAX_LEVEL)
		s.stock[r] = maxf(0.0, float(d.get("stock", {}).get(r, 0.0)))
		var p: Array = []
		for h in d.get("posts", {}).get(r, []):
			if Data.HEROES.has(String(h)):
				p.append(String(h))
		s.posts[r] = p
	for b in d.get("builds", []):
		if Ship.ROOMS.has(String(b.get("room", ""))):
			s.builds.append({"room": String(b.room), "to": int(b.to), "end": int(b.end)})
	for k in d.get("research", {}):
		if Ship.RESEARCH.has(String(k)):
			if Ship.RESEARCH.has(String(k)):
				s.research[String(k)] = clampi(int(d.research[k]), 0, Ship.research_max(String(k)))
	var rj: Dictionary = d.get("research_job", {})
	if not rj.is_empty() and Ship.RESEARCH.has(String(rj.get("id", ""))):
		s.research_job = {"id": String(rj.id), "end": int(rj.end)}
	for k in d.get("training", {}):
		s.training[String(k)] = float(d.training[k])
	for k in d.get("shuttles", {}):
		var sh: Dictionary = d.shuttles[k]
		if Ship.SHUTTLES.has(String(k)) and not sh.is_empty() and Ship.DESTS.has(String(sh.get("dest", ""))):
			s.shuttles[String(k)] = {"dest": String(sh.dest), "hero": String(sh.get("hero", "")), "end": int(sh.end), "back": bool(sh.get("back", false))}
	s.last_tick = int(d.get("last_tick", now()))
	s.seen_tier = clampi(int(d.get("seen_tier", 1)), 1, 5)
	if s.unlocked:
		s.open_rooms()
	return s
