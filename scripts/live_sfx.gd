extends RefCounted
## Sons du combat en direct : de courts signaux synthétisés (aucun fichier audio). Chaque son est généré une fois puis réutilisé.

const RATE := 22050

# nom : [fréquence de départ, fréquence d'arrivée, durée, forme, volume]
const SOUNDS := {
	"hurt": [160.0, 70.0, 0.20, "saw", 0.5],
	"dodge": [700.0, 900.0, 0.12, "sine", 0.35],
	"shield": [300.0, 340.0, 0.16, "tri", 0.4],
	"scan": [880.0, 1100.0, 0.22, "sine", 0.35],
	"charge": [160.0, 380.0, 0.30, "saw", 0.5],
	"warn": [420.0, 420.0, 0.07, "square", 0.22],
	"kill": [240.0, 160.0, 0.12, "square", 0.3],
	"win": [520.0, 1040.0, 0.5, "tri", 0.45],
	"lose": [180.0, 60.0, 0.6, "saw", 0.5],
}

static var _cache := {}


static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	if not SOUNDS.has(name):
		return null
	var d: Array = SOUNDS[name]
	var n := int(RATE * float(d[2]))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var k := float(i) / float(n)
		var f := lerpf(float(d[0]), float(d[1]), k)
		phase += f / float(RATE)
		var ph := fposmod(phase, 1.0)
		var v := 0.0
		match String(d[3]):
			"sine": v = sin(ph * TAU)
			"square": v = 1.0 if ph < 0.5 else -1.0
			"saw": v = ph * 2.0 - 1.0
			"tri": v = 1.0 - 4.0 * absf(ph - 0.5)
		v *= float(d[4]) * pow(1.0 - k, 1.5)          # enveloppe : le son s'éteint
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	_cache[name] = wav
	return wav
