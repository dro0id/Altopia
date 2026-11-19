class_name Cosmetics
extends RefCounted

const Data = preload("res://scripts/data.gd")
## Peintures de l'Aurore et tenues des héros (maquette YG) : gagnées par des succès, aucun bonus de combat.

## Peintures : couleur des plaques claires, des bandes sombres et des cinq repères de modules.
const PAINTS := {
	"amiraute": {"name": "Amirauté", "light": Color("dfe6f5"), "navy": Color("1e2a55"), "marks": [Color("ffd166"), Color("4fd8ff"), Color("ff9f6b"), Color("b388ff"), Color("9dff6b")], "bg": Color("0b1226")},
	"braise": {"name": "Braise", "light": Color("f6bf9f"), "navy": Color("6a1e0c"), "marks": [Color("ffd166"), Color("ff9f6b"), Color("ff6b4a"), Color("ffb142"), Color("ffe08a")], "bg": Color("2a0e06")},
	"echo": {"name": "Écho", "light": Color("dcbcff"), "navy": Color("3e1258"), "marks": [Color("ff7ad9"), Color("b388ff"), Color("e6d6ff"), Color("ff7ad9"), Color("7fdcff")], "bg": Color("200a2a")},
	"serre": {"name": "Serre", "light": Color("bdf0c4"), "navy": Color("143e22"), "marks": [Color("9dff6b"), Color("7dffb0"), Color("d8ff6b"), Color("4fd8a0"), Color("9dff6b")], "bg": Color("082012")},
}
## Tenues : couleur de la combinaison et de ses liserés.
const OUTFITS := {
	"origine": {"name": "D’origine"},
	"escorte": {"name": "Tenue d’escorte", "suit": Color("d9452f"), "accent": Color("ffe0d0")},
	"quart": {"name": "Tenue de quart", "suit": Color("2f9e57"), "accent": Color("e6ffe9")},
	"seuil": {"name": "Tenue du Seuil", "suit": Color("9b4fd6"), "accent": Color("f0dcff")},
}
## Succès : ce qu'il faut accomplir, et ce que ça ouvre.
const LIST := [
	{"id": "chap4", "name": "Le chapitre des braises", "desc": "Terminer le chapitre 4", "goal": 1, "reward": {"paint": "braise"}},
	{"id": "boss10", "name": "Chasseur de géants", "desc": "Vaincre 10 gros boss", "goal": 10, "reward": {"paint": "echo"}},
	{"id": "ship15", "name": "Jardin volant", "desc": "Monter l’Aurore au niveau 15", "goal": 15, "reward": {"paint": "serre"}},
	{"id": "harvest100", "name": "Main verte", "desc": "Récolter 100 fois", "goal": 100, "reward": {"outfit": "escorte"}},
	{"id": "convos10", "name": "On se connaît", "desc": "Lire 10 conversations d’équipage", "goal": 10, "reward": {"outfit": "quart"}},
	{"id": "story", "name": "Au-delà du Seuil", "desc": "Terminer l’histoire (chapitre 5)", "goal": 1, "reward": {"outfit": "seuil"}},
]


static func progress(id: String, g: Node) -> int:
	match id:
		"chap4":
			return 1 if (g.chapters_done as Array).has(4) else 0
		"story":
			return 1 if (g.chapters_done as Array).has(5) else 0
		"boss10":
			var n := 0
			for k in g.stars:
				if Data.boss_type(int(k)) == "big":
					n += 1
			return n
		"ship15":
			return int(g.ship.level)
		"harvest100":
			return int(g.ship.harvests)
		"convos10":
			return (g.bond_read as Array).size()
	return 0


static func is_done(a: Dictionary, g: Node) -> bool:
	return progress(String(a.id), g) >= int(a.goal)


static func paint_open(id: String, g: Node) -> bool:
	if id == "amiraute":
		return true
	for a in LIST:
		if String(a.reward.get("paint", "")) == id:
			return is_done(a, g)
	return false


static func outfit_open(id: String, g: Node) -> bool:
	if id == "origine":
		return true
	for a in LIST:
		if String(a.reward.get("outfit", "")) == id:
			return is_done(a, g)
	return false


static func reward_text(a: Dictionary) -> String:
	if a.reward.has("paint"):
		return "Peinture « %s »" % PAINTS[a.reward.paint].name
	return String(OUTFITS[a.reward.outfit].name)


static var _ids_by_name := {}


## Héros avec sa tenue choisie : même dictionnaire, couleurs de combinaison remplacées.
static func dressed(h: Dictionary) -> Dictionary:
	if _ids_by_name.is_empty():
		for id in Data.HEROES:
			_ids_by_name[String(Data.HEROES[id].name)] = id
	var ml := Engine.get_main_loop()
	var g: Node = (ml as SceneTree).root.get_node_or_null("Game") if ml is SceneTree else null
	if g == null:
		return h
	var id := String(_ids_by_name.get(String(h.get("name", "")), ""))
	var o := String((g.outfits as Dictionary).get(id, "origine"))
	if o == "origine" or not OUTFITS.has(o):
		return h
	var out := h.duplicate()
	var look: Dictionary = (h.look as Dictionary).duplicate()
	look.suit = OUTFITS[o].suit
	look.accent = OUTFITS[o].accent
	out.look = look
	return out
