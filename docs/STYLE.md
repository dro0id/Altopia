# Pistes de style — « réaliste mais dessin animé »

Le style actuel du jeu (personnages dessinés en code, très simples) est **provisoire** et ne plaît pas.
Trois directions ont été dessinées en maquette, avec les mêmes écrans (Capitaine + équipement RPG + équipage AFK,
combat + butin légendaire) pour pouvoir comparer.

| | A · Cartoon héroïque | B · Peinture sci-fi | C · 3D toon doux |
|---|---|---|---|
| Trait | gros contours, ombres franches | sans contour, dégradés doux, contre-jour froid | rond, grands yeux, reflets brillants |
| Interface | panneaux violets, bordures dorées, gros boutons | verre néon, typographie technique | bulles blanches, pastel |
| Atouts | très lisible, proche de Mini Legion, facile à animer | le plus réaliste et immersif | accessible, simple à passer en 3D |
| Limites | moins « réaliste » | lourd à produire et à animer | le plus enfantin |

Images : `docs/style/` — écrans Capitaine (`capitaine_X.png`), combat (`combat_X.png`) et personnages (`persos_X.png`).

## Important : la production finale
Les maquettes sont des illustrations vectorielles générées par du code ; elles servent à **choisir une direction**.
Pour un rendu final de qualité « jeu commercial », il faudra des **assets** (illustrateur, packs graphiques ou
génération d'images) livrés en PNG/sprites ; le jeu les affichera à la place des dessins en code.
L'habillage de l'interface (panneaux, boutons, polices, couleurs, effets de rareté) peut en revanche être réalisé
directement dans Godot, dans le style choisi.
