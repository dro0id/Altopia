class_name CockpitView
extends SubViewportContainer
## Scène 3D du poste de pilotage : le pilote est assis à la barre, face à la grande baie vitrée (étoiles, planète) et à sa console.
## Tout est construit en code avec des formes simples (pas de modèle dédié) ; le pilote est le modèle de l'équipier, posé « assis » par les os.

const MODEL := "res://assets/models/char_%s.glb"
const CHAIR := Color(0.16, 0.2, 0.3)
const METAL := Color(0.2, 0.25, 0.33)

var hero_id := ""
var _vp: SubViewport
var _cam: Camera3D
var _pilot: Node3D
var _skel: Skeleton3D
var _chest := -1
var _chest_rest := Quaternion.IDENTITY
var _t := 0.0
var _planet: MeshInstance3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(540, 760)
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.02, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.4, 0.6)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 140, 0)
	key.light_energy = 1.1
	key.light_color = Color(0.85, 0.92, 1.0)
	_vp.add_child(key)
	_build_room()
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_cam.position = Vector3(2.3, 1.55, 1.1)
	_vp.add_child(_cam)
	_cam.look_at(Vector3(-0.15, 1.0, -0.3))
	if hero_id != "":
		show_pilot(hero_id)


func _box(size: Vector3, pos: Vector3, col: Color, emissive := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	if emissive > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emissive
	m.material_override = mat
	m.position = Vector3(pos.x, pos.y, -pos.z)          # le pilote regarde vers -Z : la scène est écrite côté +Z puis retournée
	m.rotation_degrees = Vector3(-rot.x, rot.y, rot.z)
	_vp.add_child(m)
	return m


func _star_texture() -> ImageTexture:
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img.fill(Color(0.01, 0.015, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 420:
		var x := rng.randi_range(0, 511)
		var y := rng.randi_range(0, 511)
		var v := rng.randf_range(0.5, 1.0)
		img.set_pixel(x, y, Color(v, v, minf(1.0, v + 0.1)))
		if rng.randf() < 0.12:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				img.set_pixel(clampi(x + d.x, 0, 511), clampi(y + d.y, 0, 511), Color(v * 0.6, v * 0.6, v * 0.7))
	return ImageTexture.create_from_image(img)


func _build_room() -> void:
	# sol et plafond, parois latérales
	_box(Vector3(6.0, 0.1, 6.0), Vector3(0, -0.05, 0.5), Color(0.07, 0.09, 0.13))
	_box(Vector3(6.0, 0.1, 6.0), Vector3(0, 2.7, 0.5), Color(0.06, 0.08, 0.12))
	_box(Vector3(0.1, 2.8, 6.0), Vector3(-2.6, 1.35, 0.5), Color(0.09, 0.12, 0.18))
	_box(Vector3(0.1, 2.8, 6.0), Vector3(2.6, 1.35, 0.5), Color(0.09, 0.12, 0.18))
	# baie vitrée : fond d'étoiles, planète, montants
	var sky := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.2, 2.5)
	sky.mesh = q
	var smat := StandardMaterial3D.new()
	smat.albedo_texture = _star_texture()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.material_override = smat
	sky.position = Vector3(0, 1.45, -2.6)
	sky.rotation_degrees = Vector3(0, 0, 0)
	_vp.add_child(sky)
	_planet = MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.85
	sph.height = 1.7
	_planet.mesh = sph
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.16, 0.38, 0.75)
	pmat.emission_enabled = true
	pmat.emission = Color(0.1, 0.28, 0.6)
	pmat.emission_energy_multiplier = 0.9
	_planet.material_override = pmat
	_planet.position = Vector3(-1.1, 1.25, -2.5)
	_vp.add_child(_planet)
	for x in [-2.5, -0.85, 0.85, 2.5]:
		_box(Vector3(0.14, 2.6, 0.14), Vector3(x, 1.4, 2.62), METAL)
	_box(Vector3(5.4, 0.14, 0.2), Vector3(0, 2.68, 2.58), METAL)
	_box(Vector3(5.4, 0.14, 0.2), Vector3(0, 0.1, 2.58), METAL)
	# tableau de bord : console basse devant le pilote, écrans qui brillent
	_box(Vector3(2.4, 0.62, 0.8), Vector3(0, 0.31, 1.45), METAL)
	_box(Vector3(2.5, 0.06, 0.9), Vector3(0, 0.65, 1.45), Color(0.12, 0.16, 0.24))
	_box(Vector3(0.7, 0.04, 0.42), Vector3(-0.7, 0.69, 1.35), Color(0.2, 0.9, 1.0), 1.6, Vector3(-18, 0, 0))
	_box(Vector3(0.7, 0.04, 0.42), Vector3(0.1, 0.69, 1.35), Color(0.35, 1.0, 0.65), 1.4, Vector3(-18, 0, 0))
	_box(Vector3(0.5, 0.04, 0.42), Vector3(0.85, 0.69, 1.35), Color(1.0, 0.7, 0.3), 1.4, Vector3(-18, 0, 0))
	for k in 6:
		_box(Vector3(0.07, 0.03, 0.07), Vector3(-0.35 + k * 0.14, 0.7, 1.12), [Color(1, 0.3, 0.3), Color(0.3, 1, 0.5), Color(0.3, 0.8, 1)][k % 3], 2.0)
	# écrans latéraux
	_box(Vector3(0.05, 0.9, 1.5), Vector3(-2.5, 1.5, 1.2), Color(0.2, 0.7, 1.0), 0.35)
	_box(Vector3(0.05, 0.9, 1.5), Vector3(2.5, 1.5, 1.2), Color(0.25, 0.55, 1.0), 0.3)
	# fauteuil du pilote (assise, dossier, accoudoirs, pied)
	_box(Vector3(0.62, 0.1, 0.62), Vector3(0, 0.46, -0.06), CHAIR)
	_box(Vector3(0.62, 0.8, 0.1), Vector3(0, 0.88, -0.42), CHAIR)
	_box(Vector3(0.12, 0.08, 0.5), Vector3(-0.38, 0.72, -0.1), CHAIR)
	_box(Vector3(0.1, 0.4, 0.1), Vector3(0, 0.22, -0.06), METAL)
	_box(Vector3(0.5, 0.05, 0.5), Vector3(0, 0.03, -0.06), METAL)


## Fait asseoir le personnage de l'équipier au fauteuil (pose donnée par les os, sans animation).
func show_pilot(id: String) -> void:
	hero_id = id
	if _vp == null:
		return
	if _pilot != null:
		_pilot.queue_free()
		_pilot = null
	var path := MODEL % id
	if not ResourceLoader.exists(path):
		return
	_pilot = (load(path) as PackedScene).instantiate()
	_vp.add_child(_pilot)
	for ap in _pilot.find_children("*", "AnimationPlayer", true, false):
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).queue_free()
	_skel = _pilot.find_children("*", "Skeleton3D", true, false)[0]
	_pilot.rotation.y = 0.0
	if (_skel.global_transform.basis * Vector3(0, 0, 1)).z < 0.0:      # l'avant du squelette doit regarder la baie (+Z)
		_pilot.rotation.y = PI
	_sit()


## Oriente un os pour que le segment os -> enfant pointe dans la direction donnée (espace du squelette) ; le reste de la chaîne suit.
func _aim(bone: String, child: String, dir: Vector3) -> void:
	var i := _skel.find_bone(bone)
	var c := _skel.find_bone(child)
	if i < 0 or c < 0:
		return
	var cur := (_skel.get_bone_global_pose(c).origin - _skel.get_bone_global_pose(i).origin).normalized()
	var q := Quaternion(cur, dir.normalized())
	var parent := _skel.get_bone_parent(i)
	var pg := Basis.IDENTITY if parent < 0 else _skel.get_bone_global_pose(parent).basis
	var g := _skel.get_bone_global_pose(i).basis
	_skel.set_bone_pose_rotation(i, (pg.inverse() * (Basis(q) * g)).get_rotation_quaternion())
	_skel.force_update_all_bone_transforms()


func _sit() -> void:
	_skel.reset_bone_poses()
	_skel.force_update_all_bone_transforms()
	# espace du squelette : l'avant du personnage est +Z, le haut +Y
	var fwd := Vector3(0, 0, 1)
	var down := Vector3(0, -1, 0)
	for side in ["L", "R"]:
		_aim("UpperLeg." + side, "LowerLeg." + side, fwd)                       # cuisses à l'horizontale, vers l'avant
		_aim("LowerLeg." + side, "Foot." + side, down)                          # tibias à la verticale
		var sx := -0.12 if side == "R" else 0.12                                # les mains restent un peu écartées
		_aim("UpperArm." + side, "LowerArm." + side, Vector3(sx, -0.75, 0.55))  # bras vers l'avant et le bas
		_aim("LowerArm." + side, "Hand." + side, Vector3(sx * 0.6, -0.1, 1.0))  # avant-bras vers la console
	_chest = _skel.find_bone("Chest")
	_chest_rest = _skel.get_bone_pose_rotation(_chest) if _chest >= 0 else Quaternion.IDENTITY
	# orientation : l'avant du personnage (nez par rapport à la tête, en monde) doit viser la baie (-Z)
	_pilot.scale = Vector3.ONE * 1.6          # les modèles mesurent environ 1,05 m : on les met à l'échelle du mobilier
	_pilot.rotation.y = 0.0
	var head := _skel.find_bone("Head")
	var nose := _skel.find_bone("Nose")
	if head >= 0 and nose >= 0:
		var d: Vector3 = _skel.global_transform.basis * (_skel.get_bone_global_pose(nose).origin - _skel.get_bone_global_pose(head).origin)
		_pilot.rotation.y = atan2(-d.x, -d.z) * -1.0 + PI * 0.0
		_pilot.rotation.y = atan2(d.x, d.z) * -1.0 + PI           # amène (d.x, d.z) sur -Z
	# bassin posé sur l'assise
	_pilot.position = Vector3.ZERO
	var hips := _skel.find_bone("Hips")
	var hp: Vector3 = _pilot.global_transform * (_skel.global_transform * _skel.get_bone_global_pose(hips).origin)
	_pilot.position = Vector3(-hp.x, 0.66 - hp.y, 0.0 - hp.z)


func _process(delta: float) -> void:
	if _pilot == null or _skel == null or not is_visible_in_tree():
		return
	_t += delta
	if _chest >= 0:                      # respiration
		_skel.set_bone_pose_rotation(_chest, _chest_rest * Quaternion(Vector3.RIGHT, deg_to_rad(0.8 * sin(_t * 1.6))))
	if _planet != null:
		_planet.rotation.y += delta * 0.05
