extends SceneTree
## Tests de logique (lancer : godot --headless --path . -s tests/run_tests.gd). Code de sortie 0 = tout est OK.
## Projet repris de zéro : pour l'instant, on vérifie seulement que la scène principale se charge.

var _failures := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures += 1
		printerr("FAIL ", msg)


func _initialize() -> void:
	var main: PackedScene = load("res://scenes/main.tscn")
	_check(main != null, "la scène principale se charge")
	_check(main.instantiate() is Control, "la scène principale est un Control")
	if _failures == 0:
		print("Tous les tests passent.")
	quit(1 if _failures > 0 else 0)
