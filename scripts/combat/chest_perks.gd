class_name ChestPerks
extends Node2D
## The chest perks that keep working after the chest is open (ChestData.apply adds a level
## per chest; two chests of a kind stack): one node under the Player, found or made with
## `of(player)`. Each kind is one small timed effect:
##   medkit  regenerates REGEN of the max health every REGEN_EVERY s per level
##   heart   a HeartShot flies to the nearest alien and charms it (shorter wait per level)
##   rocket  GunFire.rocket_nova: homing rockets burst out when aliens are around
##   hazmat  toxic aura: aliens within AURA_R take part of your damage, a green haze shows it
##   vortex  a vortex opens on the thickest pack nearby, sucks it in and implodes

const KINDS := ["medkit", "heart", "rocket", "hazmat", "vortex"]

const REGEN := 0.01
const REGEN_EVERY := 2.0
const HEART_EVERY := 9.0
const HEART_REACH := 170.0
const ROCKET_EVERY := 5.0
const ROCKET_REACH := 200.0
const AURA_R := 44.0
const AURA_EVERY := 0.5
const AURA_DMG := 0.35  # x damage per tick per level
const VORTEX_EVERY := 8.0
const VORTEX_REACH := 170.0
const VORTEX_R := 70.0  # pull radius
const VORTEX_PULL := 0.9  # seconds sucking in before the implosion
const VORTEX_BLAST := 54.0
const VORTEX_DMG := 2.5  # x damage per level
const VORTEX_PULL_SPEED := 150.0  # how fast the pack slides into it (bosses barely)
const COL_TOXIC := Color("d4ff3a")
const COL_VOID := Color("b05cff")

var levels := {}  # kind -> level
var _t := {}  # kind -> seconds to its next go
var _vortex := Vector2.INF
var _vortex_t := 0.0
var _pulse := 0.0


## The player's ChestPerks (made the first time).
static func of(p: Player) -> ChestPerks:
	var n := p.get_node_or_null("ChestPerks") as ChestPerks
	if n == null:
		n = ChestPerks.new()
		n.name = "ChestPerks"
		n.show_behind_parent = true
		p.add_child(n)
	return n


func add(kind: String) -> void:
	levels[kind] = int(levels.get(kind, 0)) + 1
	_t[kind] = minf(float(_t.get(kind, 1.0)), 1.0)  # a first go soon after opening


func level(kind: String) -> int:
	return int(levels.get(kind, 0))


func _physics_process(delta: float) -> void:
	var p := get_parent() as Player
	var w := Game.world
	if p == null or p.dead or w == null:
		return
	_pulse += delta
	for kind: String in levels:
		_t[kind] = float(_t.get(kind, 0.0)) - delta
		if float(_t[kind]) > 0.0:
			continue
		var lv := level(kind)
		match kind:
			"medkit":
				_t[kind] = REGEN_EVERY
				_regen(lv)
			"heart":
				_t[kind] = HEART_EVERY / (1.0 + 0.5 * (lv - 1))
				_heart(p, w)
			"rocket":
				_t[kind] = ROCKET_EVERY / (1.0 + 0.5 * (lv - 1))
				if not w.enemies_near(p.global_position, ROCKET_REACH).is_empty():
					GunFire.rocket_nova(p)
			"hazmat":
				_t[kind] = AURA_EVERY
				_aura(p, w, lv)
			"vortex":
				_t[kind] = VORTEX_EVERY / (1.0 + 0.4 * (lv - 1))
				_open_vortex(p, w)
	if _vortex != Vector2.INF:
		_suck(w, delta)
	if levels.has("hazmat"):
		queue_redraw()


func _regen(lv: int) -> void:
	var s := Game.stats
	if float(s.hp) >= float(s.max_hp):
		return
	s.hp = minf(float(s.max_hp), float(s.hp) + float(s.max_hp) * REGEN * lv)
	Game.hp_changed.emit()


func _heart(p: Player, w: GameWorld) -> void:
	var at := p.global_position + Vector2(0, Player.BODY_Y)
	var best: Enemy = null
	var bd := HEART_REACH
	for e in w.enemies_near(at, HEART_REACH):
		if e.dead or not e.targetable or e.charm != null:
			continue
		var d := e.global_position.distance_to(at)
		if d < bd:
			bd = d
			best = e
	if best == null:
		_t["heart"] = 1.0  # try again soon
		return
	var h := HeartShot.new()
	h.dir = (best.hit_center() - at).normalized()
	h.speed = HeartShotAbility.SPEED
	h.damage = float(Game.stats.damage) * HeartShotAbility.DAMAGE
	h.charm_time = HeartShotAbility.CHARM_TIME
	w.effects.add_child(h)
	h.global_position = at
	Sfx.play("select", 0.1, -4.0)


func _aura(p: Player, w: GameWorld, lv: int) -> void:
	var dmg := float(Game.stats.damage) * AURA_DMG * lv
	for e in w.enemies_near(p.global_position, AURA_R):
		if not e.dead and e.targetable and e.global_position.distance_to(p.global_position) < AURA_R + e.radius:
			GunFx.hit(e, dmg, Vector2.ZERO)
			if randf() < 0.3:
				w.burst(e.global_position + Vector2(0, -8), COL_TOXIC, 2, 20.0, 0.3, 1.5, -30.0)


## On the thickest pack within VORTEX_REACH (sampling a few aliens).
func _open_vortex(p: Player, w: GameWorld) -> void:
	var near := w.enemies_near(p.global_position, VORTEX_REACH)
	var best := Vector2.INF
	var most := 0
	for i in mini(near.size(), 16):
		var e := near[i]
		if e.dead or not e.targetable:
			continue
		var n := 0
		for o in near:
			if o.global_position.distance_to(e.global_position) < VORTEX_R:
				n += 1
		if n > most:
			most = n
			best = e.global_position
	if best != Vector2.INF:  # the middle of that pack
		var sum := Vector2.ZERO
		var k := 0
		for o in near:
			if not o.dead and o.global_position.distance_to(best) < VORTEX_R:
				sum += o.global_position
				k += 1
		best = sum / maxf(k, 1)
	if best == Vector2.INF:
		_t["vortex"] = 1.5
		return
	_vortex = best
	_vortex_t = VORTEX_PULL
	var fx := VortexFx.new()
	fx.life = VORTEX_PULL
	w.effects.add_child(fx)
	fx.global_position = best
	DarkLights.glow(fx)
	Sfx.play("grav", 0.1, -4.0)


func _suck(w: GameWorld, delta: float) -> void:
	for e in w.enemies_near(_vortex, VORTEX_R):
		var to := _vortex - e.global_position
		if not e.dead and to.length() < VORTEX_R + e.radius:
			var want := to.normalized() * VORTEX_PULL_SPEED * minf(1.0, to.length() / 20.0) * (0.3 if e.is_boss else 1.0)
			e.knock = e.knock.move_toward(want, 900.0 * delta)
	_vortex_t -= delta
	if _vortex_t <= 0.0:
		GunFx.implode(_vortex, VORTEX_BLAST, float(Game.stats.damage) * VORTEX_DMG * level("vortex"), COL_VOID)
		_vortex = Vector2.INF


func _draw() -> void:
	if levels.has("hazmat"):
		var k := 0.5 + 0.5 * sin(_pulse * 4.0)
		draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.0, 0.45))
		FastDraw.disc(self, Vector2.ZERO, AURA_R, Color(COL_TOXIC, 0.07 + 0.05 * k))
		FastDraw.ring(self, Vector2.ZERO, AURA_R, Color(COL_TOXIC, 0.3 + 0.2 * k), 1.5)
		draw_set_transform(Vector2.ZERO)


## The vortex on the floor (in the lit effects layer): a dark eye with purple rings that
## spin and close in while it sucks, then GunFx.implode takes over.
class VortexFx:
	extends Node2D

	var life := 1.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var f := clampf(_t / life, 0.0, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
		FastDraw.disc(self, Vector2.ZERO, 12.0 + 16.0 * f, Color(0.06, 0.0, 0.14, 0.7))
		for k in 3:
			var r := VORTEX_R * (1.0 - fmod(f * 1.6 + k / 3.0, 1.0) * 0.85)
			FastDraw.ring(self, Vector2.ZERO, r, Color(COL_VOID, 0.25 + 0.5 * (1.0 - r / VORTEX_R)), 2.0)
		# spiral arms
		for arm in 3:
			var a0 := _t * 7.0 + TAU * arm / 3.0
			var prev := Vector2.from_angle(a0) * VORTEX_R * 0.9
			for i in range(1, 9):
				var q := Vector2.from_angle(a0 + i * 0.35) * VORTEX_R * 0.9 * (1.0 - i / 9.0)
				draw_line(prev, q, Color(COL_VOID.lightened(0.3), 0.7), 2.0)
				prev = q
		draw_set_transform(Vector2.ZERO)
