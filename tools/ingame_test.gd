extends SceneTree
## Test en jeu : la vraie scène principale, pilotée par de vrais clics (scripts/autotest.gd).
## xvfb-run -a godot --path . --resolution 720x1280 -s tools/ingame_test.gd -- <dossier de captures>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	await process_frame
	var gs = root.get_node("GameState")
	gs.save_path = "user://ingame_test.json"
	var main: Control = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var t := AutoTest.new()
	root.add_child(t)
	var failures: int = await t.run(main, a[0] if a.size() > 0 else "/tmp")
	quit(1 if failures > 0 else 0)
