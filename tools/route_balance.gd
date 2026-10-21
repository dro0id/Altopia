extends SceneTree
## Équilibrage de la Route : fait jouer des voyages entiers (combats en direct simulés, équipage assisté ou joueur simulé) et affiche les taux de victoire.
## Usage : godot --headless --path . -s tools/route_balance.gd -- [voyages par palier] [échelle de difficulté]
const LiveSim = preload("res://scripts/live_sim.gd")
const RouteSim = preload("res://scripts/route_sim.gd")


static func fight_bot(human: bool, seed_base: int) -> Callable:
	var counter := [0]
	return func(cfg: Dictionary) -> Dictionary:
		counter[0] += 1
		var s := LiveSim.new(seed_base + counter[0] * 104729)
		cfg["assist"] = not human
		s.human_bot = human
		s.setup(cfg)
		var steps := 0
		while not s.over and steps < 20000:
			s.step(1.0 / 30.0)
			steps += 1
		return s.result()


static func play(tier: int, human: bool, seed_value: int, scale: float) -> Dictionary:
	var r := RouteSim.new(seed_value)
	r.setup({"tier": tier, "hp_scale": scale, "dmg_scale": scale, "cap_level": 20,
		"crew": {"pilot": {"name": "Rex", "level": 6, "present": true}, "engineer": {"name": "Gorn", "level": 4, "present": true}, "scientist": {"name": "Lumi", "level": 4, "present": true}}})
	var fb := fight_bot(human, seed_value)
	var guard := 0
	while not r.over and guard < 200:
		guard += 1
		if not r.auto_step(fb):
			break
	return r.result()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	var scale := float(args[1]) if args.size() > 1 else 1.0
	if args.size() > 2:        # réglage par palier à essayer, p. ex. [1,1,0.8,1,0.9]
		RouteSim.TIER_DMG = JSON.parse_string(args[2])
	print("Route : %d voyages par ligne, difficulté x%.2f" % [n, scale])
	for tier in LiveSim.SHIPS.size():
		var line := "palier %d %-10s" % [tier + 1, LiveSim.SHIPS[tier].name]
		for human in [false, true]:
			var wins := 0
			var steps := 0.0
			var fights := 0.0
			var objs := 0.0
			for i in n:
				var res := play(tier, human, 7001 + i * 7919, scale)
				if res.win:
					wins += 1
				steps += float(res.steps)
				fights += float(res.fights)
				objs += float(res.objectives_done)
			line += "   %s %3d %%  (%.1f étapes, %.1f combats, %.2f obj.)" % ["auto" if not human else "joueur", int(round(100.0 * float(wins) / float(n))), steps / n, fights / n, objs / n]
		print(line)
	quit()
