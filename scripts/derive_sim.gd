extends RefCounted
## Dérive : explorer une grille brouillée (6 x 7), scanner, avancer, extraire des ressources sous la menace des météores.
## Les chiffres d'une case scannée comptent les dangers autour d'elle (comme au démineur). Le météore est le « gardien » de la dérive :
## annoncé quelques secondes à l'avance, il détruit la case visée (et sa ressource) et pulvérise le vaisseau s'il tombe dessus.
## La logique est séparée de l'interface (DeriveUI) pour pouvoir la tester et l'équilibrer sans écran.

const ROWS := 7
const COLS := 6
const KINDS := ["min", "dat", "ene"]          # minerais, données, énergie
const ASSIST_SLOW := 1.3                      # l'équipage assisté agit 30 % plus lentement

## Réglages (réglés avec tools/derive_balance.gd : environ 75 % de victoires au plus, à la main comme en automatique).
static var CFG := {
	"hazards": 10, "res": 9, "energy": 13.0, "energy_max": 20.0, "time": 75.0, "min_loot": 3,
	"meteor_every": 10.0, "meteor_tele": 2.2, "aim_ship": 0.1, "aim_near": 0.15,
	"haz_dmg": 0.34, "extract_time": 1.6, "move_time": 0.35, "scan_time": 0.5, "probe_time": 0.8, "jump_time": 0.5,
	"probe_charges": 2, "probe_cost": 3.0, "jump_cost": 2.0, "scan_cost": 1.0, "energy_gain": 4.0,
}

## Pilote automatique (équipage assisté) et joueur simulé (tests).
const AI_AUTO := {"react": 0.45, "lapse": 0.12}
const AI_HUMAN := {"react": 0.4, "lapse": 0.1}

const OBJECTIVE_IDS := ["hits", "explore", "loot", "hull", "spare", "probe", "kinds", "fast"]
const CUMULATIVE := ["explore", "loot", "kinds", "probe"]       # objectifs qu'on voit se remplir pendant la partie

var rng := RandomNumberGenerator.new()
var assist := false                    # équipage assisté : le pilote automatique joue
var human_bot := false                 # joueur simulé (tests)

var cells: Array = []
var ship := [ROWS - 1, 2]
var hull := 0.0
var hull_max := 0.0
var energy := 0.0
var t := 0.0
var busy := 0.0
var hits := 0
var probes := 0
var jumps := 0
var extracted := 0
var kinds := {}
var loot := {"min": 0, "dat": 0, "ene": 0}
var over := false
var win := false
var over_reason := ""
var msg := ""
var msg_t := 0.0
var meteors: Array = []
var meteor_t := 0.0
var probe_left := 0
var objectives: Array = []
var extracting_at := -1
var extract_t := 0.0
var extract_total := 1.0
var auto_extract := false
var events: Array = []                 # sons à jouer : "scan", "move", "hurt", "probe", "extract", "done", "warn", "win", "lose"
var _ai_t := 0.0


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


static func idx(r: int, c: int) -> int:
	return r * COLS + c


static func inb(r: int, c: int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < COLS


static func neigh8(r: int, c: int) -> Array:
	var out: Array = []
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if (dr != 0 or dc != 0) and inb(r + dr, c + dc):
				out.append([r + dr, c + dc])
	return out


static func neigh4(r: int, c: int) -> Array:
	var out: Array = []
	for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		if inb(r + d[0], c + d[1]):
			out.append([r + d[0], c + d[1]])
	return out


## cfg : hull (coque du vaisseau), hazards (nombre de dangers), assist.
func setup(cfg: Dictionary = {}) -> void:
	hull_max = float(cfg.get("hull", 1000.0))
	hull = hull_max
	assist = bool(cfg.get("assist", false))
	var hazards := int(cfg.get("hazards", CFG.hazards))
	ship = [ROWS - 1, 2]
	energy = float(CFG.energy)
	t = 0.0
	busy = 0.0
	hits = 0
	probes = 0
	jumps = 0
	extracted = 0
	kinds = {}
	loot = {"min": 0, "dat": 0, "ene": 0}
	over = false
	win = false
	over_reason = ""
	meteors = []
	meteor_t = float(CFG.meteor_every) * 0.8
	probe_left = int(CFG.probe_charges)
	extracting_at = -1
	extract_t = 0.0
	auto_extract = false
	events = []
	_ai_t = 0.0
	cells = []
	for i in ROWS * COLS:
		cells.append({"haz": false, "res": "", "seen": false, "done": false, "crater": false, "destroyed": false, "num": 0})
	var sr: int = ship[0]
	var sc: int = ship[1]
	var safe := {idx(sr, sc): true}
	for n in neigh4(sr, sc):
		safe[idx(n[0], n[1])] = true
	var free: Array = []
	for i in ROWS * COLS:
		if not safe.has(i):
			free.append(i)
	for h in hazards:
		var k := rng.randi_range(0, free.size() - 1)
		cells[free[k]].haz = true
		free.remove_at(k)
	var cand: Array = []
	for i in ROWS * COLS:
		if not cells[i].haz and i != idx(sr, sc):
			cand.append(i)
	for q in int(CFG.res):
		var k2 := rng.randi_range(0, cand.size() - 1)
		cells[cand[k2]].res = KINDS[q % 3]
		cand.remove_at(k2)
	for r in ROWS:
		for c in COLS:
			var n2 := 0
			for nb in neigh8(r, c):
				if cells[idx(nb[0], nb[1])].haz:
					n2 += 1
			cells[idx(r, c)].num = n2
	cells[idx(sr, sc)].seen = true
	objectives = _pick_objectives()
	say("Touchez une case voisine en pointillés : un premier toucher la sélectionne, un second la scanne.")


func say(s: String) -> void:
	msg = s
	msg_t = 3.0


func _pick_objectives() -> Array:
	var pool: Array = OBJECTIVE_IDS.duplicate()
	var out: Array = []
	for i in 2:
		var k := rng.randi_range(0, pool.size() - 1)
		out.append(pool[k])
		pool.remove_at(k)
	return out


func seen_share() -> float:
	var n := 0
	for c in cells:
		if c.seen:
			n += 1
	return float(n) / float(ROWS * COLS)


func objective_text(id: String) -> String:
	match id:
		"hits": return "Moins de 2 impacts"
		"explore": return "Explorer 70 % de la grille"
		"loot": return "Ramener 6 ressources"
		"hull": return "Finir avec 60 % de coque"
		"spare": return "Finir avec 5 d'énergie"
		"probe": return "Utiliser la sonde 2 fois"
		"kinds": return "Une ressource de chaque type"
		"fast": return "Terminer en moins de 60 s"
	return id


func objective_done(id: String) -> bool:
	match id:
		"hits": return hits < 2
		"explore": return seen_share() >= 0.7
		"loot": return extracted >= 6
		"hull": return hull >= 0.6 * hull_max
		"spare": return energy >= 5.0
		"probe": return probes >= 2
		"kinds": return kinds.has("min") and kinds.has("dat") and kinds.has("ene")
		"fast": return t < 60.0
	return false


## Pour l'affichage pendant la partie : seuls les objectifs qui se remplissent (cumulatifs) s'allument avant la fin.
func objective_live_done(id: String) -> bool:
	return objective_done(id) and (over or CUMULATIVE.has(id))


func objectives_done() -> int:
	var n := 0
	for id in objectives:
		if objective_done(id):
			n += 1
	return n


func _dur(x: float) -> float:
	return x * (ASSIST_SLOW if (assist or human_bot) else 1.0)


func adj(r: int, c: int) -> bool:
	return maxi(absi(r - ship[0]), absi(c - ship[1])) == 1


func _hit(frac: float, why: String) -> void:
	events.append("hurt")
	var d := roundf(hull_max * frac)
	hull -= d
	hits += 1
	say("%s : -%d de coque." % [why, int(d)])
	if hull <= 0.0:
		hull = 0.0
		over_reason = "hull"
		finish(false)


func _enter(r: int, c: int) -> void:
	var cell: Dictionary = cells[idx(r, c)]
	cell.seen = true
	ship = [r, c]
	extracting_at = -1
	auto_extract = cell.res != "" and not cell.done and not cell.haz
	events.append("move")
	if cell.haz and not cell.crater:
		cell.crater = true
		_hit(float(CFG.haz_dmg), "Danger heurté")


func act_scan(r: int, c: int) -> bool:
	if busy > 0.0 or over or energy < float(CFG.scan_cost):
		return false
	var cell: Dictionary = cells[idx(r, c)]
	if cell.seen:
		return false
	energy -= float(CFG.scan_cost)
	cell.seen = true
	busy = _dur(float(CFG.scan_time))
	events.append("scan")
	if cell.haz:
		say("Danger repéré.")
	elif cell.res != "":
		say("Une ressource !")
	else:
		say("Case libre : %d danger(s) autour." % cell.num)
	return true


func act_move(r: int, c: int) -> bool:
	if busy > 0.0 or over or not adj(r, c):
		return false
	var cell: Dictionary = cells[idx(r, c)]
	if cell.destroyed:
		say("Cette case a été détruite par un météore.")
		return false
	if cell.seen and cell.haz and not cell.crater:
		say("Un danger est connu sur cette case.")
		return false
	busy = _dur(float(CFG.move_time))
	_enter(r, c)
	return true


func act_probe() -> bool:
	if busy > 0.0 or over or probe_left <= 0 or energy < float(CFG.probe_cost):
		return false
	energy -= float(CFG.probe_cost)
	probe_left -= 1
	probes += 1
	busy = _dur(float(CFG.probe_time))
	events.append("probe")
	for n in neigh8(ship[0], ship[1]):
		cells[idx(n[0], n[1])].seen = true
	say("Sonde : la zone autour de vous est révélée.")
	return true


func act_jump(r: int, c: int) -> bool:
	if busy > 0.0 or over or energy < float(CFG.jump_cost):
		return false
	var dr: int = r - ship[0]
	var dc: int = c - ship[1]
	var inline := dr == 0 or dc == 0 or absi(dr) == absi(dc)
	var d := maxi(absi(dr), absi(dc))
	if not inline or d < 1 or d > 2:
		return false
	var cell: Dictionary = cells[idx(r, c)]
	if cell.destroyed:
		say("Cette case a été détruite par un météore.")
		return false
	if cell.seen and cell.haz and not cell.crater:
		say("Un danger est connu sur cette case.")
		return false
	energy -= float(CFG.jump_cost)
	jumps += 1
	busy = _dur(float(CFG.jump_time))
	_enter(r, c)
	return true


func act_extract() -> bool:
	if busy > 0.0 or over:
		return false
	var cell: Dictionary = cells[idx(ship[0], ship[1])]
	if cell.res == "" or cell.done:
		return false
	extracting_at = idx(ship[0], ship[1])
	extract_total = _dur(float(CFG.extract_time))
	extract_t = extract_total
	events.append("extract")
	say("Extraction en cours : ne bougez pas.")
	return true


func act_leave() -> void:
	if not over:
		over_reason = "leave"
		finish(extracted >= int(CFG.min_loot) and hull > 0.0)


func finish(victory: bool) -> void:
	if over:
		return
	over = true
	win = victory and hull > 0.0 and extracted >= int(CFG.min_loot)
	if over_reason == "" and not win:
		over_reason = "loot"
	events.append("win" if win else "lose")


## Résultat à transmettre au jeu.
func result() -> Dictionary:
	return {
		"win": win, "time": t, "hits": hits, "extracted": extracted, "objectives": objectives.duplicate(),
		"objectives_done": objectives_done() if win else 0, "loot": loot.duplicate(), "reason": over_reason,
	}


# ---------- boucle ----------

func step(dt: float) -> void:
	if over:
		return
	t += dt
	busy = maxf(0.0, busy - dt)
	msg_t = maxf(0.0, msg_t - dt)
	if auto_extract and busy <= 0.0 and extracting_at < 0:
		auto_extract = false
		var ac: Dictionary = cells[idx(ship[0], ship[1])]
		if ac.res != "" and not ac.done and not ac.destroyed:
			act_extract()
	# extraction
	if extracting_at >= 0:
		extract_t -= dt
		if extract_t <= 0.0:
			var cell: Dictionary = cells[extracting_at]
			cell.done = true
			extracted += 1
			kinds[cell.res] = true
			loot[cell.res] += 1
			if cell.res == "ene":
				energy = minf(float(CFG.energy_max), energy + float(CFG.energy_gain))
			extracting_at = -1
			events.append("done")
			say("Extrait ! %d ressource(s) en soute." % extracted)
	# météores annoncés
	meteor_t -= dt
	if meteor_t <= 0.0:
		meteor_t = float(CFG.meteor_every) * rng.randf_range(0.7, 1.3)
		var tries := 0
		var r := 0
		var c := 0
		while true:
			var q := rng.randf()
			if q < float(CFG.aim_ship):
				r = ship[0]
				c = ship[1]
			elif q < float(CFG.aim_ship) + float(CFG.aim_near):
				var nb := neigh8(ship[0], ship[1])
				var p: Array = nb[rng.randi_range(0, nb.size() - 1)]
				r = p[0]
				c = p[1]
			else:
				r = rng.randi_range(0, ROWS - 1)
				c = rng.randi_range(0, COLS - 1)
			tries += 1
			var taken := false
			for m in meteors:
				if m.r == r and m.c == c:
					taken = true
			if (not taken and not cells[idx(r, c)].destroyed) or tries >= 12:
				break
		meteors.append({"r": r, "c": c, "t": 0.0})
		events.append("warn")
	var landed: Array = []
	var keep: Array = []
	for m in meteors:
		m.t += dt
		if m.t >= float(CFG.meteor_tele):
			landed.append(m)
		else:
			keep.append(m)
	meteors = keep
	for m in landed:
		var cl: Dictionary = cells[idx(m.r, m.c)]
		cl.destroyed = true
		cl.seen = true
		cl.res = ""                                   # la case et sa ressource sont perdues
		if extracting_at == idx(m.r, m.c):
			extracting_at = -1
		if m.r == ship[0] and m.c == ship[1]:
			events.append("hurt")
			hull = 0.0
			hits += 1
			over_reason = "meteor"
			say("Météore : le vaisseau est pulvérisé.")
			finish(false)
		else:
			events.append("hurt")
			say("Un météore a détruit une case.")
	if over:
		return
	if t >= float(CFG.time):
		say("La dérive est terminée.")
		over_reason = "time"
		finish(extracted >= int(CFG.min_loot) and hull > 0.0)
		return
	if assist:
		_bot_step(dt, AI_AUTO)
	elif human_bot:
		_bot_step(dt, AI_HUMAN)


# ---------- équipage assisté : un démineur qui sait aussi extraire ----------

func hazard_knowledge() -> Dictionary:
	var sure: Array = []
	var safe: Array = []
	for i in ROWS * COLS:
		sure.append(false)
		safe.append(false)
	for i in ROWS * COLS:
		var c0: Dictionary = cells[i]
		if c0.seen and c0.haz:
			sure[i] = true
		if c0.seen and not c0.haz:
			safe[i] = true
	var changed := true
	var guard := 0
	while changed and guard < 6:
		guard += 1
		changed = false
		for r in ROWS:
			for c in COLS:
				var cell: Dictionary = cells[idx(r, c)]
				if not (cell.seen and not cell.haz):
					continue
				var unk: Array = []
				var known := 0
				for n in neigh8(r, c):
					var j := idx(n[0], n[1])
					if sure[j]:
						known += 1
					elif not safe[j]:
						unk.append(j)
				var left: int = cell.num - known
				if not unk.is_empty() and left == 0:
					for j in unk:
						if not safe[j]:
							safe[j] = true
							changed = true
				elif not unk.is_empty() and left == unk.size():
					for j in unk:
						if not sure[j]:
							sure[j] = true
							changed = true
	return {"sure": sure, "safe": safe}


func hazard_prob(know: Dictionary, j: int) -> float:
	if know.sure[j]:
		return 1.0
	if know.safe[j]:
		return 0.0
	var r := j / COLS
	var c := j % COLS
	var best := -1.0
	for n in neigh8(r, c):
		var cell: Dictionary = cells[idx(n[0], n[1])]
		if not (cell.seen and not cell.haz):
			continue
		var unk := 0
		var kn := 0
		for m in neigh8(n[0], n[1]):
			var k := idx(m[0], m[1])
			if know.sure[k]:
				kn += 1
			elif not know.safe[k]:
				unk += 1
		if unk > 0:
			var p := float(cell.num - kn) / float(unk)
			if p > best:
				best = p
	if best >= 0.0:
		return minf(0.95, maxf(0.03, best))
	var rem: int = int(CFG.hazards)
	var seen := 0
	for x in cells:
		if x.seen:
			seen += 1
			if x.haz:
				rem -= 1
	return maxf(0.05, float(rem) / float(maxi(1, ROWS * COLS - seen)))


func _bfs(from: Array, goal_kind: String, know: Dictionary) -> Array:
	var q: Array = [from]
	var prev := {}
	var seen := {idx(from[0], from[1]): true}
	while not q.is_empty():
		var cur: Array = q.pop_front()
		var cell: Dictionary = cells[idx(cur[0], cur[1])]
		var is_start: bool = cur[0] == from[0] and cur[1] == from[1]
		var ok := false
		if not is_start:
			if goal_kind == "res":
				ok = cell.res != "" and not cell.done and cell.seen
			else:
				for n in neigh8(cur[0], cur[1]):
					if not cells[idx(n[0], n[1])].seen:
						ok = true
		if ok:
			var path: Array = [cur]
			while prev.has(idx(path[0][0], path[0][1])):
				path.push_front(prev[idx(path[0][0], path[0][1])])
			return path
		for n in neigh4(cur[0], cur[1]):
			var j := idx(n[0], n[1])
			if seen.has(j):
				continue
			var nc: Dictionary = cells[j]
			if nc.destroyed:
				continue
			if not ((nc.seen and not nc.haz) or (not nc.seen and know.safe[j])):
				continue
			seen[j] = true
			prev[j] = cur
			q.append(n)
	return []


func _bot_step(dt: float, p: Dictionary) -> void:
	_ai_t -= dt
	if _ai_t > 0.0 or busy > 0.0:
		return
	_ai_t = p.react
	if rng.randf() < p.lapse:
		return
	var sr: int = ship[0]
	var sc: int = ship[1]
	var here: Dictionary = cells[idx(sr, sc)]
	var know := hazard_knowledge()
	# 1. un météore vise ma case : je bouge
	var threat := false
	for m in meteors:
		if m.r == sr and m.c == sc and float(CFG.meteor_tele) - m.t < 1.5:
			threat = true
	if threat:
		var opts: Array = []
		for n in neigh4(sr, sc):
			var cc: Dictionary = cells[idx(n[0], n[1])]
			if cc.seen and not cc.haz and not cc.destroyed:
				var targeted := false
				for m in meteors:
					if m.r == n[0] and m.c == n[1]:
						targeted = true
				if not targeted:
					opts.append(n)
		if not opts.is_empty():
			var o: Array = opts[rng.randi_range(0, opts.size() - 1)]
			act_move(o[0], o[1])
			return
	# 2. extraire ici si aucun météore n'arrive
	if here.res != "" and not here.done and extracting_at < 0:
		var risky := false
		for m in meteors:
			if m.r == sr and m.c == sc and float(CFG.meteor_tele) - m.t < float(CFG.extract_time) + 0.2:
				risky = true
		if not risky:
			act_extract()
			return
	if extracting_at >= 0:
		return
	# 3. fin proche : rentrer si la charge est suffisante
	var left := float(CFG.time) - t
	if left < 6.0 and extracted >= int(CFG.min_loot):
		act_leave()
		return
	# 4. sonde dès qu'elle révèle beaucoup
	var unseen8 := 0
	for n in neigh8(sr, sc):
		if not cells[idx(n[0], n[1])].seen:
			unseen8 += 1
	if probe_left > 0 and energy >= float(CFG.probe_cost) + 1.0 and unseen8 >= 4:
		act_probe()
		return
	# 5. aller vers une ressource connue
	var path := _bfs([sr, sc], "res", know)
	if path.size() > 1:
		var nx: Array = path[1]
		var ncell: Dictionary = cells[idx(nx[0], nx[1])]
		if ncell.seen or know.safe[idx(nx[0], nx[1])]:
			act_move(nx[0], nx[1])
			return
	# 6. explorer : la case voisine la moins dangereuse d'abord
	var cands: Array = []
	for n in neigh8(sr, sc):
		if not cells[idx(n[0], n[1])].seen:
			cands.append(n)
	if not cands.is_empty():
		cands.sort_custom(func(a, b): return hazard_prob(know, idx(a[0], a[1])) < hazard_prob(know, idx(b[0], b[1])))
		var best: Array = cands[0]
		var pr := hazard_prob(know, idx(best[0], best[1]))
		var four := false
		for n in neigh4(sr, sc):
			if n[0] == best[0] and n[1] == best[1]:
				four = true
		if know.safe[idx(best[0], best[1])] and adj(best[0], best[1]) and four:
			act_move(best[0], best[1])            # déduit sûr : on avance sans payer le scan
			return
		if energy >= float(CFG.scan_cost):
			act_scan(best[0], best[1])
			return
		if pr < 0.3 and four:
			act_move(best[0], best[1])
			return
	# 7. rejoindre une case connue qui touche l'inconnu
	var back := _bfs([sr, sc], "frontier", know)
	if back.size() > 1:
		act_move(back[1][0], back[1][1])
		return
	if extracted >= int(CFG.min_loot) or left < 3.0:
		act_leave()
