extends Node
## RESCUE OPS (scenes/arenas/arena_proto_rescue.tscn, tools/build_proto_rescue.gd) played
## with the real game:
##   * unarmed, the button is a DASH, no waves, no LEVEL UP
##   * missions: rescue 5, escort 1, bonus chest; 5 survivors, the scientist escorted
##   * every survivor, alien pack and the extraction pad stand on reachable floor
##   * cameras have no endless alarm squads; the ALARM packs come in on an alarm
##   * rescuing each crew member counts; entering the vault springs the ambush;
##     the scientist follows to the pad and the arena is won
##   godot --headless --path . res://tests/rescue_ops_test.tscn

const ARENA := "res://scenes/arenas/arena_proto_rescue.tscn"

var failures := 0


func _ready() -> void:
	ArenaSession.arena_path = ARENA
	ArenaSession.test = true
	ArenaSession.invincible = true
	var host := (load(ArenaSession.PLAY_SCENE) as PackedScene).instantiate()
	add_child(host)
	var world := host.get_child(0) as ArenaWorld
	await _until(func() -> bool: return world.director != null and world.director.objectives != null \
		and world.room.walk_mask != null, 8.0)
	var p := world.player
	var arena := world.arena
	_check(not p.armed() and p.button_mode() == PlayerRules.AbilityButton.DASH, "unarmed, the button is a DASH")
	_check(not arena.data.waves_enabled and not arena.data.level_ups, "no waves, no level ups")
	var states: Array = world.director.objectives.states
	_check(states.size() == 3, "three missions")
	if states.size() == 3:
		_check(states[0].target == 5 and states[1].target == 1 and states[2].target == 1 and states[2].data.optional,
			"rescue 5, escort 1, bonus chest (%d / %d / %d)" % [states[0].target, states[1].target, states[2].target])
	var crew := arena.objects("ArenaSurvivor")
	_check(crew.size() == 5, "five survivors (%d)" % crew.size())
	var mask := world.room.walk_mask
	for o in arena.objects("ArenaSurvivor") + arena.objects("AlienPack") + arena.objects("ArenaTrigger"):
		_check(mask.has(o.global_position), "%s stands on reachable floor (%s)" % [o.name, Vector2i(o.global_position)])
	for cam in arena.find_children("*", "SecurityCamera", true, false):
		_check((cam as SecurityCamera).alarm_squad.is_empty(), "%s has no endless squad" % cam.name)
	# an alarm brings the ALARM packs
	var alarm_packs := arena.objects("AlienPack").filter(func(o: ArenaObject) -> bool:
		return (o as AlienPack).appear == AlienPack.Appear.ALARM)
	world.director.fire("alarm_raised", "cam_1", PackedStringArray(["alarm"]))
	await _wait(2.5)
	for a in alarm_packs:
		_check((a as AlienPack).members.size() == (a as AlienPack).count, "%s answered the alarm" % a.name)
	# rescue everyone; the scientist last (vault ambush, escort)
	var sci: ArenaSurvivor = null
	for o in crew:
		var s := o as ArenaSurvivor
		if not s.escort_to.is_empty():
			sci = s
			continue
		await _rescue(world, s)
	_check(sci != null, "the chief scientist waits in the vault")
	if sci == null:
		_end()
		return
	var ambush := arena.find_object(build_ambush_id()) as AlienPack
	await _rescue(world, sci)
	_check(ambush != null and ambush.members.size() > 0, "entering the vault sprang the ambush")
	_check(states[0].done, "all 5 crew rescued")
	# walk her home: the pad
	var pad := arena.find_object("extraction") as ArenaTrigger
	p.global_position = pad.global_position + Vector2(0, 20)
	sci.survivor.global_position = pad.global_position
	await _until(func() -> bool: return states[1].done, 4.0)
	_check(states[1].done, "the scientist reached the extraction pad")
	await _until(func() -> bool: return world.state == "won", 4.0)
	_check(world.state == "won", "RESCUE OPS won")
	_end()


func build_ambush_id() -> String:
	return "vault_ambush"


func _rescue(world: ArenaWorld, s: ArenaSurvivor) -> void:
	world.player.global_position = s.global_position + Vector2(18, 6)
	world.camera.reset_smoothing()
	var ok := await _until(func() -> bool: return s._rescued, s.rescue_time + 4.0)
	_check(ok, "rescued %s" % s.name)


func _end() -> void:
	ArenaSession.arena_path = ""
	print("RESCUE OPS TEST: %s" % ("PASS" if failures == 0 else "FAILED (%d)" % failures))
	get_tree().quit(0 if failures == 0 else 1)


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
