extends Node
## Aliens on the open-field fast path / crowd glide must never end up inside walls.

func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Game.playground_active = true
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await get_tree().create_timer(2.0).timeout
	w.player.invuln = 9999.0
	w.survival.choosing = true
	w.survival.set_physics_process(false)  # only our aliens
	var p := w.player.global_position
	var made := 0
	while made < 300:
		var pos := p + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 500.0)
		if w.room.bounds().grow(-12.0).has_point(pos) and w.room.is_open(pos):
			w.spawn_enemy("slime" if made % 3 else "runner", pos, 50.0, 1.0, false, true)
			made += 1
	var space := w.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	var worst := 0
	for k in 8:
		await get_tree().create_timer(1.0).timeout
		get_tree().paused = false
		var stuck := 0
		var outside := 0
		var b := w.room.bounds()
		for e in get_tree().get_nodes_in_group("enemies"):
			q.position = (e as Node2D).global_position
			if not space.intersect_point(q, 1).is_empty():
				stuck += 1
			if not b.grow(4.0).has_point(q.position):
				outside += 1
		worst = maxi(worst, stuck + outside)
		print("LEAK t=%d alive=%d in_walls=%d outside=%d crowd_every=%d" % [k, get_tree().get_nodes_in_group("enemies").size(), stuck, outside, w.crowd_every])
	print("LEAK_CHECK: ", "PASS" if worst == 0 else "FAIL (%d)" % worst)
	get_tree().quit()
