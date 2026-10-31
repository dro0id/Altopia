# Plan de construction d'Altopia, de A à Z

Chaque **branche** est un chantier qui se valide seul : objectif, contenu, livrable testable, décisions à prendre. On les traite dans l'ordre des dépendances ; une branche n'est fusionnée qu'une fois validée.

Légende de taille : S = une session courte, M = quelques sessions, L = un gros chantier.

## Socle (fait)
Prototype de combat automatique 2D animé : 5 héros, ennemis, boss tous les 5 secteurs, pouvoirs, amélioration, sauvegarde, gains hors ligne, tests de logique.

## Branche 1 · `feat/boucle-de-jeu` (M) : le Trou de verre
- **Histoire** : on entre dans un trou de verre qui s'est ouvert dans la Ceinture. Toute la boucle de jeu est cette ascension, étage après étage.
- **Structure (décidée)** : une montée d'étages comme dans un donjon. Plus on gagne, plus on monte. **Mini-boss tous les 5 étages, gros boss tous les 10.** Écran de **carte des étages** pour choisir et suivre sa progression.
- **Vocabulaire** : « étage » pour le donjon, « niveau » seulement pour les héros, afin d'éviter la confusion.
- **La boucle en quatre temps**
  1. **Combat (10 à 40 s)** : combat automatique, pouvoirs déclenchés au bon moment. Deux pouvoirs à moins de 3 s d'intervalle forment un combo (bonus de dégâts et de butin).
  2. **Sortie d'étage (5 s)** : butin, étoiles (3 selon les héros vivants), **coffre d'étage**, puis choix de **un renfort sur trois** valable jusqu'au prochain boss.
  3. **Progression (1 à 3 min)** : améliorer les héros ; aux niveaux 10 et 20, **palier d'évolution** qui renforce le pouvoir. Le bouton « Améliorer » signale le meilleur achat.
  4. **Mur et retour** : mini-boss (étages 5, 15, 25...) et gros boss (10, 20, 30...). Après une défaite, **bonus de persévérance** (+5 % de statistiques par défaite, remis à zéro à la victoire). Hors ligne : gains plafonnés à 8 h, récapitulatif, coffre gratuit toutes les 4 h.
- **Principe de difficulté (décidé)** : la difficulté monte doucement pour limiter la frustration, mais reste assez dure pour donner envie de revenir farmer des ressources. Concrètement : un indicateur de puissance recommandée sur la carte, le butin des étages déjà vaincus rejouable pour farmer, la persévérance après une défaite, et un pic de difficulté modéré aux mini-boss (étages 5, 15...) et plus marqué aux gros boss (10, 20...). Les chiffres sont à régler en test.
- **Contenu technique** : formation, écran de résultat, carte des étages, mini-boss et gros boss, coffre et renfort, paliers, persévérance, combos, retour hors ligne, réglages, icône et nom, écran d'entrée du Trou de verre.
- **Livrable** : APK de test jouable de bout en bout sur le Xiaomi 11T.
- **Décisions prises** : tout le contenu ci-dessus est gardé dans cette branche ; carte des étages ; mini-boss tous les 5, gros boss tous les 10 ; **session visée de 15 à 20 minutes** (environ 10 étages montés, un boss, un coffre et un renfort par étage, un peu de farm) ; difficulté douce mais exigeante, qui pousse à farmer.
- **Raretés de coffre** : commun (marron et or, étage normal), normal (vert, étage en 3 étoiles), rare (bleu, mini-boss), épique (violet, gros boss), légendaire (orange, gros boss en 3 étoiles), ultime (rouge, très rare). Plus la rareté monte, plus les crédits, les éclats de verre et le renfort proposé sont généreux. Chiffres d'exemple.
- **Ressources** : les crédits (améliorations des héros) et les **éclats de verre** (paliers d'évolution), gagnés dans les coffres et sur les boss.
- **Maquette** : 12 écrans (entrée, combat, résultat, carte des étages, hors ligne, réglages, coffre, renfort, mini-boss, gros boss, défaite avec persévérance, palier d'évolution).
- **À valider** : difficulté du premier mini-boss, noms et apparence du mini-boss de l'étage 5 et du gros boss de l'étage 10, ton du texte d'entrée.

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
