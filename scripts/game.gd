class_name GameWorld
extends Node2D
## Runs a world: builds rooms, spawns waves, handles CLEAN / upgrades / exit flow,
## and exposes game-feel helpers (shake, hitstop, particles, popups).

const PLAYER_START := Vector2(80, 206)

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


func _ready() -> void:
	Game.world = self
	Engine.time_scale = 1.0
	get_tree().paused = false
	if Game.stats.is_empty():
		Game.new_run()
	player = Player.new()
	entities.add_child(player)
	# frame the painted room art exactly (it is authored for a portrait phone)
	camera.position = Room.art_rect().get_center()
	hud.setup(self)
	Sfx.play_music()
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
	var layouts: Array = room_def.layouts
	var lname: String = layouts[randi() % layouts.size()]
	room.build(WorldData.LAYOUTS[lname], entities)
	player.reset_for_room(PLAYER_START)
	var ws: Array = room_def.get("waves", [])
	waves = ws.duplicate()
	hud.set_room(Game.room_index + 1, WorldData.room_count(Game.world_index))
	hud.controls.enabled = true
	state = "intro"
	state_t = 0.9
	if room_def.has("boss"):
		var final := bool(room_def.get("final", false))
		hud.banner("BOSS!" if final else "MINI BOSS", Color("ff5566"), 44, 1.0)
		state_t = 1.3
	elif Game.room_index == 0:
		hud.banner(str(WorldData.world(Game.world_index).name), Color("73eff7"), 22, 1.2)
	else:
		hud.banner("ROOM %d" % (Game.room_index + 1), Color("f4f4f4"), 32, 0.6)


func _begin_fight() -> void:
	state = "fight"
	if room_def.has("boss"):
		var id: String = room_def.boss
		var pos := Vector2(80, 70)
		pending += 1
		var m := _marker(pos, 1.0, 22.0, Color("ff5566"))
		m.finished.connect(func() -> void:
			var b := spawn_enemy(id, pos)
			hud.show_boss(b)
			Sfx.play("roar", 0.0)
			shake(0.7)
			pending -= 1)
	elif not waves.is_empty():
		_spawn_wave(waves.pop_front())


func _physics_process(delta: float) -> void:
	_read_input()
	match state:
		"intro":
			state_t -= delta
			if state_t <= 0.0:
				_begin_fight()
		"fight":
			if pending == 0 and get_tree().get_nodes_in_group("enemies").is_empty():
				if waves.is_empty():
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
			if player.global_position.y < -14.0:
				_leave_room()


func _read_input() -> void:
	var v := hud.controls.output
	var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if k.length() > 0.1:
		v = k
	var can_move := state in ["intro", "fight", "gap", "cleared", "exit"]
	player.input_dir = v if can_move else Vector2.ZERO
	if can_move and Input.is_action_just_pressed("ability"):
		player.blast()


func _room_cleared() -> void:
	state = "cleared"
	state_t = 1.1
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
	_open_exit()


func _open_exit() -> void:
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
		_start_room()
		hud.fade_to(0.0, 0.35))


func _victory() -> void:
	state = "won"
	hud.controls.enabled = false
	Game.end_run()
	Sfx.play("victory", 0.0)
	hud.show_victory()


func on_player_died() -> void:
	state = "dead"
	hud.controls.enabled = false
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
		var budget := int(w.budget)
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


func _spawn_wave(w: Dictionary) -> void:
	var list := _compose(w)
	var pts := room.spawn_points(list.size(), player.global_position)
	for i in list.size():
		spawn_with_marker(list[i], pts[i], 0.6 + i * 0.12)


func spawn_with_marker(id: String, pos: Vector2, delay: float) -> void:
	pending += 1
	var def: Dictionary = EnemyData.TYPES[id]
	var m := _marker(pos, delay, 6.0 + float(def.radius), def.color)
	m.finished.connect(func() -> void:
		spawn_enemy(id, pos)
		pending -= 1)


func _marker(pos: Vector2, dur: float, size: float, col: Color) -> SpawnMarker:
	var m := SpawnMarker.new()
	m.position = pos
	m.dur = dur
	m.size = size
	m.color = col
	decals.add_child(m)
	return m


func spawn_enemy(id: String, pos: Vector2) -> Enemy:
	var e := EnemyData.create(id)
	e.position = pos
	entities.add_child(e)
	burst(pos + Vector2(0, -4), e.def.color, 10, 50.0, 0.4, 2.0)
	Sfx.play("spawn", 0.15, -10.0)
	return e


func spawn_enemy_shot(pos: Vector2, vel: Vector2, dmg: float, tex := "glob") -> void:
	var s := EnemyShot.new()
	s.vel = vel
	s.damage = dmg
	s.tex_id = tex
	s.position = pos
	effects.add_child(s)


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
	shake(1.0 if boss else 0.22)
	hitstop(220 if boss else 35)
	var coins := int(e.def.coins) + (1 if bool(Game.stats.magnet) else 0) + int(Game.stats.get("coin_bonus", 0))
	drop_pickups(e.global_position, coins, 0.0 if boss else 0.05)
	if e.type_id == "gloop_brute" or (not boss and randf() < 0.025):
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
		var dmg := float(Game.stats.damage) * 1.5
		get_tree().create_timer(0.08).timeout.connect(func() -> void:
			_slime_burst(pos, dmg))


func _slime_burst(pos: Vector2, dmg: float) -> void:
	ring(pos, 26.0, Color("a7f070"), 0.3, 2.0, true)
	burst(pos, Color("a7f070"), 10, 80.0, 0.35, 2.0)
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as Enemy
		if e != null and e.targetable and e.global_position.distance_to(pos) < 26.0 + e.radius:
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
	if not player.dead and player.global_position.distance_to(pos) < radius:
		player.take_damage(player_dmg, pos)
	for n in get_tree().get_nodes_in_group("barrels"):
		var b := n as Barrel
		if b != null and not b.exploded and b.global_position.distance_to(pos) < radius + 6.0:
			b.trigger(0.12)


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
