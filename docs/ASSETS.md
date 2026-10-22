# Assets 3D réalistes — sources et licences

Script de téléchargement : `tools/fetch_assets.sh` (dossier `assets_src/`, non versionné).
Aperçu : `docs/style/assets_reels.png` (4 scènes, ambiances R1 à gauche et R2 à droite).

| Source | Contenu | Licence | État |
|---|---|---|---|
| NASA 3D Resources | Rover Perseverance, module lunaire Apollo, sonde Dawn, astéroïde Bennu, combinaison ACES | Domaine public | Téléchargé |
| Solar System Scope | Textures 2K Terre, nuages, Mars, Lune, Jupiter, Saturne, Vénus, Soleil | CC BY 4.0 : citer l'auteur dans le jeu | Téléchargé |
| Poly Haven | Rochers lunaires (moon_rock_01/03/05) | CC0 | Téléchargé |
| Kenney Space Kit | Vaisseaux low-poly | CC0 | Essayé, trop cartoon |
| Sketchfab | Astronautes et vaisseaux réalistes | CC BY | Téléchargement impossible sans compte |

## Points techniques
- Les .glb de la NASA sont compressés en Draco : à décompresser avant import dans Godot 4.3.
- Poly Haven fournit 4 niveaux de détail par rocher dans le même fichier : n'en garder qu'un.
- La combinaison NASA n'a pas de textures, Bennu n'est qu'une boule : à ne pas utiliser tels quels.
- Le rover est lourd (68 maillages) : à alléger pour mobile.

## Astronautes Sketchfab à télécharger (compte gratuit, format glTF)
- https://sketchfab.com/3d-models/none-e2c4b146e58141e4b87917456a9970b1 (Animated Floating Astronaut, LasquetiSpice)
- https://sketchfab.com/3d-models/none-4221cf7fea944ae6852d752514b5b4bb (Lunar Space Astronaut, Ali Raza)
- https://sketchfab.com/3d-models/none-de876bfdce1c47a4aa67670faee7208e (Sci-Fi Soldier, ART_LOLL)

## Proposition R2 avec le pack Kenney
Aperçu : `docs/style/kenney_r2.png` (scène three.js : `docs/style/kenney_r2_scene.html`).
La licence CC0 permet de modifier le pack. La retouche remplace les matières par nom (metal, metalDark, dark, metalRed, skin, crystal, rock) : acier nuit, accents cyan émissifs, visière teintée, cristaux magenta. Les formes ne changent pas.

## R2 avec le pack Kenney complet, version spatiale
Aperçu : `docs/style/kenney_full_r2.png` (scène : `docs/style/kenney_full_r2_scene.html`).
4 scènes : base lunaire, station orbitale, exploration, combat spatial. Une trentaine de modèles du pack (hangars, fusée, tourelles, antennes, couloirs, rover, vaisseaux, rochers, cristaux) en palette R2, avec de vraies textures de planètes en fond.

## Altopack R2
Nom du pack de personnages et d'engins retouchés du projet (base Kenney CC0, palette R2) : `assets/altopack_r2/` (modèles), `tools/blender/altopack_*.py` (scripts), `docs/style/altopack_*.png` (aperçus).
Personnages : le Capitaine (acier clair, accents cyan), le Pilote (bleu, visière ambrée, ailerons), l'Ingénieur (orange, casque de chantier, ceinture, réservoirs) et le Scientifique (blanc et vert, antennes, parabole, bocal) ; ennemi : le golem.

## Modèles de la Route (Blender)
Générés par script avec Blender (bpy) : `tools/blender/build_assets.py` (utilitaires dans `lib.py`). Sorties : `assets/models/*.glb` (jeu Godot) et, avec `--fbx <dossier>`, des FBX pour le prototype Unity.
Modèles : `player` (vaisseau du convoi), `enemy` et `elite` (chasseurs), `boss` (gardien), `asteroid1` à `asteroid3`, `station`, `wreck`. Le nez pointe vers +Y dans Blender (-Z dans Godot et three.js). Comparaison avec les rendus Blender : `docs/comparaison_blender_vs_scene.png`.
Régénérer : `python tools/blender/build_assets.py` (paquet `bpy` 5.2), puis ouvrir Godot pour réimporter.


## Astronautes low poly (Blender, de zéro)
Direction artistique : astronautes low poly facettés (polygones plats, peu de segments), combinaison segmentée, casque à visière claire qui laisse voir le visage, sac de survie à tuyaux, panneau de commandes, genouillères, ceinture et manchettes colorées.
- Générateur : `tools/blender/characters.py` (12 personnages : le Capitaine, les 9 héros rex, nova, zara, bolt, tess, gorn, lumi, quark, elara, plus Vance et Nox). Chacun a sa silhouette (taille, corpulence), ses couleurs, sa coiffure, sa barbe, son couvre-chef et ses accessoires ; les épiques ont un équipement en plus.
- Version actuelle (`tools/blender/characters_q.py`) : corps, visages et squelette Humanoid (49 os) des packs Quaternius (CC0, aucune attribution requise, sources dans `art_src/quaternius/`), habillés sur mesure (combinaison gonflée, casque, sac, panneau, anneaux, accessoires par héros). Androïdes : `nox` et `droid` (tête métal, yeux lumineux). `characters.py` reste l'ancienne version boîtes.
- Export Godot : `python tools/blender/export_characters.py` -> `assets/base/captain.glb` (matières `suit_steel` et `accent_cyan`, nœuds `antenna`, `antenna_tip`, `pack_panel`, clips Walk, Shoot, Idle) et `assets/models/char_<id>.glb` pour les autres.
- Portraits 2D : `python tools/blender/hub_scenes.py <dossier> pg_<id>` (256 x 256, fond transparent) puis copie dans `assets/portraits/`. `chibi.gd` les affiche à la place du dessin en code.
- Les anciens modèles Kenney de l'équipage (`assets/base/crew_*.glb`) sont retirés.
