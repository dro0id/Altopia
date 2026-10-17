extends SceneTree
## Génère les portraits PNG (équipage, capitaine, ennemis) depuis les modèles 3D.
## xvfb-run godot --path . --resolution 256x256 -s tools/render_portraits.gd
const Data = preload("res://scripts/game_data.gd")
const OUT := "res://assets/portraits/"

func _tint(n: Node, suit: Color, accent_tint: Color, mix: float) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src := m.get_active_material(i) as StandardMaterial3D
			if src == null:
				continue
			var mat := src.duplicate() as StandardMaterial3D
			if mat.resource_name == "suit_steel" and mix > 0.0:
				mat.albedo_color = mat.albedo_color.lerp(suit, mix)
			elif mat.resource_name == "accent_cyan" or mat.resource_name == "enemy_body":
				mat.emission = mat.emission.lerp(accent_tint, 0.22)
			m.set_surface_override_material(i, mat)


func _shot(model: String, out: String, ry: float, suit: Color, tint: Color, mix: float, fov: float = 30.0, cam_pos := Vector3(0.05, 0.52, 1.85)) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.6
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 1.3
	rim.light_color = Color(1.0, 0.31, 0.85)
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.position = cam_pos
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.4, 0))
	var n: Node3D = (load("res://assets/base/%s.glb" % model) as PackedScene).instantiate()
	n.rotation.y = ry
	vp.add_child(n)
	_tint(n, suit, tint, mix)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + out + ".png"))
	vp.queue_free()


func _initialize() -> void:
	await process_frame
	for id in Data.HERO_ORDER:
		var h: Dictionary = Data.HEROES[id]
		var idx: int = Data.HERO_ORDER.find(id)
		var suit: Color = Data.LOOK_SUITS[idx % Data.LOOK_SUITS.size()]
		var tint: Color = Data.RARITY[h.rarity].color
		await _shot("crew_" + h["class"], id, PI - 0.45, suit, tint, 0.0)
	await _shot("captain", "captain", PI - 0.45, Data.LOOK_SUITS[0], Color(0.2, 0.9, 1.0), 0.0)
	var kinds := {"asteroids": Color(0.55, 0.45, 0.4), "star": Color(1.0, 0.6, 0.2), "planet": Color(0.3, 0.9, 0.5)}
	for k in kinds:
		await _shot("enemy_golem", "enemy_" + k, PI + 0.5, Color.WHITE, kinds[k], 0.0, 34.0, Vector3(0.0, 0.5, 2.0))
	print("portraits OK")
	quit()
