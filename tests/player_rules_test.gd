extends Node
## Arena PlayerRules (escape / stealth missions): builds a small arena in memory whose
## rules say no weapon, ability button = DASH, 3 hits to die, speed x1.5, stealth 0.5,
## no upgrades, no mutation, and plays it with the real game:
##   no shot is fired with an alien right next to him, and no weapon is in the hand
##   the button dashes (a quick burst, briefly untouchable) on its own cooldown, "DASH"
##   walking is 1.5x faster
##   every hit costs a third of the health: three hits and he is down
##   placed aliens see / hear half as far; no LEVEL UP choices; MUTATE does nothing
##   ability_button NONE hides the button and makes it do nothing
##   leaving the arena puts the aliens' senses back
##   godot --headless --path . res://tests/player_rules_test.tscn

const PATH := "user://player_rules_test_arena.tscn"
const FLOOR := "res://assets/arena/pixel25d/floor.png"

var failures := 0


func _ready() -> void:
	_save_arena()
	ArenaSession.arena_path = PATH
	ArenaSession.invincible = false
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	var world := host.get_child(0) as ArenaWorld
	await _until(func() -> bool: return world.director != null and world.director.objectives != null, 6.0)
	var p := world.player
	_check(p.rules != null and not p.rules.weapon, "the arena's rules reach the player")
	_check(not p.armed() and p.body.unarmed, "no weapon allowed, none in the hand")
	await _wait(0.3)
	_check(not p.body.gun.visible, "the gun is not drawn")
	# an alien right next to him: no shooting
	var e := world.spawn_enemy("slime", p.global_position + Vector2(40, 0))
	e.mind = null
	var hp0 := e.hp
	await _wait(1.5)
	_check(is_instance_valid(e) and is_equal_approx(e.hp, hp0), "no shot fired at an alien next to him")
	if is_instance_valid(e):
		e.queue_free()
	# speed
	Input.action_press("move_right")
	await _wait(0.2)
	var want := float(Game.stats.move_speed) * 1.5
	_check(absf(p.velocity.x - want) < want * 0.1, "walks 1.5x faster (%.0f vs %.0f)" % [p.velocity.x, want])
	Input.action_release("move_right")
	# the button is a DASH
	Input.action_press("move_left")
	await _wait(0.05)
	var x0 := p.global_position.x
	p.blast()
	_check(p.invuln > 0.0, "dashing makes him briefly untouchable")
	await _wait(0.25)
	Input.action_release("move_left")
	_check(x0 - p.global_position.x > 45.0, "the dash bursts him away (%.0f)" % (x0 - p.global_position.x))
	_check(is_equal_approx(p.blast_t, 2.5) or p.blast_t > 2.0, "on its own cooldown (%.2f)" % p.blast_t)
	await _wait(0.1)
	_check(world.hud.controls.ability_label == "DASH" and not world.hud.controls.ability_hidden, "the button reads DASH")
	# senses, level ups, mutation
	_check(is_equal_approx(AlienMind.senses, 0.5), "placed aliens see / hear half as far")
	_check(world.survival.choosing, "no LEVEL UP choices")
	p.mutate()
	_check(not p.infected.active and not p.infected.transforming, "MUTATE does nothing")
	# three hits and he is down
	for i in 3:
		p.invuln = 0.0
		p.take_damage(1.0)
	_check(p.dead, "three tiny hits are enough (hits_to_die 3)")
	# NONE: no button
	p.rules.ability_button = PlayerRules.AbilityButton.NONE
	p.blast_t = 0.0
	await _wait(0.1)
	_check(world.hud.controls.ability_hidden, "NONE hides the ability button")
	host.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(is_equal_approx(AlienMind.senses, 1.0), "leaving the arena puts the senses back")
	ArenaSession.arena_path = ""
	print("PLAYER RULES TEST: %s" % ("PASS" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


func _save_arena() -> void:
	var arena := Arena.new()
	arena.name = "Arena"
	var data := ArenaData.new()
	data.arena_id = "rules_test"
	data.start_delay = 0.5
	data.minimap = false
	data.waves_enabled = false
	var r := PlayerRules.new()
	r.weapon = false
	r.ability_button = PlayerRules.AbilityButton.DASH
	r.dash_cooldown = 2.5
	r.mutation = false
	r.upgrades = false
	r.speed_mult = 1.5
	r.hits_to_die = 3
	r.alien_senses = 0.5
	data.player_rules = r
	var o := ObjectiveData.new()  # (an arena with no objective is won at once)
	o.type = ObjectiveData.Type.SURVIVE
	o.target_count = 600
	data.objectives = [o] as Array[ObjectiveData]
	arena.data = data
	for layer_name: String in Arena.LAYERS:
		var n: Node = TileMapLayer.new() if layer_name == "Walls" else Node2D.new()
		n.name = layer_name
		_own(arena, arena, n)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load(FLOOR)
	src.texture_region_size = Vector2i(32, 32)
	src.create_tile(Vector2i(0, 0))
	ts.add_source(src, 0)
	for layer_name: String in Arena.TERRAIN:
		var tl := TileMapLayer.new()
		tl.name = layer_name
		tl.tile_set = ts
		_own(arena, arena.get_node("Terrain"), tl)
	var fl := arena.get_node("Terrain/Floor") as TileMapLayer
	for y in 24:
		for x in 24:
			fl.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	var bounds := ArenaBounds.new()
	bounds.name = Arena.BOUNDS
	bounds.size = Vector2(24, 24) * Arena.TILE
	_own(arena, arena, bounds)
	var spawn := PlayerSpawn.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(380, 400)
	_own(arena, arena.get_node("GameplayObjects"), spawn)
	var packed := PackedScene.new()
	packed.pack(arena)
	ResourceSaver.save(packed, PATH)
	arena.free()


func _own(arena: Arena, parent: Node, n: Node) -> void:
	parent.add_child(n)
	n.owner = arena


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _until(cond: Callable, secs: float) -> bool:
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


func _check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1
