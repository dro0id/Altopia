extends RefCounted
## Icônes monoligne en SVG, rasterisées au chargement (aucun fichier image à maintenir).

const PATHS := {
	"credits": "<circle cx='24' cy='24' r='15'/><path d='M24 14v20M18 19h9a4 4 0 010 8h-7a4 4 0 000 8h9'/>",
	"data": "<path d='M24 6l14 8v16l-14 8-14-8V14z'/><path d='M24 6v16M10 14l14 8 14-8M24 22v16'/>",
	"minerals": "<path d='M8 32l8-16 10-6 14 12-8 16H16z'/><path d='M16 16l10 8 14 0M26 10l0 14-6 14'/>",
	"energy": "<path d='M27 4L10 27h12l-3 17 19-24H26z'/>",
	"captain": "<circle cx='24' cy='22' r='13'/><path d='M14 21a10 8 0 0020 0'/><path d='M10 40a14 8 0 0128 0'/>",
	"crew": "<circle cx='24' cy='16' r='7'/><circle cx='10' cy='22' r='5'/><circle cx='38' cy='22' r='5'/><path d='M12 40a12 9 0 0124 0M2 38a8 6 0 018-7M46 38a8 6 0 00-8-7'/>",
	"exp": "<circle cx='24' cy='24' r='10'/><ellipse cx='24' cy='24' rx='21' ry='7' transform='rotate(-25 24 24)'/>",
	"ship": "<path d='M24 4c7 8 9 18 8 28H16c-1-10 1-20 8-28z'/><path d='M16 30l-8 8M32 30l8 8M20 38l4 6 4-6'/><circle cx='24' cy='20' r='3'/>",
}

static var _cache := {}


static func icon(name: String, px: int = 48, color: Color = Color.WHITE) -> Texture2D:
	var key := "%s_%d_%s" % [name, px, color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='48' height='48' viewBox='0 0 48 48' fill='none' stroke='#%s' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [
		color.to_html(false), PATHS.get(name, "")]
	var img := Image.new()
	var tex: Texture2D = null
	if img.load_svg_from_string(svg, float(px) / 48.0) == OK:
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
