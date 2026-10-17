# Altopia

Jeu Android de type **RPG idle / AFK** dans l'espace : vous êtes le **Capitaine** d'un vaisseau.
Vous l'équipez, placez votre équipage (cartes à collectionner) à ses postes, puis vous partez
explorer et combattre automatiquement (astéroïdes, étoiles, planètes). La progression continue hors-ligne.

- Moteur : [Godot 4](https://godotengine.org/) (GDScript)
- Plateforme cible : Android (portrait)
- Visuel : 2D (fond parallaxe, portraits) + scènes 3D (destinations, vaisseau)

## Documentation
- [Game design (GDD)](docs/GDD.md)
- [V2 : le Capitaine, équipement, règles et captures](docs/V2.md)
- [Feuille de route](docs/ROADMAP.md)
- [Guide de démarrage (débutant)](docs/GETTING_STARTED.md)

## Outils
- `tools/setup_godot.sh` : télécharge Godot 4.3 (Linux) pour l'exécuter en ligne de commande.
- GitHub Actions (`.github/workflows/validate.yml`) : importe et lance le projet à chaque push pour détecter les erreurs.

## Lancer le prototype
Voir le guide de démarrage. En bref : installer Godot 4.3+, « Importer » le
dossier du projet (`project.godot`), puis appuyer sur F5.
