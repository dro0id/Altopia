extends Node
## Sons du jeu (autoload « Sfx ») : tous synthétisés par le code, aucun fichier audio. Bruitages courts et une ambiance de fond en boucle.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds["shoot"] = _tone([[880.0, 440.0]], 0.11, "square", 0.25)
	_sounds["hit"] = _tone([[220.0, 110.0]], 0.09, "noise", 0.35)
	_sounds["cast"] = _tone([[300.0, 900.0]], 0.35, "sine", 0.35)
	_sounds["boom"] = _tone([[110.0, 45.0]], 0.5, "noise", 0.5)
	_sounds["warn"] = _tone([[500.0, 500.0], [700.0, 700.0], [500.0, 500.0]], 0.45, "square", 0.22)
	_sounds["click"] = _tone([[1300.0, 1300.0]], 0.04, "sine", 0.3)
	_sounds["coin"] = _tone([[1200.0, 1200.0], [1800.0, 1800.0]], 0.18, "sine", 0.3)
	_sounds["chest"] = _tone([[392.0, 392.0], [523.0, 523.0], [659.0, 659.0], [784.0, 784.0], [1046.0, 1046.0]], 0.7, "sine", 0.35)
	_sounds["win"] = _tone([[523.0, 523.0], [659.0, 659.0], [784.0, 784.0], [1046.0, 1046.0]], 0.8, "sine", 0.4)
	_sounds["lose"] = _tone([[440.0, 440.0], [370.0, 370.0], [294.0, 294.0], [220.0, 220.0]], 0.9, "sine", 0.4)
	_sounds["star"] = _tone([[900.0, 1400.0]], 0.18, "sine", 0.3)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = _pad()
	_music.volume_db = -16.0
	add_child(_music)
	refresh_music()


## Joue un bruitage (ignoré si les effets sont coupés).
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var g := get_node_or_null("/root/Game")
	if g != null and not g.sfx_on:
		return
	var st: AudioStream = _sounds.get(sound)
	if st == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = st
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func refresh_music() -> void:
	var g := get_node_or_null("/root/Game")
	var on: bool = g == null or g.music_on
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


## Suite de notes [[freq début, freq fin], ...] de durée totale `dur`, avec une enveloppe qui s'éteint.
func _tone(notes: Array, dur: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var phase := 0.0
	var last := 0.0
	for i in n:
		var k := float(i) / n
		var seg := mini(int(k * notes.size()), notes.size() - 1)
		var sk := k * notes.size() - seg
		var f: float = lerpf(notes[seg][0], notes[seg][1], sk)
		phase += TAU * f / RATE
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if sin(phase) > 0.0 else -1.0
			"noise":
				last = lerpf(last, rng.randf_range(-1.0, 1.0), 0.35)
				v = last + sin(phase) * 0.6
			_:
				v = sin(phase)
		var env := pow(1.0 - sk, 1.5) if notes.size() > 1 else pow(1.0 - k, 1.5)
		env *= minf(1.0, float(i) / 120.0)
		var s := int(clampf(v * env * vol, -1.0, 1.0) * 32000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.data = data
	return st


## Nappe d'ambiance : quatre accords doux qui tournent, boucle de 16 s.
func _pad() -> AudioStreamWAV:
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7], [196.0, 233.1, 293.7]]
	var seg_len := 4.0
	var n := int(RATE * seg_len * chords.size())
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var seg := int(t / seg_len)
		var local := fmod(t, seg_len)
		var env := minf(1.0, local / 1.2) * minf(1.0, (seg_len - local) / 1.2)
		var v := 0.0
		for f in chords[seg]:
			v += sin(TAU * f * t) * 0.3 + sin(TAU * f * 2.0 * t) * 0.08
		v *= env * (0.8 + 0.2 * sin(TAU * 0.25 * t))
		var s := int(clampf(v * 0.35, -1.0, 1.0) * 32000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st
