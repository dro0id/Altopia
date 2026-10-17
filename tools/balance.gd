extends SceneTree
## Simulation d'équilibrage : un joueur « robot » suit un planning de sessions (avec des absences entre),
## lance les recherches et dépense au mieux. Il sert à vérifier la durée du jeu et l'absence de frustration.
##   godot --headless --path . -s tools/balance.gd -- <profil> [jours]
## Profils : casual (1 session de 5 min/jour), regular (3 x 8 min), hardcore (6 x 10 min), evening (1 x 15 min le soir).
const Data = preload("res://scripts/game_data.gd")
const PROFILES := {
	"casual": [[8.0, 5.0]],
	"evening": [[21.0, 15.0]],
	"regular": [[8.0, 8.0], [12.5, 8.0], [19.0, 8.0]],
	"hardcore": [[7.0, 10.0], [10.0, 10.0], [13.0, 10.0], [16.0, 10.0], [19.0, 10.0], [22.0, 10.0]],
}
const CHECK_DAYS := [1, 3, 7, 14, 21, 30, 45, 60, 75, 90, 120]
const RESEARCH_PRIORITY := ["labo_annexe", "academie_capitaine", "academie_equipage", "labo_vitesse", "calibrage",
	"protocoles", "soute", "entrainement", "cartographie", "propulsion", "butin",
	"calibrage_ii", "entrainement_ii", "cartographie_ii", "propulsion_ii", "butin_ii",
	"calibrage_iii", "entrainement_iii", "cartographie_iii", "propulsion_iii", "butin_iii"]
var gs: Node
var _last_sig := 0
var _no_progress_run := 0
var _worst_no_progress := 0
var _sessions := 0
var _sessions_with_progress := 0
var _recent: Array = []     # progrès des dernières sessions (1/0)
var _cap_log: Array = []    # jours où un plafond de niveau a monté
var _last_caps := Vector2i.ZERO
var _day := 0
var _last_progress_day := 0
var _worst_gap_days := 0


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.save_path = "user://balance_test.json"
	var args := OS.get_cmdline_user_args()
	var profile := args[0] if args.size() > 0 else "regular"
	var days := int(args[1]) if args.size() > 1 else 60
	gs.new_game()
	gs.rng.seed = 12345
	var sessions: Array = PROFILES[profile]
	print("Profil : %s, %d jours" % [profile, days])
	print(" jour | capitaine (plafond) | équipage niv./plafond | recherches | vaisseau | postes | crédits/h | données | obj. | sessions avec progrès (14 derniers) | pire série sans progrès")
	var clock := 0.0                       # secondes depuis le début
	var cp := 0
	for day in days:
		for s in sessions:
			var start: float = day * 86400.0 + float(s[0]) * 3600.0
			if start > clock:
				var away: float = start - clock
				if away > 60.0:
					gs.simulate_offline(away)
				else:
					gs.tick(away)
				clock = start
			_play(float(s[1]) * 60.0)
			clock += float(s[1]) * 60.0
			_day = day + 1
			_track()
		if cp < CHECK_DAYS.size() and day + 1 == CHECK_DAYS[cp]:
			_report(day + 1)
			cp += 1
	print("Plafonds : ", " · ".join(_cap_log))
	_worst_gap_days = maxi(_worst_gap_days, days - _last_progress_day)
	print("Sessions avec progrès : %d/%d, pire série sans progrès : %d sessions, plus longue période sans aucun progrès : %d jour(s)" % [_sessions_with_progress, _sessions, _worst_no_progress, _worst_gap_days])
	quit()


func _play(seconds: float) -> void:
	var step := 20.0
	var t := 0.0
	while t < seconds:
		_spend()
		gs.tick(step)
		t += step
	_spend()


func _signature() -> int:
	var n: int = int(gs.captain.level) + gs.hero_order.size() * 3 + gs.goals_claimed.size() * 5
	for id in gs.hero_order:
		n += gs.heroes[id].level
	for id in gs.research_levels:
		n += gs.research_levels[id] * 4
	for id in gs.upgrade_levels:
		n += gs.upgrade_levels[id] * 2
	for slot in Data.EQUIP_SLOTS:
		n += int(gs.item_power(gs.equipped_item(slot)) / 40.0) if not gs.equipped_item(slot).is_empty() else 0
	return n


func _track() -> void:
	var caps := Vector2i(gs.captain_cap(), gs.crew_cap())
	if caps != _last_caps:
		_cap_log.append("j%d: capitaine %d / équipage %d" % [_day, caps.x, caps.y])
		_last_caps = caps
	var sig := _signature()
	var progressed := sig > _last_sig
	_last_sig = sig
	_sessions += 1
	if progressed:
		_sessions_with_progress += 1
		_no_progress_run = 0
		_worst_gap_days = maxi(_worst_gap_days, _day - _last_progress_day)
		_last_progress_day = _day
	else:
		_no_progress_run += 1
		_worst_no_progress = maxi(_worst_no_progress, _no_progress_run)
	_recent.append(1 if progressed else 0)
	if _recent.size() > 14:
		_recent.pop_front()


## Politique d'achat du robot.
func _spend() -> void:
	gs.claim_goal()
	for i in gs.slot_count():
		if gs.slots[i].dest == "":
			for d in ["planet", "star", "asteroids"]:
				if gs.launch_block_reason(d, i) == "" and gs.launch(i, d):
					break
	gs.auto_squad(0)
	for a in gs.research_active.duplicate():       # accélère quand l'énergie est largement suffisante
		if gs.research_boost_cost(a.id) > 0.0 and gs.res.energy > gs.research_boost_cost(a.id) * 8.0:
			gs.boost_research(a.id)
			gs.boost_research(a.id)
	for k in 4:
		var id := _pick_research()
		if id == "" or not gs.start_research(id):
			break
	for pass_i in 6:
		var bought := false
		if gs.captain.level < gs.captain_cap() and gs.res.credits >= gs.captain_train_cost():
			bought = gs.train_captain() or bought
		var best := ""
		var best_c := 1e30
		for id in gs.hero_order:
			if gs.heroes[id].level < gs.hero_cap(id) and gs.train_cost(id) < best_c:
				best = id
				best_c = gs.train_cost(id)
		if best != "" and gs.res.credits >= best_c:
			bought = gs.train(best) or bought
		for id in Data.UPGRADE_ORDER:
			if gs.upgrade_maxed(id):
				continue
			if id == "docks" and gs.res.credits < 3000.0:
				continue
			if gs.can_afford(gs.upgrade_cost(id)) and gs.res.credits > gs.upgrade_cost(id).credits * 1.5:
				bought = gs.buy_upgrade(id) or bought
		if gs.hero_order.size() < Data.HEROES.size() and gs.res.credits >= gs.recruit_cost() * 2.0:
			gs.recruit()
			bought = true
		if not bought:
			break
	gs.auto_equip()


func _pick_research() -> String:
	var cap_close: bool = gs.captain.level >= gs.captain_cap() - 3
	var crew_close := false
	for id in gs.hero_order:
		if gs.heroes[id].level >= gs.hero_cap(id) - 3:
			crew_close = true
	for id in RESEARCH_PRIORITY:
		if id == "academie_capitaine" and not cap_close:
			continue
		if id == "academie_equipage" and not crew_close:
			continue
		if gs.research_block_reason(id) == "" and gs.can_afford(gs.research_cost(id)):
			return id
	return ""


func _report(day: int) -> void:
	var crew_lv := 0
	for id in gs.hero_order:
		crew_lv += gs.heroes[id].level
	var rs := 0
	var rs_max := 0
	for id in Data.RESEARCH_ORDER:
		rs += gs.research_levels[id]
		rs_max += Data.RESEARCH[id].max
	var ships := 0
	for u in ["laser", "solar", "scanner", "engines"]:
		ships += gs.upgrade_levels[u]
	var st := 0
	for c in Data.CREW_ORDER:
		st += gs.upgrade_levels["st_" + c]
	var prod: Dictionary = gs.production_per_sec()
	var rec := 0
	for v in _recent:
		rec += v
	print("%5d | %3d (%3d) | %4d / %3d | %3d/%3d | %3d | %3d | %9s | %9s | %2d/%d | %2d/%2d | %d" % [
		day, gs.captain.level, gs.captain_cap(), crew_lv, gs.crew_cap() * gs.hero_order.size(), rs, rs_max, ships, st,
		Data.fmt(prod.credits * 3600.0), Data.fmt(gs.data_total), gs.goals_claimed.size(), Data.GOALS.size(),
		rec, _recent.size(), _worst_no_progress])
	if OS.get_cmdline_user_args().has("--detail"):
		print("      revenus/h  cr %s  min %s  én %s  don %s   |  stock  cr %s  min %s  én %s  don %s" % [
			Data.fmt(prod.credits * 3600.0), Data.fmt(prod.minerals * 3600.0), Data.fmt(prod.energy * 3600.0), Data.fmt(prod.data * 3600.0),
			Data.fmt(gs.res.credits), Data.fmt(gs.res.minerals), Data.fmt(gs.res.energy), Data.fmt(gs.res.data)])
