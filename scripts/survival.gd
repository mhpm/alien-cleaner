class_name Survival
extends Node
## Survivor-style stage (WorldData room with "survival"): a wide open arena and a clock.
## Every WAVE_SECS a new, harder wave starts (more aliens alive at once, faster spawns,
## tougher aliens as the minutes pass, golden elites) and some waves open with an event:
##   "swarm"  a pack of `count` `id` charges in from one side
##   "ring"   `count` `id` appear in a circle around the player
##   "boss"   a mini boss joins the fight
## A wave with "total" sends exactly that many aliens over its 30 s (events included;
## what the alive cap holds back carries over to the next wave). "invasion": n = after an
## INVASION INCOMING! warning, a horde of n bursts in from every side at once.
## Alien hits are sized to the player: a Slime's hit takes 1/HITS_TO_DIE of max health.
## When the clock reaches "duration" the final "boss" arrives: the horde is wiped away,
## an electric BossFence rings the fight and nothing else spawns (the boss may call its
## own minions); cleaning it clears the stage and powers the fence down. "boss_help"
## sends small squads of the level's aliens in through the fence during the fight (see
## _boss_help).
## BOSS CHALLENGE (Game.boss_rush, from the world select once the world is cleared): no
## waves; the astronaut starts with no upgrades (they come from the XP of the helpers
## the boss calls in) and, after a short countdown, the final boss fight begins as if
## the clock had run out. `fight_time()` is what gets recorded.
## Aliens drop XP gems (each level up offers an upgrade) and coins; the only power-up for
## now is the gravity well (a black hole that pulls in every gem and coin on the floor).
## The other power-ups (CollectibleData) and the supply crates are off: turn them back
## on with DROPS / SUPPLY_CRATES.

const WAVE_SECS := 30.0
const MAX_ALIVE := 100
const INVASION_ALIVE := 160  # an invasion may crowd the arena up to this many
const INVASION_WARN := 3.0  # seconds of warning before the horde arrives
const RUSH_INTRO := 3.0  # BOSS CHALLENGE countdown before the fence goes up
const HELP_MERCY := 0.25  # no reinforcements while the astronaut is below this health
const FENCE_R := 270.0  # radius of the electric fence around the final boss fight
const HITS_TO_DIE := 6.0  # a Slime's hit = max health / 6 (tougher aliens hit harder)
const REF_DMG := 10.0  # the Slime's base damage: the yardstick for every alien
const BOSS_DMG := 0.8  # bosses are scaled a little softer (their base damage is ~2x)
const DMG_PER_MIN := 0.05  # alien damage ramp (+5% per minute)
## Aliens that shoot (EnemyData "shoots": spitter, droid, UFO, octo) are kept a minority
## so the horde is mostly green slimes and red runners that chase you: at most this share
## of new aliens ("shooters" per wave overrides it), and never more than MAX_SHOOTERS alive.
const SHOOTER_SHARE := 0.2
const INVASION_SHOOTERS := 0.08
const MAX_SHOOTERS := 15
const CRATE_EVERY := 30.0
const MAX_CRATES := 3
const PICKUP_RANGE := 26.0  # XP gems fly to you from this close (the magnet upgrade: more)
## chance per cleaned alien to drop each power-up (just the gravity well for now)
const DROPS := {"magnet": 0.003}
const ELITE_MAGNET := 0.35  # golden elites: coins and, often, a gravity well
const SUPPLY_CRATES := false  # supply crates with power-ups (off for now)
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
var gems := 0  # XP gem value collected this run (victory screen)
var quota := 0  # aliens the waves still have to send (waves with "total")
var wave_end := 0.0
var sent := 0  # aliens sent by the waves so far
var invasion_left := 0  # horde still to burst in
var invasion_warn := 0.0  # > 0: warning countdown before the horde
var invasion_acc := 0.0
var fence: BossFence  # the final boss fight's electric fence
var help_t := 9.0  # next boss-fight reinforcement squad
var rush := false  # BOSS CHALLENGE run
var rush_started := false
var final_at := 0.0  # clock when the final boss fight began


func setup(w: GameWorld, d: Dictionary) -> void:
	world = w
	def = d
	waves = d.waves
	rush = Game.boss_rush
	if rush:
		# the fight happens at the end of the clock: bosses and helpers as tough as then
		t = duration() - RUSH_INTRO
		wave = waves.size() - 1


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
	if rush and not rush_started:
		_rush_begin()
	if not final_sent:
		if t >= duration():
			_send_final()
		else:
			var wi := mini(int(t / WAVE_SECS), waves.size() - 1)
			if wi != wave:
				_start_wave(wi)
	_spawn(delta)
	_invasion(delta)
	_boss_help(delta)
	leash_t -= delta
	if leash_t <= 0.0:
		leash_t = 0.5
		_leash()
	crate_t -= delta
	if SUPPLY_CRATES and crate_t <= 0.0:
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
	if rush:
		var ft := fight_time()
		world.hud.room_label.text = "%02d:%02d" % [floori(ft / 60.0), int(ft) % 60] if final_sent else "READY"
		var best := float(Game.boss_best.get(str(Game.world_index), 0.0))
		var wt := "BOSS CHALLENGE" if not final_sent else ("BEST %dm %02ds" % [floori(best / 60.0), int(best) % 60] if best > 0.0 else "BOSS CHALLENGE")
		if not final_sent:
			wt += "   %d" % ceili(maxf(0.0, duration() - t))
		world.hud.set_wave_text(wt)
		world.hud.set_xp(float(xp) / float(need(level)), level)
		return
	var left := maxf(0.0, duration() - t)
	var clock := "%02d:%02d" % [floori(t / 60.0), int(t) % 60]
	world.hud.room_label.text = "BOSS" if final_sent else clock
	var wtxt := "FINAL BOSS" if final_sent else "WAVE %d/%d" % [wave + 1, waves.size()]
	if invasion_warn > 0.0:
		wtxt = "INVASION IN %d" % ceili(invasion_warn)
	elif not final_sent and left < 30.0:
		wtxt += "   BOSS IN %d" % ceili(left)
	world.hud.set_wave_text(wtxt)
	world.hud.set_xp(float(xp) / float(need(level)), level)


# ---------------------------------------------------------------- waves

func _start_wave(i: int) -> void:
	wave = i
	var w: Dictionary = waves[i]
	quota += int(w.get("total", 0))  # plus whatever the last wave could not send
	wave_end = (i + 1) * WAVE_SECS
	var ev := str(w.get("event", ""))
	if w.has("invasion"):
		_warn_invasion(int(w.invasion))
		return
	match ev:
		"swarm":
			world.hud.banner("SWARM!", Color("ff9a4d"), 34, 0.8)
			_swarm(str(w.id), int(w.count))
		"ring":
			world.hud.banner("SURROUNDED!", Color("ff5566"), 30, 0.8)
			_ring(str(w.id), int(w.count))
		"boss":
			var n := int(w.get("count", 1))
			world.hud.banner("MINI BOSS!" if n == 1 else "%d MINI BOSSES!" % n, Color("ff5566"), 36, 1.0)
			for k in n:
				world._spawn_boss(str(w.id), _ring_pos(130.0), _boss_hp_mult(), _dmg_mult() * BOSS_DMG)
		_:
			if i > 0:
				world.hud.banner("WAVE %d" % (i + 1), Color("ffcd75"), 32, 0.6)
	if i > 0 and ev == "":
		Sfx.play("alert", 0.0, -4.0)


## BOSS CHALLENGE: a warning banner before the countdown (no upgrades: earn them in the fight).
func _rush_begin() -> void:
	rush_started = true
	var boss_name := str(EnemyData.TYPES[str(def.boss)].name)
	world.hud.banner("BOSS CHALLENGE", Color("ff5566"), 34, RUSH_INTRO - 1.0)
	world.popup_text(world.player.global_position + Vector2(0, -34), boss_name, Color("ffcd75"), 14)
	Sfx.play("alert", 0.0)


## Seconds since the final boss fight began (BOSS CHALLENGE time).
func fight_time() -> float:
	return maxf(0.0, t - final_at) if final_sent else 0.0


func _send_final() -> void:
	final_sent = true
	final_at = t
	quota = 0
	invasion_left = 0
	invasion_warn = 0.0
	_wipe_horde()
	# an electric fence closes a ring around the astronaut (kept inside the arena)
	var b := world.room.bounds().grow(-(FENCE_R + 12.0))
	var c := world.player.global_position
	if b.size.x > 0.0 and b.size.y > 0.0:
		c = c.clamp(b.position, b.end)
	fence = BossFence.new().setup(c, FENCE_R)
	world.effects.add_child(fence)
	world.hud.banner("FINAL BOSS!", Color("ff5566"), 40, 1.2)
	Sfx.play("roar", 0.0)
	world._spawn_boss(str(def.boss), c + Vector2(0, -FENCE_R * 0.55), _boss_hp_mult(), _dmg_mult() * BOSS_DMG)


## Boss fight reinforcements ("boss_help": pool, max alive helpers, seconds between squads
## at full / no boss health, squad size): a few aliens slip in through the fence on the
## far side from the astronaut, more often as the boss weakens (one more per squad once
## it is under half health), never beyond "max" alive and never while the astronaut is
## below HELP_MERCY health.
func _boss_help(delta: float) -> void:
	var h: Dictionary = def.get("boss_help", {})
	if h.is_empty() or done or fence == null or not is_instance_valid(fence):
		return
	var boss: Enemy = null
	var helpers := 0
	for n in world.enemy_cache:
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e.type_id == str(def.boss):
			boss = e
		elif not e.is_boss:
			helpers += 1
	if boss == null:
		return
	help_t -= delta
	if help_t > 0.0:
		return
	var ratio := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	var every: Array = h.get("every", [16.0, 8.0])
	help_t = lerpf(float(every[1]), float(every[0]), ratio)
	if Game.hp_ratio() < HELP_MERCY:
		return
	var n_help := mini(int(h.get("squad", 3)) + (1 if ratio < 0.5 else 0), int(h.get("max", 8)) - helpers)
	if n_help <= 0:
		return
	var pool: Array = h.get("pool", ["slime"])
	var c := fence.global_position
	var away := c - world.player.global_position
	var a0 := away.angle() if away.length() > 4.0 else randf() * TAU
	for i in n_help:
		var pos := c + Vector2.from_angle(a0 + randf_range(-0.8, 0.8)) * (FENCE_R - 16.0)
		world.spawn_with_marker(str(pool[randi() % pool.size()]), pos, 0.8 + i * 0.1, _hp_mult(), 1.0, false, _dmg_mult())
		world.burst(pos, Color("5fe6ff"), 6, 50.0, 0.3, 1.5)
	Sfx.play("zap", 0.1, -6.0)


## The final boss arrives alone: every alien and shot vanishes in a zap (no rewards),
## and the XP gems left on the floor fly to the astronaut.
func _wipe_horde() -> void:
	var i := 0
	for n in world.enemy_cache:
		if not is_instance_valid(n):
			continue
		var e := n as Enemy
		if e.is_boss or e.dead:
			continue
		e.dead = true
		e.targetable = false
		e.remove_from_group("enemies")
		var pos := e.hit_center()
		var col: Color = e.def.color
		var ee := e
		get_tree().create_timer(0.01 * i, false).timeout.connect(func() -> void:
			world.burst(pos, col, 6, 60.0, 0.3, 2.0)
			world.burst(pos, Color("5fe6ff"), 3, 40.0, 0.25, 1.5)
			if is_instance_valid(ee):
				ee.queue_free())
		i += 1
	for n in get_tree().get_nodes_in_group("enemy_shots"):
		(n as EnemyShot).pop()
	for n in get_tree().get_nodes_in_group("pickups"):
		var pk := n as Pickup
		if pk != null and pk.kind in ["xp", "coin"]:
			pk.magnet = true
	Sfx.play("zap", 0.0, 3.0)
	world.hud.tint_flash(Color("5fe6ff"), 0.35, 0.5)
	world.shake(0.6)


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
	if fence != null and is_instance_valid(fence):
		fence.dissolve()
	world._survival_clear()


func _spawn(delta: float) -> void:
	if rush and not final_sent:
		return  # BOSS CHALLENGE countdown: nothing spawns
	if fence != null:
		return  # the boss fight: no horde (the boss calls its own minions)
	var w := _current()
	var alive := 0
	for n in world.enemy_cache:
		if not is_instance_valid(n):  # freed since the cache was refreshed
			continue
		if not (n as Enemy).is_boss:
			alive += 1
	# waves with a "total" pace their quota over the time left; others use "rate"
	var stream := quota - invasion_left
	var counted := stream > 0
	var rate := float(w.get("rate", 1.0))
	if counted:
		rate = maxf(rate if final_sent else 0.0, stream / maxf(wave_end - t, 3.0))
	elif w.has("total"):
		return  # this wave sent everything it had
	spawn_acc += rate * delta
	var pool: Array = w.get("pool", ["slime"])
	while spawn_acc >= 1.0:
		spawn_acc -= 1.0
		if alive >= mini(int(w.get("alive", 10)), MAX_ALIVE):
			spawn_acc = 0.0
			break
		var id := _pick(pool, float(w.get("shooters", SHOOTER_SHARE)))
		_spawn_one(id, _edge_pos(), randf() < float(w.get("elite", 0.0)))
		alive += 1
		if counted:
			_count(1)
			if quota - invasion_left <= 0:
				break


## A random alien of the wave's pool: a shooter only `share` of the time (and while
## fewer than MAX_SHOOTERS are alive), otherwise one that just chases you.
func _pick(pool: Array, share: float) -> String:
	var melee: Array = []
	var ranged: Array = []
	for id: String in pool:
		if bool(EnemyData.TYPES[id].get("shoots", false)):
			ranged.append(id)
		else:
			melee.append(id)
	if melee.is_empty():
		return str(ranged[randi() % ranged.size()])
	if ranged.is_empty() or randf() >= share or _shooters_alive() >= MAX_SHOOTERS:
		return str(melee[randi() % melee.size()])
	return str(ranged[randi() % ranged.size()])


func _shooters_alive() -> int:
	var n := 0
	for node in world.enemy_cache:
		if is_instance_valid(node) and bool((node as Enemy).def.get("shoots", false)) and not (node as Enemy).is_boss:
			n += 1
	return n


## Aliens sent out of the waves' quota.
func _count(n: int) -> void:
	var k := mini(n, quota)
	quota -= k
	sent += k


# ---------------------------------------------------------------- invasions

## INVASION INCOMING!: sirens and a red warning, then the horde (see _invasion).
func _warn_invasion(n: int) -> void:
	invasion_left = n
	invasion_warn = INVASION_WARN
	invasion_acc = 0.0
	world.hud.banner("INVASION INCOMING!", Color("ff3344"), 30, INVASION_WARN - 0.6)
	_siren()


func _siren() -> void:
	Sfx.play("alert", 0.0, 0.0)
	Sfx.play("charge", 0.0, -6.0)
	world.hud.tint_flash(Color("ff1f3a"), 0.28, 0.5)


func _invasion(delta: float) -> void:
	if invasion_left <= 0:
		return
	if invasion_warn > 0.0:
		var before := invasion_warn
		invasion_warn -= delta
		if floori(before) != floori(invasion_warn) and invasion_warn > 0.0:
			_siren()  # one siren per second of warning
		if invasion_warn <= 0.0:
			world.hud.banner("INVASION!", Color("ff3344"), 46, 0.8)
			Sfx.play("roar", 0.0)
			world.shake(0.9)
			world.hud.tint_flash(Color("ff1f3a"), 0.4, 0.7)
		return
	# the horde pours in from every side, a few dozen per second
	var alive := 0
	for n in world.enemy_cache:
		if is_instance_valid(n) and not (n as Enemy).is_boss:
			alive += 1
	invasion_acc += 45.0 * delta
	var w := _current()
	var pool: Array = w.get("pool", ["slime"])
	while invasion_acc >= 1.0 and invasion_left > 0 and alive < INVASION_ALIVE:
		invasion_acc -= 1.0
		var id := _pick(pool, INVASION_SHOOTERS)
		_spawn_one(id, _edge_pos(), randf() < float(w.get("elite", 0.0)) * 0.5)
		invasion_left -= 1
		alive += 1
		_count(1)
	if alive >= INVASION_ALIVE:
		invasion_acc = 0.0


## Clock the toughness ramps read (world 2 starts where world 1 ended).
func _ramp_t() -> float:
	return t + float(def.get("t_offset", 0.0))


func _hp_mult() -> float:
	return 1.0 + _ramp_t() / 60.0 * float(def.get("hp_per_min", 0.3))


## Bosses grow with the clock too (a bit slower than the horde).
func _boss_hp_mult() -> float:
	return 1.0 + _ramp_t() / 60.0 * float(def.get("hp_per_min", 0.3)) * 0.75


## Alien damage: a Slime's hit takes 1/HITS_TO_DIE of the player's max health, and
## every alien hits a little harder as the minutes pass.
func _dmg_mult() -> float:
	var per_hit := float(Game.stats.max_hp) / HITS_TO_DIE
	return per_hit / REF_DMG * (1.0 + _ramp_t() / 60.0 * DMG_PER_MIN)


func _spawn_one(id: String, pos: Vector2, elite := false) -> Enemy:
	return world.spawn_enemy(id, pos, _hp_mult(), 1.0 + minf(_ramp_t() / 60.0 * 0.03, 0.25), elite, true, _dmg_mult())


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
	_count(count)


func _ring(id: String, count: int) -> void:
	var p := world.player.global_position
	var b := world.room.bounds().grow(-14.0)
	for i in count:
		var pos := (p + Vector2.from_angle(TAU * i / count) * minf(world.view_size().x * 0.5 - 12.0, 150.0)).clamp(b.position, b.end)
		world.spawn_with_marker(id, pos, 0.7, _hp_mult(), 1.0, false, _dmg_mult())
	_count(count)


## Aliens left far behind reappear around the player (the horde never thins out).
func _leash() -> void:
	if fence != null:
		return  # everyone is held inside the fence
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

## Called by GameWorld when an alien is cleaned: XP gems, a few coins, now and then a
## gravity well.
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
		_drop("magnet", pos)
		_drop("gold", pos)
		world.drop_pickups(pos, int(e.def.coins), 0.0)
		return
	_drop("xp", pos, val)
	if randf() < 0.22:
		world.drop_pickups(pos, 1, 0.0)
	if e.elite:
		if randf() < ELITE_MAGNET:
			_drop("magnet", pos)
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
	if fence != null and is_instance_valid(fence):  # boss fight: inside the fence
		pos = fence.global_position + Vector2.from_angle(a) * randf_range(0.3, 0.7) * FENCE_R
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
		Game.total_xp += value
		gems += value
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
