# Expéditions : refonte (cahier des charges)

Les expéditions ne sont **pas** de l'AFK : elles se jouent en direct, avec le Capitaine et son équipage, et servent de bonus de ressources. Maquettes : canvas « Altopia — Refonte des Expéditions » (propositions A, B, C et D, puis la série E : lancement, briefing, combat, gardien, résultat et charte graphique du combat).

## Décisions validées

- Trois modes d'exploration : **Combat en direct** (B), **Dérive** (grille de scan, C) et **Route** (carte d'étapes, A).
- **Le joueur choisit le mode** au lancement (Combat, Dérive ou Route), ou choisit **« Aléatoire »** : le jeu tire un mode pondéré selon la destination (voir plus bas, jamais le même mode trois fois de suite).
- **Bonus de gains** (multiplicateurs sur les gains de l'expédition, jamais cumulés entre eux) :

| Cas | Gains |
|---|---|
| Mode choisi | x1 |
| Mode Aléatoire | x1,5 |
| Mode choisi, sur le secteur du jour | x1,3 |
| Mode Aléatoire, sur le secteur du jour | x1,6 |

- Le **« secteur du jour »** est une destination mise en avant pendant quelques heures (rotation). Le bonus s'applique quel que soit le mode joué sur cette destination.
- **L'AFK n'est pas modifié par cette refonte.** Le Capitaine ne reçoit aucune XP de l'AFK : son XP vient uniquement des anomalies et des expéditions jouées en direct. L'AFK sert seulement à produire des ressources hors ligne (et du matériel pour l'équipage), ce qui est déjà un bonus pour un joueur casual qui compense son manque de jeu. Les gains d'expédition se règlent donc pour le jeu en direct, sans référence à l'AFK.
- Une **refonte des combats** est nécessaire : le combat actuel (`Battle.simulate`, rejoué en animation) devient un vrai combat en direct avec des couloirs, des tirs annoncés et des compétences d'équipage.
- Les chances de victoire (« sûr » à partir de 80 %, « risqué », « très risqué ») et la règle « une défaite garde 25 % du butin » s'appliquent aux trois modes.
- Hors ligne, les expéditions restent en pause.

## Équipage commun aux trois modes

| Rôle | Dérive | Combat | Route |
|---|---|---|---|
| Pilote | Propulseurs (saute 2 cases) | Esquive | Évite un piège |
| Ingénieur | Extracteur (récolte la case) | Bouclier | Force les soutes |
| Scientifique | Sonde 3×3 | Analyse (faiblesse, critique) | Scanne |
| Capitaine | Décide et se déplace | Tir chargé | Choisit la route |

Les niveaux de l'équipage au poste améliorent les chances et l'efficacité dans les trois modes ; un équipier blessé les réduit.

## Combat en direct (refonte)

- Arène à 3 couloirs, vagues d'ennemis (3 à 7 selon la destination).
- Les ennemis annoncent leurs tirs (télégraphe de ~1,2 s dans un couloir) ; le joueur change de couloir en glissant.
- Compétences d'équipage avec temps de recharge ; jauge de Tir chargé qui se remplit en touchant.
- Il doit rester jouable à une main, sans exigence de réflexes extrêmes : la fenêtre de réaction s'allonge avec le niveau du Pilote.
- Le calcul de chances de victoire (Monte-Carlo) continue d'exister sur le même modèle de stats, pour afficher « sûr / risqué » avant de décoller.

## Dérive (grille de scan)

- Grille 6×7 brouillée, énergie de scan limitée et durée limitée (~2 min).
- Chaque case scannée montre le nombre de dangers voisins ; on déduit, on extrait minerai, données ou énergie.
- Un impact retire de la coque ; la fin de la dérive ramène le butin (rentrer plus tôt le garde en entier).

## Route (carte d'étapes)

- 9 étapes environ : combats (mode Combat), événements à choix risqués, grilles de dérive pour les épaves, point de repos, gardien final.
- La coque et la soute se gardent d'une étape à l'autre ; seul le repos soigne.

## Tirage du mode « Aléatoire » (par défaut, à régler)

| Destination | Dérive | Combat | Route |
|---|---|---|---|
| Champ d'astéroïdes | 50 % | 40 % | 10 % |
| Étoile naine | 30 % | 50 % | 20 % |
| Planète inconnue | 15 % | 35 % | 50 % |

## Combat en direct : règles implémentées (`scripts/live_sim.gd`, `live_view.gd`, `live_ui.gd`)

- **Arène :** 3 couloirs, 5 vagues (drones, drones, essaim, canonnière + drones, gardien « Foreuse des anneaux » ; la destination peut ne pas avoir de gardien : la vague finale est alors faite de canonnières et d'essaims). Le vaisseau tire seul dans son couloir ; on change de couloir en touchant ou en glissant.
- **Danger annoncé :** la canonnière et le gardien annoncent leur tir (durée variable, de 0,5 à 0,8 s ; balayage du gardien environ 1,1 s avec un couloir sûr), avec un motif hachuré (le danger ne repose pas que sur la couleur). Les projectiles ennemis ont quatre vitesses : lent (orbe), rapide (trait fin), accélérant et normal.
- **Compétences de l'équipage :** Esquive (Rex, 1,5 s, recharge 8 s), Bouclier (Gorn, absorbe un tir, recharge 12 s), Analyse (Lumi, x2 dégâts 8 s, recharge 15 s) et Tir chargé (jauge qui se remplit en touchant, dégâts sur le couloir). Face au gardien, les couloirs de côté touchent ses points faibles (x2) et Analyse rend le centre efficace.
- **Équipage assisté (bouton Auto) :** un pilote automatique lit les tirs annoncés et les projectiles, choisit le couloir le plus sûr puis le plus rentable, et utilise bouclier, esquive, analyse et tir chargé. Il a 0,3 s de temps de réaction et rate parfois une esquive. Il tire à 75 % de la puissance : jouer soi-même reste plus fort. Le combo compte dans tous les modes.
- **Objectifs :** deux objectifs tirés au hasard par partie parmi huit (combo, moins de 2 impacts, terminer en moins de 28 s, esquiver ou bloquer 3 tirs, 2 tirs chargés, 20 points faibles touchés — seulement face à un gardien —, finir avec 60 % de coque, utiliser Analyse 2 fois). La victoire donne 1 étoile, chaque objectif une étoile de plus (3 au maximum) et **+10 % de butin par objectif**.
- **Palier du vaisseau :** somme des niveaux de laser, collecteur, scanner et moteurs (0 à 80) : paliers à 0, 10, 25, 45 et 70 (Éclaireur, Corvette, Frégate, Croiseur, Amiral). Le palier le plus haut atteint est gardé, même après une refonte. Il change la forme, la coque (1 000 à 2 500) et les canons (1 à 4). Les vaisseaux seront repensés avec la personnalisation.
- **Difficulté :** réglée avec `tools/live_balance.gd` (taux de victoire) et `tools/live_fit.gd` pour qu'on ne dépasse pas environ 80 % de victoires, à la main (joueur simulé) comme en automatique. Les ennemis sont plus durs si le Capitaine est faible (calcul de chance existant) mais jamais plus faciles que la base. La chance affichée ne dépasse pas 80 %.
- **Sons et vibrations :** sons synthétisés (aucun fichier), vibrations courtes à un impact et à la fin ; bouton « Son ».
- **Butin :** `GameState.finish_live` règle le butin (victoire : mode x objectifs ; défaite : 25 % du butin de base), l'XP du Capitaine (victoire seulement) et l'adaptation des ennemis.

## Dérive : règles implémentées (`scripts/derive_sim.gd`, `derive_ui.gd`, `derive_cell.gd`)

- **Grille 6 x 7 brouillée**, 75 s, 10 dangers cachés (11 aux étoiles naines, 12 sur la planète, +1 ou +2 si le Capitaine est faible) et 9 ressources (minerai ◆, données ●, énergie ✦). La case de départ et ses voisines directes sont sûres.
- **Scanner** une case voisine coûte 1 énergie (13 au départ, 20 au maximum) et révèle son contenu et un chiffre : le nombre de dangers autour d'elle. Aller sur une case déjà scannée est gratuit. **Avancer sans scanner** est gratuit mais un danger heurté retire 34 % de la coque.
- **Extraire :** arriver sur une ressource lance l'extraction (1,6 s) toute seule ; bouger l'annule. Une énergie récoltée rend 4 points.
- **Équipage :** Lumi (sonde : révèle les 8 cases autour, 3 énergies, 2 charges), Rex (saut de 2 cases en ligne, 2 énergies), Gorn (extraction).
- **Le météore, « gardien » de la dérive :** annoncé 2,2 s à l'avance (case hachurée avec compte à rebours), il détruit la case visée et sa ressource, et pulvérise le vaisseau s'il tombe dessus (défaite immédiate). Un météore toutes les 10 s environ, qui vise le vaisseau dans 10 % des cas et ses voisines dans 15 %.
- **Réussite :** survivre et ramener au moins 3 ressources. Même système d'objectifs que le combat (huit au choix, deux tirés au hasard, 1 à 3 étoiles, +10 % de butin par objectif). Une défaite garde 25 % du butin de base.
- **Gains x1,3** : la dérive est plus difficile que le combat, elle rapporte plus. Ce gain propre au mode s'ajoute aux bonus Aléatoire et secteur du jour (qui ne se cumulent pas entre eux).
- **Équipage assisté (bouton Auto) :** un démineur automatique déduit les cases sûres, scanne la moins dangereuse, fuit les météores, extrait et rentre. Il agit 30 % plus lentement, avec 0,45 s de réaction et quelques ratés.
- **Intuitif :** un premier toucher sur une case voisine inconnue la sélectionne (boutons « Scanner » et « Avancer sans scanner »), un second la scanne ; conseil en direct, ressource la plus proche entourée d'or, coût du scan sur les cases, guide de départ (touche « ? » pour le rouvrir).
- **Accessibilité :** chaque case a un nom complet (« ligne 3, colonne 4 : danger »), le danger a une forme (✕) et pas seulement une couleur, le météore a des hachures et un compte à rebours en chiffres, boutons d'au moins 60 px, clavier (flèches ou WASD, Maj + flèche, E, Q, L).
- **Difficulté :** `tools/derive_balance.gd` : pilote automatique et joueur simulé autour de 76 % et 78 % de victoires.

## Mode Aléatoire

- Tire un mode parmi ceux qui sont prêts (combat, dérive), pondéré selon la destination (astéroïdes : dérive 50 / combat 40 ; étoile : dérive 30 / combat 50 ; planète : dérive 15 / combat 35 ; la route sera ajoutée), jamais le même mode trois fois de suite. Gains x1,5 (x1,6 sur le secteur du jour), puis le gain propre au mode (la dérive x1,3).

## État de l'implémentation

- Fait : combat en direct et dérive sur le vaisseau 1, sélecteur de mode (Combat, Dérive, Aléatoire ; Route marquée « bientôt »), secteur du jour (rotation toutes les 6 h, bannière et ★ sur la destination), bonus de gains, objectifs, palier du vaisseau, sauvegarde, tests.
- Le mode **Aléatoire** est actif depuis que la dérive existe (deux modes à tirer).
- Le vaisseau 2 (drone piloté par l'équipage seul) garde l'ancien déroulement automatique chronométré.
- Les anomalies gardent leur combat automatique.
- À faire : mode Route, étoiles (récompense au-delà du bonus de butin), combat des anomalies.

## Points ouverts

- Le combat des anomalies utilise-t-il aussi le combat en direct, ou garde-t-il le combat automatique actuel ? (pour l'instant : automatique)
- Une durée cible par mode (par défaut 1 à 2 minutes ; 8 minutes pour la route).
- La relance automatique (Cristaux) : elle relance la destination, avec le même mode choisi, ou un nouveau tirage si le mode est « Aléatoire ».
