class_name PortView
extends ShipView
## Port-Altopia en 3D (maquette WO) : une île de verre à facettes, ses districts en volumes, l'Aurore
## en miniature à quai au-dessus, reliée par un faisceau. On tourne et on pince comme sur l'Aurore.

signal district_tapped(d: String)

var isle: Node3D
var dock: Node3D
var spots := {}               # district -> position 3D (sur l'île)
var _built := {}


func build_port(levels: Dictionary) -> void:
	_built = levels.duplicate()
	if dock != null:
		dock.queue_free()
		ship = null
	spots = {}
	setup(clampi(int(Game.ship.level), 1, Ship.MAX_LEVEL), {}, {})
	set_cut(false)
	# l'Aurore réduite, à quai
	root3.remove_child(ship)
	dock = Node3D.new()
	dock.position = Vector3(4.6, 5.2, -3.2)
	dock.scale = Vector3.ONE * 0.32
	root3.add_child(dock)
	dock.add_child(ship)
	if isle != null:
		isle.queue_free()
	isle = Node3D.new()
	root3.add_child(isle)
	_build_isle()
	_frame()


func _frame() -> void:
	if isle == null:
		super._frame()
		return
	target = Vector3(0.4, 1.6, 0)
	yaw = -0.5
	pitch = 0.42
	var a := maxf(0.3, size.x / maxf(1.0, size.y))
	var vf := deg_to_rad(cam.fov)
	var hf := 2.0 * atan(tan(vf / 2.0) * a)
	dist = maxf(14.6 / 2.0 / tan(hf / 2.0), 11.0 / 2.0 / tan(vf / 2.0))
	_home_dist = dist


func _process(delta: float) -> void:
	super._process(delta)
	if dock != null:
		dock.position.y = 5.2 + sin(_t * 0.9) * 0.15


func _tap(pos: Vector2) -> void:
	if _maybe_recenter():
		return
	var k := Vector2(vp.size) / maxf(1.0, size.x) if size.x > 0 else Vector2.ONE
	var o := cam.project_ray_origin(pos * k.x)
	var d := cam.project_ray_normal(pos * k.x)
	var best := ""
	var bd := 1.6
	for key in spots:
		var p: Vector3 = spots[key] + Vector3(0, 0.8, 0)
		# distance du point au rayon
		var t := maxf(0.0, (p - o).dot(d))
		var dd := (o + d * t).distance_to(p)
		if dd < bd:
			bd = dd
			best = key
	if best != "":
		district_tapped.emit(best)


## Position à l'écran de l'étiquette d'un district.
func spot_pos(key: String) -> Dictionary:
	if not spots.has(key):
		return {}
	var wp: Vector3 = spots[key] + Vector3(0, -0.3, 0.9)
	if cam.is_position_behind(wp):
		return {}
	var k := size.x / maxf(1.0, float(vp.size.x))
	return {"pos": cam.unproject_position(wp) * k}


func _build_isle() -> void:
	# plateau à facettes : dessus clair, flancs sombres, pointe sous l'île
	var top := _mat(Color("2a4a86"), 0.1, 0.8)
	var side := _mat(Color("14203e"), 0.1, 0.9)
	_cyl(7.2, 6.4, 0.8, top, Vector3(0, -0.4, 0), 9, isle)
	_cyl(6.4, 2.0, 3.2, side, Vector3(0, -2.4, 0), 9, isle)
	_cyl(2.0, 0.2, 2.2, side, Vector3(0, -5.1, 0), 9, isle)
	# liseré de verre lumineux au bord du plateau
	_torus(6.9, 0.07, _emis(Color("4fd8ff"), 1.2), Vector3(0, -0.05, 0), isle, 64)
	# faisceau d'amarrage vers l'Aurore
	var beam := _cyl(0.12, 0.12, 1.0, _glass(Color("bfefff"), 0.35), Vector3.ZERO, 8, isle)
	var from := Vector3(3.6, 0.1, -2.4)
	var to := Vector3(4.6, 4.4, -3.2)
	var dir := to - from
	beam.transform = Transform3D(Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1)), (from + to) * 0.5)
	_cyl(0.9, 1.1, 0.25, _mat(Color("8ea4c8"), 0.6, 0.4), Vector3(3.6, 0.1, -2.4), 12, isle)
	# districts
	for key in Port.ORDER:
		var at: Vector2 = Port.DISTRICTS[key].pos3
		var p := Vector3(at.x, 0.0, at.y)
		spots[key] = p
		var lv := int(_built.get(key, 0))
		var node := Node3D.new()
		node.position = p
		isle.add_child(node)
		if lv <= 0:
			_pad(node, Port.DISTRICTS[key].col)
		else:
			node.scale = Vector3.ONE * (0.85 + 0.06 * lv)
			_district(node, key, Port.DISTRICTS[key].col)


## Emplacement à bâtir : dalle sombre et coins lumineux.
func _pad(n: Node3D, col: Color) -> void:
	_cyl(1.1, 1.1, 0.08, _mat(Color("1a2850"), 0.1, 0.9), Vector3(0, 0.04, 0), 6, n)
	for i in 6:
		var a := TAU * i / 6.0
		_box(Vector3(0.14, 0.1, 0.14), _emis(Color(col, 0.8), 0.8), Vector3(cos(a) * 1.0, 0.12, sin(a) * 1.0), n)


func _district(n: Node3D, key: String, col: Color) -> void:
	var m := _mat(col, 0.2, 0.5)
	var dark := _mat(col.darkened(0.45), 0.3, 0.6)
	_cyl(1.2, 1.25, 0.16, _mat(Color("31477a"), 0.2, 0.8), Vector3(0, 0.08, 0), 8, n)
	match key:
		"domes":
			var d := _sph(1.0, _glass(col, 0.6), Vector3(0, 0.16, 0), n, 18)
			d.scale = Vector3(1, 0.8, 1)
			_sph(0.35, _emis(col, 1.2), Vector3(0, 0.4, 0), n, 10)
			_torus(1.0, 0.07, m, Vector3(0, 0.2, 0), n, 32)
		"fonderie":
			_cyl(0.55, 0.85, 1.2, m, Vector3(0, 0.76, 0), 8, n)
			_cyl(0.16, 0.18, 1.3, dark, Vector3(0.3, 1.9, 0), 8, n)
			var fire := _sph(0.24, _emis(Color("ffb142"), 2.0), Vector3(0.3, 2.6, 0), n, 8)
			anims.append(func(t: float): fire.scale = Vector3.ONE * (0.8 + 0.3 * absf(sin(t * 5.0))))
		"academie":
			var c := _cyl(0.45, 0.6, 2.4, m, Vector3(0, 1.36, 0), 6, n)
			_cyl(0.0, 0.45, 0.7, _emis(col.lightened(0.3), 1.2), Vector3(0, 2.9, 0), 6, n)
			anims.append(func(t: float): c.rotation.y = t * 0.2)
		"marche":
			_box(Vector3(1.6, 0.8, 1.2), m, Vector3(0, 0.56, 0), n)
			var roof := _cyl(0.0, 1.05, 0.6, dark, Vector3(0, 1.26, 0), 4, n)
			roof.rotation.y = PI / 4.0
			for sx in [-0.5, 0.0, 0.5]:
				_box(Vector3(0.36, 0.05, 0.5), _emis(Color("ffe08a"), 0.8), Vector3(sx, 0.4, 0.62), n)
		"phare":
			_cyl(0.18, 0.3, 3.0, _mat(Color("eef2ff"), 0.1, 0.4), Vector3(0, 1.66, 0), 10, n)
			_sph(0.3, _emis(col, 2.2), Vector3(0, 3.3, 0), n, 12)
			var beam := _box(Vector3(4.0, 0.08, 0.5), _glass(col, 0.25), Vector3(0, 3.3, 0), n)
			anims.append(func(t: float): beam.rotation.y = t * 0.8)
		"arene":
			_cyl(1.05, 1.05, 0.06, _mat(Color("3a1620"), 0.1, 0.9), Vector3(0, 0.19, 0), 24, n)
			_torus(1.1, 0.16, m, Vector3(0, 0.3, 0), n, 40)
			for i in 6:
				var a := TAU * i / 6.0
				_cyl(0.07, 0.07, 0.8, dark, Vector3(cos(a) * 1.1, 0.56, sin(a) * 1.1), 6, n)
		"jardins":
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				var r := 0.55
				_cyl(0.06, 0.08, 0.5, _mat(Color("6a4a2a"), 0.0, 0.9), Vector3(cos(a) * r, 0.4, sin(a) * r), 6, n)
				_sph(0.32 + 0.05 * i, _mat(col, 0.0, 0.7), Vector3(cos(a) * r, 0.85, sin(a) * r), n, 10)
			var egg := _sph(0.22, _emis(Color("9fe6ff"), 1.0), Vector3(0, 0.45, 0), n, 10)
			egg.scale = Vector3(1, 1.3, 1)
		"archives":
			for i in 3:
				var b := _box(Vector3(1.3 - i * 0.3, 0.45, 1.0 - i * 0.2), m if i % 2 == 0 else dark, Vector3(0, 0.4 + i * 0.45, 0), n)
				b.rotation.y = i * 0.3
			var dish := _cyl(0.5, 0.1, 0.2, _mat(Color("c8d4e6"), 0.7, 0.3), Vector3(0, 1.75, 0), 14, n)
			anims.append(func(t: float): dish.rotation = Vector3(0.5, t * 0.5, 0))
