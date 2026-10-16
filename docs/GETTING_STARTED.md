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
