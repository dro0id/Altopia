# Altopia : document de conception (v0)

## Vision
Space opera en RPG idle de combat automatique pour mobile. Le joueur est le Capitaine d'un vaisseau qui part vers un signal inconnu : il recrute des héros (humains, robots, extraterrestres), les équipe, les fait progresser, et ses escouades affrontent des vagues d'ennemis sans qu'il ait à les piloter. Il joue par sessions courtes de 2 à 5 minutes, plusieurs fois par jour ; le jeu avance aussi hors ligne.

Références : **Top Heroes** (collection de héros, composition d'escouade, progression par chapitres, gains hors ligne) et **Mini Legion** (combats de foule lisibles à l'écran, escouades nombreuses, pouvoirs qu'on déclenche).

## Boucle de jeu
1. **Combat** : une escouade de 5 héros affronte des vagues d'un chapitre ; le combat est automatique, le joueur déclenche les pouvoirs spéciaux.
2. **Butin** : crédits, matériaux, équipement, fragments de héros.
3. **Progression** : monter les héros en niveau, les équiper, les faire évoluer (étoiles), améliorer le vaisseau.
4. **Chapitre suivant** : un boss garde chaque palier ; le battre ouvre un nouveau secteur de l'espace.
5. **Hors ligne** : le vaisseau continue de combattre ; au retour, le joueur récupère le butin accumulé (plafonné).

## Systèmes (par ordre d'importance)
- **Héros** : trois rôles (Pilote : dégâts à distance ; Ingénieur : solide, protège ; Scientifique : soutien, soins, contrôle), trois espèces (humain, robot, extraterrestre), trois raretés (commun, rare, épique). Chaque héros a un pouvoir spécial.
- **Escouade** : 5 emplacements (ligne de front, ligne arrière) ; synergies entre rôles et espèces.
- **Combat automatique** : lisible, sur un seul écran ; cibles choisies par rôle ; pouvoirs à déclencher à la main (recharge).
- **Chapitres** : secteurs de l'espace, vagues puis boss ; difficulté croissante.
- **Équipement** : emplacements arme, armure, module ; raretés avec bonus aléatoires.
- **Recrutement** : tirage avec taux affichés, sans achat en argent réel dans la première version.
- **Vaisseau** : salles qui donnent des bonus permanents et la production hors ligne.

## À faire plus tard (hors première version)
Guilde, classement, événements, achats intégrés, dérive et routes (modes déjà essayés dans l'ancienne version).

## Première version jouable (MVP)
Un chapitre complet : 1 écran de combat automatique, 5 héros jouables, un boss, butin, montée de niveau, gains hors ligne, sauvegarde. Un APK de test construit par la CI.

## Technique
- **Moteur** : Godot 4.3, GL Compatibility, orientation portrait 720×1280, Android arm64.
- **Rendu** : 2D animée entièrement vectorielle (aucune image) : héros, ennemis et décor sont dessinés par code (`scripts/art.gd`) et animés par paramètres (respiration, attaque, pouvoir, coup reçu, étourdissement).
- **Qualité** : tests de logique en ligne de commande, parcours en jeu par clics et construction d'APK en CI (déjà éprouvés dans l'ancienne version).

## Questions ouvertes
Rythme de progression, boutique et recrutement, équipement, chapitres suivants.

## État du prototype
Jouable : combat automatique de 5 héros (Mara Voss, Kaï Renn, Zyra, T-9, Oru) contre des vagues de la Ceinture d'astéroïdes, boss tous les 5 secteurs (Foreur Titan), pouvoirs manuels ou automatiques, vitesse x1 à x3, amélioration des héros, sauvegarde et gains hors ligne.
