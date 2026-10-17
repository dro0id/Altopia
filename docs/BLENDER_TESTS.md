# Tests Blender sur le pack Kenney (CC0)

Blender 5.2 (module Python `bpy`) a été utilisé en ligne de commande. Résultats :

| Test | Résultat |
|---|---|
| Import d'un astronaute Kenney | OK : 6 pièces séparées (tête, corps, 2 bras, 2 jambes), matières nommées |
| Modification de forme (silhouette du capitaine : épaulettes dorées, crête de casque, cape, sac dorsal lumineux) | OK |
| Animation par pièces (Idle, Walk, Shoot) | OK : 3 clips, tous les canaux exportés |
| Export glTF | OK : lisible dans three.js et dans Godot 4.3 (1 AnimationPlayer, 3 animations, 12 maillages) |
| Recoloration en lot R2 des 153 modèles du pack | OK : 153/153 exportés, 2,4 Mo |
| Rendu des modèles réexportés | OK (`docs/style/blender_r2_scene.png`) |

## Fichiers
- `tools/blender/captain.py` : crée le capitaine animé (`assets/altopack_r2/captain_anime.glb`), `captain.blend` en est la source.
- `tools/blender/batch_r2.py` : recolore tout le pack en palette R2.
- `assets/altopack_r2/` : modèles recolorés (ignorés par Godot grâce à `.gdignore` jusqu'à adoption).

## Reproduire
```
pip install bpy
KENNEY_GLB="<dossier GLTF format>" OUT=assets/altopack_r2/ python tools/blender/batch_r2.py
```

## Pièges rencontrés
- Un script nommé `inspect.py` masque le module standard et fait planter `bpy`.
- Sous Blender 5, un clip NLA vide en première piste fait disparaître le canal de l'objet à l'export : ne créer que des pistes non vides.
- L'avant d'un modèle glTF est +Y dans Blender.
- Le capitaine animé garde les couleurs d'origine du pack (construit avant la recoloration) : à repasser dans `batch_r2.py`.

## Altopack R2 : capitaine
Script : `tools/blender/altopack_captain.py` (source : `altopack_captain.blend`, export : `assets/altopack_r2/captain.glb`). Aperçu : `docs/style/altopack_captain.png`.
Méthode : soudure des sommets puis subdivision des pièces Kenney (look gonflé), casque sphérique + visière, sac dorsal arrondi avec antenne, bottes et gants ronds. Animations Walk, Idle et Shoot conservées.
Pièges : les sommets non soudés de Kenney donnent des bulles à la subdivision (souder d'abord) ; le nœud racine du pack est décalé (2, -1.5) : le remettre à zéro avant l'export.
Version finale : casque réduit (rayon 0,185 au lieu de 0,24), matières en palette R2 directement dans le script. Aperçu : `docs/style/altopack_captain_r2.png`.
Limites : mouvements rigides (sans squelette), blanc du costume un peu lavé.

## Équipage et ennemi (boucle de jeu)
- `tools/blender/altopack_crew.py` (variable `VARIANT` = pilot, engineer, scientist, captain) : base Altopack R2, couleur de costume, visière et accessoires propres à chaque classe (Pilote : ailerons, oreillettes, bande frontale ; Ingénieur : casque de chantier, ceinture, réservoirs ; Scientifique : antennes, parabole, écran, bocal).
- `tools/blender/altopack_enemy.py` : golem (alien Kenney arrondi, matières rouge et magenta).
- `tools/render_portraits.gd` : génère `assets/portraits/*.png` (9 équipiers, capitaine, 3 ennemis) depuis les modèles ; `scripts/chibi.gd` les affiche (cartes d'équipage, postes, combat) et retombe sur l'ancien dessin si un portrait manque.
