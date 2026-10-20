extends SceneTree
## Équilibrage de la dérive : fait jouer le pilote automatique et un joueur simulé et affiche les taux de victoire.
## Usage : godot --headless --path . -s tools/derive_balance.gd -- [parties] [réglages JSON, ex. {"energy": 12.0}]
const DeriveSim = preload("res://scripts/derive_sim.gd")


func _run(assist: bool, human: bool, n: int, seed_base: int, extra: Dictionary) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var hits := 0
	var ext := 0
	var objs := 0
	var reasons := {}
	for i in n:
		var s := DeriveSim.new(seed_base + i * 7919)
		s.human_bot = human
		var cfg := {"hull": 1000.0, "assist": assist}
		cfg.merge(extra)
		s.setup(cfg)
		var steps := 0
		while not s.over and steps < 6000:
			s.step(1.0 / 30.0)
			steps += 1
		if not s.over:
			s.finish(false)
		if s.win:
			wins += 1
			total_t += s.t
		reasons[s.over_reason] = int(reasons.get(s.over_reason, 0)) + 1
		hits += s.hits
		ext += s.extracted
		objs += s.objectives_done()
	return {"win": float(wins) / float(n), "time": total_t / maxf(1.0, float(wins)), "hits": float(hits) / float(n), "ext": float(ext) / float(n), "obj": float(objs) / float(n), "reasons": reasons}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 200
	var extra := {}
	if args.size() > 1:
		var over: Dictionary = JSON.parse_string(args[1])
		for k in over:
			if DeriveSim.CFG.has(k):
				DeriveSim.CFG[k] = over[k]
			else:
				extra[k] = over[k]
	var a := _run(true, false, n, 1001, extra)
	var h := _run(false, true, n, 5003, extra)
	print("Dérive : %d parties par ligne" % n)
	print("auto           %3d %%  (%2ds, %.2f impacts, %.1f ressources, %.2f obj.)  fins : %s" % [int(round(a.win * 100.0)), int(a.time), a.hits, a.ext, a.obj, a.reasons])
	print("joueur simulé  %3d %%  (%2ds, %.2f impacts, %.1f ressources, %.2f obj.)  fins : %s" % [int(round(h.win * 100.0)), int(h.time), h.hits, h.ext, h.obj, h.reasons])
	quit()
