# UI/UX — audit et propositions (branches 1 et 3)

Maquettes : canvas Design, rangée « Propositions UI/UX » (planches A à J). Rien n'est codé : en attente de validation.

## Audit (écran principal, Collection, Recrutement, Boutique)
1. Barre du haut surchargée (étage, crédits, Auto, vitesse, Carte, réglages) : cibles petites.
2. Bannière de statut posée sur le terrain, elle masque les ennemis.
3. Compétences au milieu de l'écran, loin du pouce.
4. Onglets Héros / Recruter / Boutique mélangés à la liste : on perd le contexte du combat.
5. Lignes de héros trop denses (3 lignes de texte, PV/ATQ/DÉF, bouton sur 3 lignes).
6. Polices 15–18 px à 720 de large, soit ≈ 8 dp : sous le minimum lisible (12 dp).
7. Collection, Recrutement, Boutique : listes textuelles, hiérarchie plate, peu de feedback.

## Propositions
- **Charte (B)** : fond #0b1226, carte #141d3a, action #4fd8ff, or #ffd166, succès #7dffb0 ; raretés en cadre + lueur (commun gris, normal vert, rare bleu, épique violet, légendaire orange, ultime rouge) ; typo 20/16/14/12 dp ; boutons ≥ 48 dp, un seul principal par écran ; monnaies icône + valeur ; grille 8 dp.
- **Combat (C)** : barre de navigation basse (Combat, Héros, Recruter, Boutique) avec pastilles ; HUD haut réduit à deux jauges de monnaie, réglages ; étage et combo en pastille centrale ; Auto/vitesse en colonne à droite ; compétences rondes avec anneau de recharge au bas du terrain ; escouade en 5 cartes compactes ; un seul bouton « meilleur achat ».
- **Carte (D)** : chemin vertical en tour, nœuds mini-boss/boss plus gros, étoiles, bouton « Monter » collé en bas, prochain mini-boss et coffre gratuit en résumé.
- **Coffre/Résultat (E)** : coffre plein écran « touche pour ouvrir », gains en pastilles après ouverture, un bouton principal.
- **Collection (F)** : tableau de formation 3 avant + 2 arrière en haut (glisser pour échanger), synergies en pastilles, filtres, grille de cartes à cadre de rareté.
- **Fiche héros (G)** : portrait, étoiles, barres de stats, compétence, jauge de fragments, actions en bas.
- **Recrutement (H)** : orbe central, deux barres de garantie, ×1 / ×10, historique des derniers appels, taux en lien.
- **Boutique (I)** : onglets, offre du jour, cartes d'offres, cristaux « bientôt ».
- **Navigation (J)** : barre basse partout sauf plein écran, retour en haut à gauche, actions dans le tiers bas, pastilles de notification, marges de sécurité, contraste ≥ 4,5:1, retour haptique.

## Mise en œuvre
Tout l'écran du jeu suit maintenant les planches de la maquette (coordonnées de la maquette × 2, palette de la charte B). Écrans faits : combat et combat de boss (C, L), navigation du bas (J), carte en tour (D), coffre de fin d'étage (E), collection et formation (F), fiche héros (G), recrutement (H), boutique (I), renfort (M), palier d'évolution (N), défaite (O), réglages (P), retour hors ligne (Q), états et retours (R : vibration, boutons grisés, notification).

Mécaniques ajoutées pour que ces écrans soient vrais : offre du jour (pack légendaire à 20 cristaux, une fois par jour), boost ×2 de crédits pendant 1 h, héros en vedette de la bannière (une chance sur deux quand un héros épique est tiré), historique des 5 derniers tirages, jauge de persévérance, éclats gagnés hors ligne, réglages de volume, vibrations, chiffres de dégâts, économie de batterie, réduction des secousses.

Écarts connus avec la planche, par nécessité de gameplay (à valider) :
- la carte s'ouvre en touchant l'étage (ou la barre du boss) car la planche C n'a pas de bouton Carte ;
- Auto et vitesse restent affichés pendant les combats de boss ;
- sur un boss, la barre d'achat reste visible sous le conseil ;
- les portraits sont ronds sur fond sombre (la planche les montre sur un carré gris, artefact d'export) ;
- les raretés de héros sont celles du jeu (Normal, Rare, Épique) et non les six couleurs de la collection ;
- le texte des conseils et des renforts vient des vraies données du jeu.

### Branche 4 : équipement (planches S à AC)
Quatre emplacements par héros (arme, armure, module, relique), débloqués aux niveaux 1, 5, 10 et 15 du héros. Les objets ont six raretés, de 0 à 3 bonus secondaires, un niveau (plafonné par celui de son héros) et, à partir de rare, un ensemble (Prisme, Bastion, Sillage) avec des bonus à 2 et 4 pièces. Un objet équipé est lié au héros : le premier changement est gratuit, les suivants coûtent 400 crédits. Chaque coffre donne un objet (chances selon la rareté du coffre, un légendaire garanti au plus tard au 3e gros boss). La puissance d'un objet est un seul chiffre ; l'écran « À qui l'équiper ? » classe les héros par gain. L'inventaire contient 60 objets (les communs peuvent être recyclés automatiquement) ; la forge fusionne trois objets en un de rareté supérieure ou les recycle. L'équipement compte dans la puissance de l'escouade et dans le combat (attaque, PV, défense, critique, vitesse, soins, recharge, dégâts aux boss).

## Boosters d'objets (branche 4, ajout)

- Recrutement : onglet **Objets** (maquettes AD, AE, AF). Monnaie : jetons d'objet (4 offerts au départ).
- Coût : 2 jetons l'ouverture, 18 pour ×10 (une offerte). Sources : 1 jeton par gros boss, offre du jour (+2), boutique (×6 pour 8 ◆).
- Taux : normal 50 %, rare 32 %, épique 15 %, légendaire 3 %. ×10 : au moins un objet rare. Garanties : épique à la 10e, légendaire à la 40e ouverture.
- Le niveau de puissance suit le meilleur étage ; si l'inventaire est plein, le surplus part en réserve.
- Écart assumé avec la maquette AE : les tuiles n'affichent pas « Nv 12 » (les objets neufs sont de niveau 1, la puissance vient de l'étage).

## Refonte Android

Maquettes BA à BZ (canvas, rangées « Refonte Android »), toutes codées :
- Socle : bouton Retour (fermer la fenêtre, « Quitter Altopia ? » sur le combat), zones sûres, barre du bas 80 dp à pastille, boutons pilule, zones d'appui de 48 dp, kit `M3` (barre du haut, segments, puces, cartes, lignes, menu ⋮, feuilles du bas).
- Écrans : combat (portraits = pouvoirs, Auto, pouvoirs prêts, vitesse), Héros / Objets / Ensembles (formation dans le menu ⋮), fiche héros (Stats / Équipement / Pouvoirs), recrutement héros et objets, résultat d'ouverture, boutique, carte des étages, réglages, coffre et victoire, défaite, renfort, évolution, hors ligne, intro, tutoriel, détail d'objet, choix d'objet, « À qui l'équiper ? », forge.
- Taille du texte (Normal, Grand, Très grand) dans Réglages ; les textes trop longs se réduisent au lieu d'être coupés.
- Non fait : économie de batterie automatique sous 20 % (Godot 4.3 ne donne pas le niveau de batterie sans module Android).
- Écarts assumés : l'amélioration rapide d'un héros n'est plus sur l'écran de combat (elle se fait dans Héros, la pastille du bas l'indique) ; la forge et la formation passent par le menu ⋮ ; le coffre gratuit est dans la Boutique.
