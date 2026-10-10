extends Node
## Tiny chiptune synth for every sound effect (generated at startup) plus the music:
## assets/music/main-music.mp3 on the title / menus, a track of assets/music/levels/ in
## every level (the world's "music" in WorldData, or one picked by the world's number
## from whatever is in the folder: new files there join on their own) and, while a
## final boss is fought, the world's "boss_music" from assets/music/bosses/ (or
## bosses.mp3 when it has none).

const RATE := 22050

var sounds: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var last_play: Dictionary = {}
const MUSIC := {
	"menu": "res://assets/music/main-music.mp3",
	"boss": "res://assets/music/bosses.mp3",
}
const MUSIC_DB := -9.0
const LEVEL_DIR := "res://assets/music/levels/"
const BOSS_DIR := "res://assets/music/bosses/"
const LEVEL_EXT := ["mp3", "ogg", "wav"]

var music_player: AudioStreamPlayer
var music_track := ""
var music_tween: Tween
var sfx_enabled := true
var music_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_DB
	add_child(music_player)
	_build_sounds()


func play(id: String, pitch_var := 0.08, vol_db := 0.0) -> void:
	if not sfx_enabled or not sounds.has(id):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(id, -1000)) < 40:
		return
	last_play[id] = now
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = vol_db
	p.play()


## Like play() with an exact pitch (dialogue voices).
func play_pitched(id: String, pitch: float, vol_db := 0.0) -> void:
	if not sfx_enabled or not sounds.has(id):
		return
	var p := players[next_player]
	next_player = (next_player + 1) % players.size()
	p.stream = sounds[id]
	p.pitch_scale = maxf(0.05, pitch)
	p.volume_db = vol_db
	p.play()


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if on:
		play_music()
	else:
		music_player.stop()


## Plays `track` ("menu" or "level"; "" = keep the current one), fading out whatever
## else was on. Moving between screens that share a track does not restart it.
func play_music(track := "") -> void:
	if track == "level":
		track = "level:" + level_track(Game.world_index)
	elif track == "boss":
		var bt := boss_track(Game.world_index)
		if bt != "":
			track = "level:" + bt  # "level:" = a file path, not a MUSIC key
	if track != "":
		if track != music_track:
			music_track = track
			if music_player.playing:
				_fade_to(track)
				return
	if not music_enabled or music_track == "":
		return
	if not music_player.playing:
		_start(music_track)


## Every level track in LEVEL_DIR (sorted). In an exported game the folder lists the
## ".import" / ".remap" entries, so those are read back to their source names.
func level_tracks() -> Array[String]:
	return _tracks(LEVEL_DIR)


## Boss tracks in BOSS_DIR (bosses.mp3, the default, stays outside it).
func boss_tracks() -> Array[String]:
	return _tracks(BOSS_DIR)


## The final-boss track of world `world_idx`: its "boss_music" (a file in BOSS_DIR) if it
## is there; "" = the default bosses.mp3.
func boss_track(world_idx: int) -> String:
	var want := str(WorldData.world(world_idx).get("boss_music", ""))
	return BOSS_DIR + want if want != "" and boss_tracks().has(BOSS_DIR + want) else ""


func _tracks(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		var n := f.trim_suffix(".import").trim_suffix(".remap")
		if n.get_extension().to_lower() in LEVEL_EXT and not out.has(dir + n):
			out.append(dir + n)
	out.sort()
	return out


## The level track of world `world_idx`: its "music" (a file name in LEVEL_DIR) if that
## file is there, otherwise one of the folder's tracks picked by the world's number.
func level_track(world_idx: int) -> String:
	var all := level_tracks()
	if all.is_empty():
		return ""
	var want := str(WorldData.world(world_idx).get("music", ""))
	if want != "" and all.has(LEVEL_DIR + want):
		return LEVEL_DIR + want
	return all[posmod(world_idx, all.size())]


func _fade_to(track: String) -> void:
	if music_tween != null:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", -40.0, 0.4)
	music_tween.tween_callback(func() -> void:
		if music_enabled:
			_start(track)
		else:
			music_player.stop())


func _start(track: String) -> void:
	if music_tween != null:
		music_tween.kill()
	var path := str(MUSIC[track]) if MUSIC.has(track) else track.trim_prefix("level:")
	if path == "" or not ResourceLoader.exists(path):
		return
	var st: AudioStream = load(path)
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	music_player.stream = st
	music_player.volume_db = -30.0
	music_player.play()
	music_tween = create_tween()
	music_tween.tween_property(music_player, "volume_db", MUSIC_DB, 0.6)


# ---------------------------------------------------------------- synthesis

func _osc(wave: String, ph: float) -> float:
	var f := fmod(ph, 1.0)
	match wave:
		"sq":
			return 1.0 if f < 0.5 else -1.0
		"pulse":
			return 1.0 if f < 0.25 else -1.0
		"tri":
			return 1.0 - 4.0 * absf(f - 0.5)
		"saw":
			return 2.0 * f - 1.0
		"noise":
			return randf() * 2.0 - 1.0
	return sin(ph * TAU)


func _tone(dur: float, f0: float, f1: float, wave := "sq", vol := 0.4, noise := 0.0, decay := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += lerpf(f0, f1, k) / RATE
		var v := _osc(wave, ph)
		if noise > 0.0:
			v = v * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise
		var env := pow(1.0 - k, decay) * minf(1.0, i / (RATE * 0.004))
		out[i] = v * env * vol
	return out


func _noise(dur: float, cut0: float, cut1: float, vol := 0.6, decay := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var k := float(i) / n
		var a := lerpf(cut0, cut1, k)
		y += ((randf() * 2.0 - 1.0) - y) * a
		out[i] = y * pow(1.0 - k, decay) * vol * minf(1.0, i / (RATE * 0.003))
	return out


func _cat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p: PackedFloat32Array in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	if b.size() > out.size():
		out.resize(b.size())
	for i in b.size():
		out[i] += b[i]
	return out


func _arp(freqs: Array, step: float, wave: String, vol: float) -> PackedFloat32Array:
	var parts: Array = []
	for i in freqs.size():
		var f: float = freqs[i]
		var last := i == freqs.size() - 1
		parts.append(_tone(step * (3.0 if last else 1.0), f, f, wave, vol, 0.0, 1.2 if last else 0.4))
	return _cat(parts)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _build_sounds() -> void:
	var s := {}
	s["shoot"] = _tone(0.07, 480.0, 1150.0, "sin", 0.32, 0.0, 1.4)
	s["hit"] = _mix(_tone(0.06, 320.0, 140.0, "sq", 0.16, 0.0, 2.5), _noise(0.05, 0.6, 0.2, 0.3, 2.0))
	s["pop"] = _mix(_tone(0.22, 620.0, 70.0, "sin", 0.55, 0.0, 1.2), _noise(0.12, 0.5, 0.1, 0.25, 3.0))
	s["coin"] = _cat([_tone(0.05, 988.0, 988.0, "sq", 0.14, 0.0, 0.2), _tone(0.14, 1319.0, 1319.0, "sq", 0.14, 0.0, 1.6)])
	s["hurt"] = _mix(_tone(0.28, 380.0, 90.0, "saw", 0.35, 0.0, 1.5), _noise(0.15, 0.4, 0.1, 0.3, 2.0))
	s["explode"] = _mix(_noise(0.6, 0.6, 0.03, 0.9, 1.8), _tone(0.4, 120.0, 30.0, "sin", 0.6, 0.0, 1.5))
	s["blast"] = _noise(0.35, 0.05, 0.5, 0.55, 1.2)
	s["door"] = _arp([392.0, 523.0, 659.0, 784.0], 0.06, "sq", 0.14)
	s["clean"] = _arp([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.065, "tri", 0.3)
	s["upgrade"] = _mix(_tone(0.35, 300.0, 1500.0, "tri", 0.25, 0.0, 1.0), _arp([784.0, 988.0, 1175.0, 1568.0], 0.07, "sq", 0.1))
	s["spit"] = _tone(0.13, 280.0, 130.0, "sin", 0.4, 0.25, 1.5)
	s["dash"] = _noise(0.2, 0.05, 0.4, 0.4, 1.5)
	s["land"] = _mix(_tone(0.4, 110.0, 35.0, "sin", 0.8, 0.0, 1.3), _noise(0.25, 0.3, 0.05, 0.4, 2.0))
	s["spawn"] = _tone(0.25, 200.0, 760.0, "tri", 0.18, 0.0, 0.8)
	s["select"] = _tone(0.05, 880.0, 880.0, "sq", 0.12, 0.0, 1.0)
	s["shield"] = _tone(0.25, 1400.0, 400.0, "tri", 0.3, 0.0, 1.2)
	s["heal"] = _arp([660.0, 880.0, 1100.0], 0.06, "tri", 0.3)
	s["roar"] = _mix(_tone(0.8, 150.0, 55.0, "saw", 0.45, 0.35, 0.8), _tone(0.8, 75.0, 40.0, "sq", 0.2, 0.0, 0.8))
	s["alert"] = _tone(0.08, 1200.0, 1250.0, "sq", 0.1, 0.0, 0.6)
	s["bounce"] = _tone(0.04, 1500.0, 900.0, "sin", 0.18, 0.0, 1.0)
	s["charge"] = _tone(0.6, 100.0, 420.0, "sq", 0.07, 0.3, 0.2)
	s["zap"] = _zap()
	s["mutate"] = _mix(_tone(1.1, 55.0, 260.0, "saw", 0.32, 0.35, 0.5), _noise(1.1, 0.08, 0.7, 0.3, 0.7))
	s["slash"] = _mix(_noise(0.14, 0.9, 0.25, 0.4, 2.2), _tone(0.14, 950.0, 260.0, "saw", 0.12, 0.0, 2.0))
	s["freeze"] = _mix(_tone(0.2, 2000.0, 2600.0, "tri", 0.12, 0.0, 1.5), _noise(0.2, 0.9, 0.9, 0.12, 2.0))
	s["gameover"] = _arp([392.0, 330.0, 262.0, 196.0], 0.14, "tri", 0.3)
	# ARMORY weapons (GunFire)
	s["shotgun"] = _mix(_noise(0.18, 0.7, 0.08, 0.5, 2.0), _tone(0.12, 300.0, 90.0, "sq", 0.18, 0.0, 2.0))
	s["drill"] = _mix(_tone(0.14, 700.0, 1700.0, "saw", 0.12, 0.0, 1.4), _noise(0.12, 0.8, 0.4, 0.15, 2.0))
	s["spray"] = _noise(0.09, 0.9, 0.6, 0.2, 1.5)
	s["goo"] = _tone(0.16, 240.0, 80.0, "sin", 0.45, 0.3, 1.3)
	s["grav"] = _mix(_tone(0.45, 520.0, 70.0, "sin", 0.4, 0.15, 0.9), _tone(0.45, 260.0, 35.0, "tri", 0.2, 0.0, 0.9))
	s["rocket"] = _mix(_noise(0.28, 0.15, 0.6, 0.35, 1.0), _tone(0.25, 180.0, 620.0, "sq", 0.07, 0.3, 1.0))
	s["laser"] = _mix(_tone(0.38, 1900.0, 260.0, "saw", 0.16, 0.0, 1.1), _tone(0.38, 950.0, 140.0, "sin", 0.3, 0.0, 1.0))
	s["victory"] = _arp([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0, 1319.0], 0.09, "sq", 0.14)
	for id: String in s:
		sounds[id] = _wav(s[id])


func _zap() -> PackedFloat32Array:
	var n := int(0.22 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var f := 800.0
	for i in n:
		if i % 70 == 0:
			f = randf_range(200.0, 2200.0)
		ph += f / RATE
		var k := float(i) / n
		out[i] = (_osc("sq", ph) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * (1.0 - k) * 0.22
	return out
