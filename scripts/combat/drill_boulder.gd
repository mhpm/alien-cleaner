class_name DrillBoulder
extends Node2D
## DRILLBACK's boulder: lobbed in an arc, it lands and ROLLS after the astronaut (slower than
## walking, so it can be kited). When it gets close, or its time is up, it plants itself,
## sprouts glowing spikes (a warning circle) and bursts into rock chunks.

const ROLL_SPEED := 54.0
const ROLL_TIME := 4.0
const FUSE_R := 44.0
const ARM_TIME := 0.9
const BOOM_R := 32.0
const FLIGHT := 0.65

var damage := 20.0
var delay := 0.0  # seconds before it leaves the boss's hand
var from := Vector2.ZERO
var land := Vector2.ZERO
var state := "fly"
var t := 0.0
var sprite: AnimatedSprite2D
var dust_t := 0.0


func _ready() -> void:
	add_to_group("drill_boulders")
	sprite = Art.make_anim("drill_rock", 0.34)
	add_child(sprite)
	position = from
	t = -delay
	visible = delay <= 0.0
	var tg := Telegraph.new()  # where it comes down
	tg.position = land
	tg.radius = 11.0
	tg.dur = delay + FLIGHT
	tg.color = Color("b9803f")
	Game.world.decals.add_child(tg)


func _physics_process(delta: float) -> void:
	t += delta
	if t < 0.0:
		return
	visible = true
	match state:
		"fly":
			var k := clampf(t / FLIGHT, 0.0, 1.0)
			position = from.lerp(land, k) + Vector2(0, -sin(k * PI) * 46.0)
			sprite.rotation = k * TAU * 1.5
			if k >= 1.0:
				state = "roll"
				t = 0.0
				Game.world.burst(land, Color("b9803f"), 8, 60.0, 0.35, 2.0, 60.0)
				Game.world.shake(0.15)
				Sfx.play("pop", 0.0, -6.0)
		"roll":
			var p := Game.world.player
			var to := p.global_position - global_position
			var dir := to.normalized()
			position += dir * ROLL_SPEED * delta
			sprite.rotation += dir.x * delta * 9.0
			sprite.position.y = -4.0 + sin(t * 18.0) * 1.2  # bumping along
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.14
				Game.world.burst(global_position + Vector2(0, 2), Color("b9803f"), 1, 20.0, 0.3, 1.5, 30.0)
			if to.length() < FUSE_R or t > ROLL_TIME or p.dead:
				_arm()
		"arm":
			if t >= ARM_TIME:
				_boom()


func _arm() -> void:
	state = "arm"
	t = 0.0
	sprite.rotation = 0.0
	sprite.sprite_frames = Art.frames("drill_seed")
	sprite.offset = Art.anchor_offset("drill_seed")
	sprite.scale = Vector2.ONE * 0.28
	sprite.position = Vector2.ZERO
	sprite.play("arm")
	sprite.speed_scale = 1.2 / ARM_TIME  # its 6 frames (5 fps) span the fuse
	var tg := Telegraph.new()
	tg.position = global_position
	tg.radius = BOOM_R
	tg.dur = ARM_TIME
	tg.color = Color("c8ff3a")
	Game.world.decals.add_child(tg)
	Sfx.play("alert", 0.0, -6.0)


func _boom() -> void:
	var w := Game.world
	var at := global_position
	AnimFx.spawn(w.effects, "drill_boom", "pop", at, 0.4)
	w.burst(at, Color("b9803f"), 14, 110.0, 0.45, 2.5, 80.0)
	w.ring(at, BOOM_R, Color("c8ff3a"), 0.3, 2.0)
	w.shake(0.4)
	Sfx.play("explode", 0.2, -5.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - at
		if Vector2(off.x, off.y / 0.75).length() < BOOM_R:
			p.take_damage(damage, at)
			p.knock += off.normalized() * 180.0
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 + randf())
		w.spawn_enemy_shot(at + d * 8.0, d * 75.0, damage * 0.3, "drill_chunk")
	queue_free()
