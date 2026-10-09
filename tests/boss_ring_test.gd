extends Node
## Every world: when the final boss fight starts, the ring inside its BossFence is
## cleared (Explore.clear_ring): no wall, furniture or machinery left inside, the
## astronaut can cross it. Saves user://boss_ring_<world>.png when run in a window:
##   Godot --path . res://tests/boss_ring_test.tscn

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	Game.playground_active = true
	for wi in WorldData.WORLDS.size():
		Game.new_run(wi)
		var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
		add_child(w)
		await _frames(10)
		w.player.invuln = 99999.0
		w.survival.choosing = true
		# start the final fight somewhere in the middle of the map
		w.player.global_position = w.room.open_near(w.room.bounds().get_center())
		w.survival._send_final()
		await _frames(20)
		var f := w.survival.fence
		var c := f.global_position
		var r: float = Survival.FENCE_R
		var inside := 0
		for q in w.room.blockers:
			var near := (c.clamp(q.position, q.end) - c).length()
			if near < r - 4.0 and w.room.bounds().grow(-2.0).encloses(q):
				inside += 1
				print("  left inside world %d: %s at %.0f from the centre" % [wi + 1, q, near])
		_check(w.explore == null or inside == 0, "world %d: %d solid rects left inside the boss ring" % [wi + 1, inside])
		# walk across the ring: nothing stops the astronaut
		var probes := 0
		for k in 16:
			var p := c + Vector2.from_angle(TAU * k / 16.0) * r * 0.8
			if w.room.bounds().grow(-20.0).has_point(p) and not w.room.is_open(p, 0.0):
				probes += 1
		_check(w.explore == null or probes == 0, "world %d: %d blocked spots inside the ring" % [wi + 1, probes])
		if DisplayServer.get_name() != "headless":
			w.player.global_position = c + Vector2(0, 60)
			await _frames(30)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("user://boss_ring_%d.png" % (wi + 1))
		print("BOSS RING world %d: explore=%s inside=%d" % [wi + 1, w.explore != null, inside])
		w.queue_free()
		await _frames(5)
	Game.playground_active = false
	print("BOSS RING TEST OK" if failures.is_empty() else "BOSS RING TEST FAILED: %s" % str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
