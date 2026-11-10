extends Node
## Sons du jeu (autoload « Sfx ») : tous synthétisés par le code, aucun fichier audio.
## Synthèse soignée : balayages filtrés, sous-graves, timbres de cloche, légère réverbération. L'ambiance de fond est calculée en arrière-plan.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sounds["shoot"] = _stream(_laser(), 0.15)
	_sounds["hit"] = _stream(_thump(0.13, 140.0, 55.0, 0.55), 0.1)
	_sounds["cast"] = _stream(_whoosh(), 0.3)
	_sounds["boom"] = _stream(_boom(), 0.35)
	_sounds["warn"] = _stream(_alarm(), 0.2)
	_sounds["click"] = _stream(_bell(1500.0, 0.09, 0.5, 0.7), 0.0)
	_sounds["coin"] = _stream(_coin(), 0.2)
	_sounds["chest"] = _stream(_arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.09, 0.7, true), 0.4)
	_sounds["win"] = _stream(_fanfare(true), 0.45)
	_sounds["lose"] = _stream(_fanfare(false), 0.45)
	_sounds["star"] = _stream(_bell(1318.5, 0.35, 0.6, 1.0), 0.25)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -14.0
	add_child(_music)
	# l'ambiance demande plus de calcul : on la prépare à part pour ne pas ralentir le démarrage
	_thread = Thread.new()
	_thread.start(_build_music)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


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
	p.volume_db = volume_db + linear_to_db(maxf(0.001, g.sfx_vol if g != null else 1.0))
	p.pitch_scale = pitch
	p.play()
	if g != null:
		if sound in ["chest", "star", "win", "coin"]:
			g.haptic("reward")
		elif sound in ["lose", "warn"]:
			g.haptic("alert")
		elif sound == "click":
			g.haptic("tap")


func refresh_music() -> void:
	var g := get_node_or_null("/root/Game")
	var on: bool = g == null or g.music_on
	if g != null and _music != null:
		_music.volume_db = linear_to_db(maxf(0.001, g.music_vol)) - 11.0
	if _music.stream == null:
		return
	if on and not _music.playing:
		_music.play()
	elif not on:
		_music.stop()


func _music_ready(st: AudioStreamWAV) -> void:
	_thread.wait_to_finish()
	_music.stream = st
	refresh_music()


# ---------------------------------------------------------------- briques de synthèse

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(RATE * dur))
	return b


## Filtre passe-bas à un pôle appliqué sur place.
func _lowpass(b: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in b.size():
		y += a * (b[i] - y)
		b[i] = y


## Réverbération simple (quatre peignes) et normalisation douce, puis conversion en flux 16 bits.
func _stream(b: PackedFloat32Array, reverb: float) -> AudioStreamWAV:
	var tail := int(RATE * (reverb * 1.5 + 0.02))
	var n := b.size() + tail
	var out := PackedFloat32Array()
	out.resize(n)
	for i in b.size():
		out[i] = b[i]
	if reverb > 0.0:
		for d_ms in [29.7, 37.1, 41.1, 53.3]:
			var d := int(RATE * d_ms / 1000.0)
			for i in range(d, n):
				out[i] += out[i - d] * 0.42 * reverb * 2.0 * 0.5
		# mélange sec / humide approximatif : on garde le signal sec en tête
		for i in b.size():
			out[i] = b[i] * (1.0 - reverb * 0.4) + out[i] * reverb * 0.4
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var gain := 0.8 / peak if peak > 0.8 else 1.0
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := int(clampf(tanh(out[i] * gain * 1.2), -1.0, 1.0) * 30000.0)
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.data = data
	return st


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, vol: float) -> void:
	var o := int(at * RATE)
	for i in src.size():
		if o + i < dst.size():
			dst[o + i] += src[i] * vol


## Cloche : somme de partiels inharmoniques qui s'éteignent à des vitesses différentes.
func _bell(freq: float, dur: float, vol: float, bright: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var partials := [[1.0, 1.0, 1.0], [2.0, 0.45, 1.6], [2.76, 0.32, 2.2], [5.4, 0.12 * bright, 3.5]]
	for i in b.size():
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += sin(TAU * freq * p[0] * t) * p[1] * exp(-t * p[2] * (5.0 / maxf(dur, 0.05)) * 0.55)
		b[i] = v * vol * minf(1.0, t * 600.0)
	return b


func _arp(freqs: Array, step: float, vol: float, sparkle: bool) -> PackedFloat32Array:
	var total := step * freqs.size() + 0.7
	var b := _buf(total)
	for k in freqs.size():
		_mix(b, _bell(freqs[k], 0.7, 1.0, 1.0 if sparkle else 0.4), k * step, vol * (0.7 + 0.3 * float(k) / freqs.size()))
	return b


func _fanfare(win: bool) -> PackedFloat32Array:
	var b := _buf(1.3)
	var notes := [523.25, 659.25, 783.99, 1046.5] if win else [440.0, 392.0, 349.23, 261.63]
	for k in notes.size():
		var at := k * (0.13 if win else 0.2)
		var dur := 0.9 if k == notes.size() - 1 else 0.35
		var f: float = notes[k]
		var n := _buf(dur)
		for i in n.size():
			var t := float(i) / RATE
			var env := minf(1.0, t * 80.0) * exp(-t * (2.2 if k == notes.size() - 1 else 6.0))
			# timbre de cuivre doux : quelques harmoniques, léger vibrato
			var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t)
			var v := sin(TAU * f * vib * t) + 0.5 * sin(TAU * f * 2.0 * vib * t) + 0.25 * sin(TAU * f * 3.0 * vib * t)
			n[i] = v * env * 0.4
		_lowpass(n, 3200.0)
		_mix(b, n, at, 0.8)
	return b


func _laser() -> PackedFloat32Array:
	var b := _buf(0.16)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 2200.0 * exp(-t * 14.0) + 260.0
		phase += TAU * f / RATE
		var saw := 2.0 * fposmod(phase / TAU, 1.0) - 1.0
		b[i] = (saw * 0.6 + sin(phase) * 0.5) * exp(-t * 17.0) * minf(1.0, t * 800.0)
	_lowpass(b, 5200.0)
	return b


func _thump(dur: float, f0: float, f1: float, vol: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var phase := 0.0
	var noise := PackedFloat32Array()
	noise.resize(b.size())
	for i in b.size():
		noise[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 60.0)
	_lowpass(noise, 1800.0)
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, minf(1.0, t / dur)) / RATE
		b[i] = (sin(phase) * exp(-t * 26.0) + noise[i] * 0.9) * vol
	return b


func _boom() -> PackedFloat32Array:
	var b := _buf(0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var noise := PackedFloat32Array()
	noise.resize(b.size())
	for i in b.size():
		noise[i] = rng.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 4.5)
	_lowpass(noise, 900.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * (95.0 * exp(-t * 3.0) + 32.0) / RATE
		b[i] = sin(phase) * exp(-t * 4.0) * 0.9 + noise[i] * 0.9
	return b


func _whoosh() -> PackedFloat32Array:
	var b := _buf(0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	var phase2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var k := t / 0.55
		var f := 280.0 + 1500.0 * k * k
		phase += TAU * f / RATE
		phase2 += TAU * (f * 1.505 + sin(t * 18.0) * 30.0) / RATE
		var env := sin(PI * minf(1.0, k)) * exp(-t * 1.6)
		b[i] = (sin(phase + 0.8 * sin(phase2)) * 0.6 + rng.randf_range(-0.12, 0.12)) * env
	_lowpass(b, 4200.0)
	return b


func _alarm() -> PackedFloat32Array:
	var b := _buf(0.5)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := 620.0 if fmod(t, 0.25) < 0.125 else 470.0
		phase += TAU * f / RATE
		var tri := 2.0 * absf(2.0 * fposmod(phase / TAU, 1.0) - 1.0) - 1.0
		b[i] = tri * 0.5 * (0.5 + 0.5 * cos(TAU * 4.0 * t)) * minf(1.0, t * 200.0) * minf(1.0, (0.5 - t) * 40.0)
	_lowpass(b, 2600.0)
	return b


func _coin() -> PackedFloat32Array:
	var b := _buf(0.5)
	_mix(b, _bell(1567.98, 0.3, 1.0, 1.0), 0.0, 0.8)
	_mix(b, _bell(2093.0, 0.4, 1.0, 1.0), 0.07, 0.8)
	return b


## Ambiance : nappe de saws désaccordés filtrée, basse profonde, étincelles de cloche en arpège, boucle de 16 s.
func _build_music() -> void:
	var chords := [[220.0, 261.63, 329.63, 392.0], [174.61, 220.0, 261.63, 329.63], [196.0, 246.94, 293.66, 392.0], [196.0, 233.08, 293.66, 349.23]]
	var bass := [55.0, 43.65, 49.0, 49.0]
	var seg := 4.0
	var n := int(RATE * seg * chords.size())
	var b := PackedFloat32Array()
	b.resize(n)
	for c in chords.size():
		for i in int(RATE * seg):
			var t := float(i) / RATE
			var env := minf(1.0, t / 1.4) * minf(1.0, (seg - t) / 1.4)
			var v := 0.0
			for f in chords[c]:
				for det in [-0.004, 0.004]:
					var ph := fposmod(f * (1.0 + det) * (t + c * seg), 1.0)
					v += (2.0 * ph - 1.0) * 0.06
			v *= env * (0.75 + 0.25 * sin(TAU * 0.17 * t))
			v += sin(TAU * bass[c] * t) * 0.22 * minf(1.0, t / 0.4) * minf(1.0, (seg - t) / 1.0)
			b[c * int(RATE * seg) + i] = v
	_lowpass(b, 1500.0)
	# étincelles : une cloche douce chaque seconde sur les notes de l'accord
	for c in chords.size():
		for k in 4:
			var f: float = chords[c][(k * 2 + c) % 4] * 2.0
			_mix(b, _bell(f, 1.6, 1.0, 0.3), c * seg + k * 1.0 + 0.2, 0.05)
	var st := _stream(b, 0.35)
	# la reverb allonge la fin : on la reboucle proprement en recopiant la queue sur le début
	var data := st.data
	var extra := data.size() / 2 - n
	for i in extra:
		var o := (n + i) * 2
		var head := i * 2
		var a: int = data[o] | (data[o + 1] << 8)
		if a > 32767:
			a -= 65536
		var h: int = data[head] | (data[head + 1] << 8)
		if h > 32767:
			h -= 65536
		var mixed := clampi(a + h, -32768, 32767)
		data[head] = mixed & 0xFF
		data[head + 1] = (mixed >> 8) & 0xFF
	data.resize(n * 2)
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	_music_ready.call_deferred(st)
