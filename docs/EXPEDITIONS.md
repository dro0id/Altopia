# Expéditions : refonte (cahier des charges)

Les expéditions ne sont **pas** de l'AFK : elles se jouent en direct, avec le Capitaine et son équipage, et servent de bonus de ressources. Maquettes : canvas « Altopia — Refonte des Expéditions » (propositions A, B, C et D).

## Décisions validées

- Trois modes d'exploration : **Combat en direct** (B), **Dérive** (grille de scan, C) et **Route** (carte d'étapes, A).
- **Lancer une expédition tire un mode au hasard.** Le joueur choisit la destination, pas le mode. Le tirage est pondéré selon la destination (voir plus bas), jamais le même mode trois fois de suite.
- Le **« secteur du jour »** est conservé : gains ×1,5 pendant quelques heures sur une destination (ou un mode), pour pousser à varier.
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

## Tirage du mode (par défaut, à régler)

| Destination | Dérive | Combat | Route |
|---|---|---|---|
| Champ d'astéroïdes | 50 % | 40 % | 10 % |
| Étoile naine | 30 % | 50 % | 20 % |
| Planète inconnue | 15 % | 35 % | 50 % |

## Points ouverts

- Le combat des anomalies utilise-t-il aussi le combat en direct, ou garde-t-il le combat automatique actuel ?
- Une durée cible par mode, et le gain par minute de jeu actif face à l'AFK (qui doit rester l'essentiel).
- La relance automatique (Cristaux) : elle relance la destination, avec un nouveau tirage de mode.
