extends Node3D
## Scène 3D de la Route : le convoi vole vers l'étape (distorsion, étoiles qui défilent), puis l'étape apparaît avec son décor et son action
## (combat, récolte, repos, épave…). Caméra de poursuite derrière le convoi. Pure mise en scène : la logique est dans RouteSim, RouteUI relie les deux.
## Les modèles viennent de assets/models/*.glb (générés avec Blender par tools/blender/build_assets.py) ; le nez pointe vers -Z.

signal arrived
signal fx_done

const FAR_Z := 150.0
const NEAR_Z := 15.0
const TRAVEL_TIME := 1.3
## Distance d'arrêt et échelle de chaque décor (le convoi est à z = 0, la caméra à z = 12).
const STOP := {"combat": [16.0, 1.6], "elite": [16.0, 1.6], "gardien": [30.0, 1.15], "recolte": [24.0, 1.0], "epave": [24.0, 1.4], "repos": [28.0, 1.1], "inconnu": [22.0, 1.4]}
const TINTS := {"ceinture": Color("ffaa3c"), "nebuleuse": Color("aa5aff"), "guerre": Color("ff4646"), "cimetiere": Color("6ec8a0"), "havre": Color("46aaff")}

const NOISE := """
float hs(vec3 p){p=fract(p*.3183099+.1);p*=17.;return fract(p.x*p.y*p.z*(p.x+p.y+p.z));}
float nz(vec3 x){vec3 i=floor(x),f=fract(x);f=f*f*(3.-2.*f);
 return mix(mix(mix(hs(i),hs(i+vec3(1,0,0)),f.x),mix(hs(i+vec3(0,1,0)),hs(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(hs(i+vec3(0,0,1)),hs(i+vec3(1,0,1)),f.x),mix(hs(i+vec3(0,1,1)),hs(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 p){float a=.5,s=0.;for(int i=0;i<4;i++){s+=a*nz(p);p=p*2.03+vec3(1.7,9.2,3.1);a*=.5;}return s;}
"""

const SKY_SHADER := "shader_type sky;\nuniform vec3 c1 = vec3(0.5,0.27,1.0);\nuniform vec3 c2 = vec3(0.13,0.5,1.0);\n" + NOISE + """
void sky() {
	vec3 d = EYEDIR;
	vec3 p = d * 2.4;
	float n1 = fbm(p + vec3(0.,0.,TIME*0.01));
	float n2 = fbm(p*1.7 + vec3(7.3,1.2,TIME*0.015));
	float band = smoothstep(.15,.95,1.-abs(d.y*1.4+n1*.35-.1));
	float cl = smoothstep(.38,.85,n1)*band;
	vec3 col = c1*cl*1.15 + c2*smoothstep(.4,.9,n2)*band*.9;
	col += vec3(.012,.016,.035);
	vec3 q = d*220.; vec3 qi = floor(q);
	float st = hs(qi); float tw = step(.9965,st);
	vec3 qf = fract(q)-.5;
	col += vec3(.9,.95,1.) * tw * (.5+.5*hs(qi+3.)) * smoothstep(.55,0.,length(qf)) * 1.4;
	COLOR = col;
}
"""

const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, fog_disabled, cull_disabled;
uniform float offset = 0.0;
uniform float stretch = 0.4;
void vertex() {
	vec3 p = VERTEX;
	p.z = mod(p.z + offset, 420.0) - 400.0;
	if (UV.x > 0.5) p.z -= stretch;
	VERTEX = p;
}
void fragment() { ALBEDO = COLOR.rgb; ALPHA = 1.0; }
"""

const PLANET_SHADER := "shader_type spatial;\nrender_mode unshaded, fog_disabled;\nuniform vec3 c1 = vec3(0.1,0.2,0.45);\nuniform vec3 c2 = vec3(0.4,0.6,0.35);\nuniform vec3 lp = vec3(-0.75,0.3,0.45);\nuniform float t = 0.0;\nvarying vec3 wn;\nvarying vec3 op;\n" + NOISE + """
void vertex() { wn = normalize(mat3(MODEL_MATRIX) * NORMAL); op = normalize(VERTEX); }
void fragment() {
	vec3 n = normalize(wn);
	float land = fbm(op*3.2+1.3); float lm = smoothstep(.48,.54,land);
	float ice = smoothstep(.78,.92,abs(op.y)+land*.15);
	vec3 col = mix(c1*.7, c2, lm); col = mix(col, vec3(.9,.95,1.), ice);
	float cl = smoothstep(.5,.78,fbm(op*5.5+vec3(t*.01,0.,t*.006)));
	float df = dot(n, normalize(lp)); float l = smoothstep(-.12,.5,df);
	vec3 lit = col*(l*2.0+.06); lit = mix(lit, vec3(1.)*(l*1.2+.05), cl*.8);
	float night = smoothstep(.1,-.25,df);
	float city = step(.72,fbm(op*22.))*lm*(1.-ice)*night;
	lit += vec3(1.,.75,.35)*city*1.3;
	ALBEDO = lit;
}
"""

const ATMO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, fog_disabled;
uniform vec3 col = vec3(0.4,0.7,1.0);
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.6);
	ALBEDO = col * f * 1.4; ALPHA = f * 0.9;
}
"""

const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 col = vec3(0.3,0.9,1.0);
uniform float a = 0.0;
void fragment() {
	float f = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	ALBEDO = col * (f*1.6+.15); ALPHA = (f*.9+.1) * a;
}
"""

var env: Environment
var sky_mat: ShaderMaterial
var cam: Camera3D
var fleet: Node3D
var ships: Array = []                # [joueur, escorte gauche, escorte droite]
var flames: Array = []               # {node, base}
var stars_mat: ShaderMaterial
var planet: MeshInstance3D
var planet_mat: ShaderMaterial
var atmo: MeshInstance3D
var atmo_mat: ShaderMaterial
var lights: Array = []
var glow_tex: GradientTexture2D
var fire_tex: GradientTexture2D
var smoke_tex: GradientTexture2D

var obj: Node3D
var obj_type := ""
var enemies: Array = []
var mode := "idle"                   # idle, travel, arrived, leave
var t := 0.0
var mode_t := 0.0
var speed := 6.0
var star_offset := 0.0
var obj_d := FAR_Z
var obj_dir := 0.0
var bank := 0.0
var bank_target := 0.0
var fov_k := 0.0
var shake := 0.0
var warp := 0.0                      # 0 à 1 : lu par RouteUI pour le flou radial
var flash := 0.0
var hit := 0.0
var theme_id := "ceinture"
var mod_id := ""
var beam_node: MeshInstance3D
var beam_t := -1.0
var heal_t := 0.0
var reduce_motion := false
var _models := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_make_textures()
	_build_environment()
	_build_lights()
	_build_stars()
	_build_planet()
	_build_fleet()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 66.0
	cam.near = 0.1
	cam.far = 1400.0
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 3.1, 12.0)
	cam.look_at(Vector3(0, -2.2, -14.0))
	set_theme(theme_id, mod_id)


# ---------- construction ----------

func _make_textures() -> void:
	glow_tex = _radial([[0.0, Color(1, 1, 1, 1)], [0.22, Color(1, 1, 1, 0.5)], [1.0, Color(1, 1, 1, 0)]])
	fire_tex = _radial([[0.0, Color(1, 0.98, 0.86, 1)], [0.25, Color(1, 0.78, 0.35, 0.95)], [0.55, Color(1, 0.35, 0.12, 0.6)], [1.0, Color(0.3, 0.04, 0, 0)]])
	smoke_tex = _radial([[0.0, Color(0.24, 0.22, 0.23, 0.85)], [0.6, Color(0.16, 0.14, 0.16, 0.4)], [1.0, Color(0.12, 0.11, 0.12, 0)]])


func _radial(stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _additive(tint: Color, tex: Texture2D = null, billboard: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = tint
	m.vertex_color_use_as_albedo = true
	if tex != null:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


func _glow(color: Color, size: float, opacity: float = 1.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _additive(Color(color.r, color.g, color.b, opacity), glow_tex)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sky_mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _build_lights() -> void:
	# les trois lumières du studio Blender : blanche chaude, bleue, orange
	for d in [[Vector3(6, 7, 4), Color(1, 0.95, 0.88), 1.5], [Vector3(-7, 3, -2), Color(0.45, 0.6, 1.0), 0.8], [Vector3(0, -2, -8), Color(1, 0.5, 0.35), 1.1]]:
		var l := DirectionalLight3D.new()
		l.light_color = d[1]
		l.light_energy = d[2]
		l.shadow_enabled = false
		add_child(l)
		l.position = d[0] * 6.0
		l.look_at(Vector3.ZERO)
		lights.append(l)


func _build_stars() -> void:
	var n := 900
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in n:
		var a := _rng.randf() * TAU
		var r := 6.0 + pow(_rng.randf(), 0.6) * 110.0
		var p := Vector3(cos(a) * r, sin(a) * r * 0.7, -_rng.randf() * 400.0)
		var b := 0.4 + _rng.randf() * 0.6
		var c := Color(b, b * 0.8, b) if i % 6 == 0 else Color(b * 0.85, b * 0.92, b)
		for k in 2:
			verts.append(p)
			uvs.append(Vector2(float(k), 0.0))
			cols.append(c)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.custom_aabb = AABB(Vector3(-200, -200, -500), Vector3(400, 400, 600))
	var sh := Shader.new()
	sh.code = STAR_SHADER
	stars_mat = ShaderMaterial.new()
	stars_mat.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = stars_mat
	mi.extra_cull_margin = 16384.0
	add_child(mi)


func _build_planet() -> void:
	var sh := Shader.new()
	sh.code = PLANET_SHADER
	planet_mat = ShaderMaterial.new()
	planet_mat.shader = sh
	var sphere := SphereMesh.new()
	sphere.radius = 80.0
	sphere.height = 160.0
	sphere.radial_segments = 48
	sphere.rings = 24
	planet = MeshInstance3D.new()
	planet.mesh = sphere
	planet.material_override = planet_mat
	planet.position = Vector3(-210, 70, -560)
	add_child(planet)
	var ash := Shader.new()
	ash.code = ATMO_SHADER
	atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = ash
	var big := SphereMesh.new()
	big.radius = 90.0
	big.height = 180.0
	big.radial_segments = 32
	big.rings = 16
	atmo = MeshInstance3D.new()
	atmo.mesh = big
	atmo.material_override = atmo_mat
	atmo.position = planet.position
	add_child(atmo)


func _build_fleet() -> void:
	fleet = Node3D.new()
	add_child(fleet)
	var specs := [[Vector3.ZERO, 0.68, true], [Vector3(-4.2, -0.5, 2.4), 0.4, false], [Vector3(4.2, -0.5, 2.4), 0.4, false]]
	for s in specs:
		var holder := Node3D.new()
		holder.position = s[0]
		fleet.add_child(holder)
		var m := _model("player")
		m.scale = Vector3.ONE * float(s[1])
		holder.add_child(m)
		ships.append(holder)
		for sd in [-1.0, 1.0]:
			var f := _flame(Color(0.35, 0.9, 1.0), 3.4 if s[2] else 2.5, 0.22)
			f.position = Vector3(sd * 0.72 * float(s[1]), 0.0, 2.78 * float(s[1]))
			holder.add_child(f)
			flames.append(f)
		var sh := _shield(Color(0.3, 0.9, 1.0))
		sh.position = Vector3(0, 0, 0.2)
		sh.scale = Vector3(1.35, 0.8, 1.9) * 1.6 * float(s[1]) / 0.68
		holder.add_child(sh)
		holder.set_meta("shield", sh)


func _flame(color: Color, length: float, radius: float) -> Node3D:
	var root := Node3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = 0.0
	cone.height = length
	cone.radial_segments = 10
	cone.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = _additive(Color(color.r, color.g, color.b, 0.55), null, false)
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = Vector3(0, 0, length * 0.5)
	root.add_child(mi)
	var core := CylinderMesh.new()
	core.top_radius = radius * 0.45
	core.bottom_radius = 0.0
	core.height = length * 0.6
	core.radial_segments = 8
	core.rings = 1
	var mc := MeshInstance3D.new()
	mc.mesh = core
	mc.material_override = _additive(Color(1, 1, 1, 0.8), null, false)
	mc.rotation_degrees = Vector3(90, 0, 0)
	mc.position = Vector3(0, 0, length * 0.3)
	root.add_child(mc)
	root.add_child(_glow(color, radius * 5.0, 0.6))
	root.set_meta("parts", [mi, mc])
	return root


func _shield(color: Color) -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = SHIELD_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("a", 0.0)
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 20
	sp.rings = 10
	var mi := MeshInstance3D.new()
	mi.mesh = sp
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------- modèles ----------

func _model(name: String) -> Node3D:
	if not _models.has(name):
		_models[name] = load("res://assets/models/%s.glb" % name)
	var scene: PackedScene = _models[name]
	if scene == null:
		return Node3D.new()
	var inst: Node3D = scene.instantiate()
	for mi in _meshes(inst):
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var c: StandardMaterial3D = m.duplicate()
				c.resource_name = m.resource_name
				if c.resource_name == "rock":
					c.albedo_color = c.albedo_color * 0.5
				mi.set_surface_override_material(s, c)
	return inst


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _find(n: Node, prefix: String) -> Array:
	var out: Array = []
	if String(n.name).begins_with(prefix):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find(c, prefix))
	return out


# ---------- thème ----------

func set_theme(p_theme: String, p_mod: String) -> void:
	theme_id = p_theme
	mod_id = p_mod
	var c: Color = TINTS.get(p_theme, Color("6688ff"))
	sky_mat.set_shader_parameter("c1", Vector3(c.r, c.g, c.b) * 0.6)
	var c2 := c
	c2.h = fposmod(c.h + 0.35, 1.0)
	sky_mat.set_shader_parameter("c2", Vector3(c2.r, c2.g, c2.b) * 0.55)
	var pc1 := c * 0.28 + Color(0.04, 0.09, 0.19)
	var pc2 := c
	pc2.h = fposmod(c.h + 0.02, 1.0)
	pc2.s *= 0.75
	pc2.v *= 0.7
	planet_mat.set_shader_parameter("c1", Vector3(pc1.r, pc1.g, pc1.b))
	planet_mat.set_shader_parameter("c2", Vector3(pc2.r, pc2.g, pc2.b))
	var ac := c.lerp(Color(0.53, 0.8, 1.0), 0.5)
	atmo_mat.set_shader_parameter("col", Vector3(ac.r, ac.g, ac.b))
	var side := 1.0 if p_theme in ["guerre", "nebuleuse"] else -1.0
	planet.position = Vector3(side * 210.0, 70.0, -560.0)
	atmo.position = planet.position
	var lp := Vector3(-side * 0.75, 0.3, 0.45).normalized()
	planet_mat.set_shader_parameter("lp", lp)
	flash = 1.0


# ---------- étapes ----------

func _clear_obj() -> void:
	if obj != null:
		obj.queue_free()
		obj = null
	enemies = []
	beam_t = -1.0
	if beam_node != null:
		beam_node.queue_free()
		beam_node = null


func _build_obj(type: String) -> Node3D:
	var root := Node3D.new()
	match type:
		"combat", "elite":
			var n := 4 if type == "elite" else 3
			for k in n:
				var e := _model("elite" if type == "elite" else "enemy")
				e.scale = Vector3.ONE * (1.25 if type == "elite" else 1.0)
				e.rotation_degrees = Vector3(28, 180, 0)
				var home := Vector3((k - (n - 1) / 2.0) * 6.2, (k % 2) * 2.2 - 0.6, (k % 2) * -3.0)
				e.position = home
				e.set_meta("home", home)
				e.set_meta("ph", _rng.randf() * 6.0)
				var col := Color(1, 0.23, 0.29) if type == "elite" else Color(1, 0.54, 0.16)
				var g := _glow(col, 3.2, 0.7)
				g.position = Vector3(0, 0.1, -0.9)      # l'œil est à l'avant du modèle (avant = -Z local, retourné vers le convoi par la rotation)
				e.add_child(g)
				var f := _flame(col, 2.2, 0.28)
				f.position = Vector3(0, 0, 1.7)
				e.add_child(f)
				if type == "elite":
					var sh := _shield(col)
					sh.scale = Vector3(1.4, 0.9, 2.0)
					e.add_child(sh)
					e.set_meta("shield", sh)
					sh.material_override.set_shader_parameter("a", 0.25)
				root.add_child(e)
				enemies.append(e)
		"gardien":
			var b := _model("boss")
			b.rotation_degrees = Vector3(0, 180, 0)
			b.scale = Vector3.ONE * 0.95
			var gl := _glow(Color(1, 0.35, 0.8), 18.0, 0.9)
			gl.position = Vector3(0, 0, 3.2)
			root.add_child(b)
			root.add_child(gl)
			var sh2 := _shield(Color(1, 0.35, 0.8))
			sh2.scale = Vector3(8.0, 6.0, 7.0)
			root.add_child(sh2)
			sh2.material_override.set_shader_parameter("a", 0.18)
			root.set_meta("shield", sh2)
			root.set_meta("boss", b)
			enemies.append(root)
		"recolte":
			var rocks: Array = []
			for k in 14:
				var a := _model("asteroid%d" % (1 + _rng.randi() % 3))
				var sc := _rng.randf_range(0.8, 2.4)
				a.scale = Vector3(sc * _rng.randf_range(0.9, 1.3), sc * _rng.randf_range(0.8, 1.2), sc * _rng.randf_range(0.9, 1.3))
				a.rotation = Vector3(_rng.randf() * 6.0, _rng.randf() * 6.0, _rng.randf() * 6.0)
				var ang := _rng.randf() * TAU
				var rr := _rng.randf_range(1.5, 10.0)
				a.position = Vector3(cos(ang) * rr, _rng.randf_range(-2.5, 2.5), sin(ang) * rr * 0.6)
				a.set_meta("spin", Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 0.7)
				root.add_child(a)
				rocks.append(a)
			root.set_meta("rocks", rocks)
		"epave":
			var w := _model("wreck")
			w.scale = Vector3.ONE * 1.3
			root.add_child(w)
			var scraps := _find(w, "scrap")
			for s in scraps:
				s.set_meta("spin", Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 0.8)
			root.set_meta("scraps", scraps)
			root.set_meta("wreck", w)
			var l := OmniLight3D.new()
			l.light_color = Color(1, 0.55, 0.2)
			l.light_energy = 3.0
			l.omni_range = 30.0
			l.position = Vector3(1, 0.7, -1)
			root.add_child(l)
			root.set_meta("fire", l)
		"repos":
			var s := _model("station")
			root.add_child(s)
			var spin := Node3D.new()
			s.add_child(spin)
			var movers: Array = []
			for p in ["ring", "window", "spoke"]:
				movers.append_array(_find(s, p))
			for nd in movers:
				var tr: Transform3D = nd.transform
				nd.get_parent().remove_child(nd)
				spin.add_child(nd)
				nd.transform = tr
			root.rotation_degrees = Vector3(20, 0, 0)
			root.set_meta("spin", spin)
			var lt := OmniLight3D.new()
			lt.light_color = Color(0.3, 1, 0.6)
			lt.light_energy = 2.0
			lt.omni_range = 40.0
			root.add_child(lt)
		_:
			var rings: Array = []
			for k in 5:
				var tm := TorusMesh.new()
				tm.inner_radius = 2.0 + k * 1.6 - 0.09
				tm.outer_radius = 2.0 + k * 1.6 + 0.09
				tm.rings = 48
				tm.ring_segments = 8
				var mi := MeshInstance3D.new()
				mi.mesh = tm
				mi.rotation_degrees = Vector3(90, 0, 0)
				mi.material_override = _additive(Color(0.35, 0.9, 1.0, 0.85) if k % 2 == 0 else Color(0.55, 0.5, 1.0, 0.85), null, false)
				root.add_child(mi)
				rings.append(mi)
			root.add_child(_glow(Color(0.7, 0.95, 1.0), 9.0, 1.0))
			root.set_meta("rings", rings)
	return root


## Le convoi se dirige vers l'étape `type` ; `arrived` est émis à l'arrivée. dir : -1 (gauche) à 1 (droite).
func travel(type: String, dir: float = 0.0) -> void:
	_clear_obj()
	obj = _build_obj(type)
	obj_type = type
	obj.position = Vector3(dir * 7.0, 1.2, -FAR_Z)
	obj.scale = Vector3.ONE * float(STOP.get(type, [NEAR_Z, 1.6])[1])
	add_child(obj)
	obj_d = FAR_Z
	obj_dir = dir
	mode = "travel"
	mode_t = 0.0
	bank_target = -dir * 0.5
	flash = maxf(flash, 0.4)


func leave() -> void:
	if obj != null and mode != "leave":
		mode = "leave"
		mode_t = 0.0


func _after(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Combat : tirs échangés puis explosions (victoire) ou explosion du convoi (défaite). `fx_done` à la fin.
func fight(win: bool, guard: bool) -> void:
	if obj == null:
		fx_done.emit()
		return
	var shots := 14 if guard else 9
	var targets: Array = enemies if not enemies.is_empty() else [obj]
	var guns: Array[Node3D] = [ships[0], ships[0], ships[1], ships[2]]
	for i in shots:
		var from := guns[i % 4].global_position + Vector3((-0.8 if i % 2 == 0 else 0.8) if i % 4 < 2 else 0.0, 0, -1.6)
		var tg: Node3D = targets[i % targets.size()]
		_laser(from, tg.global_position, Color(0.35, 0.9, 1.0))
		get_tree().create_timer(0.15).timeout.connect(func(): _hit_shield(tg))
		if not win and i % 2 == 0:
			var f2 := tg.global_position
			get_tree().create_timer(0.12).timeout.connect(func(): _laser(f2, ships[0].global_position, Color(1, 0.35, 0.2)))
		await _after(0.095 if guard else 0.085)
	await _after(0.5)
	if win:
		if guard:
			for b in 7:
				_explosion(obj.global_position + Vector3(_rng.randf_range(-7, 7), _rng.randf_range(-4, 4), _rng.randf_range(-3, 3)), 3.0 + _rng.randf() * 2.4)
				shake = 0.6
				await _after(0.15)
			obj.visible = false
		else:
			for e in targets:
				_explosion(e.global_position, 2.4)
				e.visible = false
				shake = 0.6
				await _after(0.17)
	else:
		_explosion(ships[0].global_position, 1.8)
		shake = 1.0
		flash = 0.7
		hit = 1.0
	await _after(0.8)
	fx_done.emit()


func _hit_shield(tg: Node3D) -> void:
	if not is_instance_valid(tg):
		return
	var sh = tg.get_meta("shield") if tg.has_meta("shield") else null
	if sh is MeshInstance3D:
		(sh.material_override as ShaderMaterial).set_shader_parameter("a", 1.0)


func _laser(from: Vector3, to: Vector3, color: Color) -> void:
	var m := BoxMesh.new()
	m.size = Vector3(0.14, 0.14, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _additive(Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.95), null, false)
	add_child(mi)
	mi.global_position = from
	mi.look_at(to)
	mi.add_child(_glow(color, 2.8, 0.9))
	var d := maxf(0.25, from.distance_to(to) / 150.0)
	var tw := create_tween()
	tw.tween_property(mi, "global_position", to, d)
	tw.tween_callback(func():
		_burst(to, 8, 6.0, Color(1, 0.8, 0.4), 0.4)
		if color.r > 0.9 and color.g < 0.5:
			(ships[0].get_meta("shield").material_override as ShaderMaterial).set_shader_parameter("a", 1.0)
			hit = maxf(hit, 0.5)
		mi.queue_free())


func harvest() -> void:
	if obj == null:
		fx_done.emit()
		return
	beam_node = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.35
	c.bottom_radius = 0.35
	c.height = 1.0
	c.radial_segments = 10
	beam_node.mesh = c
	beam_node.material_override = _additive(Color(0.35, 0.94, 1.0, 0.55), null, false)
	add_child(beam_node)
	beam_t = 0.0
	await _after(1.25)
	leave()
	await _after(0.9)
	fx_done.emit()


func rest() -> void:
	heal_t = 1.2
	for k in 3:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.94
		tm.outer_radius = 1.0
		tm.rings = 40
		tm.ring_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = _additive(Color(0.3, 1.0, 0.6, 0.9), null, false)
		add_child(mi)
		mi.global_position = ships[0].global_position
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * 9.0, 0.9)
		tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.9)
		tw.chain().tween_callback(mi.queue_free)
		await _after(0.25)
	await _after(1.0)
	leave()
	await _after(0.9)
	fx_done.emit()


func event_fx(ok: bool) -> void:
	var col := Color(1, 0.85, 0.4) if ok else Color(1, 0.35, 0.3)
	_burst(ships[0].global_position + Vector3(0, 1, -4), 50 if ok else 25, 9.0 if ok else 6.0, col, 1.1)
	if not ok:
		shake = 0.5
		flash = 0.5
		hit = 0.7
	await _after(0.9)
	leave()
	await _after(0.9)
	fx_done.emit()


func win_fx() -> void:
	flash = 1.0
	speed = 300.0
	for k in 4:
		_burst(ships[0].global_position + Vector3(_rng.randf_range(-6, 6), 2 + _rng.randf() * 3, -6), 40, 12.0, Color(1, 0.82, 0.38) if k % 2 == 1 else Color(0.35, 0.9, 1.0), 1.4)
		await _after(0.22)


# ---------- effets ----------

func _burst(pos: Vector3, n: int, vel: float, color: Color, life: float) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.3
	p.initial_velocity_max = vel * 1.2
	p.gravity = Vector3.ZERO
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	p.mesh = q
	var m := _additive(color, glow_tex)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	p.material_override = m
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = g
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


func _explosion(pos: Vector3, size: float) -> void:
	var fl := _glow(Color(1, 0.94, 0.75), size * 2.6, 1.0)
	add_child(fl)
	fl.global_position = pos
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fl, "scale", Vector3.ONE * 1.8, 0.4)
	tw.tween_property(fl.material_override, "albedo_color:a", 0.0, 0.4)
	tw.chain().tween_callback(fl.queue_free)
	for f in 5:
		var q := QuadMesh.new()
		q.size = Vector2(size * 3.0, size * 3.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = _additive(Color(1, 1, 1, 1), fire_tex)
		add_child(mi)
		mi.global_position = pos + Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.4, 0.4)) * size
		mi.scale = Vector3.ONE * 0.3
		var t2 := create_tween()
		t2.set_parallel(true)
		t2.tween_property(mi, "scale", Vector3.ONE * (1.0 + _rng.randf() * 0.7), 0.8).set_delay(f * 0.05)
		t2.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.8).set_delay(f * 0.05)
		t2.chain().tween_callback(mi.queue_free)
	for s in 3:
		var q2 := QuadMesh.new()
		q2.size = Vector2(size * 3.2, size * 3.2)
		var sm := MeshInstance3D.new()
		sm.mesh = q2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = smoke_tex
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color(1, 1, 1, 0.7)
		sm.material_override = mat
		add_child(sm)
		sm.global_position = pos + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5), 0) * size
		sm.scale = Vector3.ONE * 0.4
		var t3 := create_tween()
		t3.set_parallel(true)
		t3.tween_property(sm, "scale", Vector3.ONE * 1.4, 1.8).set_delay(0.15)
		t3.tween_property(mat, "albedo_color:a", 0.0, 1.8).set_delay(0.15)
		t3.chain().tween_callback(sm.queue_free)
	_burst(pos, 60, size * 7.0, Color(1, 0.65, 0.25), 1.1)
	_burst(pos, 25, size * 4.0, Color(1, 0.95, 0.8), 0.7)
	# éclats de métal
	for d in 8:
		var bx := BoxMesh.new()
		bx.size = Vector3(0.5, 0.12, 0.35) * size
		var dm := MeshInstance3D.new()
		dm.mesh = bx
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = Color(0.25, 0.27, 0.3)
		sm2.metallic = 0.8
		sm2.roughness = 0.5
		sm2.emission_enabled = true
		sm2.emission = Color(1, 0.4, 0.12)
		sm2.emission_energy_multiplier = 1.5
		dm.material_override = sm2
		add_child(dm)
		dm.global_position = pos
		var dir := Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5).normalized() * _rng.randf_range(4.0, 10.0) * size
		var t4 := create_tween()
		t4.set_parallel(true)
		t4.tween_property(dm, "global_position", pos + dir * 1.4, 1.6)
		t4.tween_property(dm, "rotation", Vector3(_rng.randf() * 12.0, _rng.randf() * 8.0, 0), 1.6)
		t4.tween_property(sm2, "emission_energy_multiplier", 0.0, 1.6)
		t4.chain().tween_callback(dm.queue_free)


# ---------- boucle ----------

func _process(delta: float) -> void:
	t += delta
	var tgt := 6.0
	if mode == "travel":
		mode_t += delta
		var dur := 0.5 if reduce_motion else TRAVEL_TIME
		var q := clampf(mode_t / dur, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - q, 2.2)
		var near: float = float(STOP.get(obj_type, [NEAR_Z, 1.6])[0])
		obj_d = FAR_Z - (FAR_Z - near) * e
		tgt = 30.0 if reduce_motion else (260.0 if q < 0.72 else 260.0 * (1.0 - (q - 0.72) / 0.28) + 6.0)
		if obj != null:
			obj.position.x = lerpf(obj_dir * 14.0, 0.0, e)
		if q >= 1.0:
			mode = "arrived"
			bank_target = 0.0
			arrived.emit()
	elif mode == "leave":
		tgt = 30.0 if reduce_motion else 220.0
		obj_d -= delta * 95.0
		bank_target = 0.0
		if obj_d < -30.0:
			_clear_obj()
			mode = "idle"
	speed += (tgt - speed) * minf(1.0, delta * 6.0)
	fov_k += (minf(1.0, speed / 260.0) - fov_k) * minf(1.0, delta * 8.0)
	warp = 0.0 if reduce_motion else fov_k
	bank += (bank_target - bank) * minf(1.0, delta * 4.0)
	star_offset += speed * delta
	stars_mat.set_shader_parameter("offset", star_offset)
	stars_mat.set_shader_parameter("stretch", 0.35 if reduce_motion else maxf(0.35, speed * 0.045))
	planet_mat.set_shader_parameter("t", t)
	planet.rotation.y += delta * 0.008
	# convoi : flotte, penche en virage, flammes qui crépitent
	for i in ships.size():
		var s: Node3D = ships[i]
		s.rotation.z = bank + sin(t * 1.4 + i) * 0.05
		s.rotation.x = sin(t * 1.1 + i * 2.0) * 0.03
		var base_y := 0.0 if i == 0 else -0.5
		s.position.y = base_y + sin(t * 1.6 + i * 1.7) * 0.18
		var sh: MeshInstance3D = s.get_meta("shield")
		var mat := sh.material_override as ShaderMaterial
		mat.set_shader_parameter("a", maxf(0.0, float(mat.get_shader_parameter("a")) - delta * 2.2))
	for f in flames:
		var k := 0.85 + _rng.randf() * 0.3 + fov_k * 1.1
		for part in f.get_meta("parts"):
			part.scale = Vector3(1, k, 1)
	fleet.position.x += (-bank * 1.8 - fleet.position.x) * minf(1.0, delta * 3.0)
	# caméra de poursuite
	var sh_amt := shake if not reduce_motion else 0.0
	shake = maxf(0.0, shake - delta)
	cam.position = Vector3(fleet.position.x * 0.6 + (_rng.randf() - 0.5) * sh_amt * 1.4, 3.1 + (_rng.randf() - 0.5) * sh_amt * 1.4 + sin(t * 0.7) * 0.12, 12.0 - fov_k * 1.5)
	cam.look_at(Vector3(fleet.position.x * 0.3, -2.2, -14.0))
	cam.fov = 66.0 + fov_k * (0.0 if reduce_motion else 22.0)
	hit = maxf(0.0, hit - delta * 1.6)
	flash = maxf(0.0, flash - delta * (6.0 if reduce_motion else 3.2))
	if mod_id == "orage" and _rng.randf() < delta * 0.7:
		flash = maxf(flash, 0.5)
	_animate_obj(delta)


func _animate_obj(delta: float) -> void:
	if obj == null:
		return
	obj.position.z = -obj_d
	if mode != "travel":
		obj.position.x += ((0.0 if mode == "arrived" else obj_dir * 7.0) - obj.position.x) * minf(1.0, delta * 2.0)
	for i in enemies.size():
		var e: Node3D = enemies[i]
		if not is_instance_valid(e) or not e.visible:
			continue
		if e.has_meta("home"):
			var h: Vector3 = e.get_meta("home")
			var ph: float = e.get_meta("ph")
			e.position.x = h.x + sin(t * 0.8 + ph) * 1.4
			e.position.y = h.y + sin(t * 1.3 + ph) * 0.7
			e.rotation.z = sin(t * 0.8 + ph) * 0.3
		var sh = e.get_meta("shield") if e.has_meta("shield") else null
		if sh is MeshInstance3D:
			var m := (sh as MeshInstance3D).material_override as ShaderMaterial
			m.set_shader_parameter("a", maxf(0.18, float(m.get_shader_parameter("a")) - delta * 1.5))
	if obj.has_meta("boss"):
		var b: Node3D = obj.get_meta("boss")
		b.rotation.y = PI + sin(t * 0.4) * 0.25
		for r in _find(b, "ring1"):
			r.rotate_z(delta * 0.5)
		for r in _find(b, "ring2"):
			r.rotate_y(delta * 0.8)
		obj.position.y = 1.2 + sin(t * 0.8) * 0.8
	if obj.has_meta("rocks"):
		for r in obj.get_meta("rocks"):
			var sp: Vector3 = r.get_meta("spin")
			r.rotate_x(sp.x * delta)
			r.rotate_y(sp.y * delta)
			r.rotate_z(sp.z * delta)
	if obj.has_meta("scraps"):
		for s in obj.get_meta("scraps"):
			var sp2: Vector3 = s.get_meta("spin")
			s.rotate_x(sp2.x * delta)
			s.rotate_y(sp2.y * delta)
		var w: Node3D = obj.get_meta("wreck")
		w.rotation.y += delta * 0.12
		var fire: OmniLight3D = obj.get_meta("fire")
		fire.light_energy = 4.5 if _rng.randf() > 0.8 else 2.0
	if obj.has_meta("spin"):
		(obj.get_meta("spin") as Node3D).rotate_z(delta * 0.5)
	if obj.has_meta("rings"):
		var rings: Array = obj.get_meta("rings")
		for i in rings.size():
			rings[i].rotate_z(delta * (0.6 + i * 0.3) * (1.0 if i % 2 == 0 else -1.0))
	# faisceau de récolte
	if beam_node != null and beam_t >= 0.0:
		beam_t += delta
		if beam_t < 1.2 and obj != null:
			var a0: Vector3 = ships[0].global_position + Vector3(0, 0, -2.5)
			var tg := obj.global_position
			beam_node.global_position = a0.lerp(tg, 0.5)
			var len := a0.distance_to(tg)
			beam_node.look_at(tg)
			beam_node.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			var w2 := 1.0 + sin(beam_t * 40.0) * 0.2
			beam_node.scale = Vector3(w2, len, w2)
			if obj.has_meta("rocks") and _rng.randf() < 0.6:
				var rk: Array = obj.get_meta("rocks")
				var rp: Vector3 = (rk[_rng.randi() % rk.size()] as Node3D).global_position
				_burst(rp, 3, 4.0, Color(0.4, 1.0, 1.0), 0.5)
		elif beam_t >= 1.2:
			beam_node.queue_free()
			beam_node = null
			beam_t = -1.0
