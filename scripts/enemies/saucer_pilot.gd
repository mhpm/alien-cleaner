extends Enemy
## SAUCER PILOT (worlds 1-2): a little green martian flying a purple saucer. It hovers at
## mid range circling you and takes turns between two attacks:
## - BRACKET: the gun under the saucer charges (a plasma ring grows there, "charge") and
##   it fires a fan of 3 bolts (EnemyShot style "saucer_bolt"): the middle one at where
##   you are going, the other two on both sides, so side-stepping a little is not enough.
## - BOMBING RUN (every 3rd attack): a lane marks a line through you; it dives along it,
##   fast and low, dropping a plasma bomb every `BOMB_EVERY` units. Each bomb shows its
##   circle and blows up `BOMB_FUSE` s later, so the lane goes off in a chain behind the
##   saucer. Step off the lane before it dives and stay out of the circles.
## Shot down it bursts into smoke and scrap (the set's "death").

const RANGE := 115.0
const CHARGE_TIME := 0.65
const FAN := 0.26
const BOLT_SPEED := 125.0
const LANE_TIME := 0.85
const DIVE_SPEED := 210.0
const DIVE_MIN := 140.0
const DIVE_MAX := 240.0
const BOMB_EVERY := 34.0
const BOMB_FUSE := 0.6
const BOMB_R := 17.0

var _turn := 1.0
var _attacks := 0
var _dive_dir := Vector2.ZERO
var _dive_left := 0.0
var _bomb_acc := 0.0
var _ring: Sprite2D


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_ring = Sprite2D.new()
	_ring.texture = Art.frames("saucer_ring").get_frame_texture("pop", 0)
	_ring.visible = false
	_ring.z_index = 1
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_ring)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	var d := to_p.length()
	air = (6.0 if state == "dive" else 11.0) + sin(t * 2.6 + phase) * 2.0
	match state:
		"hover":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			if state_t <= 0.0 and d < RANGE * 2.0:
				_attacks += 1
				if _attacks % 3 == 0 and d < DIVE_MAX:
					_start_lane(to_p)
				else:
					_start_charge()
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.8
			v += to_p.normalized() * clampf((d - RANGE) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			var k := 1.0 - state_t / CHARGE_TIME
			_ring.position = _muzzle() - global_position
			_ring.scale = Vector2.ONE * (0.08 + 0.17 * k)
			_ring.rotation += delta * 6.0
			if state_t <= 0.0:
				_ring.visible = false
				alert.visible = false
				_fire_fan()
				state = "attack"
				state_t = 0.35
			return Vector2.ZERO
		"attack":
			if state_t <= 0.0:
				_back_to_hover()
			return Vector2.ZERO
		"lane":
			if state_t <= 0.0:
				alert.visible = false
				state = "dive"
				_bomb_acc = BOMB_EVERY * 0.5
				Sfx.play("dash", 0.1, -6.0)
			return Vector2.ZERO
		"dive":
			var step := DIVE_SPEED * delta
			_dive_left -= step
			_bomb_acc += step
			if _bomb_acc >= BOMB_EVERY:
				_bomb_acc -= BOMB_EVERY
				_drop_bomb()
			if _dive_left <= 0.0 or hit_wall:
				_back_to_hover()
				return Vector2.ZERO
			# `delta` runs `aggro` times faster: so does the dive (the distance stays right)
			return _dive_dir * DIVE_SPEED * aggro
	return Vector2.ZERO


func _back_to_hover() -> void:
	state = "hover"
	state_t = randf_range(2.0, 3.0)
	if randf() < 0.5:
		_turn = -_turn


func _start_charge() -> void:
	state = "charge"
	state_t = CHARGE_TIME
	alert.visible = true
	_ring.visible = true
	var p := player()
	aim = (p.global_position + p.velocity * 0.3 + Vector2(0, Player.BODY_Y) - _muzzle()).normalized()
	Game.world.telegraph_line(_muzzle(), aim, 200.0, 9.0, CHARGE_TIME / aggro)
	Sfx.play("charge", 0.3, -12.0)


func _fire_fan() -> void:
	var from := _muzzle()
	for i in 3:
		var dir := aim.rotated((i - 1) * FAN)
		Game.world.spawn_enemy_shot(from, dir * BOLT_SPEED, contact_damage * 0.7, "saucer_bolt")
	Game.world.burst(from, Color("ff4fd8"), 8, 70.0, 0.25, 2.0, 0.0, aim, 0.6)
	Sfx.play("zap", 0.1, -6.0)
	squash = Vector2(1.15, 0.88)


## Lane through you (and a bit past): the dive follows it no matter what.
func _start_lane(to_p: Vector2) -> void:
	_dive_dir = to_p.normalized()
	_dive_left = clampf(to_p.length() + 70.0, DIVE_MIN, DIVE_MAX)
	face = signf(_dive_dir.x) if _dive_dir.x != 0.0 else face
	state = "lane"
	state_t = LANE_TIME
	alert.visible = true
	Game.world.telegraph_line(global_position, _dive_dir, _dive_left, 18.0, LANE_TIME / aggro)
	Sfx.play("alert", 0.2, -8.0)


func _drop_bomb() -> void:
	var at := global_position
	var dmg := contact_damage * 0.8
	Game.world.telegraph_circle(at, BOMB_R, BOMB_FUSE)
	Game.world.burst(at + Vector2(0, -air), Color("ff4fd8"), 4, 30.0, 0.3, 2.0, 60.0)
	var me: GDScript = get_script()
	Game.world.get_tree().create_timer(BOMB_FUSE).timeout.connect(func() -> void: me.call("bomb_blast", at, dmg))
	Sfx.play("pop", 0.4, -14.0)


## A plasma bomb going off (static: the saucer may be gone by then).
static func bomb_blast(at: Vector2, dmg: float) -> void:
	var w := Game.world
	if w == null or not is_instance_valid(w):
		return
	w.ring(at, BOMB_R, Color("ff4fd8"), 0.3, 3.0, true)
	w.burst(at, Color("ff4fd8"), 10, 80.0, 0.35, 2.5)
	w.burst(at, Color(0.3, 0.2, 0.35, 0.8), 5, 30.0, 0.6, 3.0, -30.0)
	Sfx.play("explode", 0.3, -12.0)
	w.shake(0.15)
	var p := w.player
	if p.dead:
		return
	var off := p.global_position - at
	if Vector2(off.x, off.y / 0.75).length() < BOMB_R:
		p.take_damage(dmg, at)


## The gun under the front of the saucer.
func _muzzle() -> Vector2:
	var h := tex_h * base_scale
	return global_position + Vector2(face * h * 0.36, -h * 0.22 - air)


func _anim_name() -> String:
	match state:
		"charge", "lane":
			return "charge"
		"attack":
			return "attack"
	return "walk"


func _on_death() -> void:
	_ring.visible = false
	var w := Game.world
	var fx := AnimFx.spawn(w.effects, "saucer_pilot", "death", global_position + Vector2(0, -air), base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff4fd8"), 12, 80.0, 0.45, 2.5, 40.0)
	w.burst(hit_center(), Color(0.3, 0.28, 0.35, 0.85), 8, 40.0, 0.7, 3.5, -30.0)
	Sfx.play("explode", 0.2, -8.0)
