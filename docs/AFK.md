# Boucle AFK : progression et équilibrage

## Ce qui donne un but à chaque retour
- **Objectifs** (12 paliers, carte en haut de l'onglet Capitaine) : niveau du Capitaine, cartes d'équipage, données, expéditions, objet épique, 2e vaisseau, niveaux de postes… Chaque palier rapporte des ressources.
- **Améliorations de poste** (onglet Vaisseau) : +12 % de production du poste (Pilote, Ingénieur, Scientifique) par niveau, 30 niveaux, coût ×1,5 par niveau.
- Les gains hors ligne (rendement 50 % à 120 %, durée 4 à 24 h) restent liés à l'équipage placé et aux Ingénieurs.

## Corrections d'équilibrage
- XP, butin et rendement s'appliquent aussi hors ligne (avant, l'XP hors ligne était à 100 % : fuite).
- Le niveau des ennemis est plafonné (60) : avant, il montait sans fin et le butin recyclé s'emballait.
- Production d'un équipier : niveau^0,7 (au lieu de linéaire) ; moteurs -5 %/niveau ; durée minimale 5 s.
- Coûts d'entraînement plus raides (Capitaine ×1,35, équipage ×1,32) ; améliorations ×1,85.

## Calcul hors ligne
Les cycles d'expédition d'une absence sont regroupés (au plus ~40 combats simulés par vaisseau) : 24 h se calculent en moins d'une seconde au lieu de plusieurs minutes.

## Courbes visées (simulation `tools/balance.gd`, 3 sessions de 8 min par jour)
| Moment | Capitaine | Cartes | Niveaux d'équipage |
|---|---|---|---|
| Après la 1re nuit (4,6 h) | 14 | 5 | 45 |
| Jour 1 | 22 | 6 | 92 |
| Jour 2 | 32 | 6 | 138 |
| Jour 3 | 37 | 6 | 165 |
| Jour 7 | 48 | 7 | 258 |
| Jour 14 | 50 (max) | 8 | 320 |

Lancer : `godot --headless --path . -s tools/balance.gd -- 14` (nombre de jours).
Limite : le joueur « robot » dépense au mieux ; un vrai joueur sera plus lent. Le début est plutôt rapide (niveau 14 après la première nuit) : à ajuster d'après les retours de test.
