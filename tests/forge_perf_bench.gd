extends Node
## Performance bench of the survival worlds: by default world 5 THE FORGE (ForgeMap, built
## wall by wall) next to world 3 THE VOID (room grid) as a reference; N tough aliens kept
## alive around the astronaut, frame time printed for each N. Run it windowed, outside the
## editor:
##   Godot --path . res://tests/forge_perf_bench.tscn [-- options]
## Options: --world=6,3 (worlds to compare, 1-based: use it for every new world),
## --real (jump to the last wave and let the real waves spawn), --slimes (only simple
## chasers: isolates the map's cost), --nodetour (aliens don't follow the flow field).
## Numbers swing with whatever else the machine is doing: compare the two worlds side by
## side in the same run.

const WORLDS := [4, 2]
const COUNTS := [0, 150, 300, 500]
const IDS_ALL := ["orbit_spawn", "orbit_spawn", "comet_baby", "orbit_raider", "eye_blob", "goo_hopper"]
var IDS := IDS_ALL
const WARMUP := 1.0
const MEASURE := 2.5

var w: GameWorld
var _pf := 0


func _ready() -> void:
	call_deferred("_run")


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Game.playground_active = true
	if OS.get_cmdline_user_args().has("--slimes"):
		IDS = ["orbit_spawn"]
	if OS.get_cmdline_user_args().has("--noblob"):
		IDS = IDS_ALL.filter(func(id: String) -> bool: return id != "eye_blob")
	Enemy.no_detour = OS.get_cmdline_user_args().has("--nodetour")
	var worlds := WORLDS
	if OS.get_cmdline_user_args().has("--only5"):
		worlds = [4]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--world="):
			worlds = []
			for n in a.trim_prefix("--world=").split(","):
				worlds.append(int(n) - 1)
	for world_i: int in worlds:
		Game.new_run(world_i)
		w = (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
		add_child(w)
		await _secs(2.0)
		w.player.invuln = 999999.0
		w.survival.choosing = true  # no level-up menus
		if OS.get_cmdline_user_args().has("--real"):
			await _real(world_i)
			w.queue_free()
			await _secs(0.5)
			continue
		for n: int in COUNTS:
			_fill(n)
			await _secs(WARMUP)
			var frames := 0
			var phys := 0.0
			var proc := 0.0
			var worst := 0.0
			var t0 := Time.get_ticks_usec()
			var last := t0
			while Time.get_ticks_usec() - t0 < int(MEASURE * 1e6):
				_fill(n)
				await get_tree().process_frame
				var now := Time.get_ticks_usec()
				worst = maxf(worst, (now - last) / 1000.0)
				last = now
				frames += 1
				phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
				proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var total := (Time.get_ticks_usec() - t0) / 1000.0
			print("BENCH world=%d n=%-4d alive=%-4d fps=%-4.0f frame=%6.2fms worst=%6.1fms physics=%5.1fms process=%5.1fms draws=%d" % [
				world_i + 1, n, w.enemy_cache.size(), frames / (total / 1000.0), total / frames, worst, phys / frames, proc / frames,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		w.queue_free()
		await _secs(0.5)
	Game.playground_active = false
	print("BENCH done")
	get_tree().quit()


## The real thing: jump to the last wave (its INVASION) and let the waves spawn.
func _real(world_i: int) -> void:
	var s := w.survival
	s.t = (s.waves.size() - 1) * 30.0 - 0.5
	await _secs(2.0)
	var frames := 0
	var worst := 0.0
	var peak := 0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while Time.get_ticks_usec() - t0 < int(20.0 * 1e6):
		get_tree().paused = false
		w.player.global_position += Vector2.from_angle(frames * 0.01) * 0.6  # keeps moving
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000.0
		var _pf0 := _pf
		_pf = Engine.get_physics_frames()
		if dt > 80.0:
			print("BENCH spike %.0fms at %.1fs alive=%d wave=%d physics=%.0fms process=%.0fms nodes=%d draws=%d steps=%d" % [dt, (now - t0) / 1e6, w.enemy_cache.size(), s.wave,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_physics_frames() - _pf])
		worst = maxf(worst, dt)
		last = now
		frames += 1
		peak = maxi(peak, w.enemy_cache.size())
	var total := (Time.get_ticks_usec() - t0) / 1000.0
	print("BENCH world=%d REAL last wave: frame=%6.2fms fps=%.0f worst=%6.1fms peak alive=%d" % [
		world_i + 1, total / frames, frames / (total / 1000.0), worst, peak])


func _fill(n: int) -> void:
	get_tree().paused = false
	var all := get_tree().get_nodes_in_group("enemies")
	for i in range(n, all.size()):
		(all[i] as Enemy).queue_free()
	var p := w.player.global_position
	for i in range(all.size(), n):
		var pos := w.room.open_near(p + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 300.0))
		w.spawn_enemy(IDS[i % IDS.size()], pos, 40.0, 1.0, false, true)
