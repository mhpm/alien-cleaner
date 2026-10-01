extends GameWorld
## One exact wave, then one selected boss. No normal director or progression.

var phase := "ready"
var selected_boss: Enemy
var boss_started := false


func _ready() -> void:
	PlaygroundSession.begin()
	super._ready()


func _exit_tree() -> void:
	super._exit_tree()
	PlaygroundSession.finish()


func _start_room() -> void:
	room_def = {}
	level_def = {}
	room.build_arena(Vector2i(64, 72), entities, 4137)
	player.reset_for_room(room.bounds().get_center())
	_camera_setup()
	guide.visible = false
	survival = Survival.new()
	survival.setup(self, {"waves": [], "boss": PlaygroundSession.boss_id, "hp_per_min": 0.0, "t_offset": 0.0})
	survival.set_physics_process(false)
	add_child(survival)
	hud.enable_survival(false)
	hud.controls.enabled = true
	hud.room_label.text = "PRUEBA"
	state = "intro"
	state_t = 1.0
	hud.banner("PLAYGROUND", Color("73eff7"), 28, 1.0)


func _physics_process(delta: float) -> void:
	enemy_cache = get_tree().get_nodes_in_group("enemies")
	_build_enemy_grid()
	_read_input()
	if PlaygroundSession.invulnerable:
		player.invuln = 2.0
	if state in ["won", "dead"]:
		return
	if state == "intro":
		state_t -= delta
		if state_t <= 0.0:
			state = "fight"
			if PlaygroundSession.total() > 0:
				_start_wave()
			else:
				_start_boss()
	elif phase == "wave" and enemy_cache.is_empty():
		if PlaygroundSession.boss_id.is_empty():
			_complete()
		else:
			_start_boss()
	elif phase == "boss" and boss_started and (not is_instance_valid(selected_boss) or selected_boss.dead):
		_complete()


func _guide_target() -> Vector2:
	return Vector2.INF


func _start_wave() -> void:
	phase = "wave"
	hud.set_wave(1, 1)
	hud.banner("OLEADA 1 / 1", Color("73eff7"), 25, 0.7)
	var i := 0
	var total := PlaygroundSession.total()
	for id: String in PlaygroundSession.counts:
		for j in int(PlaygroundSession.counts[id]):
			var angle := TAU * i / maxf(total, 1)
			var distance := 110.0 + (i % 4) * 24.0
			spawn_enemy(id, room.arena_free_spot(player.global_position + Vector2.from_angle(angle) * distance))
			i += 1


func _start_boss() -> void:
	phase = "boss"
	# Remove lingering wave hazards before the boss encounter starts.
	for effect in effects.get_children():
		effect.queue_free()
	for decal in decals.get_children():
		decal.queue_free()
	for node in get_tree().get_nodes_in_group("pickups"):
		node.queue_free()
	player.input_dir = Vector2.ZERO
	player.reset_for_room(room.bounds().get_center() + Vector2(0, 70))
	var center := room.bounds().get_center()
	survival.fence = BossFence.new().setup(center, Survival.FENCE_R)
	decals.add_child(survival.fence)
	Sfx.play_music("boss")
	hud.set_wave_text("JEFE")
	hud.banner(str(EnemyData.TYPES[PlaygroundSession.boss_id].name), Color("ff5566"), 25, 1.2)
	selected_boss = spawn_enemy(PlaygroundSession.boss_id, center + Vector2(0, -110))
	hud.show_boss(selected_boss)
	boss_started = true


func enemy_killed(e: Enemy) -> void:
	# Real death art and infection meter; no drops, rewards or save writes.
	burst(e.hit_center(), e.def.color, 20, 100.0, 0.5, 2.0)
	if Art.frames(e.art).has_animation("splat"):
		add_splat(e.global_position, e.art, e.base_scale, e.face < 0.0, e.tint)
	player.infected.on_kill(e)
	Sfx.play("pop", 0.1)


func _complete() -> void:
	state = "won"
	phase = "complete"
	hud.controls.enabled = false
	hud.hide_boss()
	if is_instance_valid(survival.fence):
		survival.fence.dissolve()
	for effect in effects.get_children():
		effect.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	hud.call("show_test_result", "PRUEBA COMPLETADA")


func on_player_died() -> void:
	state = "dead"
	hud.controls.enabled = false
	hud.call("show_test_result", "PRUEBA TERMINADA")
