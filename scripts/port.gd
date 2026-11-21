class_name Port
extends RefCounted
## Port-Altopia, la Base (maquette WO, version de départ) : après l'histoire, le vaisseau descend et la Base
## grandit. Six districts, bâtis avec le verre brut rapporté des secteurs générés ; chacun a un effet simple.

const Data = preload("res://scripts/data.gd")

const DISTRICTS := {
	"domes": {"name": "Dômes", "col": Color("7dffb0"), "desc": "gains hors ligne +5 % par niveau", "pos3": Vector2(-3.4, -1.6)},
	"fonderie": {"name": "Fonderie", "col": Color("ff9f6b"), "desc": "forge un jeton d’objet toutes les 24 h (plus vite par niveau)", "pos3": Vector2(-0.6, -3.6)},
	"academie": {"name": "Académie", "col": Color("b388ff"), "desc": "entraînement des Quartiers +20 % par niveau", "pos3": Vector2(1.6, -1.2)},
	"marche": {"name": "Marché", "col": Color("ffd166"), "desc": "échanger 40 éclats contre un jeton de recrutement (une fois par jour et par niveau)", "pos3": Vector2(4.6, 0.8)},
	"phare": {"name": "Phare", "col": Color("4fd8ff"), "desc": "visiteurs : événements à bord +15 % par niveau", "pos3": Vector2(-5.4, 1.4)},
	"arene": {"name": "Arène", "col": Color("ff6b6b"), "desc": "une escouade rivale par jour : cristaux et verre", "pos3": Vector2(-1.4, 1.6)},
	"jardins": {"name": "Jardins", "col": Color("9dff6b"), "desc": "œufs de familier : éclosion 20 % plus rapide et +5 % de chance par niveau", "pos3": Vector2(1.8, 3.8)},
	"archives": {"name": "Archives", "col": Color("8ec5ff"), "desc": "expérience du Capitaine +10 % par niveau", "pos3": Vector2(-3.8, 4.4)},
}
const ORDER := ["domes", "fonderie", "academie", "marche", "phare", "arene", "jardins", "archives"]
const SLOTS := 8
const MAX_LV := 5


static func open(g: Node) -> bool:
	return (g.chapters_done as Array).has(5) or int(g.best_stage) > Data.LAST_STORY_BOSS


static func lv(g: Node, d: String) -> int:
	return int((g.port.get("lv", {}) as Dictionary).get(d, 0))


static func built(g: Node) -> int:
	var n := 0
	for d in ORDER:
		if lv(g, d) > 0:
			n += 1
	return n


## Coût du niveau suivant : verre brut et crédits.
static func cost(g: Node, d: String) -> Dictionary:
	var n := lv(g, d) + 1
	return {"glass": 4 * n * n, "credits": roundf(150.0 * Data.stage_scale(maxi(10, int(g.best_stage))) * n)}


static func can_build(g: Node, d: String) -> bool:
	if lv(g, d) >= MAX_LV:
		return false
	var c := cost(g, d)
	return int(g.glass) >= int(c.glass) and float(g.credits) >= float(c.credits)


static func build(g: Node, d: String) -> bool:
	if not can_build(g, d):
		return false
	var c := cost(g, d)
	g.glass -= int(c.glass)
	g.credits -= float(c.credits)
	var l: Dictionary = g.port.get("lv", {})
	l[d] = lv(g, d) + 1
	g.port["lv"] = l
	if d == "fonderie" and lv(g, d) == 1:
		g.port["forge_t"] = int(Time.get_unix_time_from_system())
	return true


## Verre brut d'un secteur généré gagné.
static func glass_for(stage: int) -> int:
	return 1 + maxi(0, stage - Data.LAST_STORY_BOSS) / 15


# ---------------------------------------------------------------- effets

static func offline_mult(g: Node) -> float:
	return 1.0 + 0.05 * lv(g, "domes")


static func train_mult(g: Node) -> float:
	return 1.0 + 0.2 * lv(g, "academie")


static func hatch_mult(g: Node) -> float:
	return 1.0 + 0.2 * lv(g, "jardins")


static func egg_bonus(g: Node) -> float:
	return 0.05 * lv(g, "jardins")


static func xp_mult(g: Node) -> float:
	return 1.0 + 0.1 * lv(g, "archives")


static func event_mult(g: Node) -> float:
	return 1.0 + 0.15 * lv(g, "phare")


## Fonderie : heures par jeton (24 h au niveau 1, puis plus vite).
static func forge_hours(g: Node) -> float:
	return 24.0 / (1.0 + 0.25 * float(lv(g, "fonderie") - 1))


## Jetons forgés en attente.
static func forge_ready(g: Node) -> int:
	if lv(g, "fonderie") <= 0:
		return 0
	var t0 := int(g.port.get("forge_t", 0))
	return mini(3, int((Time.get_unix_time_from_system() - t0) / (forge_hours(g) * 3600.0)))


static func forge_claim(g: Node) -> int:
	var n := forge_ready(g)
	if n <= 0:
		return 0
	g.item_tokens += n
	g.port["forge_t"] = int(Time.get_unix_time_from_system())
	return n


static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


static func trades_left(g: Node) -> int:
	if lv(g, "marche") <= 0:
		return 0
	var used := int(g.port.get("market_n", 0)) if int(g.port.get("market_day", -1)) == today() else 0
	return maxi(0, lv(g, "marche") - used)


static func trade(g: Node) -> bool:
	if trades_left(g) <= 0 or int(g.shards) < 40:
		return false
	g.shards -= 40
	g.tokens += 1
	var used := int(g.port.get("market_n", 0)) if int(g.port.get("market_day", -1)) == today() else 0
	g.port["market_day"] = today()
	g.port["market_n"] = used + 1
	return true


static func arena_ready(g: Node) -> bool:
	return lv(g, "arene") > 0 and int(g.port.get("arena_day", -1)) != today()


## Escouade rivale : un combat automatique un peu au-dessus du record. Renvoie {ok, rw}.
static func arena_fight(g: Node) -> Dictionary:
	if not arena_ready(g):
		return {}
	g.port["arena_day"] = today()
	var st := maxi(5, int(g.best_stage) - 2 + lv(g, "arene"))
	var sim := BattleSim.new(g.team(), st, today())
	var ok := sim.run(300.0) == "clear"
	var rw := {"crystals": 5 + 5 * lv(g, "arene"), "glass": 2} if ok else {"glass": 1}
	g.crystals += int(rw.get("crystals", 0))
	g.glass += int(rw.glass)
	return {"ok": ok, "rw": rw}
