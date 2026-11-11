class_name CombatHud
extends Control

const Data = preload("res://scripts/data.gd")
## Haut de l'écran de combat (maquette XC) : sur les écrans hauts, le ciel vide sert au suivi du combat.
## Puissance de l'escouade face à la puissance conseillée, frise des vagues (faites, en cours, boss),
## et le bandeau des annonces (vague, combo, pouvoir) : il n'est plus écrit sur les héros.
## La barre du boss (BossBar) est posée par main.gd entre la frise et le bandeau.

const ROW_FRIEZE := 104.0
const ROW_BOSS := 84.0
const ROW_BANNER := 76.0

var battle: BattleView
var show_boss := false
var has_banner := true


## Hauteur nécessaire selon ce qu'il y a à montrer.
static func needed(boss: bool) -> float:
	return ROW_FRIEZE + (ROW_BOSS if boss else 0.0) + ROW_BANNER


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func boss_y() -> float:
	return ROW_FRIEZE


func _draw() -> void:
	if battle == null or battle.sim == null:
		return
	var sim: BattleSim = battle.sim
	# puissance : verte si l'escouade dépasse la puissance conseillée, dorée sinon
	var pw := Game.power()
	var rec := Data.recommended_power(Game.stage)
	var ok := pw >= rec
	M3.text(self, Vector2(32, 30), "Puissance %s · conseillée %s" % [UI.num(roundf(pw)), UI.num(roundf(rec))], 22, UI.GREEN if ok else UI.GOLD, true, 656)
	# frise des vagues
	var n := maxi(1, sim.waves_total)
	var x0 := 52.0
	var x1 := 668.0
	var y := 72.0
	var cur := clampi(sim.wave, 1, n)
	var boss_last := show_boss
	draw_line(Vector2(x0, y), Vector2(x1, y), M3.S3, 6.0)
	var prog := 0.0 if n <= 1 else float(cur - 1) / float(n - 1)
	if sim.state == "clear":
		prog = 1.0
	draw_line(Vector2(x0, y), Vector2(lerpf(x0, x1, prog), y), UI.GREEN, 6.0)
	for i in n:
		var w := i + 1
		var c := Vector2(x0 if n <= 1 else lerpf(x0, x1, float(i) / float(n - 1)), y)
		var done := w < cur or sim.state == "clear"
		var now := w == cur and sim.state == "fighting"
		var is_boss := boss_last and w == n
		var r := 22.0 if (now or is_boss) else 18.0
		var fill := UI.GREEN if done else (UI.ACCENT if now else M3.S3)
		if is_boss and not done:
			fill = UI.RED if Data.boss_type(Game.stage) == "big" else Color("ffb142")
		var hex := PackedVector2Array()
		for k in 6:
			var a := PI / 6.0 + k * PI / 3.0
			hex.append(c + Vector2(cos(a), sin(a)) * r)
		if now:
			var glow := 0.5 + 0.5 * sin(battle.clock * 4.0)
			draw_circle(c, r + 8.0, Color(UI.ACCENT, 0.15 + 0.15 * glow))
		draw_colored_polygon(hex, fill)
		var ink := Color("06101f") if (done or now or is_boss) else UI.MUTED
		if done:
			draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(9, -7)]), ink, 4.0, true)
		elif is_boss:
			M3.text(self, c + Vector2(-20, 9), "☠", 24, Color.WHITE, true, 40, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			M3.text(self, c + Vector2(-20, 8), str(w), 22, ink, true, 40, HORIZONTAL_ALIGNMENT_CENTER)
	# bandeau des annonces
	if not has_banner or battle.banner_t <= 0.0 or battle.banner == "":
		return
	var by := size.y - ROW_BANNER + 6.0
	var a := minf(1.0, battle.banner_t * 2.0)
	var txt := battle.banner
	var col := UI.RED if battle.boss_wave else UI.GOLD
	if txt.begins_with("COMBO"):
		txt = "COMBO ×%d · +%d %%" % [sim.combo, int(round((Data.combo_mult(sim.combo) - 1.0) * 100.0))]
	var fsz := 34
	var w2 := M3.text_w(txt, fsz, true) + 80.0
	while w2 > 640.0 and fsz > 24:
		fsz -= 2
		w2 = M3.text_w(txt, fsz, true) + 80.0
	var r2 := Rect2((720.0 - w2) * 0.5, by, w2, 60)
	var k := 18.0
	var pl := PackedVector2Array([r2.position + Vector2(k, 0), Vector2(r2.end.x, r2.position.y), Vector2(r2.end.x - k, r2.end.y), Vector2(r2.position.x, r2.end.y)])
	draw_colored_polygon(pl, Color(col.darkened(0.6), 0.85 * a))
	draw_polyline(PackedVector2Array([pl[0], pl[1], pl[2], pl[3], pl[0]]), Color(col, 0.7 * a), 2.0, true)
	M3.text(self, Vector2(r2.position.x, by + 30 + M3.fs(fsz) * 0.36), txt, fsz, Color(col.lightened(0.3), a), true, w2, HORIZONTAL_ALIGNMENT_CENTER)
	if battle.banner_sub != "" and (txt.begins_with("INTERROMPU") or txt.begins_with("PARADE")):
		M3.text(self, Vector2(0, by - 8), battle.banner_sub, 22, Color(1, 1, 1, a), true, 720, HORIZONTAL_ALIGNMENT_CENTER)
