extends Node
## Catalog, exact wave->boss routing and isolation from persistent progression.
var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _make_world() -> GameWorld:
	var w := (load("res://scenes/game.tscn") as PackedScene).instantiate() as GameWorld
	w.set_script(load("res://scripts/playground/playground_world.gd"))
	w.get_node("HUD").set_script(load("res://scripts/playground/playground_hud.gd"))
	add_child(w)
	w.process_mode = Node.PROCESS_MODE_DISABLED
	return w


func _remove_wave(w: GameWorld) -> void:
	for n in w.get_tree().get_nodes_in_group("enemies"):
		(n as Enemy).dead = true
		n.remove_from_group("enemies")
		n.queue_free()


func _run() -> void:
	var saved_bytes := FileAccess.get_file_as_bytes(Game.SAVE_PATH) if FileAccess.file_exists(Game.SAVE_PATH) else PackedByteArray()
	var had_save := FileAccess.file_exists(Game.SAVE_PATH)
	var original_setting: Variant = ProjectSettings.get_setting(PlaygroundSession.SETTING, false)
	ProjectSettings.set_setting(PlaygroundSession.SETTING, true)
	var original_state: Dictionary = {}
	for key: String in PlaygroundSession.STATE_KEYS:
		var value: Variant = Game.get(key)
		original_state[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	PlaygroundSession.counts.clear()
	PlaygroundSession.boss_id = ""
	PlaygroundSession.invulnerable = true
	PlaygroundSession.enemies_invincible = false
	PlaygroundSession.boss_invincible = false
	_check(not PlaygroundSession.valid(), "Empty selection disables play")
	var picker := (load(PlaygroundSession.PICKER) as PackedScene).instantiate()
	add_child(picker)
	await get_tree().process_frame
	var list: VBoxContainer = picker.get("rows")
	_check(list.get_child_count() == PlaygroundSession.catalog(false).size(), "Complete enemy catalog")
	var droid_row := list.get_node("droid")
	(droid_row.find_child("Plus", true, false) as Button).pressed.emit()
	_check(PlaygroundSession.counts == {"droid": 1}, "Row buttons select the correct enemy")
	picker.call("_quantity", "droid", 1)
	picker.call("_quantity", "slime", 1)
	(picker.get("tabs")[1] as Button).pressed.emit()
	_check(list.get_child_count() == PlaygroundSession.catalog(true).size(), "Complete boss catalog")
	(list.get_node("orbit_warden").find_child("Choose", true, false) as Button).pressed.emit()
	_check(PlaygroundSession.boss_id == "orbit_warden", "Boss card selects the correct boss")
	_check(PlaygroundSession.valid() and PlaygroundSession.total() == 3, "Combined selection can play")
	var enemy_switch := picker.find_child("EnemiesInvincible", true, false) as CheckButton
	var boss_switch := picker.find_child("BossInvincible", true, false) as CheckButton
	enemy_switch.button_pressed = true
	_check(PlaygroundSession.enemies_invincible and not PlaygroundSession.boss_invincible, "Enemy switch is independent")
	boss_switch.button_pressed = true
	_check(PlaygroundSession.boss_invincible, "Boss switch updates session")
	enemy_switch.button_pressed = false
	_check(not PlaygroundSession.enemies_invincible and PlaygroundSession.boss_invincible, "Enemy toggle leaves boss toggle intact")
	boss_switch.button_pressed = false
	picker.queue_free()
	await get_tree().process_frame

	var w := _make_world()
	w._physics_process(1.1)
	_check(str(w.get("phase")) == "wave", "Combined test starts with wave")
	var ids: Array[String] = []
	for n in get_tree().get_nodes_in_group("enemies"):
		ids.append((n as Enemy).type_id)
	ids.sort()
	_check(ids == ["droid", "droid", "slime"], "Wave contains precisely the selected quantities")
	_check(not bool(w.get("boss_started")), "Boss cannot start before wave clears")
	var target := get_tree().get_nodes_in_group("enemies")[0] as Enemy
	target.spawn_t = 0.0
	target.targetable = true
	var health_before := target.hp
	PlaygroundSession.enemies_invincible = true
	target.take_damage(target.max_hp * 100.0)
	_check(target.hp == health_before and not target.dead, "Invincible enemies ignore lethal damage")
	PlaygroundSession.enemies_invincible = false
	PlaygroundSession.boss_invincible = true
	target.take_damage(1.0)
	_check(target.hp < health_before, "Boss immunity must not protect regular enemies")
	Game.total_xp += 999
	Game.run_coins = 999
	Game.save()
	Game.end_run()
	_check(Game.bank == original_state.bank and Game.runs == original_state.runs, "Test run cannot bank coins or record runs")
	_remove_wave(w)
	await get_tree().process_frame
	w._physics_process(0.016)
	_check(str(w.get("phase")) == "boss" and bool(w.get("boss_started")), "Cleared wave starts chosen boss")
	_check((w.get("selected_boss") as Enemy).type_id == "orbit_warden", "Correct boss spawned")
	_check(is_instance_valid(w.survival.fence), "Boss encounter has a fence")
	var boss := w.get("selected_boss") as Enemy
	boss.spawn_t = 0.0
	boss.targetable = true
	health_before = boss.hp
	boss.take_damage(boss.max_hp * 100.0)
	_check(boss.hp == health_before and not boss.dead, "Invincible boss ignores lethal damage")
	var minion := w.spawn_enemy("orbit_spawn", boss.position + Vector2(30, 0))
	minion.spawn_t = 0.0
	minion.targetable = true
	minion.take_damage(minion.max_hp * 100.0)
	_check(minion.dead, "Boss immunity does not automatically protect summoned minions")
	PlaygroundSession.boss_invincible = false
	PlaygroundSession.enemies_invincible = true
	boss.take_damage(10.0)
	_check(boss.hp < health_before, "Enemy immunity must not protect the boss")
	var immune_minion := w.spawn_enemy("orbit_spawn", boss.position + Vector2(-30, 0))
	immune_minion.spawn_t = 0.0
	immune_minion.targetable = true
	immune_minion.take_damage(immune_minion.max_hp * 100.0)
	_check(not immune_minion.dead, "Enemy immunity also protects summoned enemies")
	PlaygroundSession.boss_invincible = true
	Game.playground_active = false
	health_before = immune_minion.hp
	immune_minion.take_damage(1.0)
	_check(immune_minion.hp < health_before, "Test immunity flags must not affect normal runs")
	Game.playground_active = true
	PlaygroundSession.enemies_invincible = false
	PlaygroundSession.boss_invincible = false
	(w.get("selected_boss") as Enemy).die()
	w._physics_process(0.016)
	_check(w.state == "won", "Boss defeat finishes test without world victory")
	get_tree().paused = false
	w.queue_free()
	await get_tree().process_frame
	for key: String in original_state:
		_check(Game.get(key) == original_state[key], "Restores original state: " + key)
	_check(not Game.playground_active, "Leaving clears sandbox flag")

	PlaygroundSession.counts.clear()
	w = _make_world()
	w._physics_process(1.1)
	_check(str(w.get("phase")) == "boss", "Boss-only selection skips wave")
	w.on_player_died()
	_check(w.state == "dead", "Death opens test result")
	get_tree().paused = false
	w.queue_free()
	await get_tree().process_frame
	_check(Game.runs == original_state.runs, "Death cannot record a run")

	PlaygroundSession.boss_id = ""
	PlaygroundSession.counts = {"slime": 1}
	w = _make_world()
	w._physics_process(1.1)
	_remove_wave(w)
	await get_tree().process_frame
	w._physics_process(0.016)
	_check(w.state == "won" and not bool(w.get("boss_started")), "Wave-only selection finishes without a boss")
	get_tree().paused = false
	w.queue_free()
	await get_tree().process_frame
	ProjectSettings.set_setting(PlaygroundSession.SETTING, false)
	_check(not PlaygroundSession.enabled() and not PlaygroundSession.valid(), "Disable switch blocks access and play")
	var title := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	add_child(title)
	_check(not title.has_node("PlaygroundButton"), "Disabled title has no test entry")
	title.queue_free()
	await get_tree().process_frame
	_check(FileAccess.file_exists(Game.SAVE_PATH) == had_save, "Test does not create a save file")
	if had_save:
		_check(FileAccess.get_file_as_bytes(Game.SAVE_PATH) == saved_bytes, "Save file remains byte-for-byte unchanged")
	PlaygroundSession.counts.clear()
	PlaygroundSession.invulnerable = false
	PlaygroundSession.enemies_invincible = false
	PlaygroundSession.boss_invincible = false
	ProjectSettings.set_setting(PlaygroundSession.SETTING, original_setting)
	if failures.is_empty():
		print("PLAYGROUND_TEST: PASS (catalog, buttons, exact wave, boss-only, wave-only, independent immunity switches, normal-run isolation, results, save isolation, disable switch)")
	else:
		print("PLAYGROUND_TEST: FAIL ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
