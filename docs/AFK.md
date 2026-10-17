# Boucle AFK : progression et équilibrage

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
