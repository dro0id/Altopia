class_name BoardEvents
extends RefCounted
## Événements à bord (maquette WK) : de temps en temps, un « ! » apparaît sur une salle de l'Aurore.
## Un membre d'équipage raconte, le Capitaine choisit, il y a une conséquence.
## Un événement toutes les 20 à 40 minutes de jeu, trois en attente au plus, chacun expire au bout de 2 h.

const MIN_GAP := 1200.0
const MAX_GAP := 2400.0
const MAX_PENDING := 3
const LIFETIME := 7200

## Modèles : salle où il se passe, qui parle, texte, choix {label, effet}.
## Effets : shards, tokens, item_tokens, crystals, credits_min (minutes de gains de la mission),
## cost_shards (dépense), chance (probabilité que le gain tombe), stock_room + stock_pct (part de réserve perdue).
const POOL := [
	{"id": "clandestin", "room": "serre", "who": "neelo", "title": "Passager clandestin",
		"text": "Capitaine, une mite de verre dort entre deux plants. Elle n’a mordu personne. Pour l’instant.",
		"choices": [{"label": "L’étudier", "fx": {"shards": 15}}, {"label": "La relâcher dehors", "fx": {"item_tokens": 2, "chance": 0.5}}]},
	{"id": "meteores", "room": "centrale", "who": "brix", "title": "Pluie de micrométéorites",
		"text": "Des cailloux grands comme des pois tambourinent sur la coque. Je peux renforcer le blindage, mais ça coûte.",
		"choices": [{"label": "Renforcer", "fx": {"cost_shards": 10, "crystals": 2}}, {"label": "Laisser passer", "fx": {"stock_room": "raffinerie", "stock_pct": 0.5}}]},
	{"id": "terre", "room": "antenne", "who": "sora", "title": "Message de la Terre",
		"text": "L’Antenne capte un colis largué par la Terre. Trois caisses, je ne peux en ramener qu’une.",
		"choices": [{"label": "La caisse bleue", "fx": {"shards": 25}}, {"label": "La caisse violette", "fx": {"tokens": 2}}, {"label": "La caisse dorée", "fx": {"crystals": 6, "chance": 0.4}}]},
	{"id": "course", "room": "quartiers", "who": "kai", "title": "Le défi de Kaï",
		"text": "Course de drones dans la coursive, Capitaine. Je mise sur moi. Vous pariez quelque chose ?",
		"choices": [{"label": "Miser 10 éclats", "fx": {"cost_shards": 10, "shards": 25, "chance": 0.5}}, {"label": "Juste regarder", "fx": {"credits_min": 5}}]},
	{"id": "fuite", "room": "raffinerie", "who": "gorn", "title": "Fuite de verre",
		"text": "Un conduit de la Raffinerie fuit. Du verre liquide partout. Je colmate, ou on récupère ce qui coule ?",
		"choices": [{"label": "Récupérer la fuite", "fx": {"shards": 20, "stock_room": "raffinerie", "stock_pct": 0.3}}, {"label": "Colmater", "fx": {"credits_min": 10}}]},
	{"id": "cargaison", "room": "hangar", "who": "dax", "title": "Cargaison oubliée",
		"text": "Une caisse traînait au fond du Hangar. Pas d’étiquette. Ça cliquette quand on la secoue.",
		"choices": [{"label": "L’ouvrir", "fx": {"item_tokens": 2}}, {"label": "La revendre", "fx": {"credits_min": 20}}]},
	{"id": "visite", "room": "pont", "who": "vance", "title": "Inspection de l’Amirauté",
		"text": "L’Amirauté demande un rapport en direct. Je fais visiter le Pont, ou je leur envoie les chiffres ?",
		"choices": [{"label": "Faire visiter", "fx": {"tokens": 1}}, {"label": "Envoyer les chiffres", "fx": {"shards": 12}}]},
	{"id": "panne", "room": "atelier", "who": "pim", "title": "Le robot de cuisine",
		"text": "J’ai trouvé un vieux robot de cuisine. Je le démonte pour les pièces, ou je le répare ?",
		"choices": [{"label": "Le démonter", "fx": {"item_tokens": 1}}, {"label": "Le réparer", "fx": {"credits_min": 15}}]},
]

var pending: Array = []       # [{id, room, expires}]
var play_t := 0.0             # secondes de jeu depuis le dernier événement
var gap := 1800.0             # attente avant le prochain


static func template(id: String) -> Dictionary:
	for t in POOL:
		if String(t.id) == id:
			return t
	return {}


## Avance le temps de jeu ; fait apparaître un événement quand c'est l'heure. Renvoie l'événement créé, ou {}.
func update(dt: float, ship: ShipState, rng: RandomNumberGenerator, now: int) -> Dictionary:
	pending = pending.filter(func(e): return int(e.expires) > now)
	if not ship.unlocked:
		return {}
	play_t += dt
	if play_t < gap or pending.size() >= MAX_PENDING:
		return {}
	play_t = 0.0
	gap = rng.randf_range(MIN_GAP, MAX_GAP)
	return spawn(ship, rng, now)


## Crée un événement dans une salle construite qui n'en a pas déjà un.
func spawn(ship: ShipState, rng: RandomNumberGenerator, now: int) -> Dictionary:
	var taken := pending.map(func(e): return String(e.room))
	var ok := POOL.filter(func(t): return ship.room_level(String(t.room)) > 0 and not taken.has(String(t.room)))
	if ok.is_empty():
		return {}
	var t: Dictionary = ok[rng.randi() % ok.size()]
	var e := {"id": t.id, "room": t.room, "expires": now + LIFETIME}
	pending.append(e)
	return e


func at_room(room: String) -> Dictionary:
	for e in pending:
		if String(e.room) == room:
			return e
	return {}


## Applique le choix `i` de l'événement ; renvoie le texte de la conséquence, "" si impossible.
func resolve(e: Dictionary, i: int, game: Node, rng: RandomNumberGenerator) -> String:
	var t := template(String(e.id))
	if t.is_empty() or i < 0 or i >= t.choices.size() or not pending.has(e):
		return ""
	var fx: Dictionary = t.choices[i].fx
	if int(fx.get("cost_shards", 0)) > int(game.shards):
		return "Pas assez d’éclats"
	pending.erase(e)
	game.shards -= int(fx.get("cost_shards", 0))
	var parts := []
	if int(fx.get("cost_shards", 0)) > 0:
		parts.append("−%d éclats" % int(fx.cost_shards))
	if fx.has("stock_room"):
		var r := String(fx.stock_room)
		var v := float(game.ship.stock.get(r, 0.0))
		var lost := floorf(v * float(fx.stock_pct))
		game.ship.stock[r] = v - lost
		if lost >= 1.0:
			parts.append("−%d en réserve (%s)" % [int(lost), Ship.ROOMS[r].short])
	var lucky := rng.randf() < float(fx.get("chance", 1.0))
	if not lucky:
		parts.append("pas de chance cette fois")
		return " · ".join(parts)
	var rw := {}
	for k in ["shards", "tokens", "item_tokens", "crystals"]:
		if int(fx.get(k, 0)) > 0:
			rw[k] = int(fx[k])
	Orders.give(rw, game)
	if rw.size() > 0:
		parts.append("+" + Orders.reward_text(rw))
	if int(fx.get("credits_min", 0)) > 0:
		var cr: float = float(game.offline_rate_per_minute()) * float(fx.credits_min)
		game.credits += cr
		parts.append("+%s crédits" % UI.num(cr))
	return " · ".join(parts)


## Ce que promet un choix, en clair, pour le bouton.
static func choice_text(c: Dictionary) -> String:
	var fx: Dictionary = c.fx
	var bits := []
	var rw := {}
	for k in ["shards", "tokens", "item_tokens", "crystals"]:
		if int(fx.get(k, 0)) > 0:
			rw[k] = int(fx[k])
	if not rw.is_empty():
		bits.append("+" + Orders.reward_text(rw))
	if int(fx.get("credits_min", 0)) > 0:
		bits.append("crédits")
	if fx.has("chance"):
		bits.append("1 chance sur 2" if is_equal_approx(float(fx.chance), 0.5) else "%d %% de chances" % int(round(float(fx.chance) * 100.0)))
	if int(fx.get("cost_shards", 0)) > 0:
		bits.append("coûte %d éclats" % int(fx.cost_shards))
	if fx.has("stock_room"):
		bits.append("perd %d %% de réserve" % int(float(fx.stock_pct) * 100.0))
	return String(c.label) + (" · " + ", ".join(bits) if not bits.is_empty() else "")


func to_dict() -> Dictionary:
	return {"pending": pending, "play_t": play_t, "gap": gap}


static func from_dict(d: Dictionary) -> BoardEvents:
	var b := BoardEvents.new()
	b.play_t = float(d.get("play_t", 0.0))
	b.gap = float(d.get("gap", 1800.0))
	for e in d.get("pending", []):
		if e is Dictionary and not template(String(e.get("id", ""))).is_empty():
			b.pending.append({"id": String(e.id), "room": String(e.room), "expires": int(e.expires)})
	return b
