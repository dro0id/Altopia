extends RefCounted
## Mode Route : un voyage d'étapes généré à chaque départ (longueur, forme, thème, particularité et gardien changent). La logique est séparée
## de l'affichage (RouteUI / RouteScene) pour pouvoir la tester et l'équilibrer sans écran. Les combats se jouent avec LiveSim : la coque se
## garde d'un combat à l'autre (hull_frac), seules les étapes de repos soignent.

const LiveSim = preload("res://scripts/live_sim.gd")

const REWARD_BASE := 1.6                 # gain d'un voyage réussi, avant thème et longueur
const INJURY := 25.0                     # PV perdus par un équipier blessé
const REST_HULL := 40.0                  # coque rendue par un repos (en points de 100)
const REST_CREW := 50.0
const LOOT_GOAL := 200

const TYPES := {
	"depart": {"name": "Départ", "glyph": "▲"}, "combat": {"name": "Zone hostile", "glyph": "✕"}, "elite": {"name": "Embuscade", "glyph": "✱"},
	"epave": {"name": "Épave", "glyph": "◇"}, "recolte": {"name": "Champ de ressources", "glyph": "⬡"}, "repos": {"name": "Repos", "glyph": "+"},
	"gardien": {"name": "Gardien", "glyph": "◉"}, "inconnu": {"name": "Inconnu", "glyph": "?"},
}

const THEMES := [
	{"id": "ceinture", "name": "Ceinture riche", "desc": "beaucoup de champs de ressources", "w": {"combat": 2, "epave": 2, "recolte": 5, "repos": 1, "elite": 1}},
	{"id": "nebuleuse", "name": "Nébuleuse", "desc": "des événements partout, mais on n'y voit pas loin", "w": {"combat": 2, "epave": 5, "recolte": 2, "repos": 1, "elite": 1}, "fog": true},
	{"id": "guerre", "name": "Zone de guerre", "desc": "des combats et des embuscades, un butin plus riche", "w": {"combat": 5, "epave": 1, "recolte": 1, "repos": 1, "elite": 3}, "loot": 1.2},
	{"id": "cimetiere", "name": "Cimetière d'épaves", "desc": "des épaves à fouiller à chaque détour", "w": {"combat": 1, "epave": 6, "recolte": 2, "repos": 1, "elite": 1}},
	{"id": "havre", "name": "Secteur calme", "desc": "des repos, peu de combats, un butin plus maigre", "w": {"combat": 2, "epave": 2, "recolte": 3, "repos": 4, "elite": 0}, "loot": 0.9},
]
const MODS := [
	{"id": "orage", "name": "Orage magnétique", "desc": "les chances des événements baissent de 8 points"},
	{"id": "vents", "name": "Vents solaires", "desc": "les combats coûtent 30 % de coque en plus"},
	{"id": "pluie", "name": "Pluie de minerai", "desc": "les récoltes rapportent 50 % de plus"},
	{"id": "equipe", "name": "Équipage motivé", "desc": "toutes les chances montent de 6 points"},
	{"id": "calme", "name": "Eaux calmes", "desc": "les combats coûtent 25 % de coque en moins"},
]
const GUARDS := [
	{"name": "Foreuse des anneaux", "b": 0.85}, {"name": "Sentinelle solaire", "b": 0.82}, {"name": "Mère des essaims", "b": 0.88},
	{"name": "Colosse d'épave", "b": 0.80}, {"name": "Veilleuse du vide", "b": 0.86},
]
const NAMES := ["Orion", "Vega", "Kuiper", "Arcturus", "Lyra", "Cassiopée", "Altair", "Rigel", "Hydra", "Persée", "Antarès", "Sirius"]

## Postes de l'équipage : rôle → classe de héros (Data.HERO[id].class). Le Capitaine tient les choix « sans risque ».
const ROLES := {"pilot": "Pilote", "engineer": "Ingénieur", "scientist": "Scientifique"}

## Événements : chaque option est tentée par un poste ; sa chance dépend du niveau et des PV de l'équipier.
const EVENTS := [
	{"id": "wreck", "title": "Épave dérivante", "text": "Une coque éventrée dérive devant le convoi. Ses soutes sont peut-être intactes, ses réacteurs peut-être encore instables.", "opts": [
		{"who": "engineer", "name": "Forcer les soutes", "base": 0.55, "win": {"min": 34, "ene": 18}, "lose": "explosion : un équipier est blessé", "hurt": true},
		{"who": "scientist", "name": "Scanner les registres", "base": 0.85, "win": {"dat": 22}, "lose": "rien trouvé, aucune perte"},
		{"who": "cap", "name": "Passer son chemin", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "beacon", "title": "Balise de détresse", "text": "Un signal bref et régulier. Quelqu'un a laissé des données, ou un piège.", "opts": [
		{"who": "scientist", "name": "Décoder le signal", "base": 0.7, "win": {"dat": 34, "ene": 10}, "lose": "le signal brouille vos instruments : -10 % de coque", "hull": 0.1},
		{"who": "pilot", "name": "Approcher à vue", "base": 0.6, "win": {"min": 20, "dat": 20}, "lose": "une manœuvre ratée : un équipier est blessé", "hurt": true},
		{"who": "cap", "name": "Ignorer la balise", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "cloud", "title": "Nuage de poussière", "text": "Un nuage dense barre la route. On peut le traverser, ou chercher un passage.", "opts": [
		{"who": "pilot", "name": "Traverser en force", "base": 0.65, "win": {"min": 28}, "lose": "la coque encaisse : -12 % de coque", "hull": 0.12},
		{"who": "engineer", "name": "Renforcer les boucliers", "base": 0.8, "win": {"ene": 14, "min": 10}, "lose": "surcharge : un équipier est blessé", "hurt": true},
		{"who": "cap", "name": "Contourner", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "convoy", "title": "Convoi abandonné", "text": "Trois cargos à l'arrêt, sans équipage visible. Leurs moteurs chauffent encore.", "opts": [
		{"who": "engineer", "name": "Siphonner les réserves", "base": 0.6, "win": {"ene": 36, "min": 12}, "lose": "décharge : un équipier est blessé", "hurt": true},
		{"who": "scientist", "name": "Pirater les journaux", "base": 0.75, "win": {"dat": 30, "min": 10}, "lose": "le piratage vous grille : -8 % de coque", "hull": 0.08},
		{"who": "cap", "name": "Laisser le convoi", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "rift", "title": "Faille de gravité", "text": "L'espace se plie à quelques minutes-lumière. Le courant promet un raccourci ou une collision.", "opts": [
		{"who": "pilot", "name": "Surfer sur la faille", "base": 0.55, "win": {"min": 24, "dat": 24, "ene": 12}, "lose": "la faille vous secoue : -14 % de coque", "hull": 0.14},
		{"who": "scientist", "name": "Étudier le phénomène", "base": 0.8, "win": {"dat": 40}, "lose": "mesures inutilisables, aucune perte"},
		{"who": "cap", "name": "Rester à distance", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "drift", "title": "Station à la dérive", "text": "Une petite station éteinte. Ses ateliers sont peut-être encore intacts.", "opts": [
		{"who": "engineer", "name": "Remettre l'atelier en route", "base": 0.6, "win": {"min": 40}, "lose": "court-circuit : un équipier est blessé", "hurt": true},
		{"who": "pilot", "name": "Fouiller les hangars", "base": 0.65, "win": {"min": 16, "ene": 24}, "lose": "un panneau cède : un équipier est blessé", "hurt": true},
		{"who": "cap", "name": "Ne pas s'arrêter", "base": 1.0, "win": {}, "lose": ""}]},
	{"id": "nest", "title": "Nid de météores", "text": "Des fragments tournent en orbite lente autour d'un noyau métallique.", "opts": [
		{"who": "pilot", "name": "Piloter entre les débris", "base": 0.6, "win": {"min": 38, "dat": 10}, "lose": "un impact : -10 % de coque", "hull": 0.1},
		{"who": "engineer", "name": "Casser les fragments au laser", "base": 0.7, "win": {"min": 30}, "lose": "surchauffe : un équipier est blessé", "hurt": true},
		{"who": "cap", "name": "Faire demi-tour", "base": 1.0, "win": {}, "lose": ""}]},
]

const OBJECTIVES := {
	"hull": "Finir avec 60 % de coque", "noinj": "Aucun équipier blessé", "loot": "Ramener 200 ressources",
	"wrecks": "Réussir 2 événements d'épave", "norest": "Ne jamais se reposer", "cleanfight": "Gagner tous les combats sans perdre plus de 40 % de coque",
}

## Combats : quelles vagues du combat en direct jouer selon l'étape.
const FIGHT_WAVES := {"combat": [0, 1], "elite": [2, 3], "gardien": [3, 4]}
const FIGHT_DMG := {"combat": 0.9, "elite": 1.05, "gardien": 1.0}
## Réglage par palier du vaisseau (tools/route_balance.gd) : le combat en direct est réglé pour 5 vagues, la route n'en joue que 2 à 5 d'affilée.
static var TIER_DMG := [1.0, 1.0, 0.65, 1.12, 0.8]

var rng := RandomNumberGenerator.new()
var seed_value := 0
var meta: Dictionary = {}
var nodes: Array = []
var layers: Array = []
var at := 0
var phase := "map"                      # map, event, combat, harvest, rest, end
var hull := 100.0                       # points de 100
var crew: Dictionary = {}               # rôle -> {name, level, hp, present}
var cap_level := 1
var loot := {"min": 0, "dat": 0, "ene": 0}
var injuries := 0
var events_won := 0
var rests := 0
var hull_lost_fights := 0.0
var fights := 0
var steps := 0
var event: Dictionary = {}
var elite := false
var over := false
var win := false
var why := ""
var objectives: Array = []
var log: Array = []
var cfg_base: Dictionary = {}           # tier, hp_scale, dmg_scale pour les combats
var time := 0.0


func _init(p_seed: int = 0) -> void:
	if p_seed != 0:
		rng.seed = p_seed
	else:
		rng.randomize()
	seed_value = int(rng.seed)


## cfg : tier, hp_scale, dmg_scale, cap_level, crew : {rôle: {name, level, present}}.
func setup(cfg: Dictionary = {}) -> void:
	cfg_base = {"tier": int(cfg.get("tier", 0)), "hp_scale": float(cfg.get("hp_scale", 1.0)), "dmg_scale": float(cfg.get("dmg_scale", 1.0))}
	cap_level = int(cfg.get("cap_level", 20))
	crew = {}
	var given: Dictionary = cfg.get("crew", {})
	for r in ROLES:
		var g: Dictionary = given.get(r, {"name": ROLES[r], "level": 6, "present": true})
		crew[r] = {"name": String(g.get("name", ROLES[r])), "level": int(g.get("level", 1)), "hp": 100.0, "present": bool(g.get("present", true))}
	_build()
	hull = 100.0
	at = 0
	phase = "map"
	loot = {"min": 0, "dat": 0, "ene": 0}
	injuries = 0
	events_won = 0
	rests = 0
	hull_lost_fights = 0.0
	fights = 0
	steps = 0
	over = false
	win = false
	why = ""
	log = []
	time = 0.0
	var pool: Array = OBJECTIVES.keys()
	objectives = []
	for i in 2:
		objectives.append(pool.pop_at(rng.randi() % pool.size()))
	nodes[0].seen = true
	nodes[0].done = true
	_say("Secteur %s : choisissez votre première étape." % meta.name)


func _pick_w(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	var r := rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return k
	return "combat"


func _widths(n: int) -> Dictionary:
	var shapes := ["losange", "sablier", "couloir", "delta", "tremplin"]
	var sh: String = shapes[rng.randi() % shapes.size()]
	var w: Array = [1]
	for i in range(1, n - 1):
		var t := float(i) / float(n - 1)
		var base := 0
		match sh:
			"losange": base = 2 + int(round(2.0 * sin(PI * t)))
			"sablier": base = 4 - int(round(2.0 * sin(PI * t)))
			"couloir": base = 2 + (1 if i % 3 == 1 else 0)
			"delta": base = 1 + mini(3, int(round(t * 4.0)))
			_: base = 4 - int(round(t * 2.0))
		if rng.randf() < 0.3:
			base += rng.randi() % 3 - 1
		w.append(clampi(base, 2, 4))
	w.append(1)
	return {"w": w, "shape": sh}


func _build() -> void:
	var n := 7 + rng.randi() % 5
	var th: Dictionary = THEMES[rng.randi() % THEMES.size()]
	var mod: Dictionary = MODS[rng.randi() % MODS.size()]
	var gd: Dictionary = GUARDS[rng.randi() % GUARDS.size()]
	var wd := _widths(n)
	nodes = []
	layers = []
	for L in n:
		layers.append([])
		var cnt: int = wd.w[L]
		for j in cnt:
			var nd := {"id": nodes.size(), "L": L, "j": j, "x": (float(j) + 0.5) / float(cnt), "type": "combat", "next": [], "seen": false, "done": false}
			nodes.append(nd)
			layers[L].append(nd)
	nodes[0].type = "depart"
	nodes[nodes.size() - 1].type = "gardien"
	for L in range(1, n - 1):
		for nd in layers[L]:
			var w: Dictionary = th.w.duplicate()
			if L == 1:
				w["repos"] = 0
				w["elite"] = 0
			if L < 3:
				w["elite"] = 0
			nd.type = _pick_w(w)
		var all_combat := true
		for nd in layers[L]:
			if nd.type != "combat":
				all_combat = false
		if L == 1 and all_combat:
			layers[L][0].type = "epave" if th.id == "guerre" else "recolte"
	var mid := maxi(2, n / 2)
	layers[mid][rng.randi() % layers[mid].size()].type = "repos"
	if th.id != "guerre" or rng.randf() < 0.5:
		layers[n - 2][rng.randi() % layers[n - 2].size()].type = "repos"
	for L in n - 1:
		for nd in layers[L]:
			var cand: Array = layers[L + 1].duplicate()
			cand.sort_custom(func(a, b): return absf(a.x - nd.x) < absf(b.x - nd.x))
			nd.next.append(cand[0].id)
			if cand.size() > 1 and (rng.randf() < 0.55 or layers[L].size() == 1):
				nd.next.append(cand[1].id)
			if layers[L].size() == 1 and cand.size() > 2 and rng.randf() < 0.4:
				nd.next.append(cand[2].id)
			if L + 2 < n - 1 and rng.randf() < 0.12:
				var far: Array = layers[L + 2].duplicate()
				far.sort_custom(func(a, b): return absf(a.x - nd.x) < absf(b.x - nd.x))
				if not nd.next.has(far[0].id):
					nd.next.append(far[0].id)
		for m in layers[L + 1]:
			var has := false
			for nd in layers[L]:
				if nd.next.has(m.id):
					has = true
			if not has:
				var c: Array = layers[L].duplicate()
				c.sort_custom(func(a, b): return absf(a.x - m.x) < absf(b.x - m.x))
				c[0].next.append(m.id)
	meta = {"name": "%s-%d" % [NAMES[rng.randi() % NAMES.size()], 10 + rng.randi() % 90], "theme": th, "mod": mod, "guard": gd, "layers": n,
		"shape": wd.shape, "fog": bool(th.get("fog", false)), "danger": 0.97 + rng.randf() * 0.06,
		"reward_mult": REWARD_BASE * float(th.get("loot", 1.0)) * (1.0 + 0.04 * float(n - 9))}


func _say(t: String) -> void:
	log.append(t)
	while log.size() > 4:
		log.remove_at(0)


func message() -> String:
	return String(log[log.size() - 1]) if not log.is_empty() else ""


func total_loot() -> int:
	return int(loot.min) + int(loot.dat) + int(loot.ene)


# ---------- carte ----------

func reachable() -> Array:
	var out: Array = []
	for i in nodes[at].next:
		out.append(nodes[i])
	return out


## Type montré au joueur : dans une nébuleuse, les étapes lointaines sont cachées derrière des « ? ».
func shown_type(nd: Dictionary) -> String:
	if bool(meta.fog) and not nd.seen and nd.L > nodes[at].L + 1:
		return "inconnu"
	return nd.type


func go_to(id: int) -> bool:
	if over or phase != "map" or not nodes[at].next.has(id):
		return false
	var nd: Dictionary = nodes[id]
	at = id
	steps = nd.L
	nd.seen = true
	nd.done = true
	elite = false
	match nd.type:
		"epave":
			event = EVENTS[rng.randi() % EVENTS.size()]
			phase = "event"
			_say(_flavor("epave"))
		"combat", "elite":
			phase = "combat"
			elite = nd.type == "elite"
			_say(_flavor("elite" if elite else "combat"))
		"gardien":
			phase = "combat"
			_say("« %s » barre la route." % meta.guard.name)
		"recolte":
			phase = "harvest"
			_say(_flavor("recolte"))
		"repos":
			phase = "rest"
			_say(_flavor("repos"))
		_:
			phase = "map"
	return true


func _flavor(kind: String) -> String:
	var a: Array = {
		"combat": ["Des intercepteurs sortent de l'ombre d'un astéroïde.", "Un convoi pirate vous repère et ouvre le feu.", "Des drones de patrouille verrouillent le convoi.", "Une escadrille hostile coupe la route."],
		"elite": ["Embuscade ! Des chasseurs lourds surgissent de la poussière.", "Un piège : des mines et des tireurs embusqués."],
		"epave": ["Épave en vue : qui s'en occupe ?"],
		"recolte": ["Un champ dense de minerais flotte devant le convoi.", "Des débris riches en données dérivent tout près.", "Une poche d'énergie pure brille dans le vide."],
		"repos": ["Une balise abandonnée offre un abri calme.", "Un vieux dock en orbite accepte les réparations.", "Un coin tranquille : l'équipage souffle enfin."],
	}[kind]
	return a[rng.randi() % a.size()]


func current_type() -> String:
	return String(nodes[at].type)


# ---------- événements ----------

func _crew_hp(who: String) -> float:
	return hull if who == "cap" else float(crew[who].hp)


func _who_name(who: String) -> String:
	if who == "cap":
		return "Capitaine"
	return crew[who].name if crew[who].present else "Capitaine (seul)"


func option_chance(opt: Dictionary) -> float:
	if float(opt.base) >= 1.0:
		return 1.0
	var who: String = opt.who
	var lv: int = int(crew[who].level) if who != "cap" else cap_level
	var p: float = float(opt.base) + minf(0.15, float(lv) * 0.006)
	p *= 0.5 + 0.5 * _crew_hp(who) / 100.0
	if who != "cap" and not crew[who].present:
		p -= 0.1                           # personne à ce poste : le Capitaine s'en charge, moins bien
	if meta.mod.id == "orage":
		p -= 0.08
	if meta.mod.id == "equipe":
		p += 0.06
	return clampf(p, 0.05, 0.97)


static func label_of(p: float) -> String:
	return "sûr" if p >= 0.8 else ("risqué" if p >= 0.5 else "très risqué")


func option_available(opt: Dictionary) -> bool:
	return opt.who == "cap" or not crew[opt.who].present or float(crew[opt.who].hp) > 10.0


## Tente l'option `i` ; retourne {ok, text}. `roll` : tirage imposé (tests), sinon aléatoire.
func pick_option(i: int, roll: float = -1.0) -> Dictionary:
	if over or phase != "event":
		return {"ok": false, "text": ""}
	var o: Dictionary = event.opts[i]
	var p := option_chance(o)
	var good := (rng.randf() if roll < 0.0 else roll) < p
	var text := ""
	if float(o.base) >= 1.0:
		text = "Vous passez votre chemin."
	elif good:
		_add_loot(o.win)
		events_won += 1
		text = "%s : réussi ! %s." % [o.name, loot_text(o.win)]
	else:
		var t: String = o.lose
		if o.get("hurt", false):
			var w := _hurt_crew()
			if w != "":
				t = "%s est blessé." % w
		if o.has("hull"):
			hull = maxf(5.0, hull - float(o.hull) * 100.0)
		text = "%s : raté. %s" % [o.name, t]
	_say(text)
	phase = "map"
	_check_end()
	return {"ok": good or float(o.base) >= 1.0, "text": text}


func _hurt_crew() -> String:
	var cand: Array = []
	for r in ROLES:
		if crew[r].present and float(crew[r].hp) > 10.0:
			cand.append(r)
	if cand.is_empty():
		return ""
	var who: String = cand[rng.randi() % cand.size()]
	crew[who].hp = maxf(5.0, float(crew[who].hp) - INJURY)
	injuries += 1
	return crew[who].name


func _add_loot(l: Dictionary) -> void:
	for k in l:
		loot[k] = int(loot[k]) + int(l[k])


static func loot_text(l: Dictionary) -> String:
	var a: Array = []
	if l.has("min"):
		a.append("+%d min" % int(l.min))
	if l.has("dat"):
		a.append("+%d don" % int(l.dat))
	if l.has("ene"):
		a.append("+%d én" % int(l.ene))
	return " ".join(a) if not a.is_empty() else "rien"


# ---------- récolte et repos ----------

func harvest(kind: String) -> void:
	if over or phase != "harvest":
		return
	var l: Dictionary = {"min": 46} if kind == "min" else ({"dat": 34, "ene": 10} if kind == "dat" else {"ene": 40})
	if meta.mod.id == "pluie":
		for k in l:
			l[k] = int(round(float(l[k]) * 1.5))
	_add_loot(l)
	_say("Récolte : %s." % loot_text(l))
	phase = "map"


func rest() -> void:
	if over or phase != "rest":
		return
	hull = minf(100.0, hull + REST_HULL)
	for r in ROLES:
		crew[r].hp = minf(100.0, float(crew[r].hp) + REST_CREW)
	rests += 1
	_say("Repos : la coque et l'équipage récupèrent.")
	phase = "map"


func skip_rest() -> void:
	if phase == "rest":
		phase = "map"
		_say("Vous poursuivez sans vous reposer.")


# ---------- combats ----------

## Réglages du combat en direct de l'étape en cours (voir LiveSim.setup).
func fight_cfg(assist: bool = false) -> Dictionary:
	var kind: String = "gardien" if current_type() == "gardien" else ("elite" if elite else "combat")
	var dmg: float = float(cfg_base.dmg_scale) * float(FIGHT_DMG[kind]) * float(meta.danger) * float(TIER_DMG[int(cfg_base.tier)])
	var hp: float = float(cfg_base.hp_scale)
	if kind == "gardien":
		hp *= 1.0 + (0.85 - float(meta.guard.b)) * 2.0
	return {"tier": cfg_base.tier, "use_boss": kind == "gardien", "hp_scale": hp, "dmg_scale": dmg, "assist": assist,
		"waves": FIGHT_WAVES[kind], "hull_frac": clampf(hull / 100.0, 0.05, 1.0)}


## Applique le résultat d'un combat (LiveSim.result()) : coque restante, butin, fin du voyage si le gardien tombe ou si la coque est détruite.
func apply_fight(res: Dictionary) -> String:
	var kind: String = "gardien" if current_type() == "gardien" else ("elite" if elite else "combat")
	var start := hull
	fights += 1
	time += float(res.get("time", 0.0))
	var left: float = float(res.get("hull_frac", 0.0)) * 100.0
	var lost := maxf(0.0, start - left)
	var mult := 1.0
	if meta.mod.id == "vents":
		mult = 1.3
	elif meta.mod.id == "calme":
		mult = 0.75
	lost *= mult
	var text := ""
	if not bool(res.get("win", false)) or start - lost <= 0.0:
		hull = 0.0
		text = "Combat perdu : la coque est détruite."
		_finish(false, "combat")
	else:
		hull = maxf(5.0, start - lost)
		hull_lost_fights += lost
		if kind == "gardien":
			_add_loot({"min": 60, "dat": 50, "ene": 40})
			text = "« %s » est vaincu ! Le secteur est ouvert." % meta.guard.name
			_finish(true, "")
		else:
			var l: Dictionary = {"min": 40 + rng.randi() % 3 * 10, "dat": 28 + rng.randi() % 3 * 8} if elite else {"min": 22 + rng.randi() % 3 * 8, "dat": 14 + rng.randi() % 3 * 6}
			_add_loot(l)
			text = "%s : -%d %% de coque, %s." % ["Embuscade repoussée" if elite else "Combat gagné", int(round(lost)), loot_text(l)]
			phase = "map"
	elite = false
	_say(text)
	return text


## Résolution abstraite d'un combat (sans LiveSim) : utilisée par les tests rapides de la carte.
func fight_abstract(roll: float = -1.0) -> String:
	var p := 0.9 * float(meta.danger) * (0.55 + 0.45 * hull / 100.0)
	var good := (rng.randf() if roll < 0.0 else roll) < p
	var left := hull - rng.randf_range(6.0, 22.0) * (1.5 if current_type() == "gardien" else 1.0)
	return apply_fight({"win": good, "hull_frac": maxf(0.0, left) / 100.0, "time": 20.0})


func _check_end() -> void:
	if not over and hull <= 0.0:
		_finish(false, "hull")


func _finish(victory: bool, reason: String) -> void:
	over = true
	win = victory
	why = reason
	phase = "end"


# ---------- objectifs et résultat ----------

func objective_text(id: String) -> String:
	return OBJECTIVES[id]


func objective_done(id: String) -> bool:
	match id:
		"hull": return hull >= 60.0
		"noinj": return injuries == 0
		"loot": return total_loot() >= LOOT_GOAL
		"wrecks": return events_won >= 2
		"norest": return rests == 0
		"cleanfight": return hull_lost_fights <= 40.0
	return false


func objectives_done() -> int:
	var n := 0
	for id in objectives:
		if objective_done(id):
			n += 1
	return n


## Multiplicateur propre au voyage : thème, longueur et butin ramené (la soute compte un peu).
func route_mult() -> float:
	return float(meta.reward_mult) * clampf(0.8 + float(total_loot()) / 500.0, 0.8, 1.2)


## Résultat à transmettre à GameState.finish_live.
func result() -> Dictionary:
	return {"win": win, "time": time, "objectives": objectives.duplicate(), "objectives_done": objectives_done() if win else 0,
		"hull_frac": hull / 100.0, "loot": loot.duplicate(), "route_mult": route_mult(), "steps": steps, "fights": fights}


# ---------- pilote automatique (équipage assisté) et joueur simulé ----------

func _score(nd: Dictionary) -> float:
	var s := 0.5
	match nd.type:
		"repos": s = 3.0 if hull < 60.0 else 0.5
		"recolte": s = 1.2
		"epave": s = 1.1
		"combat": s = 1.0 if hull > 50.0 else -0.5
		"elite": s = 1.3 if hull > 75.0 else -1.0
	return s + rng.randf() * 0.2


func _min_crew_hp() -> float:
	var m := 100.0
	for r in ROLES:
		if crew[r].present:
			m = minf(m, float(crew[r].hp))
	return m


func _event_value(o: Dictionary) -> float:
	var p := option_chance(o)
	var s := 0.0
	for k in o.win:
		s += float(o.win[k])
	return 0.2 if float(o.base) >= 1.0 else p * s / 60.0 - (1.0 - p) * 0.35


func auto_node() -> int:
	var best_node := -1
	var best_score := -999.0
	for nd in reachable():
		var sc := _score(nd)
		if sc > best_score:
			best_score = sc
			best_node = nd.id
	return best_node


func auto_option() -> int:
	var best := 0
	var bs := -1.0
	for i in event.opts.size():
		if not option_available(event.opts[i]):
			continue
		var v := _event_value(event.opts[i])
		if v > bs:
			bs = v
			best = i
	return best


func auto_wants_rest() -> bool:
	return hull < 80.0 or _min_crew_hp() < 60.0


## Une décision du pilote automatique. `fight` : Callable(cfg) -> résultat de combat (LiveSim.result()). Retourne faux si rien à faire.
func auto_step(fight: Callable) -> bool:
	if over:
		return false
	match phase:
		"map":
			go_to(auto_node())
		"event":
			pick_option(auto_option())
		"combat":
			apply_fight(fight.call(fight_cfg(true)))
		"harvest":
			harvest("min")
		"rest":
			if auto_wants_rest():
				rest()
			else:
				skip_rest()
		_:
			return false
	return true
