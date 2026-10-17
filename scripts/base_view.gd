extends SubViewportContainer

const Data = preload("res://scripts/game_data.gd")
## Aperçu 3D du Capitaine (style R2) devant la base lunaire : modèles Kenney retouchés sous Blender.

const MODELS := "res://assets/base/%s.glb"

var look: Dictionary = {}
var _vp: SubViewport
var _captain: Node3D
var _anim: AnimationPlayer
var _turn := 0.0
var _suit_mats: Array = []
var _accent_mats: Array = []


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(380, 460)
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.6
	key.light_color = Color(0.87, 0.92, 1.0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 1.3
	rim.light_color = Color(1.0, 0.31, 0.85)
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0.1, 0.5, 1.75)
	_vp.add_child(cam)
	cam.look_at(Vector3(0, 0.38, 0))
	_captain = _spawn("captain", Vector3.ZERO, 0.0, 1.0)
	_captain.rotation.y = PI - 0.4
	_prepare_captain()
	_apply_look()


func _spawn(model: String, pos: Vector3, ry: float, s: float) -> Node3D:
	var scene: PackedScene = load(MODELS % model)
	var n: Node3D = scene.instantiate()
	n.position = pos
	n.rotation.y = ry
	n.scale = Vector3.ONE * s
	_vp.add_child(n)
	return n


func _prepare_captain() -> void:
	for mi in _captain.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var src: Material = m.get_active_material(i)
			if src == null:
				continue
			var mat: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			m.set_surface_override_material(i, mat)
			if mat.resource_name == "suit_steel":
				_suit_mats.append(mat)
			elif mat.resource_name == "accent_cyan":
				_accent_mats.append(mat)
	var players := _captain.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		_anim = players[0]
		for a in _anim.get_animation_list():
			_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")


func setup_captain(p_look: Dictionary) -> void:
	look = p_look
	if _captain != null:
		_apply_look()


func _apply_look() -> void:
	if look.is_empty():
		return
	var suit: Color = Data.LOOK_SUITS[int(look.get("suit", 0)) % Data.LOOK_SUITS.size()]
	var accent: Color = Data.LOOK_HAIRS[int(look.get("hair", 0)) % Data.LOOK_HAIRS.size()].lerp(Color(0.2, 0.9, 1.0), 0.35)
	for m in _suit_mats:
		m.albedo_color = Color(0.42, 0.5, 0.62).lerp(suit, 0.18)
	for m in _accent_mats:
		m.emission = accent
		m.albedo_color = accent * 0.2
	var style := int(look.get("style", 0))
	for n in ["antenna", "antenna_tip"]:
		var node := _captain.find_child(n, true, false)
		if node != null:
			node.visible = style != 1
	var panel := _captain.find_child("pack_panel", true, false)
	if panel != null:
		panel.visible = style != 2


func play(clip: String) -> void:
	if _anim != null and _anim.has_animation(clip):
		_anim.play(clip)
		_anim.queue("Idle")


func _process(delta: float) -> void:
	if _captain == null or not is_visible_in_tree():
		return
	_turn += delta
	_captain.rotation.y = PI - 0.4 + sin(_turn * 0.5) * 0.45
