extends Node
## The ability button shows the character's ability (CharacterAbility.icon / meter) and
## the MUTATE button above it the infection meter; BLAST never mutates, only MUTATE does.
## In a window saves user://ability_hud_<character>.png (bottom-right corner).

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, m: String) -> void:
	if not ok:
		failures.append(m)
		push_error(m)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	img.get_region(Rect2i(w / 2, h / 2, w / 2, h / 2)).save_png("user://ability_hud_%s.png" % name)


func _run() -> void:
	Game.playground_active = true
	var keep_char := Game.character
	var keep_inf := int(Game.perm.infected)
	Game.perm.infected = 1  # Infected Mode on: the MUTATE button shows
	for id: String in ["girl", "kid_astronaut"]:
		Game.character = id
		Game.new_run(0)
		var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
		add_child(w)
		await _frames(20)
		w.player.invuln = 99999.0
		w.survival.set_physics_process(false)
		var c := w.hud.controls
		_check(c.ability_icon != null and c.ability_icon == w.player.ability.icon(), "%s: the ability button shows her ability icon" % id)
		if id == "girl":
			_check(c.ability_meter >= 0.0, "girl: the button shows the heart meter")
		_check(c.infect_state == 1 and c.mutate_icon != null, "%s: the MUTATE button shows, charging" % id)
		w.player.infected.charge = 1.0
		await _frames(3)
		_check(c.infect_state == 2, "%s: full meter = MUTATE!" % id)
		await _shot(id)
		w.player.blast_t = 0.0
		w.player.blast()
		_check(not w.player.infected.transforming and not w.player.infected.active, "%s: BLAST does not mutate" % id)
		w.player.mutate()
		_check(w.player.infected.transforming or w.player.infected.active, "%s: MUTATE mutates" % id)
		w.queue_free()
		await _frames(3)
	Game.character = keep_char
	Game.perm.infected = keep_inf
	Game.playground_active = false
	if failures.is_empty():
		print("ABILITY HUD TEST OK")
	else:
		print("ABILITY HUD TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
