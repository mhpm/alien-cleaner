extends Node
## Performance bench: plays an arena (ArenaWorld, god mode, no level-up menus) and keeps
## N tough aliens alive around the astronaut, printing the frame time for each N.
## Run it windowed so drawing counts too, outside the editor for steadier numbers:
##   Godot --path . res://tests/arena_perf_bench.tscn
## Numbers swing with whatever else the machine is doing: compare runs side by side.

const ARENA := "res://scenes/arenas/arena_world_10_level_01.tscn"
const COUNTS := [0, 100, 200, 300, 500, 800]
const IDS := ["slime", "slime", "runner", "slime", "mini_slime", "spitter"]
const WARMUP := 1.0
const MEASURE := 2.5

var w: GameWorld


func _ready() -> void:
	call_deferred("_run")


func _secs(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	ArenaSession.arena_path = ARENA
	ArenaSession.invincible = true
	add_child((load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate())
	w = Game.world
	await _secs(2.0)
	w.survival.choosing = true  # no level-up menus (they pause the tree mid-measure)
	var dlg := w.find_child("ArenaDialogue", true, false)
	if dlg != null:
		dlg.queue_free()  # arena dialogues pause the tree
	print("BENCH arena=", ARENA)
	for n: int in COUNTS:
		_fill(n)
		await _secs(WARMUP)
		var frames := 0
		var worst := 0.0
		var t0 := Time.get_ticks_usec()
		var last := t0
		var steps0 := Engine.get_physics_frames()
		while Time.get_ticks_usec() - t0 < int(MEASURE * 1e6):
			_fill(n)
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
			frames += 1
		var total := (Time.get_ticks_usec() - t0) / 1000.0
		print("BENCH n=%-4d alive=%-4d fps=%-4.0f frame=%6.2fms worst=%6.1fms physics_steps/frame=%.2f crowd_every=%d draws=%d" % [
			n, w.enemy_cache.size(), frames / (total / 1000.0), total / frames, worst,
			float(Engine.get_physics_frames() - steps0) / frames, w.crowd_every,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	print("BENCH done")
	get_tree().quit()


## Tops the horde up to `n` tough aliens in a ring around the astronaut (fewer: the
## extra ones are cleared).
func _fill(n: int) -> void:
	get_tree().paused = false
	var all := get_tree().get_nodes_in_group("enemies")
	for i in range(n, all.size()):
		(all[i] as Enemy).queue_free()
	var p := w.player.global_position
	for i in range(all.size(), n):
		var pos := p + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 220.0)
		w.spawn_enemy(IDS[i % IDS.size()], pos, 40.0, 1.0, false, true)
