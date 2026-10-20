extends SceneTree
## Aide au réglage du combat en direct : pour chaque palier, essaie plusieurs multiplicateurs de dégâts et affiche les taux de victoire
## du pilote automatique et du joueur simulé (on retient le plus petit multiplicateur qui garde les deux sous la cible).
## Usage : godot --headless --path . -s tools/live_fit.gd -- [parties] [palier de départ] [palier de fin]
const LiveSim = preload("res://scripts/live_sim.gd")
const FACTORS := [1.0, 1.2, 1.45, 1.75, 2.1, 2.6]


func _play(tier: int, assist: bool, human: bool, n: int, seed_base: int) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	for i in n:
		var s := LiveSim.new(seed_base + i * 7919)
		s.human_bot = human
		s.setup({"tier": tier, "assist": assist})
		var steps := 0
		while not s.over and steps < 20000:
			s.step(1.0 / 30.0)
			steps += 1
		if s.win:
			wins += 1
			total_t += s.t
	return {"win": float(wins) / float(n), "time": total_t / maxf(1.0, float(wins))}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var t0 := int(args[1]) if args.size() > 1 else 0
	var t1 := int(args[2]) if args.size() > 2 else LiveSim.SHIPS.size() - 1
	for tier in range(t0, t1 + 1):
		var base: float = LiveSim.DIFF.dmg[tier]
		for f in FACTORS:
			LiveSim.DIFF.dmg[tier] = base * f
			var a := _play(tier, true, false, n, 4242)
			var h := _play(tier, false, true, n, 8484)
			print("palier %d  dmg %.1f  -> auto %3d %% (%2d s)   joueur simulé %3d %% (%2d s)" % [tier + 1, base * f, int(a.win * 100.0), int(a.time), int(h.win * 100.0), int(h.time)])
		LiveSim.DIFF.dmg[tier] = base
	quit()
