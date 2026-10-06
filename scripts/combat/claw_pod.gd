class_name ClawPod
extends Node2D
## CLAWDOZER's crab-pod: lobbed in an arc, it lands, BURROWS and tunnels after the astronaut
## (a trail of dirt shows where, slower than walking); then it stops, a circle marks the spot
## and it pops up in a burst of spikes. Can't be shot: just keep moving.

const FLIGHT := 0.55
const HIDE_TIME := 1.7
const HIDE_SPEED := 40.0
const POP_R := 26.0
const WARN := 0.8

var damage := 20.0
var delay := 0.0
var from := Vector2.ZERO
var land := Vector2.ZERO
var state := "wait"
var t := 0.0
var sprite: AnimatedSprite2D
var dust_t := 0.0


func _ready() -> void:
	add_to_group("claw_pods")
	sprite = Art.make_anim("claw_pod", 0.3)
	add_child(sprite)
	position = from
	visible = false
	t = -delay
	var tg := Telegraph.new()  # where it comes down
	tg.position = land
	tg.radius = 9.0
	tg.dur = delay + FLIGHT
	tg.color = Color("7dff9a")
	Game.world.decals.add_child(tg)


func _physics_process(delta: float) -> void:
	t += delta
	if t < 0.0:
		return
	if state == "wait":
		state = "fly"
		visible = true
		sprite.play("fly")
	match state:
		"fly":
			var k := clampf(t / FLIGHT, 0.0, 1.0)
			position = from.lerp(land, k) + Vector2(0, -sin(k * PI) * 40.0)
			if k >= 1.0:
				state = "land"
				t = 0.0
				position = land
				sprite.play("land")
				Game.world.burst(land, Color("b9803f"), 8, 60.0, 0.35, 2.0, 60.0)
				Sfx.play("pop", 0.0, -6.0)
		"land":
			if t >= 0.4:
				state = "hide"
				t = 0.0
				sprite.play("hide")
		"hide":
			var p := Game.world.player
			var to := p.global_position - global_position
			position += to.normalized() * HIDE_SPEED * delta
			dust_t -= delta
			if dust_t <= 0.0:
				dust_t = 0.1
				Game.world.burst(global_position, Color("b9803f"), 2, 30.0, 0.35, 2.0, 40.0)
			if t >= HIDE_TIME or p.dead:
				state = "warn"
				t = 0.0
				var tg := Telegraph.new()
				tg.position = global_position
				tg.radius = POP_R
				tg.dur = WARN
				tg.color = Color("7dff9a")
				Game.world.decals.add_child(tg)
				Sfx.play("alert", 0.2, -8.0)
		"warn":
			sprite.position.x = sin(t * 50.0) * 0.8
			if t >= WARN:
				_pop()


func _pop() -> void:
	state = "done"
	sprite.position.x = 0.0
	sprite.play("pop")
	BossCrab.spike(global_position, damage, POP_R)
	for i in 4:
		var d := Vector2.from_angle(TAU * i / 4.0 + randf())
		Game.world.spawn_enemy_shot(global_position + Vector2(0, -6), d * 70.0, damage * 0.3, "claw_drop")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
