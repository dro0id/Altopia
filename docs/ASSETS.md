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
