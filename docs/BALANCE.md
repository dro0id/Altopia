# Équilibrage de la branche 1

Tout vient de simulations sans écran (le moteur de combat est le même que dans le jeu). Pour les relancer :

```
godot --headless --path . -s tools/calibrate.gd -- 40      # niveau minimal pour gagner chaque étage
godot --headless --path . -s tools/balance.gd -- 40 1      # joueur type qui monte et dépense ses crédits
```

## Règle de difficulté (décidée)
La difficulté monte doucement, mais reste assez dure pour donner envie de farmer. En pratique : les étages normaux se passent presque tous en 3 étoiles ; les mini-boss demandent environ 1 niveau de plus que prévu ; les gros boss demandent environ 5 à 7 niveaux de plus que les étages voisins, donc un mur qui oblige à farmer.

## Niveau d'escouade minimal, sans renfort ni évolution (5 graines, au moins 2 étoiles)
| Étage | Type | Niveau minimal | Niveau conseillé affiché |
|---|---|---|---|
| 5 | mini-boss | 1 | 1 |
| 10 | gros boss | 11 | 10 |
| 15 | mini-boss | 7 | 7 |
| 20 | gros boss | 18 | 18 |
| 25 | mini-boss | 14 | 14 |
| 30 | gros boss | 28 | 25 |
| 35 | mini-boss | 21 | 20 |
| 40 | gros boss | 39 | 33 |

Le niveau conseillé tient compte des renforts et des paliers d'évolution, que le joueur a en jouant : il est donc un peu en dessous du niveau minimal « à nu ». Formule : `0,65 × étage − 3,4`, plus 1 pour un mini-boss, plus `5,5 + 0,12 × étage` pour un gros boss (voir `Data.recommended_level`).

## Joueur type avec la branche 1b (renforts, paliers, persévérance ; dépense tout dans le meilleur achat, évolue dès que possible, farme l'étage précédent après une défaite)
| Étage | Temps cumulé de combat | Temps passé sur l'étage | Niveau moyen | Défaites avant victoire |
|---|---|---|---|---|
| 5 | 1,0 min | 17 s | 2,8 | 0 |
| 10 | 5,2 min | 198 s | 7,8 | 1 |
| 15 | 6,5 min | 19 s | 10,2 | 0 |
| 20 | 11,5 min | 239 s | 16,4 | 1 |
| 30 | 16,3 min | 142 s | 21,4 | 0 |
| 40 | 21,7 min | 180 s | 29,4 | 0 |

À retenir :
- Un étage normal dure 11 à 20 s de combat. Les 10 premiers étages prennent environ 5 min de combat, dont 3 min autour du premier gros boss.
- Avec les écrans (résultat, coffre, renfort, améliorations, carte) et le farm, une session de **15 à 20 minutes** couvre à peu près les étages 1 à 20, soit deux gros boss.
- Les gros boss forment chacun un mur de 2,5 à 4 minutes. C'est voulu : c'est là qu'on revient farmer.
- Les renforts et les paliers rendent le joueur nettement plus fort : sans correction, les gros boss ne bloquaient plus du tout. Leurs points de vie ont donc été relevés (Gardien de verre ×140, Foreur éclaté ×16).

## Gros boss différents
Les étages 10, 20, 30, 40… présentent à tour de rôle le Gardien de verre (étage 10, 40), la Sentinelle prismatique (20) et la Reine des mites (30). Niveau minimal mesuré sans renfort ni évolution : 11, 17, 26, 39. Le niveau conseillé affiché reste une moyenne de ces murs.

## Correctif (refonte Android)
Les renforts choisis entre les étages n'étaient pas transmis au combat affiché (seule la simulation les appliquait). Corrigé : la partie de contrôle passe de nouveau l'étage 10 et atteint l'étage 20 en 240 s, sans défaite.

## Limites
- Joueur simulé : il joue en automatique, sans lancer les pouvoirs à la main, donc sans combos. Un vrai joueur ira un peu plus vite. Il choisit les renforts dans un ordre fixe, ce qui n'est pas optimal.
- Les chiffres de coffre et d'économie sont à régler au test sur téléphone.
- Le temps réel d'une session dépend du temps passé dans les écrans, non simulé.

## Secteurs générés (étage 41 et au-delà)
- Chaque secteur de 10 étages est tiré d'une graine fixe (`scripts/sector.gd`) : nom, couleurs, règle, ennemis d'élite (12 % puis jusqu'à 35 %), gros boss titré avec un trait.
- Difficulté adaptative : ×1,04 par victoire, ×0,80 par défaite (à la frontière) ; l'équilibre donne 85 % de victoires. Le butin des secteurs générés est multiplié par ce même facteur.
- Un combat de secteur généré ne peut pas durer plus de 3 minutes : l'escouade se replie (compte comme une défaite).
- Mesure (`tools/progress.gd -- 160`) : 83 % de victoires sur 145 tentatives entre les étages 41 et 160 ; facteur entre ×0,4 et ×3,5 selon la profondeur.
- Les étages 1 à 40 (histoire) ne changent pas.
