# Altopia · Route (prototype Unity)

Version Unity de la scène 3D de la Route, **séparée du jeu Godot** : un prototype visuel, il ne se branche pas sur le jeu.

## Lancer (dans l'éditeur)
1. Unity Hub → *Open* → ce dossier (Unity **2022.3 LTS**, rendu *Built-in*).
2. Ouvrir n'importe quelle scène (ou menu **Altopia → Créer la scène Route**), puis *Play*. `RouteDirector` s'installe seul : caméra, lumières, étoiles, convoi, décors.
3. Panneau à gauche : mode auto (enchaîne toutes les étapes) ou un bouton par type d'étape.

## Testeur intégré à l'éditeur
Menu **Altopia → Testeur Route** ouvre une fenêtre avec trois onglets :
- **Vitrine** : chaque modèle seul, éclairé comme dans Blender, à tourner à la souris (sans lancer le jeu), avec le sens de l'avant.
- **Scène** : lancer/arrêter Play, créer la scène, mode auto et un bouton par type d'étape.
- **Vérifications** : modèles, matériaux, orientation, shaders, avec le détail de chaque échec, et un raccourci vers le Test Runner.

## Tester
| Quoi | Où | Besoin |
|---|---|---|
| Les scripts compilent (jeu + fenêtre Editor) | `tools/unity_check.sh` (et job *compile* de la CI) | .NET, pas d'éditeur ni de licence |
| Modèles, matériaux, orientation, shaders | éditeur : *Window → General → Test Runner → EditMode* | éditeur Unity |
| Chaque étape joue sans erreur | *Test Runner → PlayMode* | éditeur Unity |
| Builds Android (APK) et WebGL + tests | job *unity* de la CI (`.github/workflows/unity.yml`) | secrets GitHub `UNITY_LICENSE`, `UNITY_EMAIL`, `UNITY_PASSWORD` (voir game.ci/docs/github/activation) |

Sans les secrets, la CI exécute seulement la compilation. Avec eux, elle lance les tests puis publie l'APK et le build WebGL en artefacts.
Build local : menu *Altopia* ou `Unity -batchmode -executeMethod BuildRoute.Android -quit`.

## Contenu
- `Assets/Resources/Models/*.fbx` : modèles Blender, générés par `tools/blender/build_assets.py --fbx unity/AltopiaRoute/Assets/Resources/Models`.
- `Assets/Scripts/ModelLook.cs` : redonne aux FBX leur métal, rugosité et émission d'origine, et tourne l'avant des modèles vers +Z grâce à un repère nommé (`cannon_tip`, `eye`).
- `Assets/Scripts/SimpleBloom.cs` + `Assets/Resources/Altopia*.shader` : bloom, vignette, aberration chromatique, matériau additif.
- `Assets/Scripts/RouteDirector.cs` : la scène (étapes, combats, récolte, repos…).

## Ce qui n'est pas vérifié
Écrit sans éditeur Unity : seule la **compilation des scripts** est vérifiée (jeu : DLL UnityEngine 2021.3 ; code Editor : UnityEditor 2020.2, sauf les API plus récentes comme `NamedBuildTarget`). Jamais exécutés : la fenêtre Testeur, les tests, les shaders (`.shader`), le rendu et les builds. Les premières erreurs viendront probablement de là ; renvoie-les-moi.
