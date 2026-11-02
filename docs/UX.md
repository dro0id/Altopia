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
