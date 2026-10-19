# Boucle AFK : progression et équilibrage

> **Mise à jour (architecture « deux jeux »)** : le Capitaine ne participe plus à l'AFK et les plafonds de niveau n'existent plus. Voir la section « Deux jeux, un cercle » ci-dessous ; les passages plus bas sur les plafonds et académies sont historiques.

Objectif : un jeu qui dure **environ 3 mois** avant sa première « fin », **sans frustrer** le joueur.
Ce document décrit le socle de durée (Labo, plafonds de niveau) et les résultats du simulateur.

## Règles anti-frustration (à respecter pour toute nouvelle fonction)
1. Jamais de mur sans issue : une autre voie progresse toujours en parallèle.
2. Aucune perte : pas de ressources qui disparaissent, pas de réinitialisation forcée, défaite = 25 % du butin.
3. Chaque limite est annoncée (« Plafond atteint : relevez-le au Labo », prérequis affichés sur les recherches).
4. Attentes supportables : premières recherches de moins d'une minute, plusieurs recherches en parallèle, tout se termine hors ligne exactement, file d'attente payée d'avance et annulable.
5. Chaque courte session donne quelque chose.
6. Pas de malchance pure (garantie de recrutement et de butin : à faire).
7. Aucune punition pour un jour manqué (missions cumulatives : à faire).

## Le Labo (onglet « Labo »)
- **Recherches en temps réel** : durées de 30 s à plusieurs jours, qui avancent hors ligne **jusqu'au bout** (pas de plafond de coffre).
- **1 poste** au départ, **jusqu'à 3** (Laboratoire annexe). **File d'attente** de 3 recherches, payées d'avance, annulables (remboursement 100 % en file, 70 % en cours).
- **Accélérer** : retire 25 % de la durée totale contre de l'énergie, 2 fois par recherche au plus (le rythme reste prévisible).
- **21 recherches** : production, gains d'expédition, XP, vitesse, rendement et coffre hors ligne, butin, automatisation du labo, postes de recherche, et deux **académies** qui relèvent les plafonds de niveau. Les lignes de base ont des paliers II et III qui s'ouvrent quand la précédente est terminée.

## Trois activités, un cercle
- **L'AFK, c'est l'équipage aux postes** (continue hors ligne) : il produit des ressources, **gagne son XP en travaillant** (heures par niveau = 1 + 0,25 x niveau) et **fabrique les objets du Capitaine** (environ 1,2 par heure de travail). Il n'y a **plus de plafond de niveau** : la courbe d'XP (XP_PER_LEVEL x niveau) ralentit toute seule.
- **Les expéditions ne sont pas de l'AFK** : elles se jouent en direct, **avec le Capitaine** à bord du vaisseau 1 (il y gagne de l'XP, 5 % d'une victoire d'anomalie par victoire) et son équipage qui l'accompagne (35 % de ses stats). Le vaisseau 2 est un drone piloté par l'équipage seul. **Hors ligne, les expéditions se mettent en pause** (rien n'est perdu). Les gains d'expédition sont multipliés par 12 pour compenser.
- **Les anomalies** sont l'autre activité du Capitaine (voir plus bas) : c'est elles qui font surtout monter son niveau.
- **Le pont : l'AFK fabrique l'équipement du Capitaine.** Le **niveau d'AFK** (niveaux de l'équipage aux postes + améliorations de postes et de vaisseau) fait monter la rareté (surtout épique et légendaire) et le niveau des objets. Les chances sont affichées dans l'onglet Équipage.

## Anomalies (Capitaine, onglet Capitaine)
- Faille n : 2 sentinelles et 1 gardien, niveau d'ennemi 1 + 4 x (n-1). La faille n+1 s'ouvre quand on réussit la n.
- **Charges** : 20 au maximum, 1 de plus par heure (aussi hors ligne). Une défaite **rend la charge**.
- XP d'une victoire : xp_needed(niveau) / (3 + niveau/2,5), modulée de x0,5 à x1 selon la difficulté de la faille (pas de bonus de 1re réussite : on ne monte pas en niveau en grimpant seulement). Crédits à chaque victoire ; bonus de ressources à la 1re réussite ; record de tours (+50 % de crédits quand on le bat).
- Le combat est animé, comme les expéditions.

## Règles d'économie
- Niveau des ennemis AFK = 1 + (victoires / 150)^0,65 ; **chaque défaite fait redescendre le compteur de 10 %** : les ennemis s'adaptent, l'équipage gagne presque toujours (99 % en simulation).
- Butin : ~1,2 objet par heure de travail aux postes (~29 par jour) ; niveau d'objet = 3 + niveau d'AFK / 8.
- Vitesse d'expédition : bonus additifs plafonnés à x2,5. Gains du rôle requis en niveau^0,7.

## Le Labo
Recherches en temps réel (voir plus bas), file de 5 recherches payées d'avance, **recherche automatique** (un poste libre lance la plus courte recherche abordable). Les académies de plafond ont disparu avec les plafonds ; les recherches d'XP ne concernent plus que l'équipage.

## Résultats du simulateur (120 jours, robot)
| Profil | Capitaine j7 / j30 / j90 | Faille max j90 | Niveau d'AFK j90 | Équipement j90 | Victoires expéditions |
|---|---|---|---|---|---|
| casual (1 x 5 min/jour) | 24 / 54 / 101 | 179 | 581 | niv. 68, 6 légendaires | 100 % |
| evening (1 x 15 min) | 27 / 59 / 105 | 254 | 755 | niv. 90, 5 légendaires | 100 % |
| regular (3 x 8 min) | 34 / 65 / 125 | 221 | 621 | niv. 75, 6 légendaires | 100 % |
| hardcore (6 x 10 min) | 37 / 73 / 136 | 220 | 621 | niv. 74, 6 légendaires | 100 % |

- La plus longue période sans progrès est de **2 jours** au pire. Le premier objet épique arrive vers le jour 7, les premiers légendaires vers le jour 14-30.
- XP perdue : **0** (plus de plafond). Défaites en anomalie : 0 (le robot ne tente que les failles qu'il peut gagner ; un joueur peut tenter plus haut, la charge lui est rendue).
- Postes de recherche vides au début d'une session : 56 % (casual), 40 % (evening), 18 % (regular), 4 % (hardcore) **sans** la recherche automatique, qui règle ce cas.

### Mis de côté (à reprendre plus tard)
- Inventaire plein dès le jour 30 (60 objets) : recyclage plus simple à prévoir.
- Entraînement payant du Capitaine et des cartes : coût inabordable après le niveau ~60, à baisser ou retirer.
- Objectifs : les 12 paliers sont tous faits au jour 90, il en faut qui continuent.

### Limites connues
- Le robot dépense au mieux : un vrai joueur sera plus lent. Les chiffres donnent la direction.
- Les expéditions ne présentent presque plus de défi (les ennemis s'adaptent) : le défi est dans les anomalies. À voir selon les retours.
- Le rythme de l'équipement (premiers légendaires entre le jour 14 et 30) et du Capitaine (niveau ~100 au jour 90) est à confirmer par des tests réels.
- Garanties de butin et de recrutement, missions du jour : pas encore faites.

Lancer : `godot --headless --path . -s tools/balance.gd -- <casual|evening|regular|hardcore> <jours> [--detail]`

---
## Historique : socle de durée et analyse de frustration (avant la refonte)
## Plafonds de niveau
- Capitaine : **30** au départ, **+10 par niveau de l'Académie des capitaines** (jusqu'à 100). Équipage : **25**, **+11 par niveau de l'Académie de l'équipage** (jusqu'à 80).
- Au plafond, l'XP est **mise de côté** (un niveau) : le niveau tombe dès que le plafond monte. Un joueur déjà au-dessus d'un plafond ne perd jamais de niveau.

## Corrections d'économie (nécessaires pour durer)
- Vitesse d'expédition : bonus **additifs**, plafonnés à ×2,5 (durée minimale = 40 % de la base). Avant, ils se multipliaient et les expéditions descendaient à 5 s.
- Gains du rôle requis : croissance en niveau^0,7 au lieu de linéaire.
- L'XP d'une victoire grandit avec le niveau des ennemis ; niveau d'ennemi plafonné à 60.
- Rendement et durée hors ligne : moins dépendants des niveaux de l'équipage, pour que la recherche compte.
- Calcul hors ligne regroupé : 24 h se calculent en moins d'une seconde.

## Résultats du simulateur (`tools/balance.gd`, 120 jours)
Niveau du Capitaine (plafond), recherches terminées sur 314 niveaux :

| Profil | Jour 1 | Jour 7 | Jour 30 | Jour 60 | Jour 120 | Recherches j.120 |
|---|---|---|---|---|---|---|
| casual (1 × 5 min/jour) | 3 | 18 (30) | 80 (80) | 80 (80) | 90 (90) | 233 |
| evening (1 × 15 min) | 3 | 32 (40) | 80 (80) | 90 (90) | 90 (90) | 259 |
| regular (3 × 8 min) | 10 | 50 (50) | 70 (70) | 80 (80) | 90 (90) | 243 |
| hardcore (6 × 10 min) | 23 | 70 (70) | 80 (80) | 80 (80) | 90 (90) | 256 |

- Plafond du Capitaine à 100 : **non atteint en 120 jours** (90 au mieux). Plus de 70 % des recherches restent à faire au jour 60 pour un joueur occasionnel.
- Sessions avec progrès : casual 118/120, evening 120/120, regular 212/360, hardcore 280/720.
- **Plus longue période sans aucun progrès** : casual 2 jours, evening 1 jour, regular 3 jours, hardcore 4 jours.

### Limites connues (à traiter par les étapes suivantes)
- **Les joueurs très assidus manquent de contenu actif** vers le jour 80 (4 jours sans progrès pour hardcore) : tout est limité par le temps réel. Les secteurs, les boss et les missions d'équipage ajouteront de l'activité.
- Le robot dépense au mieux : un vrai joueur sera plus lent.
- Le début (jour 1) est lent pour une session de 5 minutes (Capitaine niveau 3) : à surveiller dans les retours.
- Les garanties de recrutement et de butin et les missions du jour ne sont pas encore faites.

Lancer : `godot --headless --path . -s tools/balance.gd -- <casual|evening|regular|hardcore> <jours> [--detail]`


## Analyse de la frustration (simulateur, 120 jours, 8 variantes)
Mesures ajoutées au simulateur : XP perdue au plafond, sessions au plafond, postes de recherche vides au début d'une session, taux de victoire, plus longue période sans progrès. Deux comportements : « naïf » (dépense au fil de l'eau) et « économe » (garde ses crédits pour l'académie qui bloque).

| Mesure | casual | evening | regular | hardcore |
|---|---|---|---|---|
| XP perdue au plafond | 97 % | 97 % | 97 % | 98 % |
| Sessions avec le Capitaine au plafond | 105/120 | 106/120 | 344/360 | 690/720 |
| Poste de recherche vide au début de session (naïf / économe) | 20 % / 50 % | 18 % / 68 % | 5 % / 54 % | 2 % / 63 % |
| Jour où le plafond Capitaine passe à 90 (naïf) | 39 | 47 | 52 | 51 |
| Jour où le plafond équipage passe à 80 (naïf) | 94 | 108 | 92 | 94 |
| Taux de victoire global (naïf) | 69 % | 69 % | 69 % | 85 % |
| Plus longue période sans progrès (naïf / économe) | 2 j / 3 j | 3 j / 7 j | 2 j / 3 j | 3 j / 6 j |

### Points de frustration, par gravité
1. **L'XP est perdue presque tout le temps (97 %).** Passé les premières semaines, le joueur est au plafond dans 88 à 96 % des sessions : les combats ne font plus monter personne.
2. **Les plafonds sont bloqués par le coût en crédits, pas par le temps.** L'académie niveau 6 demande environ 12 M de crédits ; le joueur en a 3 à 4 M et en gagne un peu plus d'1 M par jour tout en finançant le reste. Résultat : 40 à 100 jours au même plafond, avec 5 à 10 M d'énergie et des millions de données inutilisés.
3. **Les postes de recherche restent vides.** 20 % des sessions d'un joueur occasionnel commencent avec un poste libre (du temps de labo perdu). Quand le joueur économise pour une académie, c'est 50 à 68 %.
4. **Les ennemis continuent de monter alors que le joueur est plafonné.** Avec la relance automatique, 15 à 31 % des combats sont perdus (butin réduit à 25 %, aucune XP).
5. **Périodes sans aucun progrès** de 2 à 7 jours, surtout en fin de parcours et chez les joueurs assidus.
6. Le jour 1 reste lent pour une session de 5 minutes (Capitaine niveau 3).

### Corrections proposées
- **Ne jamais perdre l'XP** : mise de côté jusqu'à +10 niveaux (un cran d'académie) ; le plafond qui monte donne alors les 10 niveaux d'un coup. Le surplus au-delà devient une ressource.
- **Payer les académies avec les ressources en surplus** (énergie, données) et ramener la part en crédits à ~3 jours de revenus. Afficher « il vous manque X (≈ N jours) ».
- **Recherche automatique** : un réglage qui lance la prochaine recherche abordable dès qu'un poste se libère ; file portée à 5.
- **Difficulté adaptative** : le niveau des ennemis ne monte plus quand la victoire devient incertaine ; la relance automatique repasse à la destination inférieure plutôt que d'enchaîner les défaites.
- **Contenu actif** pour combler les périodes calmes : secteurs, boss, missions d'équipage (étapes suivantes).

## La Base : salles, spécialités, Atelier ciblé

L'AFK est le gameplay de l'équipage : chaque équipier travaille dans une salle de la **Base** (onglet « Base »).

| Salle | Produit | Effet propre |
|---|---|---|
| Mine | minerais + crédits | |
| Centrale | énergie + crédits | |
| Laboratoire | données + crédits | |
| Atelier | crédits | cadence de fabrication, qualité des objets, ciblage |
| Quartiers | crédits | + XP de tout l'équipage au travail |
| Soute | crédits | coffre hors ligne plus long, meilleur rendement |

- Niveaux de salle 1 à 30 (+6 % par niveau, coût ×1,75 par niveau). Un équipier de la bonne classe travaille à +25 %, un spécialiste de la salle à +50 % (`specialty` dans `HEROES`).
- L'Atelier fabrique des objets pour le capitaine : l'emplacement et l'affixe visés peuvent être choisis (chacun réduit la cadence de 15 %). La puissance de fabrication = niveau d'AFK + 3 × niveau d'Atelier ; elle règle le niveau d'objet et la chance de raretés élevées.
- Migration : les anciens postes (Pilote/Ingénieur/Scientifique) deviennent les niveaux de salle correspondants, l'équipage est placé automatiquement.
- Calibrage (4 profils, 120 jours) : niveau du capitaine à ±5 % de l'ancienne boucle (j7/j30/j90 casual 24/55/95, evening 27/59/109, regular 33/66/121, hardcore 36/74/139). Le niveau d'AFK affiché est environ 2× plus grand : 6 équipiers au travail au lieu de 3. Aucune période sans progrès de plus d'un jour.

- Une salle sans équipier ne produit rien et n'a aucun effet (l'Atelier est à l'arrêt, Quartiers et Soute inactifs, la salle ne compte pas dans le niveau d'AFK).
- L'interface sépare la **Base** (salles, Atelier) du **Vaisseau** (améliorations laser, collecteur, scanner, moteurs, docks).

## Objectifs de long terme (Base)

La chaîne d'objectifs passe de 12 à 22 paliers. Les 10 nouveaux suivent l'AFK : niveau d'AFK (400, 900, 1 500, 2 200), niveau de l'Atelier, objets fabriqués (1 500, 15 000), niveau minimal des 6 salles (10, 18, 24). Leurs récompenses incluent un objet garanti (épique, puis légendaire) au niveau de fabrication de l'Atelier. Rythme simulé (regular) : environ 12 objectifs à 7 jours, 15 à 30 jours, 18 à 60 jours, 20 à 90 jours.
Une recrue est placée d'office dans la salle vide où elle travaille le mieux.

## Refonte de la Base (prestige)

But : allonger la durée de vie de la boucle AFK sans frustrer. Ce n'est pas un accélérateur.
- Débloquée à 90 niveaux de salles cumulés (environ 3-4 semaines de jeu). Toujours volontaire, avec confirmation en deux appuis.
- Remet à zéro : salles (elles repartent au niveau 1, plus haut avec « Fondations »), améliorations du vaisseau (sauf les docks), ressources, expéditions en cours (rappelées). Conservés : équipage et ses niveaux, Capitaine, équipement, cartes, recherches, objectifs.
- Éclats gagnés au total = (niveaux de salles cumulés / 30)^2,5. La refonte ne donne que la différence avec les éclats déjà gagnés : refaire la même Base ne rapporte rien (pas de farm), il faut dépasser son record. Le niveau maximal des salles monte de 5 par refonte.
- Cinq bonus permanents (15 niveaux, coût x1,45 par niveau) : Rendement (+12 % production), Formation (+12 % XP équipage), Fabrication (+10 % cadence de l'Atelier), Qualité (+20 puissance de fabrication), Fondations (salles repartent 2 niveaux plus haut).
- Simulation regular, 150 jours, refonte quand elle promet au moins 20 éclats (2 refontes) : niveau d'AFK +19 %, équipement +21 %, faille +30 %, capitaine −5 % par rapport à sans refonte. Aucune période sans progrès de plus d'un jour.
- Leçons de la conception : remettre à zéro les niveaux d'équipage rendait la refonte perdante à tous les seuils testés (niveau d'AFK à 120 jours divisé par 2). Une refonte qui paie à chaque fois sans condition est exploitable (boucles de refontes) : d'où la règle « seulement du nouveau ».

## AFK : une aide, pas une triche ; boucle sur un an

Principes : l'AFK n'a pas de fin, mais il aide le Capitaine sans remplacer la boucle RPG.
- Le niveau des objets de l'Atelier est borné à 70 % du niveau du Capitaine (`AFK_ILVL_CAP_RATIO`) : pour que l'AFK serve, il faut monter le Capitaine (anomalies, expéditions). Les légendaires de l'Atelier sont plus rares.
- La montée de niveau de l'équipage ralentit de plus en plus : heures par niveau = 1 + 0,25 L + 0,002 L² (`AFK_XP_HOURS_QUAD`).
- Simulation sur 365 jours avec refontes (conseillées à partir de 20 éclats promis), profils regular / casual :
  - Début de partie inchangé : regular jour 7 / 14 / 30 : capitaine 32 / 45 / 67, équipement niv. 19 / 30 / 45.
  - Jour 300 : regular capitaine 238, équipement niv. 159, niveau d'AFK 3 194 ; casual capitaine 191, équipement niv. 130, niveau d'AFK 3 043.
  - 3 refontes sur l'année, plus longue période sans progrès 1 à 2 jours, aucune défaite en anomalie.
- Limite connue : les recherches du Labo sont presque toutes finies vers le jour 300 (290/302 en regular). Il faudra de nouvelles recherches (paliers) pour tenir au-delà.

## Niveaux du Capitaine compressés (niveau 50 en un an)

Un niveau du Capitaine vaut 5 « niveaux de puissance » (`CAPTAIN_LEVEL_SPAN`). Stats, XP par victoire et ennemis suivent la même courbe qu'avant : la difficulté est inchangée, seuls les numéros de niveau sont ~5x plus espacés (stats +75 % par niveau, XP par niveau ≈ celle de 5 anciens niveaux). Les anciennes sauvegardes sont converties (ancien niveau 47 = niveau 10 + le reste en XP).
- Simulation regular : niveau 7 / 10 / 15 / 20 / 28 / 39 / 44 aux jours 7 / 14 / 30 / 60 / 120 / 240 / 300, soit environ 50 vers le jour 365. Casual : 5 / 8 / 12 / 17 / 23 / 35 / 38.
- Limite : en fin d'année un niveau tombe tous les 7 à 10 jours ; la barre d'XP reste le retour de progression entre deux niveaux.

## Recherches de palier IV

Calibrage, Cartographie, Propulsion et Butin gagnent un palier IV (prérequis : le palier III au maximum, durées jusqu'à 12 à 72 jours par niveau). Entraînement n'en a pas, pour ne pas accélérer l'XP du Capitaine. Simulation regular sur 480 jours : recherches 302/372 au jour 240, 325/372 au jour 365, 347/372 au jour 480, capitaine niveau 51 au jour 365 et 56 au jour 480. En fin de boucle, moins de la moitié des sessions montrent un gain visible (niveau, recherche terminée) : le suivi passe par les barres de progression.

## Règle : le Capitaine plafonne au niveau 50 ; objectifs de refonte

- Le Capitaine ne peut jamais dépasser le niveau 50 (`CAPTAIN_MAX_LEVEL`) : l'XP en trop est perdue, l'entraînement payant est refusé, l'anomalie ne donne plus d'XP. La puissance vient ensuite de l'équipement (les objets de l'Atelier restent bornés par le niveau du Capitaine). Les anciennes sauvegardes au-delà sont ramenées à 50.
- Chaîne d'objectifs de refonte (6 paliers, indépendante de la chaîne principale) : 1, 3 et 5 refontes, 10 et 30 niveaux de bonus cumulés, 150 éclats gagnés par des refontes. Récompenses : éclats et objets épiques puis légendaires. Les éclats d'objectif ne réduisent pas les gains des futures refontes.

## Labo : 1 poste, déblocages spéciaux

- Un seul poste de recherche au départ. Le Laboratoire annexe (recherche, 1 niveau) donne le 2e poste.
- Le 3e poste et la recherche automatique ne s'obtiennent plus par le jeu : ils se débloquent avec une monnaie spéciale, les **Cristaux** (300 et 150), non obtenable en jeu pour le moment (`PREMIUM_OBTAINABLE = false`), prévue plus tard via un achat. L'interface les montre verrouillés.
- Anciennes sauvegardes : ceux qui avaient déjà le 3e poste ou la recherche automatique les gardent (pas de perte).
- Simulation d'un an avec 1 à 2 postes et sans recherche automatique (le robot relance ses recherches à chaque session) : recherches 319/371 (regular) et 302/371 (casual) au jour 365, contre 325/372 avant ; capitaine niveau 50 (regular) et 43 (casual) au jour 365. Les ressources limitent plus la recherche que le nombre de postes.

## Interface de la Base (d'après la maquette validée)

- 4 onglets en bas (Capitaine, Équipage, Expéditions, Base) ; la Base a un sous-menu Salles · Atelier · Labo · Vaisseau · Rang. Code : `scripts/base_ui.gd` (la maquette est dans l'artifact « Altopia — Refonte UX de la Base AFK »).
- Salles : vue station (pouls de production, 6 tuiles, Atelier en direct, objectif), fiche de salle (équipiers avec l'effet du changement avant validation, amélioration avec gain et retour sur investissement).
- Écarts assumés avec la maquette : cadre « pointillé » dessiné à la main, 5 raretés d'objets au lieu de 4, catalogue complet des recherches ajouté sous le Labo (il faut bien pouvoir lancer une recherche), les équipiers déjà en poste ailleurs ne sont pas sélectionnables (« occupé »).
- Hors ligne : rendement fixe de 50 %, 70 % avec le déblocage en Cristaux (200). Les anciens bonus de rendement (équipage, recherche Protocoles, Soute, objets) sont retirés : Protocoles et Soute allongent désormais le coffre (durée comptée).

## Anomalies : réserve de 100 charges

- Réserve de 100 charges, 10 consommées par entrée en faille (10 entrées en réserve), recharge de +1 charge par tranche de 2 min 30 (24 charges par heure : une entrée toutes les 25 min, réserve pleine en 4 h 10). Une défaite rend les 10 charges. Les anciennes sauvegardes sont converties (x10).
- Le combat étant déterministe et l'issue annoncée à l'avance, le robot ne perd jamais ; le taux de réussite minimum de 80 % visé pour les anomalies et les expéditions sera réglé avec les futures boucles de gameplay.

## Taux de réussite minimum (80 %) : tests et réglages

Simulateur : `tools/balance.gd -- <profil> <jours> <refonte> push` fait jouer un joueur « naïf » qui fonce toujours sur le contenu le plus dur (faille la plus haute ouverte, expédition la plus difficile), sans regarder l'aperçu du combat ; il s'arrête après une défaite d'anomalie. Sans `push`, le joueur prudent choisit ce qu'il peut gagner.

Avant réglage (90 jours) : anomalies 0 à 1 % (29 % / 14 % en casual / regular une fois la boucle de réessais retirée), expéditions 99 à 100 %.

Réglages :
- Expéditions : le niveau des ennemis monte vite avec les victoires (`1 + victoires / 4`, plafond 2 500) et chaque défaite retire 4 victoires (`ENEMY_DEFEAT_LOSS`) : un joueur qui pousse hovère autour de 80 % de réussite. Les récompenses ne dépendent pas du niveau des ennemis.
- Anomalies : palier d'une faille à la suivante réduit (`ANOMALY_ENEMY_LEVEL_PER_FAILLE` = 0,35, contre 5,5) pour que la faille suivante reste à portée ; l'XP d'une victoire se module par le niveau des ennemis relatif à celui du Capitaine. Les numéros de faille montent beaucoup plus haut (environ 1 300 à 60 jours en regular) : c'est un numéro, pas une difficulté.

Résultats, joueur naïf, 60 jours :

| Profil | Anomalies | Expéditions |
|---|---|---|
| casual | 100 % | 99 % |
| regular | 90 % | 85 % |
| hardcore | 78 % | 82 % |

Limites : le combat reste déterministe (aperçu exact), donc un échec n'arrive que si le joueur ignore l'aperçu. En casual, peu d'expéditions sont lancées : les ennemis ne rattrapent pas l'équipe et le taux reste proche de 100 %.

Rythme sur un an après réglage (joueur prudent, avec refontes) : le Capitaine garde le même rythme (regular : niveau 15 / 26 / 39 / 50 aux jours 30 / 90 / 180 / 300 ; casual : 8 / 15 / 22 / 29). Numéro de faille atteint : environ 800 au jour 30 et 6 000 au jour 300 en regular. Expéditions : 85 % de réussite en regular, 92 % en casual, même avec le choix prudent (le repli sur les astéroïdes peut perdre).

## Combats avec un vrai risque d'échec (20 % maximum)

- Les vrais combats ont maintenant du hasard : chaque coup varie de ±35 % (`BATTLE_VARIANCE`) et les critiques sont tirés au sort. L'aperçu (sans hasard) reste utilisé pour les animations ; l'interface annonce une **chance de victoire** calculée par tirages répétés : « sûr » à partir de 80 %, « risqué » à partir de 50 %, « très risqué » en dessous.
- Un joueur qui ne tente que le contenu « sûr » (≥ 80 % de chance) perd au plus 20 % du temps. Une défaite coûte quelque chose : en anomalie la moitié des charges est rendue (`ANOMALY_DEFEAT_REFUND`), en expédition le butin tombe à 25 % et les ennemis s'adaptent.
- Mesure (90 jours, joueur qui ne tente que ≥ 80 % de chance) : réussite en anomalies / expéditions : casual 100 % / 91 %, regular 85 % / 83 %, hardcore 83 % / 81 %. Joueur naïf qui fonce toujours : casual 100 % / 93 %, regular 81 % / 83 %, hardcore 68 % / 82 %.
- Les expéditions regroupées hors ligne tirent quelques combats pour estimer la part de victoires.
- Rythme sur un an avec le hasard (joueur qui ne tente que ≥ 80 % de chance) : Capitaine regular niveau 14 / 26 / 36 / 46 aux jours 30 / 90 / 180 / 300 (le niveau 50 passe d'environ le jour 300 à environ le jour 330) ; casual 8 / 15 / 22 / 28. Les défaites rallongent donc la boucle d'environ 10 % sans la casser.
