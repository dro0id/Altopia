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
	"weapon": "<path d='M5 27h22l6-6h10v9l-6 4H23l-4 9h-9l3-9H5z'/><path d='M33 21v13'/>",
	"helmet": "<path d='M9 30a15 15 0 0130 0v8H9z'/><path d='M15 26h18v7H15z'/><path d='M24 9v6'/>",
	"suit": "<path d='M17 7l-9 6 4 11 5-2v21h14V22l5 2 4-11-9-6c-2 4-9 4-13 0z'/>",
	"gloves": "<path d='M13 43V27l-4-9 4-2 4 7V9h4v15V7h4v17V9h4v18l4-6 4 2-6 14v7z'/>",
	"boots": "<path d='M15 6h13v22l13 6v9H9V6z'/><path d='M15 14h13'/>",
	"module": "<rect x='12' y='12' width='24' height='24' rx='3'/><rect x='19' y='19' width='10' height='10'/><path d='M18 6v6M30 6v6M18 36v6M30 36v6M6 18h6M6 30h6M36 18h6M36 30h6'/>",
	"pilot": "<path d='M24 3l6 19v12l-6 5-6-5V22z'/><path d='M18 25L5 34v6l13-3M30 25l13 9v6l-13-3'/><circle cx='24' cy='17' r='3'/><path d='M21 42v4M27 42v4'/>",
	"engineer": "<circle cx='24' cy='24' r='14'/><circle cx='24' cy='24' r='6'/><path d='M24 4v6M24 38v6M4 24h6M38 24h6M9.9 9.9l4.2 4.2M33.9 33.9l4.2 4.2M9.9 38.1l4.2-4.2M33.9 14.1l4.2-4.2'/>",
	"scientist": "<path d='M18 6h12M20 6v12L8 38a3 3 0 003 6h26a3 3 0 003-6L28 18V6'/><path d='M13 31h22'/><circle cx='22' cy='37' r='1.5'/><circle cx='28' cy='34' r='1.5'/>",
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


## Interrupteur : piste arrondie et pastille, rasterisés pour CheckButton.
static func toggle(on: bool, disabled: bool = false) -> Texture2D:
	var key := "toggle_%s_%s" % [on, disabled]
	if _cache.has(key):
		return _cache[key]
	var track := "#1b6f82" if on else "#0b1b27"
	var stroke := "#7ff2ff" if on else "#4b7482"
	var knob := "#e8fdff" if on else "#7c9aa6"
	var cx := 62 if on else 22
	var op := 0.45 if disabled else 1.0
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='84' height='44' viewBox='0 0 84 44' opacity='%s'><rect x='2' y='4' width='80' height='36' rx='18' fill='%s' stroke='%s' stroke-width='3'/><circle cx='%d' cy='22' r='12' fill='%s'/></svg>" % [op, track, stroke, cx, knob]
	var img := Image.new()
	var tex: Texture2D = null
	if img.load_svg_from_string(svg, 1.0) == OK:
		tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
