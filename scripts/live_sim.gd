extends RefCounted
## Combat en direct des expéditions : une arène à trois couloirs, des ennemis qui annoncent leurs tirs, des compétences d'équipage
## et deux objectifs tirés au sort par partie. La logique est séparée du dessin (LiveView) pour pouvoir la tester et l'équilibrer sans écran.
## Repères : l'arène fait 360 x 520 ; le vaisseau du joueur est en bas, les ennemis arrivent par le haut.

const W := 360.0
const H := 520.0
const LANES := [60.0, 180.0, 300.0]
const PY := 424.0                      # hauteur du vaisseau du joueur

const C_CYAN := Color("80f2ff")
const C_ORANGE := Color("ffb26b")
const C_GREEN := Color("6eff9c")
const C_GOLD := Color("ffd159")
const C_RED := Color("ff6b7a")
const C_PINK := Color("ff9bed")
const C_SAND := Color("ccb39e")
const C_INK := Color("e6faff")

const COOLDOWN := {"dodge": 8.0, "shield": 12.0, "scan": 15.0}
const DODGE_TIME := 1.5
const SCAN_TIME := 8.0
const CHARGE_DAMAGE := 260.0
const WAVE_COUNT := 5

## Le palier du vaisseau vient de la somme des niveaux d'améliorations (voir GameState.ship_tier).
const SHIPS := [
	{"name": "Éclaireur", "hull": 1000.0, "guns": [0.0], "dmg": 26.0},
	{"name": "Corvette", "hull": 1250.0, "guns": [-12.0, 12.0], "dmg": 26.0},
	{"name": "Frégate", "hull": 1550.0, "guns": [-10.0, 10.0], "dmg": 30.0},
	{"name": "Croiseur", "hull": 1950.0, "guns": [-9.0, 9.0, -34.0, 34.0], "dmg": 30.0},
	{"name": "Amiral", "hull": 2500.0, "guns": [-10.0, 10.0, -36.0, 36.0], "dmg": 34.0},
]

## Difficulté par palier : réglée (tools/live_balance.gd) pour qu'une partie ne dépasse pas ~80 % de victoires, à la main comme en automatique.
## cm : nombre d'ennemis x ; hp et dmg : multiplicateurs ; rate : cadence de tir x.
static var DIFF := {
	"cm": [1.0, 1.4, 1.8, 2.3, 2.8],
	"hp": [0.6, 1.25, 1.62, 2.5, 3.0],
	"dmg": [10.6, 10.0, 17.0, 17.0, 20.0],
	"rate": [7.0, 9.0, 7.6, 9.0, 9.0],
	"tele": 0.55, "speed": 1.6,
}

## Pilote automatique (équipage assisté) et joueur simulé pour les tests.
const AI_AUTO := {"react": 0.3, "lapse": 0.08, "dodge_miss": 0.2}
const AI_HUMAN := {"react": 0.42, "lapse": 0.18, "dodge_miss": 0.3}

const OBJECTIVE_IDS := ["combo", "hits", "fast", "avoid", "charge", "weak", "hull", "scan"]
const FAST_GOAL := 28.0
const ASSIST_DAMAGE := 0.75            # l'équipage assisté tire à 75 % de la puissance : jouer soi-même reste plus fort

var rng := RandomNumberGenerator.new()
var tier := 0
var use_boss := true
var wave_list: Array = [0, 1, 2, 3, 4] # vagues jouées (le mode Route n'en joue que quelques-unes)
var wave_total := 5
var hp_scale := 1.0                    # difficulté de la destination (>= 1)
var dmg_scale := 1.0
var assist := false                    # équipage assisté : le pilote automatique joue
var human_bot := false                 # joueur simulé (tests)

var t := 0.0
var wave := -1
var delay := 0.6
var enemies: Array = []
var pbullets: Array = []
var ebullets: Array = []
var beams: Array = []
var fx: Array = []
var texts: Array = []
var hull := 0.0
var hull_max := 0.0
var lane := 1
var px := 180.0
var shield := 0.0
var dodge := 0.0
var scan := 0.0
var cd := {"dodge": 0.0, "shield": 0.0, "scan": 0.0}
var gauge := 40.0
var combo := 0
var max_combo := 0
var hits := 0
var minerals := 0
var data := 0
var fire := 0.0
var over := false
var win := false
var shake := 0.0
var banner := ""
var banner_t := 0.0
var boss: Dictionary = {}
var summoned := false
var avoided := 0
var charges := 0
var weak := 0
var scans := 0
var objectives: Array = []
var events: Array = []                 # sons et vibrations à jouer : "hurt", "dodge", "shield", "scan", "charge", "kill", "warn", "win", "lose"
var _ai_t := 0.0


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


## cfg : tier, use_boss, hp_scale, dmg_scale, assist ; optionnel (mode Route) : waves (indices de vagues), hull_frac (coque de départ, 0 à 1).
func setup(cfg: Dictionary = {}) -> void:
	tier = clampi(int(cfg.get("tier", 0)), 0, SHIPS.size() - 1)
	use_boss = bool(cfg.get("use_boss", true))
	hp_scale = float(cfg.get("hp_scale", 1.0))
	dmg_scale = float(cfg.get("dmg_scale", 1.0))
	assist = bool(cfg.get("assist", false))
	wave_list = Array(cfg.get("waves", [0, 1, 2, 3, 4]))
	wave_total = wave_list.size()
	t = 0.0
	wave = -1
	delay = 0.6
	enemies = []
	pbullets = []
	ebullets = []
	beams = []
	fx = []
	texts = []
	hull_max = SHIPS[tier].hull
	hull = hull_max * clampf(float(cfg.get("hull_frac", 1.0)), 0.01, 1.0)
	lane = 1
	px = LANES[1]
	shield = 0.0
	dodge = 0.0
	scan = 0.0
	cd = {"dodge": 0.0, "shield": 0.0, "scan": 0.0}
	gauge = 40.0
	combo = 0
	max_combo = 0
	hits = 0
	minerals = 0
	data = 0
	fire = 0.0
	over = false
	win = false
	shake = 0.0
	boss = {}
	summoned = false
	avoided = 0
	charges = 0
	weak = 0
	scans = 0
	events = []
	_ai_t = 0.0
	objectives = _pick_objectives()
	_banner("Vague 1", 1.4)


func _banner(s: String, d: float) -> void:
	banner = s
	banner_t = d


# ---------- objectifs ----------

func _pick_objectives() -> Array:
	var pool: Array = []
	for id in OBJECTIVE_IDS:
		if id == "weak" and not use_boss:
			continue          # les points faibles n'existent que face à un gardien
		pool.append(id)
	var out: Array = []
	for i in 2:
		var k := rng.randi_range(0, pool.size() - 1)
		out.append(pool[k])
		pool.remove_at(k)
	return out


func combo_goal() -> int:
	return 10 * SHIPS[tier].guns.size()


func objective_text(id: String) -> String:
	match id:
		"combo": return "Combo x%d" % combo_goal()
		"hits": return "Moins de 2 impacts"
		"fast": return "Terminer en moins de %d s" % int(FAST_GOAL)
		"avoid": return "Esquiver ou bloquer 3 tirs"
		"charge": return "2 tirs chargés"
		"weak": return "20 points faibles touchés"
		"hull": return "Finir avec 60 % de coque"
		"scan": return "Utiliser Analyse 2 fois"
	return id


func objective_done(id: String) -> bool:
	match id:
		"combo": return max_combo >= combo_goal()
		"hits": return hits < 2
		"fast": return t < FAST_GOAL
		"avoid": return avoided >= 3
		"charge": return charges >= 2
		"weak": return weak >= 20
		"hull": return hull >= 0.6 * hull_max
		"scan": return scans >= 2
	return false


func objectives_done() -> int:
	var n := 0
	for id in objectives:
		if objective_done(id):
			n += 1
	return n


# ---------- paramètres de difficulté ----------

func _hp_mul() -> float:
	return DIFF.hp[tier] * hp_scale


func _dmg_mul() -> float:
	return DIFF.dmg[tier] * dmg_scale


func _rate() -> float:
	return DIFF.rate[tier]


func guns() -> Array:
	return SHIPS[tier].guns


# ---------- ennemis ----------

func _spawn(kind: String, n: int) -> void:
	var cm: float = DIFF.cm[tier]
	if kind == "drone" or kind == "swarm":
		n = maxi(1, int(round(float(n) * cm)))
	for i in n:
		var e := {"k": kind, "x": LANES[i % 3], "y": -40.0, "ty": 0.0, "hp": 0.0, "max": 0.0, "r": 24.0, "move": rng.randf_range(1.0, 3.0),
			"shoot": rng.randf_range(1.0, 2.6), "tx": 0.0, "lane": i % 3, "flash": 0.0, "dead": false, "safe": 1}
		match kind:
			"drone":
				e.hp = round(70.0 * _hp_mul() / cm)
				e.ty = 84.0 + floorf(float(i) / 3.0) * 30.0 + float(i % 2) * 10.0
				e.x = LANES[(i * 2 + 1) % 3]
				e.tx = e.x
			"swarm":
				e.hp = round(28.0 * _hp_mul() / cm)
				e.r = 13.0
				e.ty = 56.0 + floorf(float(i) / 3.0) * 40.0
				e.x = LANES[i % 3] + (18.0 if i % 2 == 1 else -18.0)
				e.tx = e.x
				e.shoot = rng.randf_range(2.0, 5.0)
			"tireur":
				e.hp = round(170.0 * _hp_mul())
				e.r = 32.0
				e.ty = 70.0
				e.x = LANES[1]
				e.tx = e.x
				e.shoot = 2.2
			"boss":
				e.hp = round(1500.0 * _hp_mul())
				e.r = 60.0
				e.ty = 64.0
				e.x = LANES[1]
				e.tx = e.x
				e.shoot = 3.0
		e.max = e.hp
		enemies.append(e)
		if kind == "boss":
			boss = e


func _spawn_wave(i: int) -> void:
	match i:
		0: _spawn("drone", 2)
		1: _spawn("drone", 3)
		2: _spawn("swarm", 6)
		3:
			_spawn("tireur", 1)
			_spawn("drone", 2)
		4:
			if use_boss:
				_spawn("boss", 1)
			else:
				_spawn("tireur", 2)
				_spawn("swarm", 3)


func _ebullet(x: float, y: float, base: float) -> void:
	var r := rng.randf()
	var b := {"x": x, "y": y, "v": 0.0, "a": 0.0, "kind": "norm", "dead": false}
	var sp: float = DIFF.speed
	if r < 0.3:
		b.v = 105.0 * sp
		b.kind = "slow"
	elif r < 0.6:
		b.v = 330.0 * sp
		b.kind = "fast"
	elif r < 0.85:
		b.v = 90.0 * sp
		b.a = 300.0 * sp
		b.kind = "accel"
	else:
		b.v = base * sp
	ebullets.append(b)


func _tele(lanes: Array, dur: float, dmg: float, label: String) -> void:
	events.append("warn")
	beams.append({"lanes": lanes, "t": 0.0, "dur": dur, "dmg": dmg, "label": label, "fired": false, "flash": 0.0})


static func lane_of(x: float) -> int:
	return 0 if x < 120.0 else (1 if x < 240.0 else 2)


func set_lane(n: int) -> void:
	lane = clampi(n, 0, 2)


# ---------- dégâts ----------

func _text(x: float, y: float, s: String, col: Color, size: int = 16) -> void:
	texts.append({"x": x, "y": y, "s": s, "c": col, "z": size, "t": 0.0})


func _ring(x: float, y: float, col: Color) -> void:
	fx.append({"k": "ring", "x": x, "y": y, "c": col, "t": 0.0})


func _burst(x: float, y: float, col: Color, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var s := rng.randf_range(40.0, 150.0)
		fx.append({"k": "p", "x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s, "c": col, "t": 0.0})


func _hurt(d: float) -> void:
	if over:
		return
	if dodge > 0.0:
		events.append("dodge")
		avoided += 1
		_text(px, PY - 40.0, "ESQUIVÉ", C_CYAN, 15)
		return
	if shield > 0.0:
		events.append("shield")
		shield = 0.0
		avoided += 1
		_text(px, PY - 40.0, "BLOQUÉ", C_ORANGE, 15)
		_ring(px, PY, C_ORANGE)
		return
	events.append("hurt")
	hull -= d
	combo = 0
	hits += 1
	shake = 10.0
	_text(px, PY - 40.0, "-%d" % int(d), C_RED, 20)
	if hull <= 0.0:
		hull = 0.0
		_end(false)


func _damage_enemy(e: Dictionary, d: float, ln: int) -> void:
	var m := ASSIST_DAMAGE if assist else 1.0
	if scan > 0.0:
		m *= 2.0
	if e.k == "boss":
		m *= (0.45 if scan > 0.0 else 0.3) if ln == 1 else 2.0
	var dm := roundf(d * m)
	e.hp -= dm
	e.flash = 0.08
	gauge = minf(100.0, gauge + (3.0 if assist else 6.0))
	combo += 1
	max_combo = maxi(max_combo, combo)
	if e.k == "boss" and ln != 1:
		weak += 1
	if dm >= d * 1.9:
		_text(e.x + rng.randf_range(-14.0, 14.0), e.y + e.r + 6.0, str(int(dm)), C_GOLD, 22)
	elif rng.randf() < 0.35:
		_text(e.x + rng.randf_range(-14.0, 14.0), e.y + e.r + 6.0, str(int(dm)), C_INK, 13)
	if e.hp <= 0.0 and not e.dead:
		events.append("kill")
		e.dead = true
		_burst(e.x, e.y, C_PINK if e.k == "boss" else C_SAND, 60 if e.k == "boss" else 14)
		var mult := 8 if e.k == "boss" else (3 if e.k == "tireur" else 1)
		minerals += 6 * mult
		data += 3 * mult


# ---------- compétences ----------

func use_ability(k: String) -> bool:
	if over:
		return false
	if k == "dodge" and cd.dodge <= 0.0:
		dodge = DODGE_TIME
		cd.dodge = COOLDOWN.dodge
		_ring(px, PY, C_CYAN)
		events.append("dodge")
		return true
	elif k == "shield" and cd.shield <= 0.0:
		shield = 1.0
		cd.shield = COOLDOWN.shield
		_ring(px, PY, C_ORANGE)
		return true
	elif k == "scan" and cd.scan <= 0.0:
		events.append("scan")
		scan = SCAN_TIME
		scans += 1
		cd.scan = COOLDOWN.scan
		_ring(px, PY, C_GREEN)
		_text(180.0, H / 2.0, "ANALYSE", C_GREEN, 26)
		return true
	elif k == "charge" and gauge >= 100.0:
		events.append("charge")
		gauge = 0.0
		charges += 1
		var ln := lane
		fx.append({"k": "col", "x": LANES[ln], "t": 0.0})
		for e in enemies:
			if e.dead:
				continue
			if lane_of(e.x) == ln or (e.k == "boss" and ln != 1) or absf(e.x - LANES[ln]) < e.r:
				_damage_enemy(e, CHARGE_DAMAGE, ln)
		shake = 6.0
		return true
	return false


## Abandon : compte comme une défaite.
func abandon() -> void:
	_end(false)


# ---------- boucle ----------

func step(dt: float) -> void:
	if over:
		_step_effects(dt)
		return
	t += dt
	banner_t = maxf(0.0, banner_t - dt)
	shake = maxf(0.0, shake - dt * 30.0)
	for k in ["dodge", "shield", "scan"]:
		cd[k] = maxf(0.0, cd[k] - dt)
	dodge = maxf(0.0, dodge - dt)
	scan = maxf(0.0, scan - dt)
	px += (LANES[lane] - px) * minf(1.0, dt * 14.0)

	# vagues
	if enemies.is_empty():
		if delay >= 9000.0:
			delay = 0.8                              # la vague vient d'être éliminée
		elif delay > 0.0:
			delay -= dt
		else:
			if wave >= wave_total - 1:
				_end(true)
				return
			wave += 1
			_banner("GARDIEN" if (wave_list[wave] == WAVE_COUNT - 1 and use_boss) else "Vague %d" % (wave + 1), 1.5)
			_spawn_wave(wave_list[wave])
			delay = 9999.0

	if assist:
		_ai_step(dt, AI_AUTO)
	elif human_bot:
		_ai_step(dt, AI_HUMAN)

	# tir automatique
	fire -= dt
	if fire <= 0.0:
		fire = 0.28
		for g in SHIPS[tier].guns:
			pbullets.append({"x": px + g, "y": PY - 34.0, "lane": lane, "v": rng.randf_range(420.0, 680.0), "dead": false})
	# projectiles du joueur
	for b in pbullets:
		b.y -= b.v * dt
		for e in enemies:
			if e.dead:
				continue
			var inx: bool = true if e.k == "boss" else absf(b.x - e.x) < e.r + 6.0
			var bottom: float = e.y + (44.0 if e.k == "boss" else e.r)
			if inx and b.y < bottom and b.y > e.y - e.r - 20.0:
				b.dead = true
				_damage_enemy(e, SHIPS[tier].dmg, b.lane)
				break
		if b.y < -10.0:
			b.dead = true
	pbullets = pbullets.filter(func(b): return not b.dead)

	# ennemis
	for e in enemies.duplicate():
		if e.dead:
			continue
		e.flash = maxf(0.0, e.flash - dt)
		e.y += (e.ty - e.y) * minf(1.0, dt * 4.0)
		e.x += (e.tx - e.x) * minf(1.0, dt * 3.0)
		match e.k:
			"drone":
				e.move -= dt
				if e.move <= 0.0:
					e.move = rng.randf_range(2.5, 4.5)
					e.tx = LANES[rng.randi_range(0, 2)]
				e.shoot -= dt
				if e.shoot <= 0.0 and e.y > 40.0:
					e.shoot = rng.randf_range(2.2, 3.2) / _rate()
					_ebullet(e.x, e.y + 20.0, 170.0)
			"swarm":
				e.x += sin(t * 2.0 + float(e.lane)) * dt * 14.0
				e.shoot -= dt
				if e.shoot <= 0.0 and e.y > 30.0:
					e.shoot = rng.randf_range(3.0, 5.0) / _rate()
					_ebullet(e.x, e.y + 10.0, 150.0)
			"tireur":
				e.shoot -= dt
				if e.shoot <= 0.0 and beams.is_empty():
					e.shoot = 3.6 / _rate()
					var ln: int = lane if rng.randf() < 0.7 else rng.randi_range(0, 2)
					e.tx = LANES[ln]
					_tele([ln], rng.randf_range(0.85, 1.4) * DIFF.tele, roundf(110.0 * _dmg_mul()), "TIR")
			"boss":
				e.shoot -= dt
				if e.shoot <= 0.0 and beams.is_empty():
					e.shoot = 4.6 / _rate()
					var safe := rng.randi_range(0, 2)
					var lanes: Array = []
					for l in 3:
						if l != safe:
							lanes.append(l)
					_tele(lanes, 2.0 * DIFF.tele, roundf(170.0 * _dmg_mul()), "BALAYAGE")
					e.safe = safe
				if not summoned and e.hp < e.max * 0.3:
					summoned = true
					_banner("PHASE 3", 1.3)
					_spawn("drone", 2)
	enemies = enemies.filter(func(e): return not e.dead)
	if boss.size() > 0 and boss.dead:
		boss = {}

	# projectiles ennemis
	for b in ebullets:
		b.v = minf(380.0 * DIFF.speed, b.v + b.a * dt)
		b.y += b.v * dt
		if b.y > PY - 26.0 and b.y < PY + 22.0 and absf(b.x - px) < 26.0:
			b.dead = true
			_hurt(roundf(90.0 * _dmg_mul()))
		if b.y > H + 10.0:
			b.dead = true
	ebullets = ebullets.filter(func(b): return not b.dead)
	# tirs annoncés
	for b in beams:
		b.t += dt
		if not b.fired and b.t >= b.dur:
			b.fired = true
			b.flash = 0.35
			if b.lanes.has(lane):
				_hurt(b.dmg)
			shake = maxf(shake, 5.0)
		if b.fired:
			b.flash -= dt
	beams = beams.filter(func(b): return not (b.fired and b.flash <= 0.0))
	_step_effects(dt)


func _step_effects(dt: float) -> void:
	for f in fx:
		f.t += dt
		if f.k == "p":
			f.x += f.vx * dt
			f.y += f.vy * dt
	fx = fx.filter(func(f): return f.t < (0.7 if f.k == "p" else 0.5))
	for tx in texts:
		tx.t += dt
		tx.y -= 28.0 * dt
	texts = texts.filter(func(x): return x.t < 0.9)


func _end(victory: bool) -> void:
	if over:
		return
	over = true
	win = victory
	events.append("win" if victory else "lose")


## Résultat à transmettre au jeu.
func result() -> Dictionary:
	return {
		"win": win, "time": t, "hits": hits, "max_combo": max_combo, "objectives": objectives.duplicate(),
		"objectives_done": objectives_done() if win else 0, "minerals": minerals, "data": data, "tier": tier, "hull_frac": hull / hull_max,
	}


# ---------- équipage assisté ----------

func _ai_step(dt: float, p: Dictionary) -> void:
	_ai_t -= dt
	if _ai_t > 0.0:
		return
	_ai_t = p.react
	if p.lapse > 0.0 and rng.randf() < p.lapse:
		return
	var dan := [0.0, 0.0, 0.0]
	var soon := [9.0, 9.0, 9.0]
	for b in beams:
		if b.fired:
			continue
		var rem: float = b.dur - b.t
		for l in b.lanes:
			dan[l] += 1000.0 if rem < 0.75 else 200.0
			soon[l] = minf(soon[l], rem)
	for b in ebullets:
		for l in 3:
			if absf(b.x - LANES[l]) < 30.0:
				var d: float = PY - b.y
				var eta: float
				if b.a > 0.0:
					eta = (-b.v + sqrt(b.v * b.v + 2.0 * b.a * maxf(0.0, d))) / b.a
				else:
					eta = d / b.v
				if eta > -0.12 and eta < 1.1:
					dan[l] += 500.0 * (1.0 - eta / 1.3)
					soon[l] = minf(soon[l], maxf(0.0, eta))
	var val := [0.0, 0.0, 0.0]
	for e in enemies:
		if e.dead:
			continue
		if e.k == "boss":
			val[0] += 2.2 if scan > 0.0 else 3.2
			val[2] += 2.2 if scan > 0.0 else 3.2
			val[1] += 1.4 if scan > 0.0 else 0.3
			continue
		var w := 2.2 if e.k == "tireur" else (0.9 if e.k == "swarm" else 1.2)
		for l in 3:
			if absf(e.x - LANES[l]) < e.r + 12.0:
				val[l] += w * (0.5 + 0.5 * e.hp / e.max)
	var best := lane
	var bs := -1.0e9
	for l in 3:
		var sc: float = val[l] * 10.0 - dan[l] - absf(float(l - lane)) + (1.5 if l == lane else 0.0)
		if sc > bs:
			bs = sc
			best = l
	if best != lane:
		set_lane(best)
	var cur := lane
	var all_bad: bool = dan[0] >= 400.0 and dan[1] >= 400.0 and dan[2] >= 400.0
	var hit_soon: bool = dan[cur] >= 400.0 and soon[cur] < 0.4
	if hit_soon or (all_bad and soon[cur] < 0.6):
		if shield <= 0.0 and cd.shield <= 0.0:
			use_ability("shield")
		elif dodge <= 0.0 and cd.dodge <= 0.0 and soon[cur] < 0.3 and rng.randf() > p.dodge_miss:
			use_ability("dodge")
	if shield <= 0.0 and cd.shield <= 0.0 and dan[cur] >= 200.0 and soon[cur] < 0.6 and hull < hull_max * 0.7:
		use_ability("shield")
	var hp := 0.0
	for e in enemies:
		if not e.dead:
			hp += e.hp
	if cd.scan <= 0.0 and scan <= 0.0 and ((boss.size() > 0 and not enemies.is_empty()) or hp > 380.0):
		use_ability("scan")
	if gauge >= 100.0 and val[cur] > 0.8:
		use_ability("charge")
