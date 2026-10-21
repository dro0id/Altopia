# Altopia · Route (prototype Unity)

Version Unity de la scène 3D de la Route, **séparée du jeu Godot** : elle ne se branche pas sur le jeu, c'est un prototype visuel à ouvrir dans Unity.

- Unity **2022.3 LTS** (Hub → *Open* → ce dossier). Paquet installé automatiquement : *Post Processing* (bloom, vignette, aberration chromatique).
- Lancer n'importe quelle scène vide (ou en créer une) puis *Play* : `RouteDirector` se met en route tout seul et construit la caméra, les lumières, les étoiles, le convoi et les décors.
- Panneau à gauche : mode auto (enchaîne combat, récolte, épave, repos, embuscade, inconnu, gardien) ou boutons pour déclencher chaque étape.
- Modèles : `Assets/Resources/Models/*.fbx`, générés avec Blender par `tools/blender/build_assets.py --fbx unity/AltopiaRoute/Assets/Resources/Models`.
- `ModelLook` redonne aux FBX leurs matériaux d'origine (métal, rugosité, émission).

**Non testé** : ce projet a été écrit sans pouvoir lancer Unity (pas d'éditeur ici). Points à vérifier à l'ouverture :
1. Le sens des modèles : le nez des vaisseaux est remis vers +Z automatiquement ; si l'œil du boss regarde dans le mauvais sens, cocher *Flip Boss* sur l'objet « Route ».
2. Les couleurs et la brillance des matériaux (rendu *Built-in*, shader Standard) : à comparer avec `docs/comparaison_blender_vs_scene.png`.
3. Les erreurs de compilation éventuelles dans la console.
