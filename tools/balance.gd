extends SceneTree
## Simulation d'équilibrage : un joueur « robot » suit un planning de sessions (avec des absences entre),
## lance les recherches, fait des anomalies avec ses charges et dépense au mieux.
##   godot --headless --path . -s tools/balance.gd -- <profil> [jours] [--detail]
## Profils : casual (1 session de 5 min/jour), regular (3 x 8 min), hardcore (6 x 10 min), evening (1 x 15 min le soir).
const Data = preload("res://scripts/game_data.gd")
const PROFILES := {
	"casual": [[8.0, 5.0]],
	"evening": [[21.0, 15.0]],
	"regular": [[8.0, 8.0], [12.5, 8.0], [19.0, 8.0]],
	"hardcore": [[7.0, 10.0], [10.0, 10.0], [13.0, 10.0], [16.0, 10.0], [19.0, 10.0], [22.0, 10.0]],
}
const CHECK_DAYS := [1, 3, 7, 14, 21, 30, 45, 60, 75, 90, 120]
const Bot = preload("res://tools/bot.gd")
var gs: Node
var bot
var _last_sig := 0
var _day := 0
var _last_progress_day := 0
var _worst_gap_days := 0
var _sessions := 0
var _sessions_with_progress := 0
var _idle_research_starts := 0     # sessions commencées avec un poste de recherche libre et rien en file
var _full_charge_starts := 0       # sessions commencées avec les charges d'anomalie pleines (recharge perdue)


func _initialize() -> void:
	await process_frame
	gs = root.get_node("GameState")
	gs.save_path = "user://balance_test.json"
	var args := OS.get_cmdline_user_args()
	var profile := args[0] if args.size() > 0 else "regular"
	var days := int(args[1]) if args.size() > 1 else 60
	gs.new_game()
	gs.rng.seed = 12345
	bot = Bot.new(gs)
	var sessions: Array = PROFILES[profile]
	print("Profil : %s, %d jours" % [profile, days])
	print(" jour | capitaine | faille max | niveau AFK | équipage niv. | équipement (niv. moy., épiques+, légend.) | recherches | AFK victoires | sessions avec progrès (14 dern.) | pire écart")
	var clock := 0.0
	var cp := 0
	var recent: Array = []
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
			_session_start_stats()
			bot.play(float(s[1]) * 60.0)
			clock += float(s[1]) * 60.0
			_day = day + 1
			recent.append(1 if _track() else 0)
			if recent.size() > 14:
				recent.pop_front()
		if cp < CHECK_DAYS.size() and day + 1 == CHECK_DAYS[cp]:
			_report(day + 1, recent)
			cp += 1
	_worst_gap_days = maxi(_worst_gap_days, days - _last_progress_day)
	print("FRUSTRATION | sessions avec progrès %d/%d | plus longue période sans progrès %d j | postes de recherche vides au début %d/%d | charges d'anomalie pleines au début (recharge perdue) %d/%d | défaites en anomalie %d/%d | sessions sans charge %d" % [
		_sessions_with_progress, _sessions, _worst_gap_days, _idle_research_starts, _sessions, _full_charge_starts, _sessions,
		bot.anomaly_defeats, bot.anomaly_runs, bot.no_charge_sessions])
	quit()


func _session_start_stats() -> void:
	if gs.research_active.size() < gs.research_slots() and gs.research_queue.is_empty():
		_idle_research_starts += 1
	if gs.anomaly_charges >= float(Data.ANOMALY_CHARGES_MAX) - 0.01:
		_full_charge_starts += 1


func _signature() -> int:
	var n: int = int(gs.captain.level) + gs.hero_order.size() * 3 + gs.goals_claimed.size() * 5 + gs.anomaly_max * 2
	for id in gs.hero_order:
		n += gs.heroes[id].level
	for id in gs.research_levels:
		n += gs.research_levels[id] * 4
	for id in gs.upgrade_levels:
		n += gs.upgrade_levels[id] * 2
	for slot in Data.EQUIP_SLOTS:
		var it: Dictionary = gs.equipped_item(slot)
		if not it.is_empty():
			n += int(gs.item_power(it) / 40.0)
	return n


func _track() -> bool:
	var sig := _signature()
	var progressed := sig > _last_sig
	_last_sig = sig
	_sessions += 1
	if progressed:
		_sessions_with_progress += 1
		_worst_gap_days = maxi(_worst_gap_days, _day - _last_progress_day)
		_last_progress_day = _day
	return progressed


func _report(day: int, recent: Array) -> void:
	var crew_lv := 0
	for id in gs.hero_order:
		crew_lv += gs.heroes[id].level
	var rs := 0
	var rs_max := 0
	for id in Data.RESEARCH_ORDER:
		rs += gs.research_levels[id]
		rs_max += Data.RESEARCH[id].max
	var ilvl_sum := 0
	var n_items := 0
	var epic_plus := 0
	var legend := 0
	for slot in Data.EQUIP_SLOTS:
		var it: Dictionary = gs.equipped_item(slot)
		if not it.is_empty():
			ilvl_sum += it.ilvl
			n_items += 1
			if it.rarity == "epic" or it.rarity == "legendary":
				epic_plus += 1
			if it.rarity == "legendary":
				legend += 1
	var wins: int = gs.afk_wins
	var rec := 0
	for v in recent:
		rec += v
	print("%5d | niv %3d | %3d | %4d | %5d | niv. %3d, %d/6 épiques+, %d légend. | %3d/%3d | %3d %% | %2d/%2d | %d" % [
		day, gs.captain.level, gs.anomaly_max, gs.afk_level(), crew_lv, ilvl_sum / maxi(1, n_items), epic_plus, legend, rs, rs_max,
		int(100.0 * wins / maxf(1.0, float(gs.afk_wins + gs.afk_defeats))), rec, recent.size(), _worst_gap_days])
