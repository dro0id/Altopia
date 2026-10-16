# Démarrer (zéro expérience)

1. Téléchargez **Godot 4.3 ou plus** (version standard, pas .NET) : https://godotengine.org/download
   Aucune installation : on dézippe et on lance.
2. Récupérez le projet : `git clone https://github.com/dro0id/altopia` puis `git checkout ccr-41c9e96e-8i6hq4`
   (ou téléchargez le ZIP depuis GitHub).
3. Dans Godot : **Importer** → choisissez `project.godot` → **Importer et éditer**.
4. Appuyez sur **F5** : le prototype se lance (fenêtre portrait).
5. Pour tester sur Android plus tard : *Projet → Installer le modèle d'export Android*
   (nécessite le SDK Android ; on le fera à l'étape 6, pas besoin maintenant).

## Où est quoi
- `scripts/game_state.gd` : cerveau du jeu (ressources, équipage, hors-ligne, sauvegarde).
- `scripts/main.gd` : interface (construite en code, aucun réglage à faire dans l'éditeur).
- `scenes/main.tscn` : scène principale, quasi vide.

## Premiers essais pour apprendre
Dans `game_state.gd`, changez `base_rate` ou `base_cost` d'un rôle, relancez (F5), observez.

## Tester sur votre téléphone Android (APK automatique)
À chaque push, GitHub lance les tests puis génère un APK.
1. Sur le téléphone, ouvrez la page **Releases** du dépôt GitHub → **Altopia — dernière version de test**.
2. Téléchargez `altopia.apk`.
3. Ouvrez le fichier ; Android demandera d'autoriser l'installation depuis le navigateur (« sources inconnues »). Acceptez.
4. Les mises à jour suivantes s'installent par-dessus la précédente (même clé de signature de debug).

Alternative : onglet **Actions** → dernier run → artefact `altopia-apk` (ZIP à dézipper).
Lancer les tests en local : `$(tools/setup_godot.sh) --headless --path . -s tests/run_tests.gd`
