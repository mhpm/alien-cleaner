extends Node
## The girl astronaut (CharacterData "girl"): picked with Game.character she is the
## player of a run, plays her poses while shooting and her PULSE BLASTER fires pink.
## Clearing world 1 unlocks her (Game.CREW): NEW CREW MEMBER! on the victory screen,
## "!" on the CREW tile, picked in the CREW panel.
## In a window saves user://girl_test_<pose>.png (zoomed on her), _victory, _crew.

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://girl_test_%s.png" % name)


func _run() -> void:
	Game.playground_active = true
	var keep := Game.character
	Game.character = "girl"
	Game.gun = "pulse"
	Game.new_run(0)
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	add_child(w)
	await _frames(20)
	w.player.invuln = 99999.0
	w.survival.set_physics_process(false)
	var c := w.player.body.character
	_check(c != null and c.character_id == "girl", "the run plays the girl")
	for a in CharacterData.ANIMS:
		_check(c.frames.has_animation(a), "she has the %s animation" % a)
	_check(ResourceLoader.exists("res://assets/guns/shot_pulse_pink.png"), "her pink shot art exists")
	for n in w.enemy_cache:
		if is_instance_valid(n):
			(n as Enemy).queue_free()
	(w.get_node("Camera2D") as Camera2D).zoom = Vector2(4, 4)
	await _frames(3)
	await _shot("idle")
	var dummy := w.spawn_enemy("slime", w.room.open_near(w.player.global_position + Vector2(70, 0)), 1.0, 1.0, false, true)
	dummy.max_hp = 1e9
	dummy.hp = dummy.max_hp
	dummy.speed = 0.0
	var pink := 0
	var cyan := 0
	for i in 120:
		dummy.hp = dummy.max_hp
		await get_tree().physics_frame
		for e in w.effects.get_children():
			if e is GunShot:
				if (e as GunShot).art == "shot_pulse_pink":
					pink += 1
				elif (e as GunShot).art == "shot_pulse":
					cyan += 1
	_check(pink > 0 and cyan == 0, "her pulse shots are pink (pink %d, cyan %d)" % [pink, cyan])
	await _shot("shoot_side")
	for pose: Array in [["down", Vector2(0, 70)], ["up", Vector2(0, -70)]]:
		dummy.global_position = w.room.open_near(w.player.global_position + (pose[1] as Vector2))
		await _frames(30)
		await _shot("shoot_" + str(pose[0]))
	print("GIRL anim while firing: ", w.player.body.body.animation)
	# walking while aiming up / down plays her walking aim (8 frames), standing the still pose
	var astro := w.player.body
	astro.shooting = true
	for k: Array in [[-PI * 0.5, "walk_shoot_up", "shoot_up"], [PI * 0.5, "walk_shoot_down", "shoot_down"]]:
		astro.aim = float(k[0])
		astro.play("walk")
		_check(astro.body.animation == StringName(k[1]) and astro.body.sprite_frames.get_frame_count(k[1]) == 8,
			"walking while aiming plays %s (got %s)" % [k[1], astro.body.animation])
		astro.play("idle")
		_check(astro.body.animation == StringName(k[2]), "standing while aiming plays %s" % k[2])
	var kid := CharacterData.load_id("kid_astronaut")
	_check(kid.resolve("walk_shoot_up") == "shoot_up", "a character without it keeps its still pose")
	# unlocking: clearing world 1 adds her to the crew
	var keep_chars := Game.characters.duplicate()
	var keep_cleared := Game.worlds_cleared
	var keep_new := Game.crew_new.duplicate()
	Game.characters = [CharacterData.DEFAULT_ID]
	Game.crew_new = []
	Game.worlds_cleared = 0
	Game.world_index = 0
	Game.record_world(400.0, true)
	_check(Game.characters.has("girl") and Game.last_crew == ["girl"], "clearing world 1 unlocks her")
	_check(Game.crew_new == ["girl"], "she is flagged new for the TALENTS badge")
	w.hud.show_victory({"time": 400.0, "kills": 900, "coins": 120, "gems": 300, "bonus": 150,
		"first": true, "next": true, "chest": true, "crew": ["girl"]})
	for i in 600:
		await get_tree().process_frame
	await _shot("victory")
	w.queue_free()
	get_tree().paused = false
	var ws := (load("res://scenes/world_select.tscn") as PackedScene).instantiate() as Control
	add_child(ws)
	for i in 30:
		await get_tree().process_frame
	_check(ws.get("badges").crew.visible, "the CREW tile shows the new crew badge")
	await _shot("world_select")
	CrewPanel.open(ws, func() -> void: pass)
	for i in 3:
		await get_tree().process_frame
	_check(Game.crew_new.is_empty(), "opening the CREW panel clears the badge")
	for i in 60:
		await get_tree().process_frame
	await _shot("crew")
	Game.characters = keep_chars
	Game.worlds_cleared = keep_cleared
	Game.crew_new = keep_new
	Game.character = keep
	Game.playground_active = false
	if failures.is_empty():
		print("GIRL TEST OK")
	else:
		print("GIRL TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
