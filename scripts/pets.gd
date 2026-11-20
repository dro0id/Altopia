class_name Pets
extends RefCounted
## Familiers de verre (maquette WI) : des mites apprivoisées. Des œufs en expédition et sur les gros boss,
## qui éclosent dans la Serre ; un familier suit l'escouade (seul celui-là agit), on le nourrit d'éclats.

const KINDS := {
	"luciole": {"name": "Luciole", "desc": "+5 % de crédits", "col": Color("ffd166"), "base": Color("c9a83a")},
	"rongeuse": {"name": "Rongeuse", "desc": "+1 éclat par vague", "col": Color("4fd8ff"), "base": Color("3a7ec8")},
	"veilleuse": {"name": "Veilleuse", "desc": "+8 % de soins", "col": Color("7dffb0"), "base": Color("3a9a6a")},
	"piquante": {"name": "Piquante", "desc": "attaque avec l’escouade", "col": Color("ff8a6b"), "base": Color("b8442e")},
	"fileuse": {"name": "Fileuse", "desc": "+5 % de production à bord", "col": Color("b388ff"), "base": Color("7a52c8")},
	"gardienne": {"name": "Gardienne", "desc": "bouclier de 5 % au départ", "col": Color("ffb142"), "base": Color("c47a2e")},
}
const ORDER := ["luciole", "rongeuse", "veilleuse", "piquante", "fileuse", "gardienne"]
const MAX_LV := 10
const HATCH_HOURS := 2.0
const EGG_EXPEDITION := 0.35            # chance d'un œuf au retour d'une expédition
const EGG_BIG_BOSS := 0.5               # chance d'un œuf sur un gros boss


## Force d'un familier : ×1 au niveau 1, +10 % par niveau.
static func power(lv: int) -> float:
	return 1.0 + 0.1 * float(clampi(lv, 1, MAX_LV) - 1)


static func feed_cost(lv: int) -> int:
	return 10 * lv


static func palette(kind: String) -> Dictionary:
	var k: Dictionary = KINDS.get(kind, KINDS.luciole)
	var acc: Color = k.col
	return {"base": k.base, "acc": acc, "core": acc.lerp(Color.WHITE, 0.7), "eye": Color("ffffff")}


## Texte de l'effet au niveau donné.
static func effect_text(kind: String, lv: int) -> String:
	var p := power(lv)
	match kind:
		"luciole":
			return "+%d %% de crédits" % int(round(5.0 * p))
		"rongeuse":
			return "+%d éclat%s par vague" % [int(round(p)), "s" if round(p) > 1 else ""]
		"veilleuse":
			return "+%d %% de soins" % int(round(8.0 * p))
		"piquante":
			return "attaque avec l’escouade (×%s)" % ("%.1f" % p).replace(".", ",")
		"fileuse":
			return "+%d %% de production à bord" % int(round(5.0 * p))
		"gardienne":
			return "bouclier de %d %% au départ" % int(round(5.0 * p))
	return ""
