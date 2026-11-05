class_name Story
extends RefCounted

const Data = preload("res://scripts/data.gd")
## Histoire (branche 2, maquettes CA à CI) : scènes courtes déclenchées autour des étages, choix de réponse du Capitaine
## (ils changent la réplique suivante, pas la suite), journal pour les revoir.
## Une scène : {id, chapter, title, sub, when ("before" ou "after"), stage, lines}. Une réplique : {who, text} ;
## une réplique avec `choice` propose deux réponses au Capitaine, et `replies` donne la réplique qui suit chacune.

## Un chapitre = un secteur = 10 étages (maquettes GA à GF). Les chapitres 3 et 4 (étages 21 à 40) restent à écrire ;
## à partir de l'étage 41, secteurs générés sans histoire.
const CHAPTERS := [
	{"n": 1, "title": "Le signal", "from": 1, "to": 10, "color": Color("4fd8ff"), "head": Color("16305e"), "reward": {"credits": 1000, "shards": 10, "tokens": 6}},
	{"n": 2, "title": "Les Échos", "from": 11, "to": 20, "color": Color("b388ff"), "head": Color("2c1866"), "teaser": "le signal répond avec des voix humaines.", "reward": {"credits": 2000, "shards": 20, "tokens": 6}},
	{"n": 3, "title": "Le Retour", "from": 21, "to": 30, "color": Color("a9b6d6"), "head": Color("1c2640"), "teaser": "la suite arrive bientôt.", "reward": {"credits": 3000, "shards": 30, "tokens": 6}},
]

## Personnages qui parlent sans être des héros jouables : gros boss, avec leur dessin (« crystal » ou « prism »).
const SPEAKERS := {
	"gardien": {"name": "Gardien de verre", "role": "Gardien du premier seuil", "color": Color("ff9b9b"), "art": "crystal", "fight": "Combattre le Gardien"},
	"phare": {"name": "Sentinelle prismatique · le Phare", "role": "Porteuse des voix", "color": Color("d6bfff"), "art": "prism", "fight": "Combattre la Sentinelle"},
}

const PROLOGUE := [
	{"eyebrow": "PROLOGUE · TERRE, 2291", "title": "Depuis trois nuits, la Ceinture d'Altopia émet le même signal.", "text": "Une suite de chiffres, répétée sans fin. Personne ne sait la lire."},
	{"eyebrow": "PONT DE L'AURORE", "who": "vance", "text": "Capitaine, l'Amirauté nous confie l'Aurore. Personne d'autre n'a voulu y aller. Je le prends comme un compliment."},
	{"eyebrow": "PROLOGUE · DÉCOLLAGE", "title": "Au fond de la Ceinture, un trou de verre s'est ouvert.", "text": "Le signal vient de l'intérieur. Il faut descendre, étage après étage."},
]

const SCENES := [
	{"id": "c1_entree", "chapter": 1, "title": "L'entrée", "sub": "Avant l'étage 1 · Vance, Mara", "when": "before", "stage": 1, "lines": [
		{"who": "vance", "text": "Le signal vient de l'intérieur. On descend étage par étage."},
		{"who": "mara", "text": "Des drones à l'entrée. Pas vraiment un comité d'accueil.", "choice": ["On passe en force.", "Restez prudents."],
			"replies": [{"who": "vance", "text": "Bien reçu. En force, donc."}, {"who": "vance", "text": "Prudents. C'est noté, Capitaine."}]},
	]},
	{"id": "c1_soleil", "chapter": 1, "title": "Plus vieux que le Soleil", "sub": "Après l'étage 4 · T-9, Kaï", "when": "after", "stage": 4, "lines": [
		{"who": "t9", "text": "Analyse terminée : le verre des parois est plus ancien que le Soleil."},
		{"who": "kai", "text": "Donc plus de garantie constructeur."},
		{"who": "t9", "text": "Exact."},
	]},
	{"id": "c1_haut", "chapter": 1, "title": "Vers le haut", "sub": "Après le mini-boss · Zyra", "when": "after", "stage": 5, "lines": [
		{"who": "zyra", "text": "Le Foreur creusait vers le haut. Quelque chose veut sortir, Capitaine.", "choice": ["Ou quelqu'un veut entrer.", "Alors on l'en empêche."],
			"replies": [{"who": "zyra", "text": "Entrer… Oui. C'est peut-être nous qu'il attendait."}, {"who": "zyra", "text": "Alors il faudra descendre plus vite que lui ne monte."}]},
	]},
	{"id": "c1_gardien", "chapter": 1, "title": "Le Gardien parle", "sub": "Avant l'étage 10", "when": "before", "stage": 10, "lines": [
		{"who": "gardien", "text": "Vous portez le signal sur vous comme une odeur. Repartez tant que le verre vous laisse passer."},
		{"who": "vance", "text": "Il parle ? Personne ne m'avait dit qu'ils parlaient."},
		{"who": "gardien", "text": "Je garde. Je ne parle qu'une fois."},
	]},
	{"id": "c1_fin", "chapter": 1, "title": "Une réponse", "sub": "Fin du chapitre 1 · Oru, Vance, Zyra", "when": "after", "stage": 10, "end": 1, "lines": [
		{"who": "oru", "text": "Son cœur de verre bat encore… au rythme du signal."},
		{"who": "vance", "text": "Le signal a changé. Ce n'est plus un appel… c'est une réponse.", "key": true},
		{"who": "zyra", "text": "Il nous a reconnus."},
	]},
	{"id": "c2_voix", "chapter": 2, "title": "Des voix connues", "sub": "Avant l'étage 11 · Vance, Zyra", "when": "before", "stage": 11, "lines": [
		{"who": "vance", "text": "Le signal répond… avec des voix humaines. Enregistrées il y a quarante ans."},
		{"who": "zyra", "text": "Ce ne sont pas des échos. Ce sont des souvenirs."},
	]},
	{"id": "c2_epave", "chapter": 2, "title": "L'épave de l'Aube", "sub": "Après l'étage 12 · Kaï", "when": "after", "stage": 12, "lines": [
		{"who": "kai", "text": "Une épave terrienne. Classe Aurore. Comme nous.", "choice": ["On fouille l'épave.", "On la laisse en paix."],
			"replies": [{"who": "kai", "text": "Je prends la soute. Si quelque chose bouge, je hurle."}, {"who": "kai", "text": "Reçu. Je note juste son nom sur la coque : l'Aube."}]},
	]},
	{"id": "c2_holt", "chapter": 2, "title": "Commandant Holt", "sub": "Après l'étage 14 · T-9, Vance", "when": "after", "stage": 14, "lines": [
		{"who": "t9", "text": "Journal de bord récupéré. Commandant : Holt."},
		{"who": "vance", "text": "… Mon père commandait l'Aube."},
	]},
	{"id": "c2_temple", "chapter": 2, "title": "Le temple", "sub": "Après l'étage 15 · Oru", "when": "after", "stage": 15, "lines": [
		{"who": "oru", "text": "Les mites ne mangent pas le verre. Elles le gardent propre. Comme un temple."},
	]},
	{"id": "c2_phare", "chapter": 2, "title": "Le phare", "sub": "Avant l'étage 18 · Mara", "when": "before", "stage": 18, "lines": [
		{"who": "mara", "text": "Lecture énorme droit devant. On dirait un phare.", "choice": ["Éteignons-le.", "Voyons ce qu'il éclaire."],
			"replies": [{"who": "vance", "text": "Escouade, on éteint la lumière."}, {"who": "vance", "text": "Curiosité scientifique. Je note que c'était votre idée."}]},
	]},
	{"id": "c2_porteuse", "chapter": 2, "title": "Porteuse des voix", "sub": "Avant l'étage 20", "when": "before", "stage": 20, "lines": [
		{"who": "phare", "text": "J'ai porté leurs voix jusqu'à vous. Je porterai les vôtres plus loin."},
		{"who": "vance", "text": "Pas aujourd'hui."},
	]},
	{"id": "c2_fin", "chapter": 2, "title": "Ne répondez pas", "sub": "Fin du chapitre 2 · Vance, Kaï", "when": "after", "stage": 20, "end": 2, "lines": [
		{"who": "vance", "text": "Dernier message de mon père : “Si quelqu'un nous trouve, ne répondez pas.”", "key": true},
		{"who": "kai", "text": "Un peu tard."},
	]},
]


static func scene(id: String) -> Dictionary:
	for s in SCENES:
		if s.id == id:
			return s
	return {}


static func chapter_scenes(n: int) -> Array:
	return SCENES.filter(func(s): return int(s.chapter) == n)


## Scènes d'étages déjà dépassés (au-delà de l'étage tout juste vaincu) : on ne les rejoue pas d'un coup,
## elles sont débloquées dans le journal (parties commencées avant un nouveau chapitre).
static func behind(seen: Array, best_stage: int) -> Array:
	return SCENES.filter(func(s): return not seen.has(s.id) and int(s.stage) + 1 < best_stage)


## Réplique mise en avant à la fin d'un chapitre.
static func end_line(n: int) -> Dictionary:
	for s in chapter_scenes(n):
		if s.has("end"):
			for l in s.lines:
				if l.get("key", false):
					return l
			return s.lines[0]
	return {}


## Chapitres qui ont des scènes (le journal n'affiche que ceux-là).
static func written() -> Array:
	return CHAPTERS.filter(func(c): return not chapter_scenes(int(c.n)).is_empty())


static func chapter(n: int) -> Dictionary:
	for c in CHAPTERS:
		if int(c.n) == n:
			return c
	return {}


## Scène à jouer maintenant (ou {}) : « après » un étage vaincu pour la première fois, puis « avant » l'étage où l'on arrive.
static func pending(seen: Array, stage: int, best_stage: int) -> Dictionary:
	for s in SCENES:
		if seen.has(s.id):
			continue
		if s.when == "after" and best_stage > int(s.stage):
			return s
	for s in SCENES:
		if seen.has(s.id):
			continue
		if s.when == "before" and stage == int(s.stage) and stage >= best_stage:
			return s
	return {}


## Nom, rôle et couleur d'un personnage qui parle.
static func speaker(who: String) -> Dictionary:
	if SPEAKERS.has(who):
		return SPEAKERS[who]
	var h: Dictionary = Data.HEROES.get(who, {})
	if h.is_empty():
		return {"name": who, "role": "", "color": UI.ACCENT}
	var role := String(h.get("job", ""))
	if role == "":
		role = "%s · %s" % [Data.SPECIES_NAMES[h.species], Data.ROLE_NAMES[h.role]]
	return {"name": String(h.name), "role": role, "color": Data.RARITY_COLORS[h.rarity]}
