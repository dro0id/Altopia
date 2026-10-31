# Équilibrage de la branche 1

Tout vient de simulations sans écran (le moteur de combat est le même que dans le jeu). Pour les relancer :

```
godot --headless --path . -s tools/calibrate.gd -- 40      # niveau minimal pour gagner chaque étage
godot --headless --path . -s tools/balance.gd -- 40 1      # joueur type qui monte et dépense ses crédits
```

## Règle de difficulté (décidée)
La difficulté monte doucement, mais reste assez dure pour donner envie de farmer. En pratique : les étages normaux se passent presque tous en 3 étoiles ; les mini-boss demandent environ 1 niveau de plus que prévu ; les gros boss demandent environ 5 à 7 niveaux de plus que les étages voisins, donc un mur qui oblige à farmer.

## Niveau d'escouade minimal (5 graines, au moins 2 étoiles)
| Étage | Type | Niveau minimal | Niveau conseillé affiché |
|---|---|---|---|
| 5 | mini-boss | 1 | 1 |
| 10 | gros boss | 8 | 9 |
| 15 | mini-boss | 7 | 7 |
| 20 | gros boss | 16 | 16 |
| 25 | mini-boss | 14 | 14 |
| 30 | gros boss | 23 | 24 |
| 35 | mini-boss | 21 | 20 |
| 40 | gros boss | 30 | 31 |

Le niveau conseillé affiché est à peu près le niveau minimal, à ±1. Formule : `0,65 × étage − 3,4`, plus 1 pour un mini-boss, plus `4,5 + 0,1 × étage` pour un gros boss (voir `Data.recommended_level`).

## Joueur type (dépense tout dans le meilleur achat, farme l'étage précédent après une défaite)
| Étage | Temps cumulé de combat | Temps passé sur l'étage | Niveau moyen | Défaites avant victoire |
|---|---|---|---|---|
| 5 | 1,1 min | 18 s | 2,6 | 0 |
| 10 | 4,8 min | 158 s | 6,8 | 2 |
| 15 | 6,2 min | 21 s | 9,4 | 0 |
| 20 | 10,8 min | 203 s | 15,0 | 2 |
| 30 | 16,9 min | 202 s | 23,0 | 1 |
| 40 | 22,0 min | 121 s | 29,4 | 0 |

À retenir :
- Un étage normal dure 11 à 20 s de combat. Monter les 10 premiers étages prend environ 5 min de combat, dont 2 à 3 min autour du premier gros boss (défaites et farm).
- Avec les écrans (résultat, coffre, améliorations, carte) et le farm, une session de **15 à 20 minutes** couvre à peu près les étages 1 à 20, soit deux gros boss.
- Les gros boss à partir de l'étage 10 forment chacun un mur de 2 à 3,5 minutes. C'est voulu : c'est là qu'on revient farmer.

## Limites
- Joueur simulé : il joue en automatique, sans lancer les pouvoirs à la main, et n'a ni renforts ni persévérance (branche 1b). Un vrai joueur ira plus vite.
- Les chiffres de coffre et d'économie sont à régler au test sur téléphone.
- Le temps réel d'une session dépend du temps passé dans les écrans, non simulé.
