# Plan de construction d'Altopia, de A à Z

Chaque **branche** est un chantier qui se valide seul : objectif, contenu, livrable testable, décisions à prendre. On les traite dans l'ordre des dépendances ; une branche n'est fusionnée qu'une fois validée.

Légende de taille : S = une session courte, M = quelques sessions, L = un gros chantier.

## Socle (fait)
Prototype de combat automatique 2D animé : 5 héros, ennemis, boss tous les 5 secteurs, pouvoirs, amélioration, sauvegarde, gains hors ligne, tests de logique.

## Branche 1 · `feat/boucle-de-jeu` (M) : le Trou de verre
- **Histoire** : on entre dans un trou de verre qui s'est ouvert dans la Ceinture. Toute la boucle de jeu est cette ascension, étage après étage.
- **Structure (décidée)** : une montée d'étages comme dans un donjon. **Mini-boss tous les 5 étages, gros boss tous les 10.** Carte des étages. Vocabulaire : « étage » pour le donjon, « niveau » pour les héros.
- **Session visée (décidée)** : 15 à 20 minutes, environ 10 à 20 étages, un coffre par étage, du farm.
- **Difficulté (décidée)** : douce, mais assez dure pour pousser à farmer. Réglée par simulation (`docs/BALANCE.md`).
- **Étoiles** : 3 si aucun héros ne tombe, 2 si un héros tombe, 1 sinon. Si tous les héros tombent, c'est une défaite : choix entre réessayer, farmer l'étage d'avant ou améliorer.

### Branche 1a · le noyau jouable (FAIT dans le code)
Étages et carte, mini-boss (Foreur éclaté, étage 5) et gros boss (Gardien de verre, étage 10, deux phases, avertissement avant son gros coup), étoiles, coffre à six raretés avec garanties, éclats de verre, farm automatique des étages déjà vaincus, meilleur achat signalé, coffre gratuit toutes les 4 h, retour hors ligne (plafond 8 h), réglages, écran d'entrée, tutoriel intégré, sons synthétisés, sauvegarde versionnée, tests et outils d'équilibrage.

### Branche 1b · la profondeur (À FAIRE)
Choix d'un renfort parmi trois après chaque coffre, paliers d'évolution (niveaux 10 et 20, payés en crédits et éclats), bonus de persévérance après défaite, combos de pouvoirs, écran de coffre d'une rareté propre à chaque rareté (mise en scène), gros boss avec davantage de variété.

- **Raretés de coffre** : commun (chaque étage vaincu), normal (étage en 3 étoiles), rare (mini-boss), épique / légendaire / ultime sur les gros boss : épique 10 % en 1 ou 2 étoiles et 20 % en 3 étoiles ; légendaire 3 % (garanti au 2e gros boss en 3 étoiles sans légendaire) ; ultime 0,5 % (garanti au 10e sans ultime).
- **Ressources** : crédits (améliorations) et éclats de verre (paliers d'évolution, plus tard).
- **Maquette** : 14 écrans (voir le canvas).
- **À valider** : ton du texte d'entrée, noms des boss, chiffres d'économie après test sur téléphone.

## Branche 2 · `feat/histoire-capitaine` (M) : le signal et le Capitaine
- **Objectif** : l'histoire space opera est portée par le jeu, pas par un texte à part.
- **Contenu** : introduction courte (Terre, signal, décollage), dialogues entre combats (Capitaine, Vance, héros), un héros ou un ennemi marquant par chapitre, fin du chapitre 1 qui ouvre le suivant.
- **Livrable** : le chapitre 1 se joue avec son histoire de bout en bout.
- **À valider** : ton (sérieux ou léger), longueur des dialogues, voix du Capitaine (silencieux ou personnage).

## Branche 3 · `feat/heros-collection` (L) : recruter et faire évoluer
- **Objectif** : la collection est le moteur de rétention, comme dans Top Heroes.
- **Contenu** : 15 héros au total (trois raretés, trois espèces, trois rôles), recrutement par tirage avec taux affichés et jeton gagné en jeu, doublons en fragments, étoiles et paliers d'évolution, formation de 5 à placer (ligne avant/arrière), synergies d'espèce et de rôle.
- **Livrable** : on recrute, on compose son escouade, on voit l'effet des synergies.
- **À valider** : nombre de héros, système de rareté, monnaie de recrutement (aucun achat en argent réel dans la première version).

## Branche 4 · `feat/equipement` (M) : butin et build
- **Contenu** : 4 emplacements par héros, raretés et bonus aléatoires, fusion et recyclage, inventaire, comparaison avant équipement.
- **Livrable** : un objet change réellement l'issue d'un combat.
- **À valider** : emplacements, profondeur des bonus, objets liés à un héros ou communs.

## Branche 5 · `feat/vaisseau-base` (L) : le hub et la production
- **Contenu** : le vaisseau comme hub avec des salles (mine, centrale, labo, atelier, quartiers), production hors ligne, améliorations permanentes, la Base débloquée à l'arrivée de la première planète.
- **Livrable** : le joueur a une raison de revenir hors combat.
- **À valider** : nombre de salles, lien avec les héros (affectation) ou production passive seule.

## Branche 6 · `feat/modes-de-jeu` (M) : varier le rythme
- **Contenu** : failles (combat de boss à tentatives limitées), expéditions chronométrées, défis quotidiens ; les modes Dérive et Route de l'ancien projet ne sont repris que si tu les veux.
- **Livrable** : au moins deux modes en plus de la campagne.
- **À valider** : quels modes, et lesquels de l'ancien projet on reprend.

## Branche 7 · `feat/tutoriel` (S/M) : l'entrée en matière
- **Contenu** : missions guidées sur les 10 premières minutes (placer l'escouade, lancer un pouvoir, monter un héros, première recrue), déblocages progressifs des onglets, aucun mur de texte.
- **Livrable** : un nouveau joueur sans explications comprend la boucle.
- **Dépend de** : branches 1 à 3.

## Branche 8 · `feat/interface-finition` (M) : son et rendu
- **Contenu** : thème d'interface unifié, musique et effets sonores (libres de droits), animations de victoire, transitions, écrans de chargement, accessibilité (taille du texte).
- **Livrable** : le jeu paraît fini.
- **À valider** : source des sons et de la musique.

## Branche 9 · `feat/qualite-et-perf` (M, en continu) : tenir sur téléphone
- **Contenu** : tests de logique à chaque branche, parcours en jeu par clics, mesure d'images par seconde et de mémoire sur un vrai téléphone, optimisation du dessin, CI qui construit l'APK de test à chaque envoi.
- **Livrable** : budget de performance tenu (cible : 60 images par seconde sur le Xiaomi 11T).

## Branche 10 · `feat/publication` (M) : sortir le jeu
- **Contenu** : signature et APK de release, fiche Google Play, politique de confidentialité, version de test fermée, collecte des retours.
- **Dépend de** : toutes les autres. Point de décision : l'achat de la licence développeur Google Play est payant.

## Ordre proposé
1 → 2 → 3 → 7 → 4 → 5 → 6 → 8 → 10, avec la branche 9 menée en parallèle de chacune.

## Jalons
- **A. Jouable** (branches 1 et 2) : le chapitre 1 est complet.
- **B. Collectionneur** (branches 3, 4 et 7) : recrutement, équipement, tutoriel.
- **C. Complet** (branches 5, 6 et 8) : hub, modes, finition.
- **D. Publié** (branche 10).
