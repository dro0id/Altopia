# Direction artistique — réaliste 2D/3D spatial

Décision : **pas de cartoon**. Deux pistes réalistes ont été maquettées (rendus three.js, même HUD de cockpit).

| | R1 · Réaliste sobre | R2 · Réaliste cinématique |
|---|---|---|
| Ambiance | Soleil chaud, acier blanc, orange sécurité | Contre-jour cyan/magenta, océans, atmosphère |
| Interface | Panneaux biseautés, typo technique | Verre teinté, néons fins |
| Coût mobile | Léger | Plus lourd (bloom à limiter) |

Maquettes : `docs/style/` (ui1/ui2 = écrans Capitaine et Combat, R1 et R2).

## Ce qui est faisable dans Godot
- Planètes, astéroïdes, étoiles, vaisseaux, lumière, bloom : oui (3D + shaders).
- Interface (panneaux, polices, cadres de rareté) : oui, via thème Godot.
- Personnages : nécessitent de vrais modèles 3D (glTF). Les formes simples restent « jouet ».

## Prochaine étape
Choisir R1, R2 ou un mélange, puis habiller le jeu (thème UI, rendu des destinations) et remplacer `chibi.gd` par des modèles.
