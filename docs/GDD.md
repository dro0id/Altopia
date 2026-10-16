# Altopia — Game Design Document (v0.1)

## Pitch
Vous dirigez un vaisseau d'exploration. Votre équipage explore automatiquement
des secteurs de la galaxie, récupère des ressources et découvre de nouveaux
mondes. Le joueur ne pilote pas : il **recrute, compose, améliore et choisit
où aller**. Tout continue hors-ligne.

## Piliers
1. **Simple à reprendre** : une session de 1 à 3 minutes doit être satisfaisante.
2. **Composition d'équipe** : les rôles et leurs synergies comptent plus que la puissance brute.
3. **Exploration** : toujours un nouveau secteur / une découverte à l'horizon.
4. **Progression visible** : chiffres qui montent, carte qui s'agrandit.

## Boucle principale
1. L'équipage explore le secteur actuel (gain passif de **Crédits** et de **Données**).
2. Le joueur dépense pour recruter / améliorer l'équipage.
3. Les **Données** débloquent de nouveaux secteurs (plus rentables, plus risqués).
4. Un boss / anomalie ferme chaque secteur → il faut une bonne composition.
5. **Prestige** : « Saut hyperspatial » — reset contre un bonus permanent.
6. Retour hors-ligne : récap des gains (plafonné, ex. 8 h).

## Couche RPG (V1)
Les membres d'équipage sont des **héros nommés** à collectionner (classe, rareté, niveau, étoiles),
regroupés en **escouades de 3** qui partent en expédition et **combattent automatiquement**.
Détails et chiffres : [V1.md](V1.md).

## Équipage (v0.1, remplacé par les héros)
| Rôle | Fonction | Bonus de synergie |
|---|---|---|
| Pilote | Vitesse d'exploration | Avec Ingénieur : +10 % |
| Ingénieur | Efficacité / coûts | Avec Scientifique : +10 % |
| Scientifique | Génère des Données | Avec Pilote : +10 % |

Équipage complet (les 3 rôles) : bonus global supplémentaire.
Plus tard : raretés, classes, formation en slots, équipements, vaisseaux.

## Exploration : types de destinations
Chaque secteur contient plusieurs **corps célestes**. Chacun a sa propre phase
d'exploration (auto, avec un petit choix du joueur avant l'envoi) :

| Destination | Phase d'exploration | Récompenses | Rôle clé | Risques / événements |
|---|---|---|---|---|
| **Planète** | Orbite → scan → atterrissage → expédition au sol (étapes avec événements : ruines, faune, météo) | Données, Crédits, artefacts, nouveaux membres d'équipage | Scientifique | Tempêtes, créatures hostiles |
| **Étoile** | Approche → collecte d'énergie / échantillons stellaires, sans atterrir | Énergie (améliore vaisseau), Données rares | Ingénieur | Éruptions solaires, chaleur (exige un bouclier) |
| **Astéroïdes** | Champ à traverser → minage automatique | Minerais (Crédits, matériaux de craft) | Pilote | Collisions, pirates |
| **Anomalie** *(plus tard)* | Énigme / événement unique | Récompenses uniques | Équipage complet | Imprévisible |

### Fonctionnement
- Une **expédition** = destination + équipage assigné + durée (de 30 s à plusieurs heures, terminable hors-ligne).
- Le **rôle adapté** accélère l'expédition et augmente les gains ; une mauvaise composition la ralentit ou augmente les risques.
- Chaque destination se **découvre** (scan) avant d'être explorable, puis peut être explorée à plusieurs niveaux de profondeur.
- Les ressources collectées alimentent : améliorations du vaisseau, équipement, déblocage de nouveaux secteurs.
- Visuellement : chaque type a sa petite scène 2D (planète en orbite, étoile en gros plan, champ d'astéroïdes en parallaxe).

## Ressources
- **Crédits** : monnaie principale (recrutement, améliorations).
- **Données** : débloquent secteurs et recherche.
- **Énergie** (étoiles) et **Minerais** (astéroïdes) : améliorations du vaisseau et craft.
- *(plus tard)* **Cristaux** premium / prestige.

## Direction artistique
2D stylisée, fond spatial en plusieurs plans (parallaxe) pour donner du
volume. Palette sombre + accents néon. Passage à des éléments 3D possible
ensuite (Godot gère les deux).

## Monétisation (à décider plus tard)
Pubs récompensées (boost x2 gains), achats intégrés cosmétiques / confort.
Éviter le « pay-to-win » dur.

## Hors périmètre v1
Multijoueur, PvP, chat. Priorité : un solo solide et hors-ligne.
