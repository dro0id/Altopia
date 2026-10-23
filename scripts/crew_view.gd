extends SubViewportContainer
## Fiche 3D d'un équipier : modèle animé (assets/models/char_<id>.glb + bibliothèque d'animations), glisser pour le tourner.

const MODEL := "res://assets/models/char_%s.glb"
const IDLE := "Idle"

var hero_id := ""
var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _model: Node3D
var _anim: AnimationPlayer
var _yaw := 0.0
var _auto := true


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(420, 520)
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.58, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -25, 0)
	key.light_energy = 1.5
	key.light_color = Color(0.9, 0.94, 1.0)
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 150, 0)
	rim.light_energy = 1.1
	rim.light_color = Color(0.4, 0.85, 1.0)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 32.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	if hero_id != "":
		show_hero(hero_id)


## Charge le modèle de l'équipier et lance son animation de repos.
func show_hero(id: String) -> void:
	hero_id = id
	if _holder == null:
		return
	if _model != null:
		_model.queue_free()
		_model = null
		_anim = null
	var path := MODEL % id
	if not ResourceLoader.exists(path):
		return
	_model = (load(path) as PackedScene).instantiate()
	_holder.add_child(_model)
	_anim = CharAnims.attach(_model)
	var box := _bounds(_model)
	var h := maxf(box.size.y, 0.5)
	_model.position.y = -box.position.y
	_cam.position = Vector3(0, h * 0.52, h * 2.05)
	_cam.look_at(Vector3(0, h * 0.5, 0))
	_yaw = 0.0
	_auto = true
	play(IDLE)


## Joue un geste puis revient au repos (les gestes en boucle tournent jusqu'au prochain choix).
func play(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.play(clip, 0.2)
	if _anim.get_animation(clip).loop_mode == Animation.LOOP_NONE and clip != IDLE:
		_anim.queue(IDLE)


func clips() -> PackedStringArray:
	return _anim.get_animation_list() if _anim != null else PackedStringArray()


## Hauteur du personnage d'après les os (les AABB des maillages à peau ne sont pas fiables), repli sur les maillages.
func _bounds(n: Node3D) -> AABB:
	var sk := n.find_children("*", "Skeleton3D", true, false)
	if sk.size() > 0:
		var skel: Skeleton3D = sk[0]
		var lo := INF
		var hi := -INF
		for i in skel.get_bone_count():
			var y := (skel.global_transform * skel.get_bone_global_rest(i).origin).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		return AABB(Vector3(-0.3, lo - 0.03, -0.2), Vector3(0.6, hi - lo + 0.2, 0.4))
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var a: AABB = m.global_transform * m.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
		_yaw += (ev as InputEventMouse).relative.x * 0.012 if ev is InputEventMouseMotion else (ev as InputEventScreenDrag).relative.x * 0.012
		_auto = false


func _process(delta: float) -> void:
	if _holder == null or not is_visible_in_tree():
		return
	if _auto:
		_yaw = sin(Time.get_ticks_msec() / 1000.0 * 0.6) * 0.35
	_holder.rotation.y = PI + _yaw
