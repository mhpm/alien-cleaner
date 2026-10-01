class_name GameWorld
extends Node2D
## Runs a world: builds rooms, spawns waves, handles CLEAN / upgrades / exit flow,
## and exposes game-feel helpers (shake, hitstop, particles, popups).

## Later waves of a room are sturdier; the last wave of a 3+ wave room brings elites.
const WAVE_HP_STEP := 0.22
const ROOM_BUDGET_MULT := 1.35  # rooms: more aliens per "budget" wave than the data says
const WAVE_SPEED_STEP := 0.05

@onready var room: Room = $Room
@onready var decals: Node2D = $Decals
@onready var entities: Node2D = $Entities
@onready var effects: Node2D = $Effects
@onready var camera: Camera2D = $Camera2D
@onready var hud: Hud = $HUD

var player: Player
var room_def: Dictionary = {}
var waves: Array = []
var state := "start"
var state_t := 0.0
var pending := 0
var shake_amt := 0.0
var hitstop_until := 0
# space station levels (StationData): sectors to clean, camera follows the player
var station_mode := false
var level_def: Dictionary = {}
var sectors_clean: Array[bool] = []
var sector := -1
var boss_pending := ""
var guide: GuideArrow
var wave_i := 0  # waves spawned so far in this room / sector
var wave_n := 0
var follow_cam := false
var indicators: OffscreenIndicators
var survival: Survival  # survivor-style stage director (WorldData "survival")
var enemy_cache: Array[Node] = []  # the "enemies" group, refreshed every physics frame
const GRID_CELL := 16.0
var enemy_grid: Dictionary = {}  # Vector2i cell -> aliens in it (same refresh): cheap neighbour lookups


func _ready() -> void:
	Game.world = self
	Engine.time_scale = 1.0
	get_tree().paused = false
	if Game.stats.is_empty():
		Game.new_run()
	player = Player.new()
	entities.add_child(player)
	# frame the painted room art exactly (it is authored for a portrait phone)
	camera.position = room.art_rect().get_center()
	guide = GuideArrow.new()
	guide.player = player
	guide.z_index = 20
	add_child(guide)
	indicators = OffscreenIndicators.new()
	indicators.camera = camera
	indicators.z_index = 30
	add_child(indicators)
	hud.setup(self)
	Sfx.play_music("level")
	_start_room()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if Game.world == self:
		Game.world = null


# ---------------------------------------------------------------- room flow

func _start_room() -> void:
	for c in entities.get_children():
		if c != player:
			c.queue_free()
	for c in decals.get_children():
		c.queue_free()
	for c in effects.get_children():
		c.queue_free()
	pending = 0
	room_def = WorldData.room(Game.world_index, Game.room_index)
	level_def = room_def
	if survival != null:
		survival.queue_free()
		survival = null
	hud.enable_survival(room_def.has("survival"))
	if room_def.has("survival"):
		_start_survival()
		return
	if room_def.has("station"):
		_start_station()
		return
	station_mode = false
	var layouts: Array = room_def.layouts
	var lname: String = layouts[randi() % layouts.size()]
	var world_def := WorldData.world(Game.world_index)
	room.build(WorldData.LAYOUTS[lname], entities, str(world_def.get("theme", "ship")))
	# enter from the bottom of the room, the exit door is at the top
	player.reset_for_room(Vector2(room.room_w * 0.5, room.room_h - 18.0))
	_camera_setup()
	var ws: Array = room_def.get("waves", [])
	waves = ws.duplicate()
	_reset_waves()
	# boss rooms with waves: the boss arrives after them
	boss_pending = str(room_def.get("boss", "")) if not waves.is_empty() else ""
	hud.set_room(Game.global_room(), WorldData.total_rooms())
	hud.controls.enabled = true
	state = "intro"
	state_t = 0.9
	if room_def.has("boss") and waves.is_empty():
		var world_boss := WorldData.is_last_room(Game.world_index, Game.room_index)
		hud.banner("BOSS!" if world_boss else "MINI BOSS", Color("ff5566"), 44, 1.0)
		state_t = 1.3
	elif Game.room_index == 0:
		var col := Color("c75bd6") if Game.world_index > 0 else Color("73eff7")
		hud.banner(str(world_def.name), col, 22, 1.2)
		if Game.world_index > 0:
			state_t = 1.4
	else:
		hud.banner("ROOM %d" % Game.global_room(), Color("f4f4f4"), 32, 0.6)


## Small rooms: the camera frames the painted room exactly. Big rooms: it follows
## the astronaut and never shows past the painted art.
func _camera_setup() -> void:
	follow_cam = room.follows_camera()
	guide.target = Vector2.INF
	if not follow_cam:
		camera.position = room.art_rect().get_center()
		for side in [SIDE_LEFT, SIDE_TOP]:
			camera.set_limit(side, -10000000)
		for side in [SIDE_RIGHT, SIDE_BOTTOM]:
			camera.set_limit(side, 10000000)
		return
	var r := room.art_rect()
	camera.set_limit(SIDE_LEFT, int(r.position.x))
	camera.set_limit(SIDE_TOP, int(r.position.y))
	camera.set_limit(SIDE_RIGHT, int(r.end.x))
	camera.set_limit(SIDE_BOTTOM, int(r.end.y))
	camera.position = player.global_position + Vector2(0, -10)
	camera.reset_smoothing()


## World-space size of what the camera shows (depends on the camera zoom and screen).
## Buckets the aliens by GRID_CELL so each one only checks its neighbours (Enemy
## separation): hordes of 150+ would otherwise cost n^2 checks every frame.
func _build_enemy_grid() -> void:
	enemy_grid.clear()
	for n in enemy_cache:
		var e := n as Node2D
		var c := Vector2i((e.global_position / GRID_CELL).floor())
		var bucket: Array = enemy_grid.get(c, [])
		if bucket.is_empty():
			enemy_grid[c] = bucket
		bucket.append(e)


func view_size() -> Vector2:
	return get_viewport_rect().size / camera.zoom


## How far the auto-aim reaches: everything in rooms that fit the screen, roughly what
## is on screen when the camera scrolls.
func aim_range() -> float:
	if not follow_cam:
		return INF
	var v := view_size()
	return maxf(Room.FOLLOW_AIM_RANGE, minf(v.x, v.y) * 0.5 + 40.0)


func _reset_waves() -> void:
	wave_i = 0
	wave_n = waves.size()
	hud.set_wave(0, wave_n)


# ---------------------------------------------------------------- survival flow

## Survivor-style stage: wide arena, clock, endless escalating waves (see Survival).
func _start_survival() -> void:
	station_mode = false
	var sd: Dictionary = room_def.survival
	room.build_arena(sd.get("arena", Vector2i(64, 96)), entities, randi(), str(sd.get("art", "")))
	room.modulate = sd.get("tint", Color.WHITE)  # world 3: a violet floor
	player.reset_for_room(room.bounds().get_center() + Vector2(0, 24))
	_camera_setup()
	waves = []
	wave_n = 0
	boss_pending = ""
	survival = Survival.new()
	survival.setup(self, sd)
	add_child(survival)
	hud.controls.enabled = true
	state = "intro"
	state_t = 1.4
	var world_def := WorldData.world(Game.world_index)
	hud.banner(str(world_def.name), Color("c75bd6") if Game.world_index > 0 else Color("73eff7"), 22, 1.2)


## The final boss is down: stage clear, an exit portal opens near the player.
func _survival_clear() -> void:
	state = "cleared"
	state_t = 1.6
	hud.hide_boss()
	hud.banner("STAGE CLEAR!", Color("a7f070"), 40, 1.3)
	Sfx.play_music("level")
	Sfx.play("clean", 0.0)
	for p in get_tree().get_nodes_in_group("pickups"):
		(p as Pickup).magnet = true
	for sh in get_tree().get_nodes_in_group("enemy_shots"):
		(sh as EnemyShot).pop()
	room.exit_pos = room.arena_free_spot(player.global_position + Vector2(0, -60), 16.0)
	hud.room_label.text = "CLEAR!"
	hud.set_wave_text("TO THE PORTAL")


# ---------------------------------------------------------------- station flow

func _start_station() -> void:
	station_mode = true
	follow_cam = true
	room.build_station(str(room_def.station))
	var st: Dictionary = StationData.get_def(str(room_def.station))
	sectors_clean.clear()
	for i in room.sector_count():
		sectors_clean.append(false)
	sector = -1
	boss_pending = ""
	waves = []
	player.reset_for_room(room.start_pos())
	# the camera follows the astronaut, never showing past the map
	var b := room.bounds()
	camera.set_limit(SIDE_LEFT, int(b.position.x))
	camera.set_limit(SIDE_TOP, int(b.position.y) - 40)
	camera.set_limit(SIDE_RIGHT, int(b.end.x))
	camera.set_limit(SIDE_BOTTOM, int(b.end.y) + 60)
	camera.position = player.global_position
	camera.reset_smoothing()
	_update_station_label()
	hud.controls.enabled = true
	state = "explore"
	hud.banner(str(st.name), Color("73eff7"), 24, 1.4)


func _update_station_label() -> void:
	var n := 0
	for c in sectors_clean:
		if c:
			n += 1
	hud.room_label.text = "SECTORS %d/%d" % [n, sectors_clean.size()]


func _enter_sector(i: int) -> void:
	sector = i
	room_def = level_def.duplicate()
	var sd: Dictionary = room.station.sectors[i]
	room_def.merge(sd, true)
	room_def.erase("station")
	room_def.erase("final")  # the station ends only when every sector is clean
	waves = (sd.get("waves", []) as Array).duplicate()
	_reset_waves()
	boss_pending = str(sd.get("boss", ""))
	room.lock_sector(i)
	hud.banner(str(sd.name), Color("ffcd75"), 22, 0.9)
	state = "intro"
	state_t = 0.8


func _all_sectors_clean() -> bool:
	return not sectors_clean.has(false)


## Where the guide arrow points: nearest dirty sector, or the open exit.
func _guide_target() -> Vector2:
	if state == "exit":
		guide.color = Color("a7f070")
		if room.arena:
			return room.exit_pos
		if not station_mode:
			return Vector2(room.room_w * 0.5, -8.0)
		return room.to_world(room.station.exit).get_center()
	if state != "explore":
		return Vector2.INF
	guide.color = Color("ffcd75")
	var best := Vector2.INF
	for i in sectors_clean.size():
		if not sectors_clean[i]:
			var c := room.sector_rect(i).get_center()
			if best == Vector2.INF or player.global_position.distance_to(c) < player.global_position.distance_to(best):
				best = c
	return best


func _spawn_boss(id: String, pos: Vector2, hp_mult := 1.0, dmg_mult := 1.0) -> void:
	pending += 1
	var m := _marker(pos, 1.0, 22.0, Color("ff5566"))
	m.finished.connect(func() -> void:
		var b := spawn_enemy(id, pos, hp_mult, 1.0, false, false, dmg_mult)
		hud.show_boss(b)
		Sfx.play("roar", 0.0)
		shake(0.7)
		pending -= 1)


func _begin_fight() -> void:
	if survival != null:
		state = "survive"
		return
	state = "fight"
	if not waves.is_empty():
		_spawn_wave(waves.pop_front())
	elif not station_mode and room_def.has("boss"):
		_spawn_boss(str(room_def.boss), _boss_pos())


func _physics_process(delta: float) -> void:
	enemy_cache = get_tree().get_nodes_in_group("enemies")
	_build_enemy_grid()
	_read_input()
	match state:
		"explore":
			var i := room.sector_at(player.global_position)
			if i >= 0 and not sectors_clean[i]:
				_enter_sector(i)
		"intro":
			state_t -= delta
			if state_t <= 0.0:
				_begin_fight()
		"fight":
			if pending == 0 and get_tree().get_nodes_in_group("enemies").is_empty():
				if waves.is_empty() and boss_pending != "":
					# the sector boss arrives after its waves
					hud.banner("BOSS!", Color("ff5566"), 44, 1.0)
					_spawn_boss(boss_pending, _boss_pos())
					boss_pending = ""
				elif waves.is_empty():
					_room_cleared()
				else:
					state = "gap"
					state_t = 0.6
		"gap":
			state_t -= delta
			if state_t <= 0.0:
				state = "fight"
				_spawn_wave(waves.pop_front())
		"cleared":
			state_t -= delta
			if state_t <= 0.0:
				_after_clear()
		"exit":
			if (room.exit_reached(player.global_position) if station_mode or room.arena else player.global_position.y < -14.0):
				_leave_room()


func _read_input() -> void:
	var v := hud.controls.output
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.1:
		v = k
	var can_move := state in ["intro", "fight", "gap", "cleared", "exit", "explore", "survive"]
	player.input_dir = v if can_move else Vector2.ZERO
	if can_move and Input.is_action_just_pressed("ability"):
		player.blast()


func _room_cleared() -> void:
	state = "cleared"
	state_t = 1.1
	if station_mode:
		sectors_clean[sector] = true
		room.unlock_sector()
		_update_station_label()
		if _all_sectors_clean():
			hud.banner("STATION CLEAN!", Color("a7f070"), 36, 1.2)
		else:
			hud.banner("SECTOR CLEAN!", Color("a7f070"), 36, 0.8)
	elif room_def.has("boss") and WorldData.is_last_room(Game.world_index, Game.room_index) \
			and not bool(room_def.get("final", false)):
		hud.banner("WORLD %d CLEAR!" % (Game.world_index + 1), Color("ffcd75"), 36, 1.2)
	else:
		hud.banner("CLEAN!", Color("a7f070"), 52, 0.8)
	var heal := int(Game.stats.get("room_heal", 0))
	if heal > 0 and not player.dead and Game.hp_ratio() < 1.0:
		Game.heal(heal)
		popup_text(player.global_position + Vector2(0, -28), "+%d" % heal, Color("a7f070"), 14)
	hud.hide_boss()
	Sfx.play("clean", 0.0)
	for d in decals.get_children():
		if d.has_method("clean"):
			d.call("clean")
	for p in get_tree().get_nodes_in_group("pickups"):
		(p as Pickup).magnet = true
	for s in get_tree().get_nodes_in_group("enemy_shots"):
		(s as EnemyShot).pop()


func _after_clear() -> void:
	if station_mode and _all_sectors_clean() and bool(level_def.get("final", false)):
		_victory()
		return
	if bool(room_def.get("final", false)):
		_victory()
		return
	if bool(room_def.get("upgrade", false)):
		state = "upgrade"
		hud.show_upgrades(UpgradeData.roll(3, Game.upgrades, Game.hp_ratio()))
		return
	_open_exit()


func on_upgrade_chosen(id: String) -> void:
	Game.take_upgrade(id)
	player.refresh_upgrades()
	burst(player.global_position + Vector2(0, -8), Color("ffcd75"), 24, 90.0, 0.6, 2.0)
	ring(player.global_position + Vector2(0, -6), 24.0, Color("ffcd75"), 0.4, 2.0)
	if survival != null:
		survival.upgrade_done()  # survival: the level-up choice never opens the exit
		return
	_open_exit()


func _open_exit() -> void:
	if station_mode and not _all_sectors_clean():
		state = "explore"  # on to the next dirty sector
		return
	state = "exit"
	room.open_door()
	Sfx.play("door", 0.0)


func _leave_room() -> void:
	state = "transition"
	player.locked = true
	hud.controls.enabled = false
	var tw := hud.fade_to(1.0, 0.3)
	tw.finished.connect(func() -> void:
		Game.room_index += 1
		# past the world boss: on to the next world
		if Game.room_index >= WorldData.room_count(Game.world_index):
			Game.world_index += 1
			Game.room_index = 0
		_start_room()
		hud.fade_to(0.0, 0.35))


func _victory() -> void:
	state = "won"
	hud.controls.enabled = false
	var info := {}
	if Game.boss_rush and survival != null:
		# BOSS CHALLENGE: fight time, record, challenge coins; the world's own rewards stay put
		var secs := survival.fight_time()
		info = {"time": secs, "kills": survival.kills, "gems": survival.gems, "rush": true}
		info.record = Game.record_boss(secs)
		info.best = float(Game.boss_best.get(str(Game.world_index), secs))
		info.coins = Game.run_coins
		info.next = false
		info.chest = false
		Game.end_run()
		info.bonus = Game.boss_bonus(bool(info.record))
		Sfx.play("victory", 0.0)
		hud.show_victory(info)
		return
	var first := Game.worlds_cleared <= Game.world_index
	if survival != null:
		info = {"time": survival.t, "kills": survival.kills, "gems": survival.gems}
		Game.record_world(survival.t, true)
	info.coins = Game.run_coins
	info.first = first
	info.next = first and Game.world_index + 1 < WorldData.WORLDS.size()
	info.chest = not Game.chests.has(Game.world_index)
	Game.end_run()
	info.bonus = Game.clear_bonus(first)
	Sfx.play("victory", 0.0)
	hud.show_victory(info)


func on_player_died() -> void:
	state = "dead"
	hud.controls.enabled = false
	if survival != null and not Game.boss_rush:
		Game.record_world(survival.t, false)
	Game.end_run()
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		Sfx.play("gameover", 0.0)
		hud.show_game_over())


# ---------------------------------------------------------------- spawning

func _compose(w: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if w.has("fixed"):
		var fixed: Dictionary = w.fixed
		for id: String in fixed:
			for i in int(fixed[id]):
				out.append(id)
	if w.has("budget"):
		var budget := ceili(int(w.budget) * ROOM_BUDGET_MULT)
		var pool: Array = w.get("pool", WorldData.ALL)
		var guard := 0
		while budget > 0 and guard < 60:
			guard += 1
			var id: String = pool[randi() % pool.size()]
			var def: Dictionary = EnemyData.TYPES[id]
			var cost := int(def.cost)
			if cost <= budget:
				out.append(id)
				budget -= cost
	return out


## Spawn the next wave. Wave k of a room gets +WAVE_HP_STEP*k HP and a bit of speed;
## "elite": n (default: 1 on the last wave of rooms with 3+ waves) crowns the
## costliest aliens of the wave.
func _spawn_wave(w: Dictionary) -> void:
	var list := _compose(w)
	var pts := room.spawn_points(list.size(), player.global_position)
	var k := wave_i
	wave_i += 1
	hud.set_wave(wave_i, wave_n)
	var last := wave_i == wave_n
	var elites := int(w.get("elite", 1 if last and wave_n >= 3 else 0))
	if wave_n > 1:
		if last and wave_n >= 3:
			hud.banner("FINAL WAVE!", Color("ff9a4d"), 30, 0.7)
		elif k > 0:
			hud.banner("WAVE %d/%d" % [wave_i, wave_n], Color("ffcd75"), 30, 0.6)
	var order: Array = range(list.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return int(EnemyData.TYPES[list[a]].cost) > int(EnemyData.TYPES[list[b]].cost))
	var elite_idx: Array = order.slice(0, mini(elites, list.size()))
	var hp_mult := 1.0 + WAVE_HP_STEP * k
	var sp_mult := 1.0 + WAVE_SPEED_STEP * k
	for i in list.size():
		spawn_with_marker(list[i], pts[i], 0.6 + i * 0.12, hp_mult, sp_mult, elite_idx.has(i))


func spawn_with_marker(id: String, pos: Vector2, delay: float, hp_mult := 1.0, sp_mult := 1.0, elite := false, dmg_mult := 1.0) -> void:
	pending += 1
	var def: Dictionary = EnemyData.TYPES[id]
	var col: Color = Color("ffcd75") if elite else def.color
	var m := _marker(pos, delay, 6.0 + float(def.radius) * (1.4 if elite else 1.0), col)
	m.finished.connect(func() -> void:
		spawn_enemy(id, pos, hp_mult, sp_mult, elite, false, dmg_mult)
		pending -= 1)


func _marker(pos: Vector2, dur: float, size: float, col: Color) -> SpawnMarker:
	var m := SpawnMarker.new()
	m.position = pos
	m.dur = dur
	m.size = size
	m.color = col
	decals.add_child(m)
	return m


func spawn_enemy(id: String, pos: Vector2, hp_mult := 1.0, sp_mult := 1.0, elite := false, quiet := false, dmg_mult := 1.0) -> Enemy:
	var e := EnemyData.create(id)
	e.position = pos
	if hp_mult != 1.0 or sp_mult != 1.0 or dmg_mult != 1.0:
		e.toughen(hp_mult, sp_mult, dmg_mult)
	if elite:
		e.make_elite()
	entities.add_child(e)
	if not quiet:
		burst(pos + Vector2(0, -4), e.def.color, 10, 50.0, 0.4, 2.0)
		Sfx.play("spawn", 0.15, -10.0)
	return e


func spawn_enemy_shot(pos: Vector2, vel: Vector2, dmg: float, tex := "glob") -> EnemyShot:
	var s := EnemyShot.new()
	s.vel = vel * (1.0 + (Game.enemy_mult() - 1.0) * 0.5)  # world 2: faster globs too
	s.damage = dmg
	s.tex_id = tex
	s.position = pos
	effects.add_child(s)
	return s


# ---------------------------------------------------------------- combat events

func enemy_killed(e: Enemy) -> void:
	var c: Color = e.def.color
	var center := e.hit_center()
	var boss := e.is_boss
	burst(center, c, 50 if boss else 14, 140.0 if boss else 90.0, 0.6, 2.5 if boss else 2.0, 160.0)
	burst(center, Color.WHITE, 12 if boss else 5, 60.0, 0.3, 2.0)
	if Art.frames(e.art).has_animation("splat"):
		add_splat(e.global_position, e.art, e.base_scale, e.face < 0.0, e.tint)
	else:
		add_stain(e.global_position, c, e.radius / 5.0)
		var fx := AnimFx.spawn(effects, "glob_pop", "pop", center, e.base_scale * 0.6)
		fx.self_modulate = Color(0.45, 0.85, 1.6)
	Sfx.play("pop", 0.15, 2.0 if boss else 0.0)
	# in a survival horde kills are constant: keep the jolt for bosses and elites
	var horde := survival != null and not boss and not e.elite
	shake(1.0 if boss else (0.06 if horde else 0.22))
	hitstop(220 if boss else (0 if horde else 35))
	if e.elite:
		popup_text(center + Vector2(0, -10), "ELITE!", Color("ffcd75"), 12)
	player.infected.on_kill(e)  # fills the infection meter
	if survival != null:
		survival.on_kill(e)  # XP gems, a few coins, power-ups
	else:
		var coins := int(e.def.coins) + (1 if bool(Game.stats.magnet) else 0) + int(Game.stats.get("coin_bonus", 0))
		if e.elite:
			coins += 4
		drop_pickups(e.global_position, coins, 0.0 if boss else (0.35 if e.elite else 0.05))
		if bool(e.def.get("power_core", false)) or (not boss and randf() < 0.025):
			var pc := Pickup.new()
			pc.kind = "power"
			pc.position = e.global_position
			entities.add_child(pc)
	if boss:
		hud.hide_boss()
		ring(center, 60.0, c, 0.6, 4.0, true)
		for i in 5:
			get_tree().create_timer(0.12 * i).timeout.connect(func() -> void:
				burst(center + Vector2(randf_range(-16, 16), randf_range(-12, 12)), c, 20, 110.0, 0.5, 2.5, 120.0))
	if bool(Game.stats.death_explode) and not boss:
		var pos := center
		var lv := int(Game.stats.get("explode_lvl", 1))
		var dmg := float(Game.stats.damage) * (1.5 + 0.5 * (lv - 1))
		var rad := 26.0 + 5.0 * (lv - 1)
		get_tree().create_timer(0.08).timeout.connect(func() -> void:
			_slime_burst(pos, dmg, rad))


func _slime_burst(pos: Vector2, dmg: float, rad := 26.0) -> void:
	ring(pos, rad, Color("a7f070"), 0.3, 2.0, true)
	burst(pos, Color("a7f070"), 10, 80.0, 0.35, 2.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.targetable and e.global_position.distance_to(pos) < rad + e.radius:
			e.take_damage(dmg, (e.global_position - pos).normalized())


func explosion(pos: Vector2, radius: float, enemy_dmg: float, player_dmg: float) -> void:
	Sfx.play("explode", 0.1)
	shake(0.7)
	hitstop(60)
	ring(pos, radius, Color("ffcd75"), 0.3, 4.0, true)
	burst(pos, Color("ffcd75"), 20, 140.0, 0.45, 3.0)
	burst(pos, Color("ef7d57"), 16, 100.0, 0.55, 3.0)
	burst(pos, Color(0.2, 0.2, 0.25, 0.8), 10, 40.0, 0.8, 4.0, -30.0)
	add_stain(pos + Vector2(0, 6), Color(0.1, 0.1, 0.12), 1.8)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.targetable and e.global_position.distance_to(pos) < radius + e.radius:
			e.take_damage(enemy_dmg, (e.global_position - pos).normalized() * 3.0)
	if player_dmg > 0.0 and not player.dead and player.global_position.distance_to(pos) < radius:
		player.take_damage(player_dmg, pos)
	# chain reaction: explosive barrels and prop tanks nearby go off too
	for n in get_tree().get_nodes_in_group("barrels"):
		var b := n as Node2D
		if not bool(b.get("exploded")) and b.global_position.distance_to(pos) < radius + 6.0:
			b.call("trigger", 0.12)


func chain_lightning(from: Enemy, dmg: float, count: int) -> void:
	var hit: Array[Enemy] = [from]
	var cur_pos := from.hit_center()
	for i in count:
		var best: Enemy = null
		var bd := 60.0
		for n in get_tree().get_nodes_in_group("enemies"):
			var e := n as Enemy
			if e == null or not e.targetable or hit.has(e):
				continue
			var d := e.hit_center().distance_to(cur_pos)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		var l := Lightning.new()
		l.a = cur_pos
		l.b = best.hit_center()
		effects.add_child(l)
		hit.append(best)
		cur_pos = best.hit_center()
		best.take_damage(dmg, Vector2.ZERO)
	if hit.size() > 1:
		Sfx.play("zap", 0.2, -8.0)


func drop_pickups(pos: Vector2, coins: int, heart_chance: float) -> void:
	for i in coins:
		var p := Pickup.new()
		p.position = pos
		entities.add_child(p)
	if randf() < heart_chance:
		var h := Pickup.new()
		h.kind = "heart"
		h.value = 12
		h.position = pos
		entities.add_child(h)


func add_stain(pos: Vector2, col: Color, s: float) -> void:
	var st := Stain.new()
	st.position = pos
	st.setup(col, s)
	decals.add_child(st)
	if decals.get_child_count() > 80:
		decals.get_child(0).queue_free()


func add_splat(pos: Vector2, art: String, s: float, flip: bool, tint: Color) -> void:
	var st := Stain.new()
	st.position = pos
	st.setup_splat(art, s, flip, tint)
	decals.add_child(st)
	if decals.get_child_count() > 80:
		decals.get_child(0).queue_free()


func add_puddle(pos: Vector2, radius: float) -> void:
	var p := SlimePuddle.new()
	p.position = pos
	p.radius = radius
	decals.add_child(p)


# ---------------------------------------------------------------- game feel

func burst(pos: Vector2, col: Color, count := 10, speed := 60.0, life := 0.45, size := 2.0,
		grav := 0.0, dir := Vector2.ZERO, spread := PI) -> void:
	Burst.spawn(effects, pos, col, count, speed, life, size, grav, dir, spread)


func ring(pos: Vector2, radius: float, col: Color, dur := 0.3, width := 2.0, filled := false) -> void:
	var r := RingFx.new()
	r.position = pos
	r.radius = radius
	r.color = col
	r.dur = dur
	r.width = width
	r.filled = filled
	effects.add_child(r)


func telegraph_circle(pos: Vector2, radius: float, dur: float) -> void:
	var tg := Telegraph.new()
	tg.position = pos
	tg.radius = radius
	tg.dur = dur
	decals.add_child(tg)


func telegraph_line(pos: Vector2, dir: Vector2, length: float, width: float, dur: float) -> void:
	var tg := Telegraph.new()
	tg.kind = "line"
	tg.position = pos
	tg.dir = dir
	tg.length = length
	tg.width = width
	tg.dur = dur
	decals.add_child(tg)


func shake(amount: float) -> void:
	shake_amt = clampf(maxf(shake_amt, amount), 0.0, 1.0)


func hitstop(ms: int) -> void:
	if ms <= 0:
		return
	Engine.time_scale = 0.05
	hitstop_until = maxi(hitstop_until, Time.get_ticks_msec() + ms)


func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func popup_damage(pos: Vector2, amount: float, crit: bool) -> void:
	if crit:
		hud.popup(world_to_screen(pos), "%d!" % roundi(amount), Color("ffcd75"), 20)
	else:
		hud.popup(world_to_screen(pos), str(roundi(amount)), Color("f4f4f4"), 13)


func popup_text(pos: Vector2, text: String, col: Color, size: int) -> void:
	hud.popup(world_to_screen(pos), text, col, size)


func _process(delta: float) -> void:
	if hitstop_until > 0 and Time.get_ticks_msec() >= hitstop_until:
		hitstop_until = 0
		Engine.time_scale = 1.0
	shake_amt = maxf(0.0, shake_amt - delta * 2.4)
	var s := shake_amt * shake_amt
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * s
	if follow_cam:
		var target := player.global_position + Vector2(0, -10)
		camera.position = camera.position.lerp(target, 1.0 - exp(-7.0 * delta))
		guide.target = _guide_target()
	hud.set_enemies_left(get_tree().get_nodes_in_group("enemies").size() + pending
			if state in ["fight", "gap"] else -1)


## Boss entrance point: in a station, the far end of the sector from the player; in a
## room, the upper part (or further down when the player stands up there).
func _boss_pos() -> Vector2:
	if not station_mode:
		var top := Vector2(room.room_w * 0.5, minf(70.0, room.room_h * 0.3))
		if follow_cam and player.global_position.distance_to(top) < 110.0:
			return Vector2(room.room_w * 0.5, room.room_h * 0.6)
		return top
	var r := room.sector_rect(sector)
	var pts := room.spawn_points(1, player.global_position)
	return pts[0] if not pts.is_empty() else r.get_center()
