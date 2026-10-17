extends SceneTree
## Simulation d'équilibrage : un joueur « robot » suit un planning (sessions courtes + absences)
## et dépense au mieux ses ressources. Affiche des points de contrôle.
##   godot --headless --path . -s tools/balance.gd -- [jours]
const Data = preload("res://scripts/game_data.gd")
var gs: Node

func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.save_path = "user://balance_test.json"
	var days := 7
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		days = int(args[0])
	gs.new_game()
	gs.rng.seed = 12345
	var checkpoints := [4.6, 8.0, 16.0, 24.0, 36.0, 48.0, 60.0, 72.0, 168.0, 336.0]
	var next_cp := 0
	var t := 0.0                       # heures écoulées depuis la première session
	var started := true
	print("  heure | capitaine | équipage(niv.) | postes | vaisseau | crédits/h (en ligne) | données | objectifs | exp.")
	# planning quotidien : 3 sessions de 8 min (matin, midi, soir) ; le reste du temps, absent
	var sessions := [[0.0, 0.13], [4.5, 0.13], [11.0, 0.13]]
	while t < days * 24.0:
		var day_t := fmod(t, 24.0)
		var nxt := 24.0
		var length := 0.0
		for s in sessions:
			if s[0] >= day_t - 0.0001:
				nxt = s[0]
				length = s[1]
				break
		if nxt > day_t + 0.0001 and not started:
			t += nxt - day_t        # le joueur commence à sa première session
			started = true
		elif nxt > day_t + 0.0001:
			_away((nxt - day_t) * 3600.0)
			t += nxt - day_t
		else:
			_session(length * 3600.0)
			t += length
			if length == 0.0:
				t += 0.01
		while next_cp < checkpoints.size() and t >= checkpoints[next_cp]:
			_report(checkpoints[next_cp])
			next_cp += 1
	quit()


func _session(seconds: float) -> void:
	var step := 5.0
	var elapsed := 0.0
	while elapsed < seconds:
		_spend()
		gs.tick(step)
		elapsed += step


func _away(seconds: float) -> void:
	gs.simulate_offline(seconds)


## Politique d'achat : récupère les objectifs, lance les expéditions, puis dépense au mieux.
func _spend() -> void:
	gs.claim_goal()
	for i in gs.slot_count():
		if gs.slots[i].dest == "":
			for d in ["planet", "star", "asteroids"]:
				if gs.launch_block_reason(d, i) == "" and gs.launch(i, d):
					break
	gs.auto_squad(0)
	for pass_i in 6:
		var bought := false
		# Capitaine
		if gs.res.credits >= gs.captain_train_cost() * 1.0 and gs.captain.level < Data.CAPTAIN_MAX_LEVEL:
			bought = gs.train_captain() or bought
		# Héros : le moins cher d'abord
		var best := ""
		var best_c := 1e30
		for id in gs.hero_order:
			if gs.heroes[id].level < Data.MAX_LEVEL and gs.train_cost(id) < best_c:
				best = id
				best_c = gs.train_cost(id)
		if best != "" and gs.res.credits >= best_c:
			bought = gs.train(best) or bought
		# Améliorations : la moins chère en crédits
		for id in Data.UPGRADE_ORDER:
			if gs.upgrade_maxed(id):
				continue
			if id == "docks" and gs.res.credits < 3000.0:
				continue
			if gs.can_afford(gs.upgrade_cost(id)) and gs.res.credits > gs.upgrade_cost(id).credits * 1.5:
				bought = gs.buy_upgrade(id) or bought
		# Recrutement
		if gs.hero_order.size() < Data.HEROES.size() and gs.res.credits >= gs.recruit_cost() * 2.0:
			gs.recruit()
			bought = true
		if not bought:
			break
	gs.auto_equip()


func _report(h: float) -> void:
	var crew_lv := 0
	for id in gs.hero_order:
		crew_lv += gs.heroes[id].level
	var st := 0
	for c in Data.CREW_ORDER:
		st += gs.upgrade_levels["st_" + c]
	var ships := 0
	for u in ["laser", "solar", "scanner", "engines"]:
		ships += gs.upgrade_levels[u]
	var prod: Dictionary = gs.production_per_sec()
	print("%7.2f | niv %2d | %2d cartes / %3d | %3d | %3d | %9s | %9s | %2d/%d | %d" % [
		h, gs.captain.level, gs.hero_order.size(), crew_lv, st, ships, Data.fmt(prod.credits * 3600.0),
		Data.fmt(gs.data_total), gs.goals_claimed.size(), Data.GOALS.size(), gs.expeditions_done])
