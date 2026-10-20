extends SceneTree
## Équilibrage du combat en direct : fait jouer le pilote automatique et un joueur simulé et affiche les taux de victoire.
## Usage : godot --headless --path . -s tools/live_balance.gd -- [parties par palier] [échelle de difficulté] [réglages JSON]
const LiveSim = preload("res://scripts/live_sim.gd")


func _run(tier: int, assist: bool, human: bool, n: int, scale: float, seed_base: int) -> Dictionary:
	var wins := 0
	var total_t := 0.0
	var hits := 0
	var objs := 0
	for i in n:
		var s := LiveSim.new(seed_base + i * 7919)
		s.human_bot = human
		s.setup({"tier": tier, "assist": assist, "hp_scale": scale, "dmg_scale": scale})
		var steps := 0
		while not s.over and steps < 20000:
			s.step(1.0 / 30.0)
			steps += 1
		if s.win:
			wins += 1
			total_t += s.t
		hits += s.hits
		objs += s.objectives_done()
	return {"win": float(wins) / float(n), "time": total_t / maxf(1.0, float(wins)), "hits": float(hits) / float(n), "obj": float(objs) / float(n)}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 100
	var scale := float(args[1]) if args.size() > 1 else 1.0
	if args.size() > 2:        # réglages à essayer : {"hp": [...], "dmg": [...], "rate": [...], "cm": [...]}
		var over: Dictionary = JSON.parse_string(args[2])
		for k in over:
			LiveSim.DIFF[k] = over[k]
	print("Combat en direct : %d parties par ligne, difficulté x%.2f" % [n, scale])
	for tier in LiveSim.SHIPS.size():
		var a := _run(tier, true, false, n, scale, 1001)
		var h := _run(tier, false, true, n, scale, 5003)
		print("palier %d %-10s auto %3d %%  (%2ds, %.1f impacts, %.2f obj.)   joueur simulé %3d %%  (%2ds, %.1f impacts, %.2f obj.)" % [
			tier + 1, LiveSim.SHIPS[tier].name, int(round(a.win * 100.0)), int(a.time), a.hits, a.obj,
			int(round(h.win * 100.0)), int(h.time), h.hits, h.obj])
	quit()
