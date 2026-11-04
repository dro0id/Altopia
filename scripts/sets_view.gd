class_name SetsView
extends Control
## Onglet Ensembles (maquette BV) : une carte par ensemble, pièces portées sur un même héros, bonus à 2 et 4 pièces.

func _init() -> void:
	size = Vector2(720, 1120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var h := M3.para(self, Vector2(32, 236), "Les objets rares et mieux ont un ensemble. Plusieurs pièces sur un même héros donnent des bonus.", 26, UI.MUTED, 656)
	var active := {}
	for hid in Game.squad_ids():
		var counts := Items.set_counts(Game.hero_items(hid))
		for s in counts:
			active[s] = maxi(int(active.get(s, 0)), int(counts[s]))
	var y := 236.0 + h
	for sid in Items.SETS:
		var info: Dictionary = Items.SETS[sid]
		var col: Color = info.color
		var n: int = int(active.get(sid, 0))
		var r := Rect2(32, y, 656, 172)
		M3.card(self, r, M3.S2, 32, Color(col, 0.4), 2)
		M3.text(self, Vector2(64, y + 56), "◈", 36, col)
		M3.text(self, Vector2(108, y + 56), String(info.name), 32, UI.TEXT, true)
		M3.text(self, Vector2(32, y + 54), "%d/4" % n, 24, UI.MUTED, false, 624, HORIZONTAL_ALIGNMENT_RIGHT)
		M3.text(self, Vector2(64, y + 104), "(2)", 26, col if n >= 2 else UI.TEXT, true)
		M3.text(self, Vector2(118, y + 104), String(info.b2), 26, UI.MUTED, false, 540)
		M3.text(self, Vector2(64, y + 144), "(4)", 26, col if n >= 4 else UI.TEXT, true)
		M3.text(self, Vector2(118, y + 144), String(info.b4), 26, UI.MUTED, false, 540)
		y += 188.0
