class_name Survival
extends Node
## Survivor-style stage (WorldData room with "survival"): a wide open arena and a clock.
## Every WAVE_SECS a new, harder wave starts (more aliens alive at once, faster spawns,
## tougher aliens as the minutes pass, golden elites) and some waves open with an event:
##   "swarm"  a pack of `count` `id` charges in from one side
##   "ring"   `count` `id` appear in a circle around the player
##   "boss"   a mini boss joins the fight
## When the clock reaches "duration" the final "boss" arrives; cleaning it clears the
## stage. Aliens drop XP gems: each level up offers an upgrade. Power-ups (heart,
## gravity well, nuke, cryo wave, overclock, jet boots, triple shot, double damage,
## shield, super star, UFO buddies, turret drop, golden carrot, power core...; see
## CollectibleData) drop from aliens and from supply crates that keep turning up near
## the player (walk into them or shoot them).

const WAVE_SECS := 30.0
const MAX_ALIVE := 70
const CRATE_EVERY := 30.0
const MAX_CRATES := 3
const PICKUP_RANGE := 26.0  # XP gems fly to you from this close (the magnet upgrade: more)
## chance per cleaned alien to drop each power-up
const DROPS := {
	"carrot": 0.012, "heart": 0.005, "frenzy": 0.003, "boots": 0.003, "triple": 0.003,
	"rage": 0.003, "magnet": 0.0025, "bomb": 0.0025, "freeze": 0.0025, "shield": 0.002,
	"power": 0.003,
}
## what a supply crate holds (weights)
const CRATE_LOOT := {
	"medkit": 2.0, "heart_max": 1.0, "magnet": 2.0, "bomb": 2.0, "freeze": 1.5, "frenzy": 2.0,
	"boots": 1.5, "triple": 2.0, "rage": 2.0, "shield": 1.5, "star": 1.0, "ufo": 1.5,
	"turret": 1.5, "golden_carrot": 0.6, "power": 1.2, "gold": 1.0,
}

var world: GameWorld
var def: Dictionary = {}
var waves: Array = []
var t := 0.0
var wave := -1
var spawn_acc := 0.0
var level := 1
var xp := 0
var pending_levels := 0
var choosing := false
var final_sent := false
var final_seen := false
var done := false
var crate_t := 12.0
var crates: Array[Node] = []
var leash_t := 0.0
var xp_sfx_t := 0.0
var kills := 0


func setup(w: GameWorld, d: Dictionary) -> void:
	world = w
	def = d
	waves = d.waves


## Distance from the player to just past the screen edge in direction `a` (aliens
## appear there; the view is a tall rectangle, so it is shorter sideways).
func edge_dist(a: float, extra := 24.0) -> float:
	var h := world.view_size() * 0.5
	var d := Vector2.from_angle(a)
	var k := INF
	if absf(d.x) > 0.001:
		k = minf(k, h.x / absf(d.x))
	if absf(d.y) > 0.001:
		k = minf(k, h.y / absf(d.y))
	return k + extra


func duration() -> float:
	return float(def.get("duration", WAVE_SECS * waves.size()))


func need(lv: int) -> int:
	return int(5 + (lv - 1) * 4 + pow(lv, 1.5))


func pickup_range() -> float:
	return PICKUP_RANGE * (1.0 + 0.6 * int(Game.stats.get("magnet_lvl", 0)))


func _physics_process(delta: float) -> void:
	if world == null or world.state != "survive" or done:
		return
	t += delta
	xp_sfx_t -= delta
	if not final_sent:
		if t >= duration():
			_send_final()
		else:
			var wi := mini(int(t / WAVE_SECS), waves.size() - 1)
			if wi != wave:
				_start_wave(wi)
	_spawn(delta)
	leash_t -= delta
	if leash_t <= 0.0:
		leash_t = 0.5
		_leash()
	crate_t -= delta
	if crate_t <= 0.0:
		crate_t = CRATE_EVERY
		_drop_crate()
	if final_sent:
		_check_final()
	_hud()


func _current() -> Dictionary:
	if final_sent:
		return def.get("final", {"pool": ["slime"], "alive": 12, "rate": 1.2})
	return waves[maxi(wave, 0)]


func _hud() -> void:
	var left := maxf(0.0, duration() - t)
	var clock := "%02d:%02d" % [floori(t / 60.0), int(t) % 60]
	world.hud.room_label.text = "BOSS" if final_sent else clock
	var wtxt := "FINAL BOSS" if final_sent else "WAVE %d/%d" % [wave + 1, waves.size()]
	if not final_sent and left < 30.0:
		wtxt += "   BOSS IN %d" % ceili(left)
	world.hud.set_wave_text(wtxt)
	world.hud.set_xp(float(xp) / float(need(level)), level)


# ---------------------------------------------------------------- waves

func _start_wave(i: int) -> void:
	wave = i
	var w: Dictionary = waves[i]
	var ev := str(w.get("event", ""))
	match ev:
		"swarm":
			world.hud.banner("SWARM!", Color("ff9a4d"), 34, 0.8)
			_swarm(str(w.id), int(w.count))
		"ring":
			world.hud.banner("SURROUNDED!", Color("ff5566"), 30, 0.8)
			_ring(str(w.id), int(w.count))
		"boss":
			world.hud.banner("MINI BOSS!", Color("ff5566"), 36, 1.0)
			world._spawn_boss(str(w.id), _ring_pos(130.0))
		_:
			if i > 0:
				world.hud.banner("WAVE %d" % (i + 1), Color("ffcd75"), 32, 0.6)
	if i > 0 and ev == "":
		Sfx.play("alert", 0.0, -4.0)


func _send_final() -> void:
	final_sent = true
	world.hud.banner("FINAL BOSS!", Color("ff5566"), 40, 1.2)
	Sfx.play("roar", 0.0)
	world._spawn_boss(str(def.boss), _ring_pos(130.0))


func _check_final() -> void:
	var boss_id := str(def.boss)
	var alive := false
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e != null and not e.dead and e.type_id == boss_id:
			alive = true
			break
	if alive:
		final_seen = true
	elif final_seen:
		_clear()


func _clear() -> void:
	done = true
	# the rest of the horde pops with their king
	var i := 0
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e != null and not e.dead and not e.is_boss:
			var ee := e
			get_tree().create_timer(0.03 * i).timeout.connect(func() -> void:
				if is_instance_valid(ee) and not ee.dead:
					ee.take_damage(999999.0, Vector2.ZERO))
			i += 1
	world._survival_clear()


func _spawn(delta: float) -> void:
	var w := _current()
	var alive := 0
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		if not (n as Enemy).is_boss:
			alive += 1
	spawn_acc += float(w.get("rate", 1.0)) * delta
	var pool: Array = w.get("pool", ["slime"])
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive >= mini(int(w.get("alive", 10)), MAX_ALIVE):
			spawn_acc = 0.0
			break
		var id: String = pool[randi() % pool.size()]
		_spawn_one(id, _edge_pos(), randf() < float(w.get("elite", 0.0)))
		alive += 1


func _hp_mult() -> float:
	return 1.0 + t / 60.0 * float(def.get("hp_per_min", 0.3))


func _spawn_one(id: String, pos: Vector2, elite := false) -> Enemy:
	return world.spawn_enemy(id, pos, _hp_mult(), 1.0 + minf(t / 60.0 * 0.03, 0.25), elite, true)


## A spot `r` away from the player inside the arena (tries a few angles).
func _ring_pos(r: float, angle := INF) -> Vector2:
	var b := world.room.bounds().grow(-14.0)
	var p := world.player.global_position
	for i in 10:
		var a := randf() * TAU if angle == INF else angle + randf_range(-0.5, 0.5) * i * 0.3
		var q := p + Vector2.from_angle(a) * r
		if b.has_point(q):
			return q
	var q2 := p + Vector2.from_angle(randf() * TAU) * r
	return q2.clamp(b.position, b.end)


## A spot just off screen in direction `angle` (random if INF), inside the arena.
func _edge_pos(angle := INF) -> Vector2:
	var b := world.room.bounds().grow(-14.0)
	var p := world.player.global_position
	for i in 10:
		var a := randf() * TAU if angle == INF else angle + randf_range(-0.5, 0.5) * i * 0.3
		var q := p + Vector2.from_angle(a) * edge_dist(a)
		if b.has_point(q):
			return q
	var a2 := randf() * TAU
	return (p + Vector2.from_angle(a2) * edge_dist(a2)).clamp(b.position, b.end)


func _swarm(id: String, count: int) -> void:
	# from the direction the player is heading (or anywhere)
	var dir := world.player.input_dir
	var a := dir.angle() if dir.length() > 0.2 else randf() * TAU
	var centre := _edge_pos(a)
	var side := (centre - world.player.global_position).normalized().orthogonal()
	var b := world.room.bounds().grow(-14.0)
	for i in count:
		var pos := (centre + side * randf_range(-70.0, 70.0) + Vector2(randf_range(-12, 12), randf_range(-12, 12))).clamp(b.position, b.end)
		_spawn_one(id, pos)


func _ring(id: String, count: int) -> void:
	var p := world.player.global_position
	var b := world.room.bounds().grow(-14.0)
	for i in count:
		var pos := (p + Vector2.from_angle(TAU * i / count) * minf(world.view_size().x * 0.5 - 12.0, 150.0)).clamp(b.position, b.end)
		world.spawn_with_marker(id, pos, 0.7, _hp_mult())


## Aliens left far behind reappear around the player (the horde never thins out).
func _leash() -> void:
	var p := world.player.global_position
	var dir := world.player.input_dir
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e == null or e.dead or e.is_boss:
			continue
		var off := e.global_position - p
		if off.length() > edge_dist(off.angle(), 140.0):
			var a := dir.angle() + randf_range(-1.0, 1.0) if dir.length() > 0.2 else randf() * TAU
			e.global_position = _edge_pos(a)


# ---------------------------------------------------------------- drops & XP

## Called by GameWorld when an alien is cleaned: XP gems, a few coins, power-ups.
func on_kill(e: Enemy) -> void:
	kills += 1
	var pos := e.global_position
	var val := maxi(1, int(e.def.get("cost", 1)))
	if e.elite:
		val *= 5
	if e.is_boss:
		_drop("xp", pos, 40)
		for i in 6:
			_drop("xp", pos, 6)
		_drop("power", pos)
		_drop("magnet", pos)
		_drop("golden_carrot", pos)
		_drop("gold", pos)
		world.drop_pickups(pos, int(e.def.coins), 0.0)
		return
	_drop("xp", pos, val)
	if randf() < 0.22:
		world.drop_pickups(pos, 1, 0.0)
	if e.elite:
		_drop(_weighted(CRATE_LOOT), pos)
		_drop("gold", pos)
		return
	for k: String in DROPS:
		if randf() < float(DROPS[k]):
			_drop(k, pos)
			break


func _drop(kind: String, pos: Vector2, value := 1) -> void:
	var pk := Pickup.new()
	pk.kind = kind
	pk.value = 25 if kind == "heart" else value
	pk.position = pos
	world.entities.add_child(pk)


func _weighted(table: Dictionary) -> String:
	var total := 0.0
	for k: String in table:
		total += float(table[k])
	var r := randf() * total
	for k: String in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return table.keys()[0]


## A supply crate burst open: coins and one power-up (sometimes two).
func crate_loot(pos: Vector2) -> void:
	world.drop_pickups(pos, 3, 0.0)
	_drop(_weighted(CRATE_LOOT), pos)
	if randf() < 0.25:
		_drop(_weighted(CRATE_LOOT), pos)


func _drop_crate() -> void:
	var still: Array[Node] = []
	for c in crates:
		if is_instance_valid(c):
			still.append(c)
	crates = still
	if crates.size() >= MAX_CRATES:
		return
	var a := randf() * TAU
	var r := minf(world.view_size().x, world.view_size().y) * 0.5
	var pos := world.room.arena_free_spot(_ring_pos(randf_range(r * 0.5, r * 0.85), a), 14.0)
	var cell := Vector2i(pos / Room.TILE)
	var c := Prop.new().setup("loot_crate", cell, pos, "arena")
	world.entities.add_child(c)
	crates.append(c)
	world.burst(pos + Vector2(0, -6), Color("ffcd75"), 10, 50.0, 0.4, 2.0, -30.0)
	world.ring(pos, 14.0, Color("ffcd75"), 0.4, 2.0)


func add_xp(v: int) -> void:
	xp += v
	while xp >= need(level):
		xp -= need(level)
		level += 1
		pending_levels += 1
	if pending_levels > 0 and not choosing:
		_offer.call_deferred()


func _offer() -> void:
	if pending_levels <= 0 or choosing or world.state != "survive" or world.player.dead:
		return
	pending_levels -= 1
	var ids := UpgradeData.roll(3, Game.upgrades, Game.hp_ratio())
	var pp := world.player.global_position
	world.ring(pp + Vector2(0, -6), 30.0, Color("ffcd75"), 0.45, 3.0)
	world.burst(pp + Vector2(0, -8), Color("ffcd75"), 20, 90.0, 0.5, 2.0)
	if ids.is_empty():
		# everything maxed: a snack and some coins instead
		Game.heal(25.0)
		Game.add_coins(10)
		world.popup_text(pp + Vector2(0, -24), "LEVEL %d  +HP +10$" % level, Color("ffcd75"), 12)
		if pending_levels > 0:
			_offer.call_deferred()
		return
	choosing = true
	world.hud.show_upgrades(ids, "LEVEL %d!" % level, "Choose an upgrade")


## The HUD closed the upgrade choice.
func upgrade_done() -> void:
	choosing = false
	if pending_levels > 0:
		get_tree().create_timer(0.3).timeout.connect(_offer)


func collect(kind: String, value: int, _pos: Vector2) -> void:
	var p := world.player
	var pp := p.global_position
	if kind == "xp":
		add_xp(value)
		if xp_sfx_t <= 0.0:
			xp_sfx_t = 0.06
			Sfx.play("coin", 0.15, -16.0)
		return
	var item: Dictionary = CollectibleData.ITEMS.get(kind, {})
	var col: Color = item.get("color", Color.WHITE)
	world.popup_text(pp + Vector2(0, -30), str(item.get("name", kind.to_upper())), col, 13)
	world.ring(pp + Vector2(0, -6), 22.0, col, 0.35, 2.0)
	if CollectibleData.is_buff(kind):
		p.add_buff(kind, float(item.buff))
		Sfx.play("upgrade", 0.0, -3.0)
		if kind in ["shield", "star"]:
			Sfx.play("shield", 0.0)
		return
	match kind:
		"gold":
			Game.add_coins(10)
			Sfx.play("coin", 0.0)
			world.burst(pp, Color("ffcd75"), 12, 60.0, 0.4, 2.0, -40.0)
		"carrot":
			Game.heal(12.0)
			Sfx.play("heal", 0.1)
		"medkit":
			Game.heal(float(Game.stats.max_hp) * 0.5)
			Sfx.play("heal", 0.0)
			world.burst(pp + Vector2(0, -8), Color("ff5566"), 14, 60.0, 0.5, 2.0, -30.0)
		"heart_max":
			Game.stats.max_hp = float(Game.stats.max_hp) + 15.0
			Game.heal(15.0)
			Sfx.play("heal", 0.0)
			world.burst(pp + Vector2(0, -8), Color("ff5566"), 20, 80.0, 0.5, 2.0, -30.0)
		"golden_carrot":
			add_xp(need(level) - xp)
			Sfx.play("victory", 0.0, -6.0)
			world.burst(pp + Vector2(0, -8), Color("ffcd75"), 30, 110.0, 0.6, 2.5, -20.0)
		"magnet":
			for n in get_tree().get_nodes_in_group("pickups"):
				var pk := n as Pickup
				if pk != null and pk.kind in ["xp", "coin"]:
					pk.magnet = true
			Sfx.play("shield", 0.0)
			world.ring(pp, 60.0, col, 0.5, 3.0)
		"bomb":
			_bomb(pp)
		"freeze":
			_freeze(pp)
		"turret":
			_deploy_turret(pp)
	Game.hp_changed.emit()


## How far screen-wide power-ups reach (a bit past the visible screen).
func _screen_reach() -> float:
	return maxf(180.0, world.view_size().length() * 0.5 + 20.0)


## Cryo wave: every alien on screen freezes solid for a few seconds.
func _freeze(c: Vector2) -> void:
	Sfx.play("freeze", 0.0)
	world.ring(c, _screen_reach(), Color("c0f4ff"), 0.6, 4.0, true)
	world.burst(c, Color("c0f4ff"), 40, 180.0, 0.7, 3.0)
	for n in world.enemy_cache:
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e != null and not e.dead and e.global_position.distance_to(c) < _screen_reach():
			e.freeze(1.5 if e.is_boss else 4.0)


## Turret drop: an auto turret lands next to the player and fires on its own for a while.
func _deploy_turret(c: Vector2) -> void:
	var pos := world.room.arena_free_spot(c + Vector2(18, 4), 12.0)
	var tur := Prop.new().setup("turret", Vector2i(pos / Room.TILE), pos, "arena")
	tur.deploy_secs = 12.0
	world.entities.add_child(tur)
	world.burst(pos + Vector2(0, -8), Color("73eff7"), 16, 70.0, 0.4, 2.0)
	Sfx.play("door", 0.0, -4.0)


## Screen-clearing bomb: every alien near the player takes a massive hit.
func _bomb(c: Vector2) -> void:
	Sfx.play("explode", 0.0, 2.0)
	world.shake(1.0)
	world.hitstop(90)
	world.ring(c, _screen_reach(), Color("a7f070"), 0.5, 5.0, true)
	world.ring(c, 110.0, Color.WHITE, 0.35, 3.0)
	world.burst(c, Color("ffcd75"), 40, 200.0, 0.6, 3.0)
	world.burst(c, Color("ef7d57"), 30, 140.0, 0.7, 3.0)
	world.hud.banner("NUKE!", Color("a7f070"), 40, 0.4)
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		var e := n as Enemy
		if e == null or e.dead or not e.targetable:
			continue
		if e.global_position.distance_to(c) < _screen_reach():
			var dmg := e.max_hp * 0.12 if e.is_boss else e.max_hp * 3.0
			e.take_damage(dmg, (e.global_position - c).normalized() * 3.0)
