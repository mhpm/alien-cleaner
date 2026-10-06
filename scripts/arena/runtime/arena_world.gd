class_name ArenaWorld
extends GameWorld
## Plays an Arena Editor scene with the real game: GameWorld's player, camera, HUD,
## pickups, upgrades and combat, unchanged. The arena's terrain sits behind the
## entities; its props and gameplay objects come alive through an ArenaDirector.
## The Room only provides the invisible bounding walls (its own art is hidden).
## A Survival director runs with its clock off: it gives XP gems, level-ups and the
## alien damage scaling, while the arena's own waves decide what spawns.

var arena: Arena
var director: ArenaDirector
var _clear_color := Color()


func _ready() -> void:
	ArenaSession.load_request()
	var packed := load(ArenaSession.arena_path) as PackedScene if ResourceLoader.exists(ArenaSession.arena_path) else null
	if packed != null:
		arena = packed.instantiate() as Arena
	ArenaSession.begin(arena.data.world_id if arena != null and arena.data != null else 1)
	super._ready()


func _exit_tree() -> void:
	if _clear_color != Color():
		RenderingServer.set_default_clear_color(_clear_color)
	super._exit_tree()
	ArenaSession.finish()


func _start_room() -> void:
	room_def = {}
	level_def = {}
	if arena == null:
		hud.banner("NO ARENA TO PLAY", Color("ff5566"), 24, 3.0)
		push_error("ArenaWorld: could not load arena \"%s\"" % ArenaSession.arena_path)
		return
	var data := arena.data if arena.data != null else ArenaData.new()
	var b := arena.get_bounds()
	var rect := Rect2(b.position, b.size) if b != null else Rect2(0, 0, 832, 1088)
	# the arena's bounds become the room: (0, 0) at its top-left corner
	room.build_arena(Vector2i(ceili(rect.size.x / Room.TILE), ceili(rect.size.y / Room.TILE)), entities, 1)
	room.visible = false
	arena.position = -rect.position
	add_child(arena)
	move_child(arena, 0)
	var spawn := rect.get_center() - rect.position
	for o in arena.objects("PlayerSpawn"):
		spawn = o.global_position
		player.body.set_character((o as PlayerSpawn).character)
		break
	player.reset_for_room(spawn)
	_camera_setup()
	camera.reset_smoothing()
	survival = Survival.new()
	survival.setup(self, {"waves": [], "boss": "", "hp_per_min": 0.0, "t_offset": 0.0})
	if not data.level_ups:
		survival.choosing = true  # XP gems still drop, but no upgrade choices
	add_child(survival)
	# its clock stays off (the arena's waves decide what spawns); after add_child, because
	# entering the tree re-enables _physics_process
	survival.set_physics_process(false)
	hud.enable_survival(data.level_ups)
	hud.weapon_label.visible = false  # the wave line needs the room; objectives sit below it
	hud.controls.enabled = true
	hud.room_label.text = "00:00"
	director = ArenaDirector.new().setup(self, arena)
	director.waves_skip = ArenaSession.start_wave
	add_child(director)
	director.arena_finished.connect(_on_arena_finished)
	Sfx.play_music(data.music)
	_clear_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	RenderingServer.set_default_clear_color(data.background)
	if data.ambient != Color.WHITE:
		var light := CanvasModulate.new()
		light.color = data.ambient
		add_child(light)
	state = "intro"
	state_t = 1.4
	var title: String = data.display_name if not data.display_name.is_empty() else str(arena.name)
	hud.banner(title.to_upper(), Color("73eff7"), 26, 1.2)
	hud.set_wave_text("%s · %s" % [data.environment.to_upper(), data.difficulty_name().to_upper()])


func _begin_fight() -> void:
	super._begin_fight()
	if director != null and not director.finished and director.objectives == null:
		director.start()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if ArenaSession.invincible and player != null and not player.dead:
		player.invuln = maxf(player.invuln, 0.2)


func _guide_target() -> Vector2:
	if director == null or state != "survive":
		return Vector2.INF
	guide.color = Color("a7f070") if director.objectives != null and director.objectives.main_done() else Color("ffcd75")
	return director.guide_target


func enemy_killed(e: Enemy) -> void:
	super.enemy_killed(e)
	if director != null and director.objectives != null:
		director.on_enemy_killed(e)


func on_player_died() -> void:
	state = "dead"
	hud.controls.enabled = false
	if director != null:
		director.finish(false, "The aliens got you.")


func _on_arena_finished(won: bool, reason: String) -> void:
	if won:
		state = "won"
		Sfx.play("victory", 0.0)
		for sh in get_tree().get_nodes_in_group("enemy_shots"):
			(sh as EnemyShot).pop()
	hud.controls.enabled = false
	var info := {
		"won": won, "reason": reason, "time": director.elapsed, "kills": director.kills,
		"coins": Game.run_coins, "objectives": director.objectives.summary() if director.objectives != null else [],
		"name": arena.data.display_name if arena.data != null else arena.name,
		"test": ArenaSession.test,
	}
	var delay := 1.3 if not won else 0.8
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not won:
			Sfx.play("gameover", 0.0)
		hud.call("show_arena_result", info))
