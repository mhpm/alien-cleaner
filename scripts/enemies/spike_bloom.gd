class_name SpikeBloom
extends Enemy
## SPIKE BLOOM (world 8 BIODOME): a walking flower that ROOTS itself to fight. Rooted, it
## turns its head to you, opens up ("attack") and shoots a quick burst of 3 pollen orbs at
## where you are heading; every THORN_EVERY-th time it instead lobs a thorny seed in an
## arc onto a marked circle, which leaves a THORN PATCH there (pink goo that slows you and
## pricks you while you stand in it, THORN_LIFE seconds). It walks only between volleys,
## slowly: keep moving and do not stand in the thorns. Wilts (its "death").

const RANGE := 120.0
const ROOT_TIME := 0.6
const OPEN_TIME := 0.5
const BURST := 3
const ORB_SPEED := 100.0
const LEAD := 0.45
const THORN_EVERY := 3
const THORN_R := 22.0
const THORN_LIFE := 5.0

var _shots := 0
var _fire_t := 0.0
var _volleys := 0


func _init_ai() -> void:
	state = "walk"
	state_t = randf_range(1.5, 2.5)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	var to_p := _to_player()
	if absf(to_p.x) > 2.0:
		face = signf(to_p.x)
	match state:
		"walk":
			if state_t <= 0.0 and to_p.length() < RANGE * 1.4:
				state = "root"
				state_t = ROOT_TIME
				squash = Vector2(1.2, 0.85)
				Game.world.burst(global_position, Color("b97a45"), 6, 40.0, 0.4, 2.0, 60.0)
				return Vector2.ZERO
			var v := to_p.normalized() * clampf((to_p.length() - RANGE * 0.8) / 30.0, -1.0, 1.0)
			return v * speed
		"root":
			if state_t <= 0.0:
				state = "open"
				state_t = OPEN_TIME
				alert.visible = true
				Sfx.play("charge", 0.5, -10.0)
		"open":
			if state_t <= 0.0:
				alert.visible = false
				_volleys += 1
				if _volleys % THORN_EVERY == 0:
					_lob()
					_rest()
				else:
					state = "fire"
					_shots = BURST
					_fire_t = 0.0
		"fire":
			_fire_t -= delta
			if _fire_t <= 0.0 and _shots > 0:
				_shots -= 1
				_fire_t = 0.16
				var p := player()
				var target := p.global_position + p.velocity * LEAD + Vector2(0, Player.BODY_Y)
				var d := (target - hit_center()).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 10.0, d * ORB_SPEED, contact_damage * 0.55, "spike_orb").life = 2.5
				Sfx.play("spit", 0.6, -10.0)
			if _shots <= 0 and _fire_t <= 0.0:
				_rest()
	return Vector2.ZERO


func _rest() -> void:
	state = "walk"
	state_t = randf_range(1.6, 2.4)


## A thorny seed lobbed onto where the astronaut is heading: a thorn patch where it lands.
func _lob() -> void:
	var w := Game.world
	var p := player()
	var to := w.room.open_near(p.global_position + p.velocity * 0.7)
	var g := GooGlob.new()
	g.style = "red"
	g.from = hit_center()
	g.to = to
	g.height = 55.0
	g.dur = 0.8
	var dmg := contact_damage * 0.35
	g.on_land = func(at: Vector2) -> void:
		SpikeBloom.thorns(at, dmg)
	w.effects.add_child(g)
	w.telegraph_circle(to, THORN_R, g.dur)
	Sfx.play("spit", 0.2, -6.0)


## The thorn patch: pink goo that slows and pricks.
static func thorns(at: Vector2, dmg: float) -> void:
	var w := Game.world
	if w == null:
		return
	var goo := StickyGoo.new()
	goo.position = at
	goo.life = THORN_LIFE
	goo.radius = THORN_R
	goo.damage = dmg
	goo.tag = "thorns"
	goo.base = Color(0.85, 0.35, 0.6)
	goo.light = Color(1.0, 0.6, 0.8)
	goo.rim = Color(0.45, 0.6, 0.15)
	goo.glint = Color(1.0, 0.9, 0.95)
	w.decals.add_child(goo)
	w.burst(at, Color("ff9ad5"), 10, 60.0, 0.4, 2.0, 60.0)


func _anim_name() -> String:
	return "attack" if state in ["open", "fire"] else "walk"


func _on_death() -> void:
	var w := Game.world
	var fx := AnimFx.spawn(w.decals, "spike_bloom", "death", global_position, base_scale)
	fx.flip_h = face < 0.0
	w.burst(hit_center(), Color("ff9ad5"), 12, 70.0, 0.5, 2.0, 60.0)
	Sfx.play("pop", 0.4, -8.0)
