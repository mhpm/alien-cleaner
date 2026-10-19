extends Node
## Arena aliens only appear on floor the astronaut can reach (WalkMask, Room.walk_mask).
## Plays the pixel 2.5D prototype arena (two rooms joined by a corridor, void around it):
##   * the void between the rooms and below the corridor is never open, the rooms, the
##     maze and the corridor are,
##   * 600 arrival points (Survival._edge_pos, what hordes and the leash use) with the
##     astronaut standing next to the void all land on reachable floor,
##   * after a wave runs with the astronaut by the void, no living alien is off the floor,
## and times the build here and on the big open map of world 10.
##   godot --headless --path . res://tests/walk_mask_test.tscn

const PROTO := "res://scenes/arenas/arena_proto_pixel25d.tscn"
const BIG := "res://scenes/arenas/arena_world_10_level_01.tscn"

var failures := 0


func _ready() -> void:
	ArenaSession.arena_path = PROTO
	ArenaSession.invincible = true
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	var world := host.get_child(0) as GameWorld
	await get_tree().create_timer(3.0).timeout  # (intro, then the fight starts and the mask is built)
	var mask := world.room.walk_mask
	_check(mask != null, "the arena built a walk mask")
	if mask == null:
		_end()
		return
	print("MASK %d of %d cells reachable" % [mask.reachable, mask.cols * mask.rows])
	for p: Vector2 in [Vector2(700, 300), Vector2(700, 60), Vector2(700, 880), Vector2(2000, 1000),
			Vector2(320, 16), Vector2(16, 400), Vector2(1500, 16)]:  # void, behind the top walls, inside a side wall
		_check(not world.room.is_open(p), "no alien in the void at %s" % p)
	for p: Vector2 in [Vector2(320, 520), Vector2(320, 760), Vector2(704, 800), Vector2(1500, 470), Vector2(2720, 150)]:
		_check(mask.has(p), "reachable floor at %s" % p)
	var near := world.room.open_near(Vector2(700, 300))
	_check(mask.has(near), "open_near pulls a void point onto the floor (%s)" % near)
	# arrivals with the astronaut by the void
	var off := 0
	for stand: Vector2 in [Vector2(590, 300), Vector2(590, 790), Vector2(704, 800), Vector2(830, 400)]:
		world.player.global_position = stand
		for i in 150:
			var q := world.survival._edge_pos(randf() * TAU)
			if not mask.has(q):
				off += 1
	_check(off == 0, "600 arrivals next to the void, %d off the floor" % off)
	# a real wave
	world.player.global_position = Vector2(704, 800)
	world.camera.reset_smoothing()
	await get_tree().create_timer(9.0).timeout
	var bad := 0
	var alive := 0
	for e in world.entities.get_children():
		if e is Enemy and not (e as Enemy).dead:
			alive += 1
			if not mask.has((e as Enemy).global_position):
				bad += 1
				print("  off the floor: %s at %s" % [e.name, (e as Enemy).global_position])
	print("WAVE %d aliens alive" % alive)
	_check(alive > 0, "the wave sent aliens")
	_check(bad == 0, "no alien off the floor (%d)" % bad)
	# build cost
	var t := Time.get_ticks_usec()
	WalkMask.new().build((world as ArenaWorld).arena, world.room.bounds(), Vector2(320, 800), world.get_world_2d().direct_space_state)
	print("BUILD prototype %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	host.queue_free()
	await get_tree().process_frame
	await _time_big()
	_end()


func _time_big() -> void:
	ArenaSession.arena_path = BIG
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	var world := host.get_child(0) as ArenaWorld
	await get_tree().create_timer(3.0).timeout
	var mask := world.room.walk_mask
	_check(mask != null and mask.reachable > 100, "world 10 built its mask")
	var t := Time.get_ticks_usec()
	var spawn := world.player.global_position
	WalkMask.new().build(world.arena, world.room.bounds(), spawn, world.get_world_2d().direct_space_state)
	var ms := (Time.get_ticks_usec() - t) / 1000.0
	print("BUILD world 10 (%d cells) %.1f ms" % [mask.cols * mask.rows if mask != null else 0, ms])
	_check(ms < 400.0, "world 10 mask builds in under 400 ms (%.1f)" % ms)
	host.queue_free()


func _end() -> void:
	ArenaSession.arena_path = ""
	print("WALK MASK TEST: %s" % ("PASS" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL  ", what)
