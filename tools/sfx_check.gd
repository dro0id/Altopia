extends SceneTree
## Contrôle des sons : durée, niveau crête, et écriture en .wav pour les écouter (godot --headless --path . -s tools/sfx_check.gd -- <dossier>).
func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	await process_frame
	var sfx = root.get_node("Sfx")
	var t0 := Time.get_ticks_msec()
	for name in sfx._sounds:
		var st: AudioStreamWAV = sfx._sounds[name]
		var peak := 0
		var d := st.data
		for i in range(0, d.size(), 2):
			var v: int = d[i] | (d[i + 1] << 8)
			if v > 32767:
				v -= 65536
			peak = maxi(peak, absi(v))
		print("%s : %.2f s, crête %d%%" % [name, d.size() / 2.0 / st.mix_rate, peak * 100 / 32767])
		st.save_to_wav("%s/%s.wav" % [out, name])
	print("attente de l'ambiance...")
	var waited := 0
	while sfx._music.stream == null and waited < 600:
		await create_timer(0.1).timeout
		waited += 1
	var m: AudioStreamWAV = sfx._music.stream
	if m != null:
		print("ambiance prête après %.1f s : %.1f s de boucle" % [Time.get_ticks_msec() / 1000.0, m.data.size() / 2.0 / m.mix_rate])
		m.save_to_wav("%s/music.wav" % out)
	else:
		print("ambiance non prête")
	quit()
