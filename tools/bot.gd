extends RefCounted
## Le joueur « robot » : lance les expéditions, fait ses anomalies, lance les recherches et dépense au mieux.
## Partagé par tools/balance.gd (équilibrage) et tools/playthrough.gd (déroulé en captures).
const Data = preload("res://scripts/game_data.gd")
const RESEARCH_PRIORITY := ["labo_annexe", "labo_vitesse", "calibrage", "protocoles", "soute", "entrainement", "cartographie",
	"propulsion", "butin", "calibrage_ii", "entrainement_ii", "cartographie_ii", "propulsion_ii", "butin_ii",
	"calibrage_iii", "entrainement_iii", "cartographie_iii", "propulsion_iii", "butin_iii",
	"calibrage_iv", "cartographie_iv", "propulsion_iv", "butin_iv"]
var gs: Node
var anomaly_runs := 0
var anomaly_defeats := 0
var no_charge_sessions := 0
var prestige_at := 0          # éclats minimum promis pour que le robot lance une refonte (0 : jamais)
var prestige_log: Array = []


func _init(game_state: Node) -> void:
	gs = game_state


## Une session de jeu de `seconds` secondes (anomalies, puis expéditions et achats au fil du temps).
func play(seconds: float) -> void:
	var step := 20.0
	var t := 0.0
	anomalies()
	while t < seconds:
		spend()
		gs.tick(step)
		t += step
	spend()
	anomalies()


## Le robot fait ses anomalies : la plus haute faille qu'il peut gagner (en visant la suivante si elle est jouable).
func anomalies() -> void:
	var guard := 0
	while gs.anomaly_charges >= 1.0 and guard < 40:
		guard += 1
		var pick := 0
		for n in range(gs.anomaly_unlocked_max(), 0, -1):
			if gs.anomaly_preview(n).win:
				pick = n
				break
		if pick == 0:
			break
		gs.enter_anomaly(pick)
		anomaly_runs += 1
		if not gs.last_anomaly.win:
			anomaly_defeats += 1
	if gs.anomaly_charges < 1.0:
		no_charge_sessions += 1


## Politique d'achat du robot.
func spend() -> void:
	gs.claim_goal()
	if prestige_at > 0 and gs.prestige_block_reason() == "" and gs.prestige_gain() >= prestige_at:
		var lvl: int = gs.base_power()
		var got: int = gs.do_prestige()
		prestige_log.append([lvl, got])
	var cheapest := "x"
	while cheapest != "":
		cheapest = ""
		for id in Data.PRESTIGE_PERK_ORDER:
			if not gs.perk_maxed(id) and gs.prestige_points >= gs.perk_cost(id) and (cheapest == "" or gs.perk_cost(id) < gs.perk_cost(cheapest)):
				cheapest = id
		if cheapest != "":
			gs.buy_perk(cheapest)
	for i in gs.slot_count():
		if gs.slots[i].dest == "":
			var launched := false
			for d in ["planet", "star", "asteroids"]:
				if gs.launch_block_reason(d, i) == "" and gs.preview_battle(d, i).win and gs.launch(i, d):
					launched = true
					break
			if not launched:
				gs.launch(i, "asteroids")
	gs.auto_squad(0)
	gs.auto_rooms()
	gs.auto_squad(1) if gs.slot_count() > 1 else null
	for a in gs.research_active.duplicate():       # accélère quand l'énergie est largement suffisante
		if gs.research_boost_cost(a.id) > 0.0 and gs.res.energy > gs.research_boost_cost(a.id) * 8.0:
			gs.boost_research(a.id)
			gs.boost_research(a.id)
	for k in 4:
		var id := pick_research()
		if id == "" or not gs.start_research(id):
			break
	for pass_i in 6:
		var bought := false
		if gs.res.credits >= gs.captain_train_cost():
			bought = gs.train_captain() or bought
		var best := ""
		var best_c := 1e30
		for id in gs.hero_order:
			if gs.train_cost(id) < best_c:
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
		var rooms: Array = Data.ROOM_ORDER.duplicate()
		rooms.sort_custom(func(a, b): return gs.room_upgrade_cost(a).credits < gs.room_upgrade_cost(b).credits)
		for rid in rooms:
			if not gs.room_maxed(rid) and gs.can_afford(gs.room_upgrade_cost(rid)) and gs.res.credits > gs.room_upgrade_cost(rid).credits * 1.5:
				bought = gs.buy_room_upgrade(rid) or bought
		if gs.hero_order.size() < Data.HEROES.size() and gs.res.credits >= gs.recruit_cost() * 2.0:
			gs.recruit()
			bought = true
		if not bought:
			break
	gs.auto_equip()


func pick_research() -> String:
	for id in RESEARCH_PRIORITY:
		if gs.research_block_reason(id) == "" and gs.can_afford(gs.research_cost(id)):
			return id
	return ""


