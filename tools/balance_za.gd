extends SceneTree
## (godot --headless -s tools/balance_za.gd) : « SANS » et « AVEC » donnent le niveau minimum par étage.
## Niveau minimum par étage : escouade de départ avec étoiles, sans puis avec les systèmes ZA
## (talents, liens, doctrine, familier) à un niveau réaliste pour l'étage.
const Data = preload("res://scripts/data.gd")
var g: Node

func _setup(st: int, extras: bool, lv: int) -> void:
	g.reset()
	for id in Data.STARTER:
		g.owned[id] = true
		g.levels[id] = lv
		g.hero_stars[id] = clampi(1 + st / 10, 1, 5)
	g.squad = Data.STARTER.duplicate()
	if not extras:
		return
	for id in Data.STARTER:
		for tier in Data.TALENT_TIERS:
			if int(g.hero_stars[id]) >= tier:
				var t: Dictionary = g.talents.get(id, {})
				t[str(tier)] = 0
				g.talents[id] = t
	for b in Bonds.LIST:
		g.bond_xp[String(b.id)] = 40 if st >= 15 else 10
	g.captain_xp = 25 * st
	var pts := Captain.points(g.captain_grade())
	g.doctrine = []
	for id in ["feu", "sangfroid", "enchainement", "seconde", "brise", "parade", "salve", "carre"]:
		if g.doctrine.size() < pts:
			g.doctrine.append(id)
	if st >= 10:
		g.pets = [{"kind": "piquante", "lv": clampi(st / 6, 1, 10)}]
		g.pet_follow = 0

func _need(st: int, extras: bool) -> int:
	for lv in range(1, 140):
		var wins := 0
		for sd in 3:
			_setup(st, extras, lv)
			if BattleSim.new(g.team(), st, sd + 1).run(300.0) == "clear":
				wins += 1
		if wins >= 2:
			return lv
	return -1

func _initialize() -> void:
	await process_frame
	g = root.get_node("Game")
	g.save_path = "user://bal.json"
	var a := ""
	var b := ""
	for st in [6, 12, 18, 25, 32, 39, 45, 55]:
		a += "%d:%d " % [st, _need(st, false)]
		b += "%d:%d " % [st, _need(st, true)]
	print("SANS ", a)
	print("AVEC ", b)
	quit()
