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

### Branche 1b · la profondeur (FAIT dans le code, à tester sur téléphone)
Choix d'un renfort parmi trois (actif jusqu'au prochain boss, cinq renforts : tir accéléré, bouclier de départ, pouvoirs rapides, vitalité, butin doré), paliers d'évolution (un héros doit évoluer au niveau 10 puis 20 : crédits et éclats de verre, pouvoir ×1,4 puis ×1,8, statistiques +10 % puis +20 %), bonus de persévérance (+5 % par défaite jusqu'à +30 %, remis à zéro à la victoire), combos (deux pouvoirs à moins de 3 s : +10 % par pouvoir jusqu'à +50 % de puissance, et jusqu'à +25 % de crédits dans le coffre). Terminé ensuite : ouverture de coffre propre à chaque rareté (suspense de 1 à 2,6 s, ondes, éclats, flammes, éclairs et flash pour l'ultime), et trois gros boss qui tournent tous les 10 étages (Gardien de verre, Sentinelle prismatique avec faisceaux, Reine des mites avec renforts).

- **Raretés de coffre** : commun (chaque étage vaincu), normal (étage en 3 étoiles), rare (mini-boss), épique / légendaire / ultime sur les gros boss : épique 10 % en 1 ou 2 étoiles et 20 % en 3 étoiles ; légendaire 3 % (garanti au 2e gros boss en 3 étoiles sans légendaire) ; ultime 0,5 % (garanti au 10e sans ultime).
- **Ressources** : crédits (améliorations) et éclats de verre (paliers d'évolution, plus tard).
- **Maquette** : 14 écrans (voir le canvas).
- **À valider** : ton du texte d'entrée, noms des boss, chiffres d'économie après test sur téléphone.

## Branche 2 · `feat/histoire-capitaine` (M) : le signal et le Capitaine (FAIT dans le code, à tester sur téléphone ; chapitres renumérotés 2 à 5 depuis le chapitre 1 à bord, voir branche 5)
- **Objectif** : l'histoire space opera est portée par le jeu, pas par un texte à part.
- **Contenu** : introduction courte (Terre, signal, décollage), dialogues entre combats (Capitaine, Vance, héros), un héros ou un ennemi marquant par chapitre, fin du chapitre 1 qui ouvre le suivant.
- **Livrable** : le chapitre 1 se joue avec son histoire de bout en bout.
- **Décidé** : ton sérieux avec touches d'humour, 2 à 4 répliques par scène, Capitaine silencieux avec choix de réponse (sans conséquence sur la suite). Un chapitre = un secteur = 10 étages (maquettes GA à GF). Chapitre 1 « Le signal » = étages 1 à 10 : prologue en 3 écrans, 5 scènes, Gardien de verre qui parle, fin de chapitre (1 000 crédits, 10 éclats, 6 jetons). Chapitre 2 « Les Échos » = étages 11 à 20 : 7 scènes (voix humaines, épave de l'Aube, commandant Holt, la Sentinelle « le Phare » qui parle), fin (2 000 crédits, 20 éclats, 6 jetons). Chapitre 3 « Le Retour » = étages 21 à 30 : 7 scènes (le signal remonte, les dormeurs, la voix du père de Vance, la Reine des mites qui parle), 3 000 crédits, 30 éclats, 6 jetons. Chapitre 4 « Le dernier seuil » = étages 31 à 40 : 7 scènes (la voix de Holt, pris dans le verre, le Gardien du dernier seuil doré qui parle), fin de l'histoire (5 000 crédits, 50 éclats, 10 jetons, badge « Héros de la Ceinture ») qui ouvre la Ceinture sans fin : secteurs générés à partir de l'étage 41, la boucle AFK (maquettes HA à HH). Les parties déjà plus loin reçoivent les scènes dépassées dans le journal, sans rafale. Journal de bord (menu ⋮ de la carte). Script dans `scripts/story.gd`, maquettes CA à CI et GA à GF.

## Branche 3 · `feat/heros-collection` (L) : recruter et faire évoluer (FAIT dans le code, à tester sur téléphone)
- **Objectif** : la collection est le moteur de rétention, comme dans Top Heroes.
- **Collection** : 15 héros (5 communs, 6 rares, 4 épiques ; trois espèces : humain, robot, extraterrestre ; quatre rôles : rempart, dégâts, soutien, contrôle). Les cinq héros d'origine sont conservés et forment l'escouade de départ.
- **Monnaies (décidé)** : les **crédits** (niveaux), les **éclats de verre** (paliers d'évolution), les **jetons de recrutement** (gagnés en jeu : coffres, coffre gratuit ; 6 jetons offerts au départ) et les **cristaux d'Altopia** (monnaie de la boutique, gagnés sur les gros boss ; **l'achat de cristaux contre de l'argent réel viendra avec la publication**, branche 10, et n'est pas branché : le bouton affiche « bientôt »).
- **Jetons de recrutement (réduits)** : un étage réussi ne donne plus de jeton ; coffres rare 2, épique 3, légendaire 5, ultime 10 ; fins de chapitre 3, 3, 4, 4, 6 ; 6 au départ. Environ 15 tirages avant l'étage 40 (35 avant la réduction).
- **Recrutement** : 3 jetons le tirage, 27 jetons les dix. Taux affichés : commun 70 %, rare 25 %, épique 5 %. Garanties : rare ou mieux au plus tard au 10e tirage, épique au plus tard au 30e.
- **Doublons et étoiles (refonte)** : une seule progression. Chaque étoile débloque 10 niveaux (1★ = 1 à 10, 2★ = 11 à 20, jusqu'à 5★ = 41 à 50). Il faut des doublons du héros : 5 pour 2★, 10 pour 3★, 20 pour 4★, 40 pour 5★, puis 100 pour « 5★ max » (bonus de statistiques, limite de niveau inchangée). Un tirage qui tombe sur un héros déjà possédé donne 5 doublons. Des **doublons au choix** (à répartir sur n'importe quel héros) viennent des fins de chapitre (10, 15, 20, 30 puis 40), des gros boss (3 à 5), des expéditions (3, trouvaille rare) et de la boutique (10 pour 12 cristaux). Chaque étoile ajoute 12 % de statistiques ; 2★ et 3★ renforcent aussi le pouvoir. Les paliers payés en crédits et éclats n'existent plus ; dans les anciennes sauvegardes les niveaux sont conservés mais bloqués tant que les étoiles manquent.
- **Formation** : cinq emplacements. Les emplacements 1 à 3 forment la première ligne (le 1 est la cible principale des ennemis), les emplacements 4 et 5 la deuxième ligne.
- **Synergies** : par espèce (deux, trois, quatre héros ou plus de la même espèce : +6 %, +12 %, +20 % d'attaque pour les humains, de défense pour les robots, de PV pour les extraterrestres), et par rôle (rempart + soutien : +10 % PV ; deux héros de dégâts : +8 % attaque ; un contrôle : +10 % de puissance des pouvoirs).
- **Boutique (décidé)** : cinq offres payées en cristaux (jetons, coffres rares et épiques, coffre gratuit immédiat).
- **Interface** : barre « Héros / Recruter / Boutique » sous les pouvoirs ; écrans Collection, fiche de héros, Recrutement, Boutique.
- **À valider** : noms et apparences des 10 nouveaux héros, prix de la boutique, taux, vitesse de gain des jetons.

## Branche 4 · `feat/equipement` (M) : butin et build
- **Contenu** : 4 emplacements par héros, raretés et bonus aléatoires, fusion et recyclage, inventaire, comparaison avant équipement.
- **Livrable** : un objet change réellement l'issue d'un combat.
- **À valider** : emplacements, profondeur des bonus, objets liés à un héros ou communs.

## Branche 5 · `feat/vaisseau-base` (L) : l'Aurore, le hub (FAIT dans le code, à tester sur téléphone)
- **Décidé** : onglet Vaisseau au centre de la barre du bas, coupe 3D (maquettes PA à QC). Niveau max 20, un design par tranche (1–5, 6–10, 11–15, 16–19) et un design unique au niveau 20 (Aurore Éternelle). 10 salles : Pont, Centrale, Raffinerie, Atelier, Antenne, Labo, Quartiers, Hangar (navettes et expéditions), Serre, Observatoire.
- **Règles** : améliorations en temps réel, accélérables contre des cristaux (achat en argent réel à la publication) ; seuls les héros hors escouade occupent les postes ; le Pont monte avec l'étage atteint et a son propre chantier.
- **Rythme** : niveau 10 à la fin des 40 étages de l'histoire (chantiers courts) ; niveaux 11 à 20 dans les secteurs générés (étage 45 à 130, chantiers de 30 min à 12 h). Vérifié par `tools/progress.gd` et les tests.
- **Le vaisseau d'abord (maquettes RA à RG)** : la boucle AFK est la mission de l'Aurore. Dès l'étage 5 (après « Bienvenue à bord »), le jeu s'ouvre sur l'Aurore ; la barre du bas devient Aurore · Mission · Héros · Recruter · Boutique. L'accueil montre la mission en cours (qui continue au rythme du farm automatique pendant qu'on est à bord) et le chantier conseillé ; le Pont choisit la destination (étage, autre étage, Ceinture sans fin) ; la mission affiche l'apport de l'Aurore ; le retour hors ligne commence par ce qui s'est passé à bord. Plus tard, la Base entoure le tout.
- **Chapitre 1 « Cap sur Altopia » (maquettes SA à SH)** : le vaisseau est le hub dès la première minute. Après le prologue, « Bienvenue à bord », puis le voyage Terre → Ceinture (42 jours) en 6 objectifs de bord (récolte, première recrue garantie nouvelle, poste, Pont 2, Raffinerie 2, le signal) et 6 scènes, sans combat ; la Mission est verrouillée jusqu'à l'arrivée. Chantiers du voyage payés en crédits par l'Amirauté. Les chapitres de combat deviennent 2 à 5 (étages 1 à 40 inchangés) ; les anciennes sauvegardes sont décalées et ont le voyage marqué fait.
- **Histoire rendue cohérente** : Vance (commandant en second) est à bord dès le départ, au poste du Pont, hors escouade ; récompenses des chapitres 2 à 5 indexées sur le butin du dernier étage (1 700, 5 700, 19 000, 65 000 crédits) ; le titre « Héros de la Ceinture » s'affiche sous l'Aurore ; la carte nomme les secteurs de l'histoire par leur chapitre (Ch. 2 à Ch. 5) ; « Bienvenue à bord » parle du voyage ; Mara annonce l'Aurore II à la fin du chapitre 3 ; l'épilogue ouvre sur la future Base.
- **Salles à construire** : seules le Pont, la Centrale et la Raffinerie existent au départ. Une salle qui s'ouvre (Atelier niveau 3, Serre 5, Quartiers 8, Antenne, Labo et Hangar 11, Observatoire 14) est « à construire » : pastille « Construire » sur l'Aurore, fiche avec le coût (celui d'une amélioration au niveau d'ouverture) et le bouton Construire, chantier comme les autres. Petit tutoriel à la première salle qui s'ouvre (étape 12 du coach).
- **Ennemis refaits (maquettes TA à TL)** : des créatures de verre facettées (`scripts/enemy_art.gd`), un dessin par ennemi (mite de verre, drone, canonnier, Foreur éclaté, Gardien de verre, Sentinelle prismatique, Reine des mites, Gardien du dernier seuil en or). Teinte par chapitre (cyan, violet, ambre, or) ou par secteur généré, phase 2 visible (fissures, cœur rouge), anneau doré sous les élites ; scènes d'histoire avec les mêmes dessins. Les PV, attaques et le rythme ne changent pas.
- **Boutons de verre facetté (maquettes UA à UJ)** : un seul style (`scripts/glass_box.gd`) pour boutons, puces, segments et plaque de la barre du bas : angles coupés, dégradé, reflet, ombre, lueur pour les actions. Rôles par couleur : action (cyan), récolte (vert), premium (or), secondaire, danger, alerte. Compétences et boutons de combat en hexagone avec anneau de recharge ; jauge dorée dans « Accélérer ». Les écrans gardent leur logique, seul le rôle change.
- **Design, lot 1 « fondations » (maquettes D0 à D9, G1, I1, I7)** : sur écran haut (20:9), la boutique défile jusqu'à la barre du bas et le contenu de la défaite, de la fin de chapitre, du nouveau secteur et du verrou de mission descend dans l'espace libre (`UI.tall`) ; échelle de texte à six crans (`M3.step`) ; palette nommée dans `UI` (surfaces, actions, raretés). Défauts corrigés : pastilles de salles qui se recouvraient, barre de boss à 0 % avant son arrivée, réponses de dialogue collées au bord, onglets du Labo, « Monter à ★★ » actif sans doublons, bouton « Lancer » du Hangar, bouton principal du recrutement. Vocabulaire unique (« secteur » pour un combat, « zone » pour dix secteurs générés, on « descend »), une seule écriture des nombres (`UI.num` : 4 600, 57,5 k, 1,2 M) et des durées sans unité à zéro, noms d’objets sur trois lignes, texte de la jauge dorée cerné. Cartes et lignes en verre dépoli à angles coupés (`M3.glass_card`, maquette G2) ; fiche de héros : le héros en pied sous la barre du haut sur écran haut (maquette XF). Reste : victoire et recrutement sur écran haut, texte « Très grand » ; les écrans n'utilisent pas encore la palette nommée.
- **Design, lot 2 « matière et repères » (maquettes G2, G4, E3)** : feuilles du bas et boîtes de dialogue en verre à angles coupés (`M3.sheet`, `M3.dialog`) ; cadre de portrait selon la rareté (rond : normal, angles coupés : rare, hexagone : épique, `M3.frame_pts`) ; le bouton d'amélioration d'une salle porte son prix, ou dit ce qui manque (« Il manque 12 éclats »). Barre du haut unique (I3, `Wallet`) : crédits, éclats, cristaux dans le même ordre sur l'Aurore, le Recrutement et la Boutique, la monnaie de l'écran cerclée d'or (jetons ajoutés au Recrutement, crédits masqués si la place manque). Barre du bas (I4) : pastille rouge chiffrée pour ce qui est à réclamer (salles prêtes, navettes rentrées, coffre gratuit), point vert pour une action possible (héros à monter, chantier, tirage payable, offre du jour). Les boutons portent leur prix (`M3.price` : améliorer une salle, chantier conseillé, construire), ce qui manque en rouge. Toucher une monnaie l'explique ; le « + » ouvre le tiroir des six ressources (jetons, jetons d'objet, doublons au choix compris). Non fait : l'appui maintenu pour les dépenses en cristaux.
- **Design, lot 3 « l'aisance » (maquettes E2, E4, E5, I5, I6, I8)** : glisser depuis le bord gauche ferme la fenêtre (une salle d'abord, puis l'écran) comme le Retour d'Android ; trois vibrations (appui court, récompense double, alerte longue) ; les compteurs du porte-monnaie défilent jusqu'à la nouvelle valeur et la récolte vole vers sa pastille (`Wallet.fly`) ; mémo « ? » de trois lignes sur Héros, Recruter, Boutique, Secteurs et l'Aurore, doré tant qu'il n'est pas lu (`Help`) ; liste des secteurs sans « Non vaincu » répété, repère cyan pour le prochain, vert pour les vaincus ; messages brefs en haut (`M3.toast` : objet équipé, retiré, recyclé) ; salle pas construite = une seule carte « S'ouvre au niveau N » ; inventaire vide dessiné. Non fait : raccourcis contextuels (E1), boutons Retour et « Rejoindre » descendus sous le pouce, réglage Gaucher, annulation de 4 s, bulles de première visite automatiques.
- **Reporté** : la Base sur une planète. Plus tard : cadre doré des portraits au niveau 20.

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
