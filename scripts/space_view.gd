extends SubViewportContainer
## Petite scène 3D : le vaisseau devant la destination (planète, étoile, astéroïdes).

var _vp: SubViewport
var _content: Node3D
var _pivot: Node3D
var _spinners: Array = []
var _dest := "?"
var _t := 0.0


func _init() -> void:
	stretch = true
	custom_minimum_size = Vector2(0, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(656, 240)
	add_child(_vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.6)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 40, 0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.4, 7.5)
	cam.fov = 40.0
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0, 0))
	_content = Node3D.new()
	_vp.add_child(_content)
	set_dest("")


func _mat(color: Color, emissive: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	return m


func _sphere(radius: float, color: Color, emissive: float = 0.0, segs: int = 32, rings: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segs
	mesh.rings = rings
	mi.mesh = mesh
	mi.material_override = _mat(color, emissive)
	return mi


func _make_ship() -> Node3D:
	var ship := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.13
	cap.height = 0.8
	body.mesh = cap
	body.rotation_degrees = Vector3(90, 0, 0)       # nez vers -Z
	body.material_override = _mat(Color(0.85, 0.9, 1.0), 0.0, 0.35)
	ship.add_child(body)
	var wing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.8, 0.03, 0.28)
	wing.mesh = box
	wing.position = Vector3(0, 0, 0.12)
	wing.material_override = _mat(Color(0.3, 0.75, 1.0), 0.6)
	ship.add_child(wing)
	var glow := _sphere(0.07, Color(0.5, 0.95, 1.0), 3.0, 12, 6)
	glow.position = Vector3(0, 0, 0.42)
	ship.add_child(glow)
	return ship


func set_dest(dest: String) -> void:
	if dest == _dest:
		return
	_dest = dest
	for c in _content.get_children():
		c.queue_free()
	_spinners.clear()
	var radius := 2.7
	match dest:
		"asteroids":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 16:
				var rock := _sphere(rng.randf_range(0.14, 0.36), Color(0.45, 0.38, 0.33), 0.0, 7, 4)
				rock.scale = Vector3(rng.randf_range(0.7, 1.4), rng.randf_range(0.6, 1.2), rng.randf_range(0.7, 1.4))
				var piv := Node3D.new()
				piv.rotation.y = rng.randf() * TAU
				rock.position = Vector3(rng.randf_range(1.2, 3.6), rng.randf_range(-0.5, 0.5), 0)
				piv.add_child(rock)
				_content.add_child(piv)
				_spinners.append({"node": piv, "speed": rng.randf_range(0.12, 0.35), "axis": "y"})
				_spinners.append({"node": rock, "speed": rng.randf_range(0.5, 1.5), "axis": "x"})
		"star":
			var star := _sphere(1.3, Color(1.0, 0.72, 0.25), 2.5)
			_content.add_child(star)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.5)
			light.light_energy = 2.0
			light.omni_range = 12.0
			_content.add_child(light)
			_spinners.append({"node": star, "speed": 0.15, "axis": "y"})
		"planet":
			var planet := _sphere(1.35, Color(0.2, 0.5, 0.85))
			_content.add_child(planet)
			var land := _sphere(1.37, Color(0.25, 0.65, 0.35, 0.9), 0.0, 10, 5)
			land.scale = Vector3(1.0, 0.55, 1.0)
			_content.add_child(land)
			_spinners.append({"node": planet, "speed": 0.2, "axis": "y"})
			_spinners.append({"node": land, "speed": 0.2, "axis": "y"})
		_:
			radius = 0.0
	_pivot = Node3D.new()
	var ship := _make_ship()
	ship.scale = Vector3.ONE * 2.2
	ship.position = Vector3(radius, 0, 0)
	_pivot.add_child(ship)
	_content.add_child(_pivot)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for s in _spinners:
		if not is_instance_valid(s.node):
			continue
		if s.axis == "y":
			s.node.rotation.y += s.speed * delta
		else:
			s.node.rotation.x += s.speed * delta
	if _pivot:
		if _dest == "":
			_pivot.rotation.y = 0.0
			_pivot.get_child(0).rotation.y += 0.6 * delta
			_pivot.position.y = sin(_t * 1.5) * 0.12
		else:
			_pivot.rotation.y += 0.45 * delta
			_pivot.position.y = sin(_t * 1.2) * 0.35
