extends SceneTree
## Puissance minimale pour gagner chaque étage (godot --headless --path . -s tools/calibrate.gd -- [étages max]).
## Pour chaque étage : plus petit niveau d'escouade uniforme qui gagne à coup sûr (5 graines) avec au moins 2 étoiles, et le rapport à la puissance de base.

const Data = preload("res://scripts/data.gd")


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var max_stage := int(a[0]) if a.size() > 0 else 40
	var base := Data.team_power({})
	print("étage ; type ; niveau mini ; puissance ; facteur vs base*échelle")
	for st in range(1, max_stage + 1):
		var lvl := 1
		while lvl < 80 and not _wins(st, lvl):
			lvl += 1
		var lv := {}
		for id in Data.HERO_ORDER:
			lv[id] = lvl
		var p := Data.team_power(lv)
		print("%d ; %s ; %d ; %d ; %.2f" % [st, Data.boss_type(st), lvl, p, p / (base * Data.stage_scale(st))])
	quit()


func _wins(st: int, lvl: int) -> bool:
	var team: Array = []
	for id in Data.HERO_ORDER:
		team.append({"id": id, "level": lvl})
	for sd in 5:
		var s := BattleSim.new(team, st, 11 + sd * 7)
		if s.run(240.0) != "clear" or s.stars < 2:
			return false
	return true
