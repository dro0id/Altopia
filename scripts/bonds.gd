class_name Bonds
extends RefCounted
## Liens d'équipage (maquette WH) : sept groupes de héros. Un lien monte quand ses héros combattent
## ou travaillent ensemble ; à chaque niveau, ses pouvoirs se renforcent et une conversation s'ouvre.

const LEVELS := [10, 40, 100]          # points pour atteindre les niveaux 1, 2, 3
const PER_LEVEL_2 := 0.04             # bonus de pouvoir par niveau quand deux membres combattent ensemble
const PER_LEVEL_3 := 0.06             # … quand trois membres combattent ensemble

const LIST := [
	{"id": "anciens", "name": "Les anciens", "members": ["vance", "mara"], "convos": [
		{"title": "Avant l’Aurore", "lines": [["vance", "Tu te souviens de la Lyre, Mara ? Le vieux cargo."], ["mara", "Je me souviens surtout de son moteur. Je l’ai réparé onze fois."], ["vance", "Douze. La douzième, c’était moi, avec du ruban adhésif."]]},
		{"title": "Le second et l’ingénieure", "lines": [["mara", "Pourquoi tu n’as jamais voulu commander, Vance ?"], ["vance", "Parce qu’un bon second dort mieux qu’un capitaine."], ["mara", "Tu ne dors jamais."]]},
		{"title": "La promesse", "lines": [["vance", "Si on arrive à Altopia, je t’offre un vrai café."], ["mara", "Il n’y a pas de café sur Altopia."], ["vance", "Alors j’en ferai pousser. La Serre me doit bien ça."]]},
	]},
	{"id": "chasseurs", "name": "Chasseurs", "members": ["kai", "dax"], "convos": [
		{"title": "Le score", "lines": [["kai", "Quarante-deux mites. Record battu."], ["dax", "Quarante-trois. J’ai compté celle que tu as ratée."], ["kai", "Celle-là ne compte pas, elle était déjà à moitié morte."]]},
		{"title": "Les cartes", "lines": [["dax", "Comment tu fais pour gagner à chaque partie ?"], ["kai", "Je regarde ton reflet dans la verrière."], ["dax", "… On joue dans la soute, demain."]]},
		{"title": "Ailier", "lines": [["kai", "Dans le Trou de verre, tu restes à ma gauche."], ["dax", "Et toi à ma droite. Comme ça personne ne passe."], ["kai", "Personne ne passe. Marché conclu."]]},
	]},
	{"id": "ecoutent", "name": "Ceux qui écoutent", "members": ["zyra", "oru", "lumi"], "convos": [
		{"title": "Ce que dit le verre", "lines": [["oru", "Le verre chante plus fort près du Trou."], ["zyra", "Il ne chante pas. Il appelle."], ["lumi", "Il appelle quelqu’un en particulier. Et ce n’est pas nous."]]},
		{"title": "Trois oreilles", "lines": [["lumi", "Les humains n’entendent rien, vraiment ?"], ["oru", "Mara dit qu’elle entend un bourdonnement."], ["zyra", "C’est le Labo. Oru a encore oublié une expérience."]]},
		{"title": "La réponse", "lines": [["zyra", "Si on répondait au signal ?"], ["oru", "On ne sait pas ce qu’on dirait."], ["lumi", "Alors on dira la vérité : qu’on arrive."]]},
	]},
	{"id": "mecanique", "name": "La mécanique", "members": ["pim", "brix", "omega"], "convos": [
		{"title": "Pièces détachées", "lines": [["pim", "Brix, il manque un boulon à ton bras gauche."], ["brix", "Il est dans ta poche, Pim. Depuis mardi."], ["omega", "Inventaire mis à jour : Pim est un voleur."]]},
		{"title": "Protocole", "lines": [["omega", "Unité Oméga-7 : objectif, protéger l’équipage."], ["brix", "Le mien, c’est faire du bruit."], ["pim", "Le mien, c’est vous réparer après."]]},
		{"title": "Ce qu’on ressent", "lines": [["pim", "Vous croyez que les robots peuvent avoir peur ?"], ["omega", "Négatif. … Probabilité faible."], ["brix", "Moi, j’ai peur quand Pim tient un tournevis."]]},
	]},
	{"id": "medical", "name": "Corps médical", "members": ["aria", "neelo", "t9"], "convos": [
		{"title": "La liste", "lines": [["aria", "Kaï : trois bleus, une côte fêlée. Encore."], ["neelo", "Il dit qu’il s’est cogné dans le simulateur."], ["t9", "Le simulateur est éteint depuis quatre jours."]]},
		{"title": "Spores", "lines": [["neelo", "Mes spores calment tout le monde. Même Brix."], ["t9", "Brix n’a pas de poumons."], ["neelo", "Alors c’est encore plus impressionnant."]]},
		{"title": "La cheffe", "lines": [["t9", "Docteure Quill, vous ne vous reposez jamais."], ["aria", "Je me reposerai quand personne ne saignera."], ["neelo", "Alors on va vous attacher au lit. Pour la science."]]},
	]},
	{"id": "feu", "name": "Feu croisé", "members": ["sora", "brix"], "convos": [
		{"title": "Précision", "lines": [["sora", "Un tir, une cible. C’est tout."], ["brix", "Moi c’est cent tirs, cent cibles. Ou une, plusieurs fois."], ["sora", "… Restons chacun de notre côté."]]},
		{"title": "Couverture", "lines": [["brix", "Je fais diversion, tu tires dans le trou."], ["sora", "Quel trou ?"], ["brix", "Celui que je vais faire."]]},
		{"title": "Le silence", "lines": [["sora", "Pourquoi tu te tais avant un combat ?"], ["brix", "Je compte mes munitions."], ["sora", "Tu n’en manques jamais. Tu as peur, toi aussi."]]},
	]},
	{"id": "mur", "name": "Mur de verre", "members": ["gorn", "pim"], "convos": [
		{"title": "Le plus solide", "lines": [["gorn", "Ma carapace arrête tout."], ["pim", "Mon blindage aussi. Et il se répare."], ["gorn", "La mienne repousse. C’est mieux."]]},
		{"title": "Devant", "lines": [["pim", "Tu passes toujours devant moi."], ["gorn", "Tu es petit. Je te protège."], ["pim", "Je suis petit, mais je tiens la porte."]]},
		{"title": "Gardien", "lines": [["gorn", "Chez moi, on garde le verre depuis mille ans."], ["pim", "Et vous gardez quoi, exactement ?"], ["gorn", "Ce qui est derrière. On ne l’a jamais ouvert."]]},
	]},
]


static func get_bond(id: String) -> Dictionary:
	for b in LIST:
		if String(b.id) == id:
			return b
	return {}


static func level_of(xp: int) -> int:
	var lv := 0
	for t in LEVELS:
		if xp >= t:
			lv += 1
	return lv


## Liens dont au moins deux membres sont dans `ids`, avec le nombre de membres présents.
static func active(ids: Array) -> Array:
	var out := []
	for b in LIST:
		var n := 0
		for m in b.members:
			if ids.has(m):
				n += 1
		if n >= 2:
			out.append({"bond": b, "count": n})
	return out


## Bonus de pouvoir d'un héros selon les liens actifs de l'escouade et leur niveau.
static func skill_bonus(id: String, ids: Array, xp: Dictionary) -> float:
	var bonus := 0.0
	for a in active(ids):
		if (a.bond.members as Array).has(id):
			var lv := level_of(int(xp.get(a.bond.id, 0)))
			bonus += lv * (PER_LEVEL_3 if int(a.count) >= 3 else PER_LEVEL_2)
	return bonus


static func bonus_text(lv: int, size: int) -> String:
	if size >= 3:
		return "Pouvoirs +%d %% quand deux d’entre eux combattent ensemble, +%d %% à trois." % [int(round(lv * PER_LEVEL_2 * 100.0)), int(round(lv * PER_LEVEL_3 * 100.0))]
	return "Pouvoirs +%d %% quand ils combattent ensemble." % int(round(lv * PER_LEVEL_2 * 100.0))
