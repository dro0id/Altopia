class_name Story
extends RefCounted

const Data = preload("res://scripts/data.gd")
## Histoire (branche 2, maquettes CA à CI) : scènes courtes déclenchées autour des étages, choix de réponse du Capitaine
## (ils changent la réplique suivante, pas la suite), journal pour les revoir.
## Une scène : {id, chapter, title, sub, when ("before" ou "after"), stage, lines}. Une réplique : {who, text} ;
## une réplique avec `choice` propose deux réponses au Capitaine, et `replies` donne la réplique qui suit chacune.

## Chapitre 1 « Cap sur Altopia » (maquettes SA à SH) : le voyage à bord de l'Aurore, sans combat, en objectifs de bord.
## Ensuite un chapitre = un secteur = 10 étages (maquettes GA à GF) : chapitres 2 à 5, étages 1 à 40 ;
## à partir de l'étage 41, secteurs générés sans histoire.
const CHAPTERS := [
	{"n": 1, "title": "Cap sur Altopia", "board": true, "from": 0, "to": 0, "color": Color("7dffb0"), "head": Color("103a2a"), "reward": {"credits": 500, "shards": 5, "tokens": 3}},
	{"n": 2, "title": "Le signal", "teaser": "au cœur de la Ceinture, un trou de verre.", "from": 1, "to": 10, "color": Color("4fd8ff"), "head": Color("16305e"), "reward": {"credits": 1000, "shards": 10, "tokens": 6}},
	{"n": 3, "title": "Les Échos", "from": 11, "to": 20, "color": Color("b388ff"), "head": Color("2c1866"), "teaser": "le signal répond avec des voix humaines.", "reward": {"credits": 2000, "shards": 20, "tokens": 6}},
	{"n": 4, "title": "Le Retour", "from": 21, "to": 30, "color": Color("ffb142"), "head": Color("4a2c10"), "teaser": "le signal remonte vers la Terre.", "reward": {"credits": 3000, "shards": 30, "tokens": 6}},
	{"n": 5, "title": "Le dernier seuil", "from": 31, "to": 40, "color": Color("ffd166"), "head": Color("4a3a10"), "teaser": "le cœur de la Ceinture bat, très fort.", "reward": {"credits": 5000, "shards": 50, "tokens": 10, "badge": "Héros de la Ceinture"}},
]

## Personnages qui parlent sans être des héros jouables, avec leur dessin (« crystal », « prism », « moth », « voice », « gold »).
## Un gros boss (`fight`) occupe le haut de l'écran avant son combat ; une voix (Holt) aussi, sans combat.
const SPEAKERS := {
	"gardien": {"name": "Gardien de verre", "role": "Gardien du premier seuil", "color": Color("ff9b9b"), "art": "crystal", "short": "Gardien", "fight": "Combattre le Gardien"},
	"phare": {"name": "Sentinelle prismatique · le Phare", "role": "Porteuse des voix", "color": Color("d6bfff"), "art": "prism", "short": "Sentinelle", "fight": "Combattre la Sentinelle"},
	"reine": {"name": "Reine des mites", "role": "Gardienne des dormeurs", "color": Color("ffb142"), "art": "moth", "short": "Reine", "fight": "Combattre la Reine"},
	"holt": {"name": "Commandant Holt", "role": "Voix enregistrée · l'Aube", "color": Color("ffd166"), "art": "voice", "short": "Holt"},
	"seuil": {"name": "Gardien du dernier seuil", "role": "Le signal", "color": Color("ffd166"), "art": "gold", "short": "Gardien", "fight": "Combattre le Gardien"},
}

const PROLOGUE := [
	{"eyebrow": "PROLOGUE · TERRE, 2291", "title": "Depuis trois nuits, la Ceinture d'Altopia émet le même signal.", "text": "Une suite de chiffres, répétée sans fin. Personne ne sait la lire."},
	{"eyebrow": "PONT DE L'AURORE", "who": "vance", "text": "Capitaine, l'Amirauté nous confie l'Aurore. Personne d'autre n'a voulu y aller. Je le prends comme un compliment."},
	{"eyebrow": "PROLOGUE · DÉCOLLAGE", "title": "Six semaines jusqu'à la Ceinture d'Altopia.", "text": "L'Aurore part à moitié vide. Au bout du voyage, le signal."},
]

const SCENES := [
	# chapitre 1 · à bord (when « board ») : jouées après l'objectif de bord `after` (nombre d'objectifs remplis)
	{"id": "b1_bord", "chapter": 1, "title": "À bord", "sub": "Après le prologue · Vance, Mara", "when": "board", "after": 0, "stage": 0, "lines": [
		{"who": "vance", "text": "Bienvenue sur l’Aurore, Capitaine. Six semaines jusqu’à Altopia."},
		{"who": "mara", "text": "Elle tourne à vide. Donnez-moi des bras et je vous rends des éclats.", "choice": ["Au travail.", "On a six semaines."],
			"replies": [{"who": "mara", "text": "Voilà un Capitaine qui me plaît."}, {"who": "mara", "text": "Six semaines, c’est court pour un vaisseau vide."}]},
	]},
	{"id": "b1_recolte", "chapter": 1, "title": "Premiers éclats", "sub": "Après la récolte · T-9", "when": "board", "after": 1, "stage": 0, "lines": [
		{"who": "t9", "text": "Premiers éclats. Rendement : modeste. Moral : en hausse."},
	]},
	{"id": "b1_recrue", "chapter": 1, "title": "Une recrue", "sub": "Après le recrutement · Kaï, Mara", "when": "board", "after": 2, "stage": 0, "lines": [
		{"who": "kai", "text": "Un nouveau à bord. Il dort où ?"},
		{"who": "mara", "text": "À la Raffinerie. Il dormira plus tard."},
	]},
	{"id": "b1_pont", "chapter": 1, "title": "Trois jours de gagnés", "sub": "Après le chantier du Pont · Vance, T-9", "when": "board", "after": 4, "stage": 0, "lines": [
		{"who": "vance", "text": "Le Pont répond mieux. On gagne trois jours sur le trajet."},
		{"who": "t9", "text": "Je recalcule. Nous gagnons deux jours. Vance arrondit."},
	]},
	{"id": "b1_signal", "chapter": 1, "title": "Le signal compte", "sub": "Objectif 6 · Zyra", "when": "board", "after": 5, "stage": 0, "lines": [
		{"who": "zyra", "text": "Je l’entends, Capitaine. Le signal. Il compte… à rebours.", "choice": ["Jusqu’à quoi ?", "On arrive à temps ?"],
			"replies": [{"who": "zyra", "text": "Jusqu’à nous, je crois."}, {"who": "zyra", "text": "Si on ne traîne pas."}]},
	]},
	{"id": "b1_fin", "chapter": 1, "title": "La Ceinture d’Altopia", "sub": "Arrivée · Oru, Vance", "when": "board", "after": 6, "stage": 0, "end": 1, "lines": [
		{"who": "oru", "text": "La Ceinture… Le verre a un trou au milieu. Un trou qui respire.", "key": true},
		{"who": "vance", "text": "Le signal vient de l’intérieur. Préparez l’escouade, on descend étage par étage."},
	]},
	{"id": "c1_entree", "chapter": 2, "title": "L'entrée", "sub": "Avant l'étage 1 · Vance, Mara", "when": "before", "stage": 1, "lines": [
		{"who": "vance", "text": "Premier étage du Trou de verre, Capitaine. Le signal est juste en dessous."},
		{"who": "mara", "text": "Des drones à l'entrée. Pas vraiment un comité d'accueil.", "choice": ["On passe en force.", "Restez prudents."],
			"replies": [{"who": "vance", "text": "Bien reçu. En force, donc."}, {"who": "vance", "text": "Prudents. C'est noté, Capitaine."}]},
	]},
	{"id": "c1_soleil", "chapter": 2, "title": "Plus vieux que le Soleil", "sub": "Après l'étage 4 · T-9, Kaï", "when": "after", "stage": 4, "lines": [
		{"who": "t9", "text": "Analyse terminée : le verre des parois est plus ancien que le Soleil."},
		{"who": "kai", "text": "Donc plus de garantie constructeur."},
		{"who": "t9", "text": "Exact."},
	]},
	{"id": "c1_haut", "chapter": 2, "title": "Vers le haut", "sub": "Après le mini-boss · Zyra", "when": "after", "stage": 5, "lines": [
		{"who": "zyra", "text": "Le Foreur creusait vers le haut. Quelque chose veut sortir, Capitaine.", "choice": ["Ou quelqu'un veut entrer.", "Alors on l'en empêche."],
			"replies": [{"who": "zyra", "text": "Entrer… Oui. C'est peut-être nous qu'il attendait."}, {"who": "zyra", "text": "Alors il faudra descendre plus vite que lui ne monte."}]},
	]},
	{"id": "c1_gardien", "chapter": 2, "title": "Le Gardien parle", "sub": "Avant l'étage 10", "when": "before", "stage": 10, "lines": [
		{"who": "gardien", "text": "Vous portez le signal sur vous comme une odeur. Repartez tant que le verre vous laisse passer."},
		{"who": "vance", "text": "Il parle ? Personne ne m'avait dit qu'ils parlaient."},
		{"who": "gardien", "text": "Je garde. Je ne parle qu'une fois."},
	]},
	{"id": "c1_fin", "chapter": 2, "title": "Une réponse", "sub": "Fin du chapitre 2 · Oru, Vance, Zyra", "when": "after", "stage": 10, "end": 2, "lines": [
		{"who": "oru", "text": "Son cœur de verre bat encore… au rythme du signal."},
		{"who": "vance", "text": "Le signal a changé. Ce n'est plus un appel… c'est une réponse.", "key": true},
		{"who": "zyra", "text": "Il nous a reconnus."},
	]},
	{"id": "c2_voix", "chapter": 3, "title": "Des voix connues", "sub": "Avant l'étage 11 · Vance, Zyra", "when": "before", "stage": 11, "lines": [
		{"who": "vance", "text": "Le signal répond… avec des voix humaines. Enregistrées il y a quarante ans."},
		{"who": "zyra", "text": "Ce ne sont pas des échos. Ce sont des souvenirs."},
	]},
	{"id": "c2_epave", "chapter": 3, "title": "L'épave de l'Aube", "sub": "Après l'étage 12 · Kaï", "when": "after", "stage": 12, "lines": [
		{"who": "kai", "text": "Une épave terrienne. Classe Aurore. Comme nous.", "choice": ["On fouille l'épave.", "On la laisse en paix."],
			"replies": [{"who": "kai", "text": "Je prends la soute. Si quelque chose bouge, je hurle."}, {"who": "kai", "text": "Reçu. Je note juste son nom sur la coque : l'Aube."}]},
	]},
	{"id": "c2_holt", "chapter": 3, "title": "Commandant Holt", "sub": "Après l'étage 14 · T-9, Vance", "when": "after", "stage": 14, "lines": [
		{"who": "t9", "text": "Journal de bord récupéré. Commandant : Holt."},
		{"who": "vance", "text": "… Mon père commandait l'Aube."},
	]},
	{"id": "c2_temple", "chapter": 3, "title": "Le temple", "sub": "Après l'étage 15 · Oru", "when": "after", "stage": 15, "lines": [
		{"who": "oru", "text": "Les mites ne mangent pas le verre. Elles le gardent propre. Comme un temple."},
	]},
	{"id": "c2_phare", "chapter": 3, "title": "Le phare", "sub": "Avant l'étage 18 · Mara", "when": "before", "stage": 18, "lines": [
		{"who": "mara", "text": "Lecture énorme droit devant. On dirait un phare.", "choice": ["Éteignons-le.", "Voyons ce qu'il éclaire."],
			"replies": [{"who": "vance", "text": "Escouade, on éteint la lumière."}, {"who": "vance", "text": "Curiosité scientifique. Je note que c'était votre idée."}]},
	]},
	{"id": "c2_porteuse", "chapter": 3, "title": "Porteuse des voix", "sub": "Avant l'étage 20", "when": "before", "stage": 20, "lines": [
		{"who": "phare", "text": "J'ai porté leurs voix jusqu'à vous. Je porterai les vôtres plus loin."},
		{"who": "vance", "text": "Pas aujourd'hui."},
	]},
	{"id": "c2_fin", "chapter": 3, "title": "Ne répondez pas", "sub": "Fin du chapitre 3 · Vance, Kaï", "when": "after", "stage": 20, "end": 3, "lines": [
		{"who": "vance", "text": "Dernier message de mon père : “Si quelqu'un nous trouve, ne répondez pas.”", "key": true},
		{"who": "kai", "text": "Un peu tard."},
	]},
	{"id": "c3_sens", "chapter": 4, "title": "Sens inverse", "sub": "Avant l'étage 21 · Zyra, Vance, T-9", "when": "before", "stage": 21, "lines": [
		{"who": "zyra", "text": "Le signal a changé de sens. Il ne vient plus d'en bas… il monte."},
		{"who": "vance", "text": "Vers la Terre ?"},
		{"who": "t9", "text": "Vers la Terre. Inquiétude : élevée."},
	]},
	{"id": "c3_unique", "chapter": 4, "title": "Sens unique", "sub": "Après l'étage 22 · Mara, Kaï", "when": "after", "stage": 22, "lines": [
		{"who": "mara", "text": "Les parois se referment derrière nous."},
		{"who": "kai", "text": "Super. J'adore les sens uniques."},
	]},
	{"id": "c3_dormeurs", "chapter": 4, "title": "Les dormeurs", "sub": "Après l'étage 24 · Oru", "when": "after", "stage": 24, "lines": [
		{"who": "oru", "text": "Il y a des formes dans le verre. Des gens. Ils dorment.", "choice": ["On peut les réveiller ?", "Ne touchez à rien."],
			"replies": [{"who": "oru", "text": "Pas sans réveiller tout le reste."}, {"who": "oru", "text": "Je ne touche jamais à rien. Presque jamais."}]},
	]},
	{"id": "c3_route", "chapter": 4, "title": "Une route", "sub": "Après le mini-boss · Kaï, Zyra", "when": "after", "stage": 25, "lines": [
		{"who": "kai", "text": "Encore un Foreur. Ils creusent tous vers le haut."},
		{"who": "zyra", "text": "Ils préparent une route. Pour le retour."},
	]},
	{"id": "c3_voix", "chapter": 4, "title": "Sa voix", "sub": "Avant l'étage 28 · Vance", "when": "before", "stage": 28, "lines": [
		{"who": "vance", "text": "Cette voix sur le canal… c'est la sienne. Il dit mon nom.", "choice": ["On lui répond.", "On reste silencieux."],
			"replies": [{"who": "vance", "text": "… Je n'y arrive pas. Il a dit de ne pas répondre."}, {"who": "vance", "text": "Merci, Capitaine. Il aurait voulu ça."}]},
	]},
	{"id": "c3_reine", "chapter": 4, "title": "Gardienne des dormeurs", "sub": "Avant l'étage 30", "when": "before", "stage": 30, "lines": [
		{"who": "reine", "text": "Mes enfants gardent le verre propre pour ceux qui dorment. Vous faites du bruit."},
		{"who": "mara", "text": "On fait surtout des trous."},
	]},
	{"id": "c3_fin", "chapter": 4, "title": "Chez lui", "sub": "Fin du chapitre 4 · T-9, Zyra", "when": "after", "stage": 30, "end": 4, "lines": [
		{"who": "t9", "text": "La Reine gardait une porte. Elle est ouverte."},
		{"who": "zyra", "text": "Le signal ne veut pas rentrer chez nous, Capitaine. Il veut nous emmener chez lui.", "key": true},
	]},
	{"id": "c4_coeur", "chapter": 5, "title": "Le cœur bat", "sub": "Avant l'étage 31 · Oru, Kaï", "when": "before", "stage": 31, "lines": [
		{"who": "oru", "text": "Plus de mites. Plus de drones. Juste le cœur qui bat, très fort."},
		{"who": "kai", "text": "Je préférais les drones."},
	]},
	{"id": "c4_holt", "chapter": 5, "title": "Si vous m'entendez", "sub": "Après l'étage 33 · Holt, Vance", "when": "after", "stage": 33, "lines": [
		{"who": "holt", "text": "Si vous m'entendez, vous avez répondu. Alors écoutez : le verre apprend de ceux qu'il garde."},
		{"who": "vance", "text": "Papa…"},
	]},
	{"id": "c4_energie", "chapter": 5, "title": "Toute l'énergie", "sub": "Après le mini-boss · Mara, T-9", "when": "after", "stage": 35, "lines": [
		{"who": "mara", "text": "Le Foreur s'est arrêté net."},
		{"who": "t9", "text": "Quelqu'un plus bas a besoin de toute l'énergie."},
	]},
	{"id": "c4_rendormir", "chapter": 5, "title": "Se rendormir", "sub": "Après l'étage 37 · Holt", "when": "after", "stage": 37, "lines": [
		{"who": "holt", "text": "Le Gardien du dernier seuil porte le signal. Éteignez-le, et la Ceinture se rendort.", "choice": ["Et votre équipage ?", "Et vous ?"],
			"replies": [{"who": "holt", "text": "Ils dorment bien. Laissez-les rêver."}, {"who": "holt", "text": "Moi, j'ai déjà répondu une fois. C'était assez."}]},
	]},
	{"id": "c4_discours", "chapter": 5, "title": "Pas de discours", "sub": "Avant l'étage 38 · Zyra, Kaï", "when": "before", "stage": 38, "lines": [
		{"who": "zyra", "text": "Capitaine. Quoi qu'il arrive en bas… merci de nous avoir emmenés."},
		{"who": "kai", "text": "Pas de discours avant le boss, ça porte malheur."},
	]},
	{"id": "c4_seuil", "chapter": 5, "title": "Le premier verre", "sub": "Avant l'étage 40", "when": "before", "stage": 40, "lines": [
		{"who": "seuil", "text": "Je suis le premier verre et le dernier. Le signal, c'est moi. Répondez une dernière fois."},
		{"who": "vance", "text": "On a une réponse. Elle va vous plaire moyennement."},
	]},
	{"id": "c4_fin", "chapter": 5, "title": "Le dernier seuil", "sub": "Fin de l'histoire · Oru, Holt, Vance, Zyra, Mara", "when": "after", "stage": 40, "end": 5, "lines": [
		{"who": "oru", "text": "Le cœur s'est tu."},
		{"who": "holt", "text": "Bon travail, Commandant."},
		{"who": "vance", "text": "Merci, papa."},
		{"who": "zyra", "text": "Le verre continue plus bas. Sans signal. Sans fin."},
		{"who": "mara", "text": "Alors on continue. C'est notre métier.", "key": true},
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
	return SCENES.filter(func(s): return not seen.has(s.id) and s.when != "board" and int(s.stage) + 1 < best_stage)


## Réplique mise en avant à la fin d'un chapitre.
static func end_line(n: int) -> Dictionary:
	for s in chapter_scenes(n):
		if s.has("end"):
			for l in s.lines:
				if l.get("key", false):
					return l
			return s.lines[0]
	return {}


## Dernier chapitre de l'histoire : après lui, la Ceinture sans fin (secteurs générés).
static func last_chapter() -> int:
	return int(CHAPTERS[-1].n)


## Nom court d'un personnage (aperçu de la réplique suivante).
static func short_name(who: String) -> String:
	var sp := speaker(who)
	return String(sp.get("short", String(sp.name).split(" ")[0]))


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


## Chapitre 1 à bord : scène à jouer une fois `done` objectifs remplis (ou {}).
static func board_pending(seen: Array, done: int) -> Dictionary:
	for s in SCENES:
		if s.when == "board" and not seen.has(s.id) and int(s.after) <= done:
			return s
	return {}


## Objectifs de bord du chapitre 1 (maquette SA) : titre, détail, et où aller.
const OBJECTIVES := [
	{"title": "Récolter la Raffinerie", "sub": "Premiers éclats du voyage", "go": "raffinerie"},
	{"title": "Recruter un membre d’équipage", "sub": "Un tirage offert · nouveau héros garanti", "go": "recruit"},
	{"title": "Affecter la recrue à un poste", "sub": "Seuls les héros hors escouade travaillent", "go": "raffinerie"},
	{"title": "Pont → niveau 2", "sub": "Premier chantier · 15 s", "go": "pont"},
	{"title": "Raffinerie → niveau 2", "sub": "Deuxième chantier · 15 s", "go": "raffinerie"},
	{"title": "Écouter le signal", "sub": "Zyra l’entend depuis le Pont", "go": "signal"},
]
const VOYAGE_DAYS := 42


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
