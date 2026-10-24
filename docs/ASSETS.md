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
- Visages humains (`tools/blender/faces_q.py`) : 14 visages paramétriques uniques (tête, yeux, sourcils, cils, nez, bouche, barbe en mèches, moustache, coiffures avec mèches). Os de visage ajoutés au squelette : `Jaw`, `Blink.L/R`, `Brow.L/R`, `HairB` (queue, tresse, mèches arrière).
- Animations (`tools/blender/anims_q.py`) : 17 clips humains (Idle avec respiration et clignements, Look, Walk, Run, Shoot, Talk, Wave, Nod, Shake, Think, Point, Work, Salute, Cheer, Surprise, Laugh, Hit). Chaque modèle embarque Idle / Walk / Shoot ; la bibliothèque complète est `assets/animations/human_anims.glb` (`python tools/blender/export_anim_lib.py`), à appliquer avec `CharAnims.attach(personnage)` (`scripts/char_anims.gd`).
- Squelette anatomique (99 os) : aux 49 os de base s'ajoutent torsions (bras, avant-bras, cuisses, tibias), omoplates, cage thoracique, ventre, fessiers, orteils ; et pour les humains paupières haute et basse, joues, coins de bouche, lèvre haute, nez, oreilles, sourcils en deux moitiés, chaînes de cheveux (arrière et côtés) et de barbe. Les pièces rigides (anneaux, genouillères) reprennent les poids de la combinaison.
- Poids : `tools/blender/glb_slim.py` (appelé par l'export) passe les poids de peau et les normales en octets normalisés (~-35 % sans perte visible). Maillages allégés (~12 à 15 000 triangles par personnage).
- Export Godot : `python tools/blender/export_characters.py` -> `assets/base/captain.glb` (matières `suit_steel` et `accent_cyan`, nœuds `antenna`, `antenna_tip`, `pack_panel`, clips Walk, Shoot, Idle) et `assets/models/char_<id>.glb` pour les autres.
- Portraits 2D : `python tools/blender/hub_scenes.py <dossier> pg_<id>` (256 x 256, fond transparent) puis copie dans `assets/portraits/`. `chibi.gd` les affiche à la place du dessin en code.
- Les anciens modèles Kenney de l'équipage (`assets/base/crew_*.glb`) sont retirés.

## Équipiers en 3D dans le jeu

- `scripts/crew_view.gd` : fiche 3D d'un équipier (modèle `assets/models/char_<id>.glb` + bibliothèque d'animations, rotation au doigt). Ouverte par « Voir en 3D » sur chaque carte d'équipage, au recrutement d'une nouvelle carte, et dans l'écran de résultat du combat en direct (Victoire / Coup reçu).
- `tools/crew_shot.gd` : capture d'une fiche (`xvfb-run -a godot --path . --resolution 720x1280 -s tools/crew_shot.gd -- <id> <clip> <png>`).
- Poids mesuré : 12 000 à 17 500 triangles, environ 30 surfaces par personnage (maillages de même matière fusionnés à l'export : `merge_by_material` dans `tools/blender/export_characters.py`, 80 surfaces avant), 65 à 101 os ; un seul personnage est affiché à la fois. Non mesuré sur téléphone.
- Briefing : avant la première expédition d'une destination (par session), un équipier du groupe parle, puis « Décoller ! » lance le combat (`_open_briefing` dans `main.gd`, capture : `tools/briefing_shot.gd`).
- Test en jeu : `xvfb-run -a godot --path . --resolution 720x1280 -s tools/ingame_test.gd -- <dossier>` pilote la vraie scène par de vrais clics (onglets, fiche 3D, 17 gestes, recrutement, briefing, combat, résultat) et enregistre des captures.
- Simulation d'écran Xiaomi 11T (1080x2400, 20:9) : `xvfb-run -a -s "-screen 0 1080x2400x24" godot --path . --resolution 1080x2400 -s tools/ingame_test.gd -- <dossier>`. Coût CPU des animations : `godot --headless --path . -s tools/anim_bench.gd`.
- Test réel sur émulateur : le job `emulator` de la CI (Android 14, 1080x2400) installe l'APK de test x86_64 et déroule scripts/autotest.gd ; le rapport, les captures, gfxinfo et logcat sont dans l'artefact `emulator-report` (tools/emulator_test.sh).
