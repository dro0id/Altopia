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

## Équipage (v0.1)
| Rôle | Fonction | Bonus de synergie |
|---|---|---|
| Pilote | Vitesse d'exploration | Avec Ingénieur : +10 % |
| Ingénieur | Efficacité / coûts | Avec Scientifique : +10 % |
| Scientifique | Génère des Données | Avec Pilote : +10 % |

Équipage complet (les 3 rôles) : bonus global supplémentaire.
Plus tard : raretés, classes, formation en slots, équipements, vaisseaux.

## Ressources
- **Crédits** : monnaie principale (recrutement, améliorations).
- **Données** : débloquent secteurs et recherche.
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
