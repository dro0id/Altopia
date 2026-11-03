class_name SetsView
extends Control
## Onglet Ensembles de la collection (maquette W) : trois ensembles, quatre pièces chacun, bonus à 2 et 4 pièces.

func _init() -> void:
	size = Vector2(720, 1152)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	var fb := UI.bold_font()
	draw_string(f, Vector2(32, 214), "Les objets rares et mieux ont un ensemble. Plusieurs", HORIZONTAL_ALIGNMENT_LEFT, 656, 24, UI.MUTED)
	draw_string(f, Vector2(32, 244), "pièces sur un même héros donnent des bonus.", HORIZONTAL_ALIGNMENT_LEFT, 656, 24, UI.MUTED)
	var active := {}                       # ensemble -> plus grand nombre de pièces portées par un même héros
	for hid in Game.squad_ids():
		var counts := Items.set_counts(Game.hero_items(hid))
		for s in counts:
			active[s] = maxi(int(active.get(s, 0)), int(counts[s]))
	var i := 0
	for sid in Items.SETS:
		var info: Dictionary = Items.SETS[sid]
		var col: Color = info.color
		var y := 260.0 + i * 292.0
		i += 1
		draw_style_box(UI.box(UI.PANEL, Color(col.r, col.g, col.b, 0.4), 28, 0), Rect2(32, y, 656, 278))
		# pièces possédées par emplacement : la meilleure rareté de cet ensemble
		var best := {}
		for it in Game.items:
			if it.set == sid and (not best.has(it.slot) or Items.rarity_index(it.rarity) > Items.rarity_index(best[it.slot].rarity)):
				best[it.slot] = it
		draw_string(f, Vector2(52, y + 48), "◈", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		draw_string(fb, Vector2(95, y + 48), "Ensemble %s" % info.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, col)
		draw_string(f, Vector2(0, y + 46), "%d/4" % best.size(), HORIZONTAL_ALIGNMENT_RIGHT, 660, 24, UI.MUTED)
		for k in Items.SLOTS.size():
			var slot: String = Items.SLOTS[k]
			var r := Rect2(58.0 + k * 154.0, y + 68, 88, 88)
			if best.has(slot):
				ItemUI.tile(self, r, best[slot], false)
			else:
				ItemUI.empty(self, r)
			draw_string(f, Vector2(r.position.x - 17.0, y + 174), Items.SLOT_NAMES[slot], HORIZONTAL_ALIGNMENT_CENTER, 142.0, 18, UI.MUTED if best.has(slot) else Color(UI.MUTED, 0.5))
		var n: int = int(active.get(sid, 0))
		draw_string(fb, Vector2(54, y + 214), "(2)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col if n >= 2 else UI.MUTED)
		draw_string(f, Vector2(104, y + 214), info.b2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e8eefc"))
		draw_string(fb, Vector2(54, y + 248), "(4)", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col if n >= 4 else UI.MUTED)
		draw_string(f, Vector2(104, y + 248), info.b4, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e8eefc"))
