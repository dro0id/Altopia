class_name ShipView
extends SubViewportContainer
## Vue 3D en coupe de l'Aurore (maquettes PA à QC) : cinq versions selon le niveau du vaisseau (1–5, 6–10, 11–15, 16–19, 20).
## Tout est construit en formes simples (tours, cylindres, tores), sans modèle ni image à charger.
## La coque arrière reste visible ; la moitié avant n'apparaît qu'en mode « coque fermée ».

signal room_tapped(room: String)

const Data = preload("res://scripts/data.gd")
const HC := {"rare": Color("4fa8ff"), "common": Color("7dffb0"), "epic": Color("b388ff")}

var vp: SubViewport
var cam: Camera3D
var root3: Node3D
var ship: Node3D
var front_parts: Array = []        # visibles seulement en coque fermée
var cut_parts: Array = []          # visibles seulement en coupe
var anims: Array = []              # Callable(t)
var anchors := {}                  # salle -> position locale de l'étiquette
var boxes := {}                    # salle -> AABB locale (toucher)
var cut_mode := true
var tier := 2
var level := 6
var crew := {}                     # salle -> [héros]
var opened := {}                   # salle -> niveau (0 = scellée) ; vide = tout ouvert
var yaw := -0.35
var pitch := 0.2
var dist := 21.0
var target := Vector3(0, 4.5, 0)
var _t := 0.0
var _drag := false
var _moved := 0.0
var _press := Vector2.ZERO

# dimensions de la version courante
var MODS: Array = []
var CROWN := Vector2.ZERO
var TOP0 := 0.0
var HULL_TOP := 0.0
var KEYS: Array = []
var TOPR := 2.42
var prof: Array = []

var m_hull: StandardMaterial3D
var m_inner: StandardMaterial3D
var m_deck: StandardMaterial3D
var m_deck_side: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_metal: StandardMaterial3D
var m_paint: StandardMaterial3D
var m_navy: StandardMaterial3D
var m_gold: StandardMaterial3D
var _glow_tex := {}


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	root3 = Node3D.new()
	vp.add_child(root3)
	cam = Camera3D.new()
	cam.fov = 32.0
	cam.near = 0.1
	cam.far = 400.0
	root3.add_child(cam)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8ea4ff")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("1a2a5a")
	sm.sky_horizon_color = Color("6a4ab0")
	sm.ground_bottom_color = Color("05081a")
	sm.ground_horizon_color = Color("4fd8ff")
	sky.sky_material = sm
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	root3.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff3e0")
	key.light_energy = 1.25
	key.rotation = Vector3(deg_to_rad(-40), deg_to_rad(38), 0)
	root3.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("b388ff")
	rim.light_energy = 1.0
	rim.rotation = Vector3(deg_to_rad(10), deg_to_rad(-140), 0)
	root3.add_child(rim)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("4fd8ff")
	fill.light_energy = 0.35
	fill.rotation = Vector3(deg_to_rad(-20), deg_to_rad(-40), 0)
	root3.add_child(fill)
	_materials()


## Construit (ou reconstruit) le vaisseau pour un niveau donné.
func setup(p_level: int, p_crew: Dictionary = {}, p_rooms: Dictionary = {}) -> void:
	level = clampi(p_level, 1, Ship.MAX_LEVEL)
	tier = Ship.tier_of(level)
	crew = p_crew
	opened = p_rooms.duplicate()
	if ship != null:
		ship.queue_free()
	ship = Node3D.new()
	root3.add_child(ship)
	front_parts = []
	cut_parts = []
	anims = []
	anchors = {}
	boxes = {}
	_dimensions()
	_materials()
	_build()
	set_cut(cut_mode)
	_frame()


func set_cut(on: bool) -> void:
	cut_mode = on
	for n in front_parts:
		if is_instance_valid(n):
			n.visible = not on
	for n in cut_parts:
		if is_instance_valid(n):
			n.visible = on


func _frame() -> void:
	var need_h := HULL_TOP + (7.0 if tier == 5 else 5.2)
	var need_w := 8.6 if tier == 1 else (13.6 if tier == 5 else (14.2 if tier == 4 else 12.8))
	var a := maxf(0.3, size.x / maxf(1.0, size.y))
	var vf := deg_to_rad(cam.fov)
	var dh := need_h / 2.0 / tan(vf / 2.0)
	var hf := 2.0 * atan(tan(vf / 2.0) * a)
	var dw := need_w / 2.0 / tan(hf / 2.0)
	dist = maxf(dh, dw) * 1.02
	target = Vector3(0, (HULL_TOP - 1.6) / 2.0, 0)


func _process(delta: float) -> void:
	if ship == null:
		return
	_t += delta
	if not Game.reduce_shake and not Game.battery_saver:
		for f in anims:
			f.call(_t)
	ship.position.y = sin(_t * 0.8) * 0.06
	cam.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.look_at(target, Vector3.UP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and ship != null:
		_frame()


# ---------------------------------------------------------------- gestes : glisser pour tourner, pincer pour zoomer, toucher une salle

var _touches := {}
var _pinch0 := 0.0
var _dist0 := 0.0


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_touches[ev.index] = ev.position
			_moved = 0.0
			if _touches.size() == 2:
				var p: Array = _touches.values()
				_pinch0 = (p[0] as Vector2).distance_to(p[1])
				_dist0 = dist
		else:
			_touches.erase(ev.index)
			if _moved < 12.0 and _touches.is_empty():
				_tap(ev.position)
		accept_event()
	elif ev is InputEventScreenDrag:
		_touches[ev.index] = ev.position
		_moved += ev.relative.length()
		if _touches.size() == 1:
			yaw -= ev.relative.x * 0.008
			pitch = clampf(pitch + ev.relative.y * 0.006, -0.6, 0.9)
		elif _touches.size() == 2 and _pinch0 > 0.0:
			var p: Array = _touches.values()
			dist = clampf(_dist0 * _pinch0 / maxf(1.0, (p[0] as Vector2).distance_to(p[1])), 9.0, 42.0)
		accept_event()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = clampf(dist * 0.92, 9.0, 42.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = clampf(dist * 1.08, 9.0, 42.0)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_drag = true
				_moved = 0.0
			else:
				_drag = false
				if _moved < 12.0:
					_tap(ev.position)
	elif ev is InputEventMouseMotion and _drag and not DisplayServer.is_touchscreen_available():
		_moved += ev.relative.length()
		yaw -= ev.relative.x * 0.008
		pitch = clampf(pitch + ev.relative.y * 0.006, -0.6, 0.9)


func _tap(pos: Vector2) -> void:
	var k := Vector2(vp.size) / maxf(1.0, size.x) if size.x > 0 else Vector2.ONE
	var o := cam.project_ray_origin(pos * k.x)
	var d := cam.project_ray_normal(pos * k.x)
	var inv := ship.global_transform.affine_inverse()
	var lo := inv * o
	var ld := (inv.basis * d).normalized()
	var best := ""
	var bt := 1.0e9
	for r in boxes:
		var hit: Variant = (boxes[r] as AABB).intersects_ray(lo, ld)
		if hit != null:
			var tt := lo.distance_to(hit)
			if tt < bt:
				bt = tt
				best = r
	if best != "" and (cut_mode or best == "hangar"):
		room_tapped.emit(best)


## Position à l'écran (pixels du conteneur) de l'étiquette d'une salle, et si elle est visible.
func label_pos(r: String) -> Dictionary:
	if not anchors.has(r) or ship == null:
		return {}
	var wp: Vector3 = ship.global_transform * (anchors[r] as Vector3)
	if cam.is_position_behind(wp):
		return {}
	var p := cam.unproject_position(wp)
	var k := size.x / maxf(1.0, float(vp.size.x))
	var facing := Vector3(0, 0, 1)
	var to_cam := (cam.global_position - wp).normalized()
	var vis: bool = (r == "hangar") or (cut_mode and facing.dot(to_cam) > 0.15)
	return {"pos": p * k, "visible": vis}


# ---------------------------------------------------------------- dimensions et profil de la coque

func _dimensions() -> void:
	var n: int = [0, 3, 4, 5, 5, 5][tier]
	MODS = [Vector2(1.0, 2.4), Vector2(2.4, 3.8), Vector2(3.8, 5.2), Vector2(5.2, 6.7), Vector2(6.7, 8.1)].slice(0, n)
	CROWN = Vector2(MODS[-1].y, MODS[-1].y + (1.5 if tier == 1 else 1.7))
	TOP0 = CROWN.y
	HULL_TOP = TOP0 + (2.4 if tier == 1 else (1.75 if tier == 2 else 1.95))
	KEYS = [Vector2(0.25, 2.05), Vector2(0.33, 2.62), Vector2(0.86, 2.62), Vector2(0.98, 2.3)]
	for i in MODS.size():
		var m: Vector2 = MODS[i]
		var rr := 2.4 if i % 2 else 2.46
		KEYS.append(Vector2(m.x + 0.04, rr))
		KEYS.append(Vector2(m.y - 0.1, rr))
		KEYS.append(Vector2(m.y, 2.28))
	var rc := 2.5 if tier == 1 else 2.68
	KEYS.pop_back()
	KEYS.append(Vector2(CROWN.x, 2.28))
	KEYS.append(Vector2(CROWN.x + 0.06, rc))
	KEYS.append(Vector2(CROWN.y - 0.14, rc))
	KEYS.append(Vector2(CROWN.y, 2.3 if tier == 1 else 2.42))
	TOPR = KEYS[-1].y
	var ys: Array = []
	var y := 0.25
	while y < HULL_TOP:
		ys.append(y)
		y += 0.08
	for kp in KEYS:
		ys.append(kp.x)
		ys.append(kp.x + 0.001)
	for i in 21:
		ys.append(TOP0 + (HULL_TOP - TOP0) * i / 20.0)
	ys.sort()
	prof = []
	var last := -1.0
	for yy in ys:
		if yy - last < 0.0005 or yy > HULL_TOP:
			continue
		prof.append(Vector2(rad(yy), yy))
		last = yy


func rad(y: float) -> float:
	if y >= TOP0:
		var t := minf(1.0, (y - TOP0) / (HULL_TOP - TOP0))
		if tier == 1:
			return maxf(0.02, TOPR * pow(cos(t * PI / 2.0), 1.15))
		return maxf(0.02, TOPR * sqrt(maxf(0.0, 1.0 - t * t)))
	for i in range(1, KEYS.size()):
		var k1: Vector2 = KEYS[i]
		if y <= k1.x:
			var k0: Vector2 = KEYS[i - 1]
			return k0.y + (k1.y - k0.y) * (y - k0.x) / maxf(1e-6, k1.x - k0.x)
	return TOPR


# ---------------------------------------------------------------- matériaux et petits outils

func _materials() -> void:
	m_hull = StandardMaterial3D.new()
	m_hull.albedo_texture = _livery()
	m_hull.metallic = 0.4 if tier == 5 else 0.35
	m_hull.roughness = 0.18 if tier == 5 else 0.4
	if tier == 5:
		m_hull.clearcoat_enabled = true
		m_hull.clearcoat = 1.0
	m_inner = _mat(Color("0f1630"), 0.15, 0.85)
	m_inner.cull_mode = BaseMaterial3D.CULL_FRONT
	m_deck = _mat(Color("1b2547"), 0.5, 0.55)
	m_deck_side = _mat(Color("c9d3ea"), 0.4, 0.4)
	m_dark = _mat(Color("121a36"), 0.45, 0.5)
	m_metal = _mat(Color("8d9cc4"), 0.85, 0.3)
	m_paint = _mat(Color("dfe6f5"), 0.3, 0.4)
	m_navy = _mat(Color("1e2a55"), 0.4, 0.45)
	m_gold = _mat(Color("e0b24f") if tier == 5 else Color("c99a3a"), 0.85, 0.18)
	if tier == 5:
		m_gold.emission_enabled = true
		m_gold.emission = Color("6a4508")
		m_gold.emission_energy_multiplier = 0.6


func _mat(c: Color, metal := 0.3, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _emis(c: Color, e := 1.0) -> StandardMaterial3D:
	var m := _mat(c, 0.0, 0.4)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _add_mat(c: Color, a := 1.0, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(c, a)
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	if tex != null:
		m.albedo_texture = tex
	return m


func _glass(c: Color, a := 0.18) -> StandardMaterial3D:
	var m := _mat(c, 0.1, 0.05)
	m.albedo_color = Color(c, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _mi(mesh: Mesh, mat: Material, p := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = p
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else ship).add_child(m)
	return m


func _box(sz: Vector3, mat: Material, p: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = sz
	return _mi(b, mat, p, parent)


func _cyl(rt: float, rb: float, h: float, mat: Material, p: Vector3, seg := 16, parent: Node3D = null, open := false) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	if open:
		c.cap_top = false
		c.cap_bottom = false
	return _mi(c, mat, p, parent)


func _sph(r: float, mat: Material, p: Vector3, parent: Node3D = null, seg := 16) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return _mi(s, mat, p, parent)


func _torus(r: float, tube: float, mat: Material, p: Vector3, parent: Node3D = null, seg := 64) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = seg
	t.ring_segments = 8
	return _mi(t, mat, p, parent)


## Halo lumineux toujours tourné vers la caméra.
func _glow(c: Color, s: float, p: Vector3, a := 1.0, parent: Node3D = null) -> MeshInstance3D:
	var key := c.to_html()
	if not _glow_tex.has(key):
		var g := Gradient.new()
		g.set_color(0, Color(c, 1.0))
		g.set_color(1, Color(c, 0.0))
		g.add_point(0.3, Color(c, 0.6))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_glow_tex[key] = gt
	var m := _add_mat(Color.WHITE, a, _glow_tex[key])
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	return _mi(q, m, p, parent)


## Surface de révolution d'un profil (x = rayon, y = hauteur) entre deux angles.
func _lathe(pts: Array, seg: int, phi0: float, phil: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for j in seg + 1:
		var phi := phi0 + phil * j / seg
		var sp := sin(phi)
		var cp := cos(phi)
		for i in n:
			var p: Vector2 = pts[i]
			st.set_uv(Vector2(float(j) / seg, 1.0 - float(i) / maxf(1, n - 1)))
			st.add_vertex(Vector3(p.x * sp, p.y, p.x * cp))
	for j in seg:
		for i in n - 1:
			var a := j * n + i
			var b := (j + 1) * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
	st.generate_normals()
	return st.commit()


## Tube le long d'une suite de points.
func _tube(pts: Array, r: float, seg := 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var tg: Vector3 = ((pts[mini(n - 1, i + 1)] as Vector3) - (pts[maxi(0, i - 1)] as Vector3)).normalized()
		var ref := Vector3.UP if absf(tg.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var nx := tg.cross(ref).normalized()
		var ny := tg.cross(nx).normalized()
		for k in seg + 1:
			var a := TAU * k / seg
			var d := nx * cos(a) + ny * sin(a)
			st.set_normal(d)
			st.add_vertex(p + d * r)
	for i in n - 1:
		for k in seg:
			var a := i * (seg + 1) + k
			var b := (i + 1) * (seg + 1) + k
			st.add_index(a)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(b + 1)
	return st.commit()


func _arc(r: float, y: float, a0: float, a1: float, n := 24) -> Array:
	var p: Array = []
	for i in n + 1:
		var a := a0 + (a1 - a0) * i / n
		p.append(Vector3(r * cos(a), y, r * sin(a)))
	return p


## Polygone plat (voiles, ailerons) à partir de points 2D.
func _flat(pts: PackedVector2Array) -> ArrayMesh:
	var idx := Geometry2D.triangulate_polygon(pts)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	for i in idx:
		var p: Vector2 = pts[i]
		st.set_normal(Vector3(0, 0, 1))
		st.set_uv((p - mn) / (mx - mn))
		st.add_vertex(Vector3(p.x, p.y, 0))
	return st.commit()


## Texture de la livrée : modules clairs numérotés (couleur par module), couronne bleu nuit, bloc moteur à chevrons.
func _livery() -> ImageTexture:
	var W := 256
	var H := 1024
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var light := Color("f4f1ff") if tier == 5 else Color("dfe6f5")
	var navy := Color("0e0f1a") if tier == 5 else Color("1e2a55")
	var joint := Color("d9a53a") if tier >= 4 else navy
	img.fill(light)
	var yv := func(v: float) -> int: return clampi(int((1.0 - (v - 0.25) / (HULL_TOP - 0.25)) * H), 0, H)
	var band := func(y0: float, y1: float, c: Color) -> void:
		var a: int = yv.call(y1)
		var b: int = yv.call(y0)
		if b > a:
			img.fill_rect(Rect2i(0, a, W, b - a), c)
	band.call(0.25, 1.02, navy)
	band.call(CROWN.x, CROWN.y - 0.06, navy)
	var mc := [Color("ffd166"), Color("4fd8ff"), Color("ff9f6b"), Color("b388ff"), Color("9dff6b")]
	for i in MODS.size():
		var m: Vector2 = MODS[i]
		band.call(m.y - 0.12, m.y + 0.06, joint)
		band.call(m.x + 1.1, m.x + 1.13, mc[i])
		# repères du numéro de module (traits)
		for k in 4:
			var x := int(W * (k + 0.5) / 4.0) - 12
			for q in i + 1:
				img.fill_rect(Rect2i(x + q * 6, yv.call(m.x + 0.9), 3, 10), Color("2b3a6b"))
	# lignes de plaques
	var line := Color("c9a24a") if tier == 5 else Color("6f7ea8")
	for yy in range(0, H, 32):
		for x in W:
			img.set_pixel(x, yy, img.get_pixel(x, yy).lerp(line, 0.35))
	if tier > 1:
		band.call(CROWN.x + 0.62, CROWN.x + 1.35, Color("0b1226"))
		band.call(CROWN.x + 0.56, CROWN.x + 0.6, Color("4fd8ff"))
	if tier == 1:
		band.call(CROWN.y + 0.3, CROWN.y + 0.36, Color("ff6b6b"))
	var yr: int = yv.call(0.75)
	for x in range(0, W, 24):
		img.fill_rect(Rect2i(x, yr, 12, 8), Color("ffd166"))
	if tier == 5:
		for k in 8:
			var x0 := k * W / 8
			for yy in range(0, H, 2):
				var xx := x0 + int(sin(yy / 30.0) * 9.0)
				if xx >= 0 and xx < W:
					img.set_pixel(xx, yy, Color("d9a53a"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------- construction

func _build() -> void:
	var top_prof: Array = prof.filter(func(p): return p.y >= TOP0 - 1e-6)
	var body: Array = prof.filter(func(p): return p.y <= TOP0 + 1e-6)
	var m_top: StandardMaterial3D = m_hull
	if tier >= 3:
		m_top = _glass(Color("ead9ff") if tier == 5 else Color("bfeaff"), 0.32)
		m_top.emission_enabled = true
		m_top.emission = Color("3a1f6a") if tier == 5 else Color("123a5a")
	_mi(_lathe(body, 64, PI / 2.0, PI), m_hull)
	_mi(_lathe(top_prof, 48, PI / 2.0, PI), m_top)
	var inner: Array = body.map(func(p): return Vector2(maxf(0.01, p.x - 0.06), p.y))
	if tier < 3:
		inner = prof.map(func(p): return Vector2(maxf(0.01, p.x - 0.06), p.y))
	_mi(_lathe(inner, 64, PI / 2.0, PI), m_inner)
	front_parts.append(_mi(_lathe(body, 64, -PI / 2.0, PI), m_hull))
	var ft := _mi(_lathe(top_prof, 48, -PI / 2.0, PI), m_top)
	if tier < 3:
		front_parts.append(ft)
	if tier >= 3:
		for k in 8:
			var a := TAU * k / 8.0
			var pts: Array = top_prof.map(func(p): return Vector3((p.x + 0.01) * sin(a), p.y, (p.x + 0.01) * cos(a)))
			_mi(_tube(pts, 0.035, 5), m_gold if tier >= 4 else m_paint)
	# tranche de la coupe : bord clair et filet cyan
	for s in [-1.0, 1.0]:
		var outer: Array = prof.map(func(p): return Vector3(s * p.x, p.y, 0.003))
		var e1 := _mi(_tube(outer, 0.05, 5), m_deck_side)
		var l2: Array = prof.map(func(p): return Vector3(s * (p.x - 0.1), p.y, 0.01))
		var e2 := _mi(_tube(l2, 0.02, 4), _emis(Color("4fd8ff"), 1.5))
		cut_parts.append(e1)
		cut_parts.append(e2)
	# mât et feu du sommet
	_cyl(0.03, 0.07, 1.0, m_metal, Vector3(0, HULL_TOP + 0.45, 0), 8)
	for yy in [0.25, 0.55]:
		_box(Vector3(0.7 - yy * 0.6, 0.03, 0.03), m_metal, Vector3(0, HULL_TOP + yy, 0))
	_sph(0.06, _emis(Color("ff6b6b"), 3.0), Vector3(0, HULL_TOP + 1.0, 0))
	var tip := _glow(Color("ff6b6b"), 0.6, Vector3(0, HULL_TOP + 1.0, 0))
	anims.append(func(t): tip.visible = sin(t * 3.0) > 0.0)
	if tier == 2:
		for q in [[1.1, -0.9, Color("4fd8ff")], [-0.4, -1.3, Color("7dffb0")]]:
			_cyl(0.12, 0.16, 0.18, m_navy, Vector3(q[0], TOP0 + 0.88, q[1]), 12)
			_sph(0.07, _emis(q[2], 2.0), Vector3(q[0], TOP0 + 1.02, q[1]))
	# colliers (moitié avant en coque fermée seulement)
	var ys: Array = [0.6]
	for m in MODS:
		ys.append(m.y)
	ys.append(CROWN.y)
	for y in ys:
		var r := maxf(rad(y - 0.05), rad(y + 0.05)) + 0.02
		var mat := m_navy if y == 0.6 else (m_gold if tier >= 4 else m_metal)
		_mi(_tube(_arc(r, y, PI, TAU, 48), 0.075, 8), mat)
		front_parts.append(_mi(_tube(_arc(r, y, 0.0, PI, 48), 0.075, 8), mat))
	# baie vitrée de la couronne
	if tier > 1:
		var bm := _glass(Color("7fdcff"), 0.55)
		bm.emission_enabled = true
		bm.emission = Color("1a6f99")
		bm.emission_energy_multiplier = 0.8
		var band_pts := [Vector2(2.7, CROWN.x + 0.63), Vector2(2.7, CROWN.x + 1.33)]
		_mi(_lathe(band_pts, 64, PI / 2.0, PI), bm)
		front_parts.append(_mi(_lathe(band_pts, 64, -PI / 2.0, PI), bm))
	# hublots
	var pm := _emis(Color("bfefff"), 1.4)
	for m in MODS:
		var y: float = m.x + 0.95
		for k in 14:
			var a := (k + 0.5) / 14.0 * TAU
			var r := rad(y) + 0.01
			var p := _sph(0.075, pm, Vector3(r * sin(a), y, r * cos(a)), null, 6)
			p.basis = Basis.looking_at(-Vector3(p.position.x, 0, p.position.z).normalized(), Vector3.UP).scaled(Vector3(1, 1, 0.3))
			if cos(a) > 0.0:
				front_parts.append(p)
	# nom de baptême sur la couronne
	for zs in [1.0, -1.0]:
		var lb := Label3D.new()
		lb.text = "AURORE"
		lb.font_size = 64
		lb.outline_size = 0
		lb.pixel_size = 0.006
		lb.modulate = Color("ffd27a") if tier >= 4 else Color("e8eefc")
		lb.position = Vector3(0, CROWN.x + 0.3, (rad(CROWN.x + 0.3) + 0.02) * zs)
		lb.rotation.y = 0.0 if zs > 0 else PI
		ship.add_child(lb)
		if zs > 0:
			front_parts.append(lb)
	_decks()
	_rooms()
	_props()
	_engines()
	_radiators()
	_hub()
	_extras()


func _decks() -> void:
	var floors: Array = [1.0]
	for m in MODS:
		floors.append(m.y)
	if tier >= 3:
		floors.append(TOP0)
	for y in floors:
		var r := rad(y) - 0.07
		_mi(_lathe([Vector2(0.001, y + 0.05), Vector2(r, y + 0.05), Vector2(r, y - 0.05), Vector2(0.001, y - 0.05)], 48, PI / 2.0, PI), m_deck)
		_box(Vector3(2 * r, 0.1, 0.04), m_deck_side, Vector3(0, y, 0))
		_box(Vector3(2 * r, 0.018, 0.02), _emis(Color("4fd8ff"), 1.2), Vector3(0, y + 0.06, 0.02))
	for w in [[3.85, 5.15]] + ([[5.25, 6.65]] if tier >= 2 else []):
		var h: float = w[1] - w[0]
		_box(Vector3(0.08, h, 2.3), m_dark, Vector3(0, w[0] + h / 2.0, -1.17))
		_box(Vector3(0.1, h, 0.04), m_deck_side, Vector3(0, w[0] + h / 2.0, 0))
	for k in range(1, 6):
		var a := PI + k * PI / 6.0
		var pts: Array = []
		var y := 1.05
		while y < CROWN.y - 0.05:
			pts.append(Vector3((rad(y) - 0.1) * cos(a), y, (rad(y) - 0.1) * sin(a)))
			y += 0.25
		_mi(_tube(pts, 0.03, 5), m_dark)


## Salles présentes dans cette version : intervalle de hauteur, côté (-1 gauche, 0 plein, 1 droite).
func room_layout() -> Dictionary:
	var L := {
		"centrale": [1.05, 2.35, 0], "raffinerie": [2.45, 3.75, 0], "serre": [3.85, 5.15, -1], "atelier": [3.85, 5.15, 1],
		"pont": [CROWN.x + 0.05, CROWN.x + 1.55, 0],
	}
	if tier >= 2:
		L["labo"] = [5.25, 6.65, -1]
		L["quartiers"] = [5.25, 6.65, 1]
	if tier >= 3:
		L["antenne"] = [6.75, 8.05, 0]
		L["observatoire"] = [TOP0 + 0.05, TOP0 + 1.2, 0]
	return L


func _rooms() -> void:
	var L := room_layout()
	for r in L:
		var y0: float = L[r][0]
		var y1: float = L[r][1]
		var side: int = L[r][2]
		var c: Color = Ship.ROOMS[r].color
		var R := rad(y1 - 0.1) - 0.14
		var a: Array = [PI * 1.04, PI * 1.48] if side < 0 else ([PI * 1.52, PI * 1.96] if side > 0 else [PI * 1.04, PI * 1.96])
		_mi(_tube(_arc(R, y1 - 0.12, a[0], a[1]), 0.035, 6), _emis(c, 2.2))
		# lumière de salle : halo coloré (pas de lumière dynamique, trop coûteuse sur téléphone)
		_glow(c, 2.6 if side == 0 else 1.8, Vector3(0.0 if side == 0 else side * R * 0.5, y1 - 0.4, -R * 0.7), 0.22)
		var w := 2 * R if side == 0 else R
		var cx := 0.0 if side == 0 else side * R / 2.0
		if not _open(r):
			var hm := _mat(Color.WHITE, 0.0, 0.9)
			hm.albedo_texture = _hatch_tex()
			hm.uv1_scale = Vector3(w * 2.0, (y1 - y0) * 2.0, 1)
			var q := QuadMesh.new()
			q.size = Vector2(w - 0.1, y1 - y0 - 0.1)
			cut_parts.append(_mi(q, hm, Vector3(cx, (y0 + y1) / 2.0, 0.04)))
		boxes[r] = AABB(Vector3(cx - w / 2.0, y0, -R), Vector3(w, y1 - y0, R + 0.2))
		anchors[r] = Vector3(-0.9 if r == "pont" else (0.3 if side > 0 else -R * 0.95), y1 - 0.24, -0.05)


# ---------------------------------------------------------------- équipage et accessoires

func _crewman(hid: String, p: Vector3, work := false) -> void:
	var g := Node3D.new()
	g.position = p
	ship.add_child(g)
	var h: Dictionary = Data.HEROES.get(hid, {})
	var c: Color = HC.get(String(h.get("rarity", "common")), Color("7dffb0"))
	var suit := _mat(c, 0.1, 0.55)
	var white := _mat(Color("e8eefc"), 0.0, 0.5)
	for dx in [-0.055, 0.055]:
		_cyl(0.04, 0.045, 0.2, white, Vector3(dx, 0.1, 0), 8, g)
	_cyl(0.1, 0.11, 0.24, suit, Vector3(0, 0.32, 0), 12, g)
	_box(Vector3(0.16, 0.18, 0.08), white, Vector3(0, 0.34, -0.1), g)
	var arm := _cyl(0.03, 0.032, 0.2, suit, Vector3(0.13, 0.31, 0), 8, g)
	arm.rotation.z = 0.25
	_cyl(0.03, 0.032, 0.2, suit, Vector3(-0.13, 0.31, 0), 8, g).rotation.z = -0.25
	var head := _sph(0.105, white, Vector3(0, 0.53, 0), g, 12)
	var vis := _sph(0.07, _emis(c, 0.6), Vector3(0, 0.54, 0.05), g, 10)
	vis.scale = Vector3(1, 0.7, 0.6)
	g.rotation.y = atan2(-p.x * 0.2, 1.0)
	var ph := randf() * 6.0
	anims.append(func(t):
		if work:
			arm.rotation.x = -0.8 + sin(t * 6.0 + ph) * 0.35
		else:
			g.position.y = p.y + absf(sin(t * 1.8 + ph)) * 0.012
		head.rotation.y = sin(t * 0.7 + ph) * 0.4)


func _who(r: String, i := 0, fallback := "") -> String:
	var list: Array = crew.get(r, [])
	if i < list.size():
		return String(list[i])
	return fallback


func _props() -> void:
	# Centrale : confinement, cœur, faisceau
	var y := 1.06
	_cyl(0.55, 0.62, 0.14, m_metal, Vector3(0, y + 0.07, -1.05), 24)
	_cyl(0.55, 0.62, 0.14, m_metal, Vector3(0, y + 1.22, -1.05), 24)
	_cyl(0.5, 0.5, 1.04, _glass(Color("ffe9a8"), 0.16), Vector3(0, y + 0.65, -1.05), 24, null, true)
	var core := _sph(0.26, _emis(Color("ffd166"), 3.0), Vector3(0, y + 0.65, -1.05))
	var halo := _glow(Color("ffd166"), 2.4, Vector3(0, y + 0.65, -1.05), 0.9)
	var r1 := _torus(0.4, 0.022, _emis(Color("ffd166"), 1.6), Vector3(0, y + 0.65, -1.05))
	var r2 := _torus(0.34, 0.018, _emis(Color("ffb142"), 1.6), Vector3(0, y + 0.65, -1.05))
	for s in [-1.0, 1.0]:
		_cyl(0.08, 0.08, 1.25, m_metal, Vector3(s * 1.25, y + 0.42, -0.95), 12).rotation.z = PI / 2.0
		_box(Vector3(0.4, 0.55, 0.3), m_dark, Vector3(s * 1.85, y + 0.28, -0.9))
		_box(Vector3(0.26, 0.16, 0.01), _emis(Color("ffd166"), 0.9), Vector3(s * 1.85, y + 0.42, -0.74))
	anims.append(func(t):
		var k := 1.0 + sin(t * 3.0) * 0.07
		core.scale = Vector3.ONE * k
		halo.scale = Vector3.ONE * k
		r1.rotation = Vector3(t * 0.9, t * 0.4, 0)
		r2.rotation = Vector3(-t * 0.6, 0, t * 0.8))
	_crewman(_who("centrale", 0, "brix"), Vector3(-1.25, y + 0.05, -0.35), true)
	# Raffinerie : cuves de cristaux
	y = 2.45
	for i in 4:
		var x := -1.55 + i * 0.78
		_cyl(0.27, 0.29, 0.1, m_metal, Vector3(x, y + 0.05, -1.15), 20)
		_cyl(0.27, 0.27, 0.08, m_metal, Vector3(x, y + 1.1, -1.15), 20)
		_cyl(0.25, 0.25, 1.0, _glass(Color("bff4ff"), 0.14), Vector3(x, y + 0.6, -1.15), 20, null, true)
		var liq := _glass(Color("4fd8ff"), 0.55)
		liq.emission_enabled = true
		liq.emission = Color("1aa6cf")
		_cyl(0.235, 0.235, 0.56, liq, Vector3(x, y + 0.39, -1.15), 20)
		var crm := _emis(Color("bff4ff"), 1.3)
		var pr := PrismMesh.new()
		var cr := _sph(0.15, crm, Vector3(x, y + 0.62, -1.15), null, 4)
		cr.scale = Vector3(1, 1.7, 1)
		var ph := float(i)
		anims.append(func(t):
			cr.rotation.y = t * 1.1 + ph
			cr.position.y = y + 0.62 + sin(t * 1.4 + ph) * 0.05)
	_cyl(0.06, 0.06, 3.2, m_metal, Vector3(0, y + 1.2, -1.55), 10).rotation.z = PI / 2.0
	_crewman(_who("raffinerie", 0, "gorn"), Vector3(1.62, y + 0.05, -0.45))
	_crewman(_who("raffinerie", 1, "omega"), Vector3(1.12, y + 0.05, -0.85), true)
	# Atelier (droite) : établi, bras robot, caisses
	y = 3.85
	_box(Vector3(1.1, 0.08, 0.5), m_paint, Vector3(0.95, y + 0.5, -1.2))
	for dx in [-0.48, 0.48]:
		_box(Vector3(0.06, 0.5, 0.4), m_navy, Vector3(0.95 + dx, y + 0.25, -1.2))
	var arm := Node3D.new()
	arm.position = Vector3(0.75, y + 0.66, -1.3)
	ship.add_child(arm)
	_box(Vector3(0.07, 0.42, 0.07), _mat(Color("ff9f6b")), Vector3(0, 0.21, 0), arm)
	var elbow := Node3D.new()
	elbow.position.y = 0.42
	arm.add_child(elbow)
	_box(Vector3(0.06, 0.34, 0.06), _mat(Color("ff9f6b")), Vector3(0, 0.17, 0), elbow)
	var torch := _glow(Color("ffd166"), 0.45, Vector3(0, 0.36, 0), 1.0, elbow)
	for i in 4:
		_box(Vector3(0.26, 0.26, 0.26), _mat(Color("c96f3d") if i % 2 else Color("e08a4f"), 0.1, 0.7), Vector3(1.7 + (i % 2) * 0.05, y + 0.13 + (i / 2) * 0.27, -0.75 - (i % 2) * 0.32)).rotation.y = i * 0.5
	anims.append(func(t):
		arm.rotation.z = -0.35 + sin(t * 0.9) * 0.25
		elbow.rotation.z = 0.9 + sin(t * 1.3) * 0.3
		torch.visible = randf() > 0.4)
	_crewman(_who("atelier", 0, "pim"), Vector3(0.35, y + 0.05, -0.62), true)
	# Serre (gauche du module 3) : bacs de culture, lampes de croissance
	for rr in 2:
		for i in 2:
			var x := -1.55 + i * 0.85
			var z := -1.45 + rr * 0.55
			_box(Vector3(0.74, 0.22, 0.4), m_paint, Vector3(x, y + 0.16 + rr * 0.04, z))
			for p in 4:
				var l := _sph(0.08, _mat(Color("4fbf7a") if p % 2 else Color("7ddf6b"), 0.0, 0.8), Vector3(x - 0.25 + p * 0.17, y + 0.36 + rr * 0.04, z), null, 6)
				l.scale = Vector3(1, 1.5, 1)
	for i in 2:
		_box(Vector3(0.66, 0.03, 0.06), _emis(Color("ff7ad9"), 2.0), Vector3(-1.55 + i * 0.85, y + 1.1, -1.2))
	_glow(Color("ff7ad9"), 1.6, Vector3(-1.1, y + 1.0, -1.2), 0.3)
	_crewman(_who("serre", 0, "kai"), Vector3(-0.45, y + 0.05, -0.5), true)
	if tier >= 3:
		y = 6.75
		_box(Vector3(1.0, 0.55, 0.32), m_navy, Vector3(-1.05, y + 0.28, -1.62))
		var ring := _torus(0.21, 0.012, _emis(Color("ff7ad9"), 1.5), Vector3(-1.05, y + 0.8, -1.7))
		ring.rotation.x = PI / 2.0
		var sweep := _box(Vector3(0.2, 0.01, 0.01), _emis(Color("ff7ad9"), 2.0), Vector3(-1.05, y + 0.8, -1.69))
		for i in 5:
			_box(Vector3(0.09, 0.03, 0.05), _emis([Color("ff7ad9"), Color("7dffb0"), Color("ffd166"), Color("4fd8ff"), Color("ff7ad9")][i], 1.6), Vector3(-1.4 + i * 0.17, y + 0.57, -1.45))
		var dish := Node3D.new()
		var dmesh := SphereMesh.new()
		dmesh.radius = 0.55
		dmesh.height = 0.35
		dmesh.is_hemisphere = true
		var dm := _mi(dmesh, _mat(Color("e8eefc"), 0.5, 0.3), Vector3.ZERO, dish)
		dm.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		dm.rotation.z = PI / 2.0
		_sph(0.05, _emis(Color("ff7ad9"), 3.0), Vector3(-0.35, 0, 0), dish)
		if not _open("antenne"):
			dish.visible = false
		elif tier == 2:
			dish.position = Vector3(-1.25, TOP0 + 1.1, -0.55)
			dish.rotation.z = -0.9
		elif tier >= 3:
			dish.position = Vector3(-3.3, CROWN.x + 0.7, -0.6)
			_cyl(0.05, 0.05, 0.9, m_metal, Vector3(-2.85, CROWN.x + 0.7, -0.6), 8).rotation.z = PI / 2.0
		else:
			dish.position = Vector3(-3.3, y + 0.95, -0.7)
			_cyl(0.05, 0.05, 0.9, m_metal, Vector3(-2.8, y + 0.95, -0.7), 8).rotation.z = PI / 2.0
		ship.add_child(dish)
		anims.append(func(t):
			dish.rotation.y = sin(t * 0.5) * 0.6
			sweep.rotation.z = -t * 2.2)
		_crewman(_who("antenne", 0, "lumi"), Vector3(-1.62, y + 0.05, -0.6))
		for i in 3:
			_box(Vector3(0.5, 0.42, 0.3), m_navy, Vector3(0.6 + i * 0.6, y + 0.21, -1.5))
			_box(Vector3(0.4, 0.22, 0.01), _emis(Color("ff7ad9") if i % 2 else Color("4fd8ff"), 0.9), Vector3(0.6 + i * 0.6, y + 0.6, -1.66))
	if tier >= 2:
		# Labo (gauche) : écrans, paillasse, molécule
		y = 5.25
		for q in [[-1.22, Color("7dffb0")], [-0.56, Color("b388ff")]]:
			_box(Vector3(0.62, 0.44, 0.04), m_navy, Vector3(q[0], y + 0.9, -1.74))
			_box(Vector3(0.56, 0.38, 0.01), _emis(q[1], 0.85), Vector3(q[0], y + 0.9, -1.715))
		_box(Vector3(1.4, 0.07, 0.42), m_paint, Vector3(-1.0, y + 0.45, -1.15))
		_box(Vector3(1.3, 0.38, 0.36), m_navy, Vector3(-1.0, y + 0.22, -1.15))
		var mol := Node3D.new()
		mol.position = Vector3(-0.85, y + 0.95, -1.1)
		ship.add_child(mol)
		for i in 7:
			var a := TAU * i / 7.0
			_sph(0.05, _emis(Color("b388ff") if i % 2 else Color("7dffb0"), 1.6), Vector3(cos(a) * 0.2, sin(i * 1.7) * 0.12, sin(a) * 0.2), mol, 8)
		anims.append(func(t): mol.rotation = Vector3(sin(t * 0.5) * 0.3, t * 0.8, 0))
		_crewman(_who("labo", 0, "t9"), Vector3(-0.4, y + 0.05, -0.62), true)
		# Quartiers (droite) : couchettes
		for rr in 2:
			for cc in 2:
				var X := 0.55 + cc * 1.0
				var Y := y + 0.32 + rr * 0.55
				_box(Vector3(0.88, 0.08, 0.48), m_paint, Vector3(X, Y, -1.3))
				_box(Vector3(0.84, 0.08, 0.45), _mat(Color("2e7d5b"), 0.0, 0.95), Vector3(X, Y + 0.07, -1.3))
				_box(Vector3(0.2, 0.07, 0.32), white_mat(), Vector3(X - 0.28, Y + 0.14, -1.3))
		_box(Vector3(0.06, 1.15, 0.5), m_navy, Vector3(0.05, y + 0.58, -1.3))
		_crewman(_who("quartiers", 0, "neelo"), Vector3(0.4, y + 0.05, -0.42))
		_crewman(_who("quartiers", 1, "dax"), Vector3(1.55, y + 0.05, -0.55))
	if tier >= 3:
		# Observatoire : télescope, globe
		y = TOP0 + 0.06
		_cyl(0.18, 0.26, 0.3, m_navy, Vector3(0.2, y + 0.15, -0.7), 16)
		var tel := Node3D.new()
		tel.position = Vector3(0.2, y + 0.45, -0.7)
		ship.add_child(tel)
		_cyl(0.16, 0.2, 1.3, m_paint, Vector3(0, 0.45, 0), 16, tel)
		_cyl(0.17, 0.17, 0.08, _emis(Color("e6d6ff"), 1.2), Vector3(0, 1.1, 0), 16, tel)
		tel.rotation.z = -0.6
		var globe := _sph(0.28, _add_mat(Color("b388ff"), 0.5), Vector3(-0.9, y + 0.6, -0.8), null, 12)
		anims.append(func(t):
			tel.rotation.y = sin(t * 0.3) * 0.8
			globe.rotation.y = t * 0.5)
		_crewman(_who("observatoire", 0, "zyra"), Vector3(-0.4, y + 0.05, -0.4))
	# Pont : consoles, siège, baie, carte stellaire
	y = CROWN.x + 0.05
	var consoles := ["4fd8ff", "7dffb0", "ffd166", "ff7ad9", "4fd8ff", "b388ff", "4fd8ff"]
	for i in consoles.size():
		var a := PI * 0.68 + i * PI * 0.105
		var b := _box(Vector3(0.16, 0.03, 0.1), _emis(Color(consoles[i]), 2.0), Vector3(1.45 * sin(a), y + 0.4, 0.25 + 1.45 * cos(a)))
		b.rotation.y = a
		_box(Vector3(0.3, 0.38, 0.12), m_navy, Vector3(1.5 * sin(a), y + 0.19, 0.25 + 1.5 * cos(a))).rotation.y = a
	_box(Vector3(0.34, 0.08, 0.32), m_paint, Vector3(0, y + 0.28, -0.6))
	_box(Vector3(0.34, 0.42, 0.08), m_paint, Vector3(0, y + 0.5, -0.75))
	var win := _glass(Color("7fdcff"), 0.3)
	win.emission_enabled = true
	win.emission = Color("0d3a55")
	var wp: Array = prof.filter(func(p): return p.y > CROWN.x + 0.63 and p.y < CROWN.x + 1.33).map(func(p): return Vector2(p.x - 0.09, p.y))
	if wp.size() > 1:
		_mi(_lathe(wp, 32, PI * 0.7, PI * 0.6), win)
	var mp := Node3D.new()
	mp.position = Vector3(0.9, y + 0.85, -0.9)
	ship.add_child(mp)
	var disc := _cyl(0.32, 0.32, 0.01, _add_mat(Color("4fd8ff"), 0.25), Vector3.ZERO, 32, mp)
	for i in 40:
		var a := i * 2.4
		var rr := 0.03 + i * 0.007
		_sph(0.018, _emis(Color("bff4ff"), 2.0), Vector3(cos(a) * rr, 0.02 + (i % 5) * 0.01, sin(a) * rr), mp, 4)
	_cyl(0.08, 0.12, 0.8, m_navy, Vector3(0.9, y + 0.4, -0.9), 12)
	anims.append(func(t): mp.rotation.y = t * 0.4)
	_crewman(_who("pont", 0, "vance"), Vector3(0, y + 0.3, -0.55))


func white_mat() -> StandardMaterial3D:
	return _mat(Color("e8eefc"), 0.0, 0.9)


# ---------------------------------------------------------------- propulsion, radiateurs, hub, détails de version

func _flame_tex(colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.45, 1.0])
	g.colors = PackedColorArray([colors[0], colors[1], colors[2], Color(colors[2], 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 8
	t.height = 64
	return t


func _flame(r_top: float, r_bot: float, h: float, p: Vector3, tex: Texture2D) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = 24
	c.cap_top = false
	c.cap_bottom = false
	var m := _add_mat(Color.WHITE, 0.9, tex)
	var f := _mi(c, m, p)
	var base := p.y
	anims.append(func(t):
		var k := 1.0 + sin(t * 30.0 + p.x) * 0.06 + randf() * 0.05
		f.scale = Vector3(1, k, 1)
		f.position.y = base - (k - 1.0) * h * 0.5)
	return f


func _engines() -> void:
	var mt := _mat(Color("c99a3a") if tier >= 4 else Color("3a4670"), 0.92, 0.22)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tier == 1:
		# plaque de poussée qui ferme le bas de la coque
		_mi(_lathe([Vector2(2.06, 0.27), Vector2(1.95, 0.12), Vector2(1.6, 0.02), Vector2(0.01, -0.02)], 48, 0, TAU), m_navy)
		_torus(1.62, 0.05, m_metal, Vector3(0, 0.02, 0), null, 64)
		_cyl(0.75, 0.9, 0.22, m_metal, Vector3(0, -0.12, 0), 32)
		var yt := _flame_tex([Color.WHITE, Color("fff4c4"), Color("ffd166")])
		var throat := _emis(Color("ffcf7a"), 2.4)
		# quatre tuyères en carré autour de l'axe : équilibrées sous tous les angles
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0
			var p := Vector3(cos(a) * 0.9, -0.2, sin(a) * 0.9)
			_cyl(0.2, 0.24, 0.24, m_metal, p + Vector3(0, -0.02, 0), 20)
			_mi(_lathe([Vector2(0.2, -0.12), Vector2(0.13, -0.24), Vector2(0.21, -0.42), Vector2(0.33, -0.65), Vector2(0.43, -0.88), Vector2(0.4, -0.89), Vector2(0.3, -0.65), Vector2(0.19, -0.42), Vector2(0.11, -0.25)], 24, 0, TAU), mt, p)
			_torus(0.42, 0.025, m_gold, p + Vector3(0, -0.88, 0), null, 32)
			_cyl(0.13, 0.13, 0.01, throat, p + Vector3(0, -0.26, 0), 16)
			_flame(0.38, 0.08, 1.3, p + Vector3(0, -1.53, 0), yt)
			_glow(Color("ffb142"), 1.5, p + Vector3(0, -0.95, 0))
		return
	var tex := _flame_tex([Color.WHITE, Color("e6d6ff"), Color("b388ff")]) if tier == 5 else _flame_tex([Color.WHITE, Color("c9f6ff"), Color("4fd8ff")])
	_mi(_lathe([Vector2(0.62, 0.3), Vector2(0.7, 0.1), Vector2(0.86, -0.2), Vector2(1.08, -0.55), Vector2(1.26, -0.82), Vector2(1.22, -0.84), Vector2(0.6, 0.28)], 40, 0, TAU), mt)
	var core := _cyl(1.15, 1.15, 0.01, _emis(Color("bff4ff"), 2.0), Vector3(0, -0.8, 0), 32)
	var fh := 3.8 if tier == 5 else (3.0 if tier >= 3 else 2.6)
	_flame(1.05, 0.3, fh, Vector3(0, -0.85 - fh / 2.0, 0), tex)
	_glow(Color("4fd8ff"), 4.2, Vector3(0, -1.0, 0))
	var rings: Array = [[1.8, Color("ffd166")], [2.15, Color("e6d6ff")], [2.5, Color("4fd8ff")]] if tier == 5 else ([[1.85, Color("ffd166")], [2.2, Color("ffd166")]] if tier == 4 else ([[1.85, Color("4fd8ff")], [2.2, Color("b388ff")]] if tier == 3 else [[1.9, Color("4fd8ff")]]))
	for i in rings.size():
		var ry := -0.55 - i * 0.3
		_torus(rings[i][0], 0.09, _emis(rings[i][1], 2.2), Vector3(0, ry, 0), null, 96)
		_torus(rings[i][0], 0.28, _add_mat(rings[i][1], 0.12), Vector3(0, ry, 0), null, 96)
	for k in 4:
		var a := k * PI / 2.0 + PI / 4.0
		_box(Vector3(0.1, 0.85, 0.1), m_gold if tier >= 4 else m_navy, Vector3(cos(a) * 1.9, -0.1, sin(a) * 1.9))
	if tier >= 3:
		var aux := _flame_tex([Color.WHITE, Color("c9f6ff"), Color("4fd8ff")])
		for k in 4:
			var a := k * PI / 2.0
			var p := Vector3(cos(a) * 2.35, 0.1, sin(a) * 2.35)
			_mi(_lathe([Vector2(0.12, 0.2), Vector2(0.16, 0.0), Vector2(0.24, -0.25), Vector2(0.22, -0.26), Vector2(0.1, 0.18)], 16, 0, TAU), mt, p)
			_flame(0.2, 0.05, 0.9, p + Vector3(0, -0.7, 0), aux)


func _radiators() -> void:
	var rads: Array = []
	match tier:
		2:
			rads = [[2.8, 2.9, 1.7]]
		3:
			rads = [[2.1, 1.5, 1.7], [3.8, 1.5, 1.7]]
		4:
			rads = [[2.2, 1.7, 2.6], [4.1, 1.7, 2.6], [7.4, 1.1, 1.6]]
	var cell := _mat(Color("1d3a66"), 0.3, 0.3)
	cell.emission_enabled = true
	cell.emission = Color("1a3a7a")
	cell.emission_energy_multiplier = 0.4
	for s in [-1.0, 1.0]:
		for q in rads:
			var g := Node3D.new()
			g.position = Vector3(s * 2.45, 0, -0.55)
			ship.add_child(g)
			var cy: float = q[0]
			var hh: float = q[1]
			var ww: float = q[2]
			_box(Vector3(0.55, 0.12, 0.12), m_gold if tier >= 4 else m_navy, Vector3(s * 0.27, cy, 0), g)
			var panel := Node3D.new()
			panel.position = Vector3(s * (0.55 + ww / 2.0), cy, 0)
			panel.rotation.y = s * -0.25
			g.add_child(panel)
			_box(Vector3(ww + 0.06, hh + 0.06, 0.03), m_gold if tier >= 4 else m_navy, Vector3(0, 0, -0.03), panel)
			var pm := cell.duplicate() as StandardMaterial3D
			pm.albedo_texture = _cells_tex()
			pm.uv1_scale = Vector3(ww / 0.42, hh / 0.32, 1)
			_box(Vector3(ww, hh, 0.04), pm, Vector3.ZERO, panel)
			_box(Vector3(0.04, hh, 0.05), _emis(Color("ffb142"), 1.2), Vector3(s * ww / 2.0, 0, 0), panel)
			_sph(0.05, _emis(Color("ff6b6b") if s < 0 else Color("7dffb0"), 3.0), Vector3(s * (0.6 + ww), cy + hh / 2.0, -0.2), g, 8)


var _cells: ImageTexture
## Cellule de radiateur (répétée sur le panneau).
func _cells_tex() -> ImageTexture:
	if _cells == null:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color("0d1530"))
		img.fill_rect(Rect2i(1, 1, 14, 14), Color("2a5aa8"))
		img.fill_rect(Rect2i(1, 1, 14, 2), Color("4fd8ff"))
		_cells = ImageTexture.create_from_image(img)
	return _cells


func _shuttle(kind: String) -> Node3D:
	var g := Node3D.new()
	var info: Dictionary = Ship.SHUTTLES[kind]
	var acc := _mat(Color(info.color).darkened(0.15), 0.25, 0.45)
	acc.emission_enabled = true
	acc.emission = info.color
	acc.emission_energy_multiplier = 0.2
	var paint := _mat(Color("c3cce3"), 0.35, 0.45)
	var glass := _mat(Color("9fe9ff"), 0.1, 0.0)
	glass.emission_enabled = true
	glass.emission = Color("0f5a80")
	match kind:
		"colibri":
			var body := _mi(_lathe([Vector2(0.01, -0.62), Vector2(0.1, -0.6), Vector2(0.13, -0.35), Vector2(0.14, 0.05), Vector2(0.11, 0.38), Vector2(0.06, 0.62), Vector2(0.012, 0.78)], 16, 0, TAU), paint, Vector3.ZERO, g)
			body.rotation.x = PI / 2.0
			_sph(0.1, glass, Vector3(0, 0.09, 0.3), g, 10).scale = Vector3(0.75, 0.7, 2.0)
			for s in [-1.0, 1.0]:
				var w := _mi(_flat(PackedVector2Array([Vector2(0.08 * s, 0.05), Vector2(0.62 * s, 0.42), Vector2(0.66 * s, 0.52), Vector2(0.12 * s, 0.36)])), acc, Vector3.ZERO, g)
				w.rotation.x = -PI / 2.0
				w.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
		"martin":
			_box(Vector3(0.5, 0.32, 1.0), paint, Vector3.ZERO, g)
			_box(Vector3(0.52, 0.12, 1.02), m_navy, Vector3(0, -0.12, 0), g)
			_box(Vector3(0.505, 0.05, 0.7), acc, Vector3(0, 0.05, 0.05), g)
			_box(Vector3(0.36, 0.2, 0.62), acc, Vector3(0, -0.27, 0), g)
			_box(Vector3(0.4, 0.2, 0.3), paint, Vector3(0, -0.04, 0.62), g)
			_box(Vector3(0.34, 0.12, 0.02), glass, Vector3(0, 0.06, 0.78), g)
			_box(Vector3(1.15, 0.05, 0.3), m_navy, Vector3(0, 0, -0.18), g)
			for s in [-1.0, 1.0]:
				_cyl(0.1, 0.1, 0.5, paint, Vector3(0.6 * s, 0, -0.15), 12, g).rotation.x = PI / 2.0
		_:
			var body := _mi(_lathe([Vector2(0.01, -0.78), Vector2(0.08, -0.74), Vector2(0.1, -0.4), Vector2(0.1, 0.3), Vector2(0.075, 0.62), Vector2(0.03, 0.86), Vector2(0.008, 0.95)], 16, 0, TAU), paint, Vector3.ZERO, g)
			body.rotation.x = PI / 2.0
			_box(Vector3(1.64, 0.02, 0.24), paint, Vector3(0, 0, 0.0), g)
			for s in [-1.0, 1.0]:
				_cyl(0.06, 0.06, 0.45, acc, Vector3(0.86 * s, 0, -0.06), 10, g).rotation.x = PI / 2.0
			var ring := _torus(0.2, 0.025, acc, Vector3(0, 0, -0.55), g, 24)
			ring.rotation.x = PI / 2.0
	_glow(Color("7fe3ff"), 0.5, Vector3(0, 0, -0.7), 1.0, g)
	return g


func _open(r: String) -> bool:
	return opened.is_empty() or int(opened.get(r, 1)) > 0


var _hatch: ImageTexture
## Plaque rayée d'une salle encore scellée.
func _hatch_tex() -> ImageTexture:
	if _hatch == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color("0d1328"))
		for y in 32:
			for x in 32:
				if (x + y) % 16 < 6:
					img.set_pixel(x, y, Color("3a3420"))
		_hatch = ImageTexture.create_from_image(img)
	return _hatch


func _hub() -> void:
	if tier < 2 or not _open("hangar"):
		return
	var hub := Node3D.new()
	ship.add_child(hub)
	var hy := 5.2
	var hr := 3.9
	_torus(hr, 0.13, m_paint, Vector3(0, hy, 0), hub, 96)
	_torus(hr, 0.04, _emis(Color("4fd8ff"), 1.4), Vector3(0, hy + 0.13, 0), hub, 96)
	for k in 4:
		var a := PI * 1.25 + k * PI / 2.0
		var sp := _box(Vector3(hr - 2.3, 0.1, 0.18), m_navy, Vector3(cos(a) * (2.4 + hr) / 2.0, hy, sin(a) * (2.4 + hr) / 2.0), hub)
		sp.rotation.y = -a
	for a in [PI, 0.0]:
		var md := Node3D.new()
		md.position = Vector3(cos(a) * (hr + 0.3), hy + 0.1, sin(a) * (hr + 0.3))
		md.rotation.y = -a
		hub.add_child(md)
		_box(Vector3(0.75, 0.62, 0.95), m_navy, Vector3.ZERO, md)
		_box(Vector3(0.02, 0.4, 0.5), _emis(Color("4fd8ff"), 1.2), Vector3(0.38, 0, 0), md)
		_box(Vector3(0.8, 0.06, 1.0), m_paint, Vector3(0, 0.34, 0), md)
	for q in [[PI * 0.95, "martin"], [PI * 2.05, "sterne"]]:
		var s := _shuttle(q[1])
		var x: float = cos(q[0]) * (hr + 1.15)
		var z: float = sin(q[0]) * (hr + 1.15)
		s.position = Vector3(x, hy + 0.05, z)
		hub.add_child(s)
		s.basis = Basis.looking_at(-Vector3(x, 0, z).normalized(), Vector3.UP).scaled(Vector3.ONE * 1.45)
	var fly := _shuttle("colibri")
	fly.scale = Vector3.ONE * 1.45
	hub.add_child(fly)
	anims.append(func(t):
		var p := fmod(t * 0.07, 1.0)
		var a := PI * 0.25 + p * TAU * 0.9
		var r := hr + 1.2 + sin(p * PI) * 4.5
		var y := hy + 0.6 + sin(p * PI) * 2.2
		fly.position = Vector3(cos(a) * r, y, sin(a) * r - 1.5)
		var n := Vector3(cos(a + 0.05) * r, y, sin(a + 0.05) * r - 1.5)
		fly.basis = Basis.looking_at(-(n - fly.position).normalized(), Vector3.UP).scaled(Vector3.ONE * 1.45))
	boxes["hangar"] = AABB(Vector3(-hr - 1.6, hy - 0.5, -1.0), Vector3(1.6, 1.2, 2.0))
	anchors["hangar"] = Vector3(-hr - 1.6, hy + 0.7, 0.6)


func _extras() -> void:
	if tier >= 3:
		for s in [-1.0, 1.0]:
			var g := Node3D.new()
			g.position = Vector3(s * 3.05, 7.4, -0.6)
			ship.add_child(g)
			var pod := _mi(_lathe([Vector2(0.02, -0.75), Vector2(0.42, -0.7), Vector2(0.48, -0.5), Vector2(0.48, 0.5), Vector2(0.42, 0.7), Vector2(0.02, 0.75)], 24, 0, TAU), m_hull, Vector3.ZERO, g)
			pod.rotation.z = PI / 2.0
			var rg := _torus(0.49, 0.04, _emis(Color("9dff6b"), 0.8), Vector3.ZERO, g, 24)
			rg.rotation.z = PI / 2.0
			_box(Vector3(0.7, 0.18, 0.18), m_gold if tier >= 4 else m_navy, Vector3(-s * 0.75, 0, 0), g)
		var mast := Node3D.new()
		mast.position = Vector3(1.2, CROWN.y - 0.1, -1.2)
		mast.rotation.z = -0.3
		ship.add_child(mast)
		_cyl(0.03, 0.05, 1.2, m_metal, Vector3(0, 0.6, 0), 8, mast)
		_sph(0.06, _emis(Color("ff7ad9"), 2.5), Vector3(0, 1.22, 0), mast, 8)
	if tier >= 4:
		var gr := Node3D.new()
		gr.position.y = CROWN.x + 0.85
		ship.add_child(gr)
		_torus(4.9, 0.22, m_paint, Vector3.ZERO, gr, 128)
		_torus(4.9, 0.06, _emis(Color("ffd166"), 1.6), Vector3(0, 0.2, 0), gr, 128)
		for k in 6:
			var a := TAU * k / 6.0
			_box(Vector3(2.2, 0.08, 0.12), m_gold, Vector3(cos(a) * 3.75, 0, sin(a) * 3.75), gr).rotation.y = -a
			_box(Vector3(0.6, 0.4, 0.5), m_navy, Vector3(cos(a) * 4.9, 0, sin(a) * 4.9), gr).rotation.y = -a
		anims.append(func(t): gr.rotation.y = t * 0.12)
	if tier == 5:
		var crys := _mat(Color("efe6ff"), 0.1, 0.02)
		crys.emission_enabled = true
		crys.emission = Color("8f6bff")
		crys.emission_energy_multiplier = 0.6
		var spire := _sph(0.42, crys, Vector3(0, HULL_TOP + 1.25, 0), null, 4)
		spire.scale = Vector3(0.8, 3.0, 0.8)
		_glow(Color("e6d6ff"), 3.2, Vector3(0, HULL_TOP + 1.25, 0), 0.8)
		var orb := Node3D.new()
		orb.position.y = HULL_TOP + 0.9
		ship.add_child(orb)
		for i in 6:
			var a := TAU * i / 6.0
			_sph(0.11, crys, Vector3(cos(a), sin(i * 1.7) * 0.18, sin(a)), orb, 4).scale = Vector3(1, 1.8, 1)
		anims.append(func(t):
			spire.rotation.y = t * 0.5
			orb.rotation.y = -t * 0.6)
		var arm := Node3D.new()
		arm.position.y = CROWN.x + 0.85
		ship.add_child(arm)
		var specs := [[3.5, 0.35, Color("ffd166")], [3.75, -0.5, Color("e6d6ff")], [4.0, 1.1, Color("4fd8ff")]]
		for i in 3:
			var g := Node3D.new()
			g.rotation = Vector3(i * 0.6 + PI / 2.0, 0, specs[i][1])
			arm.add_child(g)
			_torus(specs[i][0], 0.045, m_gold, Vector3.ZERO, g, 128)
			_torus(specs[i][0], 0.14, _add_mat(specs[i][2], 0.14), Vector3.ZERO, g, 128)
			var sp := 0.18 + i * 0.07
			var sg := -1.0 if i % 2 else 1.0
			anims.append(func(t): g.rotation.y = t * sp * sg)
		var sail_tex := GradientTexture2D.new()
		var sg2 := Gradient.new()
		sg2.colors = PackedColorArray([Color("7fe9ff"), Color("c9a8ff"), Color("ffd166aa")])
		sg2.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		sail_tex.gradient = sg2
		sail_tex.fill_from = Vector2(0, 0)
		sail_tex.fill_to = Vector2(1, 1)
		var sails: Array = []
		for s in [-1.0, 1.0]:
			for q in [[1.4, 3.3, 3.1], [5.6, 2.2, 2.2]]:
				var h: float = q[1]
				var w: float = q[2]
				var pts := PackedVector2Array()
				for i in 13:
					var tt := i / 12.0
					pts.append(Vector2(lerpf(0, w, tt * tt), h * 0.95 * pow(tt, 1.3)))
				pts.append(Vector2(w * 0.82, h))
				for i in 12:
					var tt := 1.0 - i / 12.0
					pts.append(Vector2(w * 0.8 * tt, h * (0.7 + 0.3 * tt)))
				var g := Node3D.new()
				g.position = Vector3(s * 2.55, q[0], -0.6)
				g.scale.x = s
				g.rotation.y = s * -0.3
				ship.add_child(g)
				var m := _mi(_flat(pts), _add_mat(Color.WHITE, 0.85, sail_tex), Vector3.ZERO, g)
				sails.append(m)
				_sph(0.07, _emis(Color("ffd166"), 3.0), Vector3(w, h * 0.95, 0), g, 8)
		anims.append(func(t):
			for i in sails.size():
				(sails[i] as MeshInstance3D).material_override.albedo_color.a = 0.7 + sin(t * 1.6 + i) * 0.2)
		_glow(Color("b388ff"), 16.0, Vector3(0, 5.2, -3.5), 0.28)
		_glow(Color("ffd166"), 9.0, Vector3(0, 3.2, -2.5), 0.18)
		var dust := CPUParticles3D.new()
		dust.amount = 160
		dust.lifetime = 14.0
		dust.preprocess = 14.0
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		dust.emission_ring_radius = 4.6
		dust.emission_ring_inner_radius = 2.6
		dust.emission_ring_height = 0.5
		dust.emission_ring_axis = Vector3.UP
		dust.direction = Vector3.UP
		dust.spread = 8.0
		dust.gravity = Vector3.ZERO
		dust.initial_velocity_min = 0.6
		dust.initial_velocity_max = 1.4
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.14)
		var dm := _add_mat(Color("ffe9b0"), 1.0, _glow_tex.get(Color("ffd166").to_html(), null))
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		q.material = dm
		dust.mesh = q
		dust.position.y = -3.0
		ship.add_child(dust)
