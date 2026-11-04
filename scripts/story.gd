class_name Story
extends RefCounted

const Data = preload("res://scripts/data.gd")
## Histoire (branche 2, maquettes CA à CI) : scènes courtes déclenchées autour des étages, choix de réponse du Capitaine
## (ils changent la réplique suivante, pas la suite), journal pour les revoir.
## Une scène : {id, chapter, title, sub, when ("before" ou "after"), stage, lines}. Une réplique : {who, text} ;
## une réplique avec `choice` propose deux réponses au Capitaine, et `replies` donne la réplique qui suit chacune.

const CHAPTERS := [
	{"n": 1, "title": "Le signal", "from": 1, "to": 20, "reward": {"credits": 2000, "shards": 20, "tokens": 6}},
	{"n": 2, "title": "Les Échos", "from": 21, "to": 40, "teaser": "la Reine des mites attend au fond.", "reward": {"credits": 6000, "shards": 40, "tokens": 9}},
]

## Personnages qui parlent sans être des héros jouables.
const SPEAKERS := {
	"gardien": {"name": "Gardien de verre", "role": "Gardien du premier seuil", "color": Color("ff9b9b")},
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
	{"id": "c1_coeur", "chapter": 1, "title": "Un cœur qui bat", "sub": "Après l'étage 10 · Oru", "when": "after", "stage": 10, "lines": [
		{"who": "oru", "text": "Son cœur de verre bat encore… au rythme du signal."},
		{"who": "vance", "text": "On note. On avance."},
	]},
	{"id": "c1_phare", "chapter": 1, "title": "Le phare", "sub": "Avant l'étage 20 · Mara", "when": "before", "stage": 20, "lines": [
		{"who": "mara", "text": "Lecture énorme droit devant. On dirait un phare.", "choice": ["Éteignons-le.", "Voyons ce qu'il éclaire."],
			"replies": [{"who": "vance", "text": "Escouade, on éteint la lumière."}, {"who": "vance", "text": "Curiosité scientifique. Je note que c'était votre idée."}]},
	]},
	{"id": "c1_fin", "chapter": 1, "title": "Une réponse", "sub": "Fin du chapitre 1 · Vance, Zyra", "when": "after", "stage": 20, "end": 1, "lines": [
		{"who": "vance", "text": "Le signal a changé, Capitaine. Ce n'est plus un appel… c'est une réponse."},
		{"who": "zyra", "text": "Il nous a reconnus."},
	]},
]


static func scene(id: String) -> Dictionary:
	for s in SCENES:
		if s.id == id:
			return s
	return {}


static func chapter_scenes(n: int) -> Array:
	return SCENES.filter(func(s): return int(s.chapter) == n)


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
