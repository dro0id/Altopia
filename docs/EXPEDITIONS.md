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

## État de l'implémentation

- Fait : combat en direct sur le vaisseau 1, sélecteur de mode (Combat jouable ; Dérive et Route marqués « bientôt »), secteur du jour (rotation toutes les 6 h, bannière et ★ sur la destination), bonus de gains, objectifs, palier du vaisseau, sauvegarde, tests.
- Le mode **Aléatoire** est verrouillé tant qu'un seul mode est prêt (sinon il donnerait x1,5 sans rien tirer). Il se débloque dès que la Dérive ou la Route existe.
- Le vaisseau 2 (drone piloté par l'équipage seul) garde l'ancien déroulement automatique chronométré.
- Les anomalies gardent leur combat automatique.
- À faire : modes Dérive et Route, étoiles (récompense au-delà du bonus de butin), combat des anomalies.

## Points ouverts

- Le combat des anomalies utilise-t-il aussi le combat en direct, ou garde-t-il le combat automatique actuel ? (pour l'instant : automatique)
- Une durée cible par mode (par défaut 1 à 2 minutes ; 8 minutes pour la route).
- La relance automatique (Cristaux) : elle relance la destination, avec le même mode choisi, ou un nouveau tirage si le mode est « Aléatoire ».
