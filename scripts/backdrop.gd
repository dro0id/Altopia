class_name Backdrop
extends Control
## Fond en trois plans (maquette G3) : nébuleuse floue teintée selon le lieu, étoiles, éclats de verre qui dérivent.
## La nébuleuse est une image calculée une fois par teinte ; seuls les éclats bougent (immobiles en économie de batterie).
## Un dégradé sombre en bas garde les boutons lisibles.

static var _cache := {}

var tint := Color("4fd8ff")
var _tex: Texture2D
var _stars := PackedVector3Array()
var _shards: Array = []
var _t := 0.0


static func make(c: Color) -> Backdrop:
	var b := Backdrop.new()
	b.tint = c
	return b


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = _nebula(tint)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		_stars.append(Vector3(rng.randf() * 720.0, rng.randf() * 1700.0, rng.randf()))
	for i in 9:
		_shards.append({"p": Vector2(rng.randf() * 720.0, rng.randf() * 1600.0), "v": Vector2(rng.randf_range(-6, 6), rng.randf_range(-10, -3)), "r": rng.randf_range(8, 22), "a": rng.randf() * TAU, "w": rng.randf_range(-0.2, 0.2)})


func _process(delta: float) -> void:
	if Game.battery_saver or Game.reduce_shake or not is_visible_in_tree():
		return
	_t += delta
	for s in _shards:
		s.p += s.v * delta
		s.a += s.w * delta
		if s.p.y < -40.0:
			s.p.y = size.y + 40.0
		s.p.x = fposmod(s.p.x, 720.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UI.BG)
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	for s in _stars:
		if s.y > size.y:
			continue
		var tw := 0.55 + 0.45 * sin(_t * (0.6 + s.z) + s.x)
		draw_circle(Vector2(s.x, s.y), 1.0 + s.z * 1.4, Color(1, 1, 1, (0.25 + 0.45 * s.z) * tw))
	for s in _shards:
		Art.shard(self, s.p, s.r, s.a, Color(tint.lightened(0.4), 0.10))
	# dégradé sombre en bas
	var h := size.y * 0.3
	var n := 12
	for i in n:
		draw_rect(Rect2(0, size.y - h + h * i / n, size.x, h / n + 1.0), Color(UI.BG, 0.6 * float(i + 1) / n))


## Nébuleuse : trois taches floues de la teinte du lieu, sur 180 × 400 px agrandis (le flou vient de l'agrandissement).
static func _nebula(c: Color) -> Texture2D:
	var key := c.to_html()
	if _cache.has(key):
		return _cache[key]
	var w := 90
	var h := 200
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var blobs := [[Vector2(0.15, 0.12), 0.55, 0.30], [Vector2(0.9, 0.38), 0.45, 0.22], [Vector2(0.35, 0.78), 0.6, 0.16]]
	var c2 := Color.from_hsv(fposmod(c.h + 0.08, 1.0), c.s * 0.8, c.v)
	for y in h:
		for x in w:
			var p := Vector2(float(x) / w, float(y) / h * 2.2)
			var col := Color(0, 0, 0, 0)
			for i in blobs.size():
				var bl: Array = blobs[i]
				var cen: Vector2 = bl[0] * Vector2(1, 2.2)
				var d := p.distance_to(cen) / float(bl[1])
				var a := maxf(0.0, 1.0 - d * d) * float(bl[2])
				var bc: Color = c if i != 1 else c2
				col = Color(bc.r, bc.g, bc.b, minf(0.5, col.a + a))
			im.set_pixel(x, y, col)
	var t := ImageTexture.create_from_image(im)
	_cache[key] = t
	return t
