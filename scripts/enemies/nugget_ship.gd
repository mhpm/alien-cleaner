extends Enemy
## RAY-EYE NUGGET SHIP (world 4): a blue one-eyed blob that CHARGES a big shot, and you can
## INTERRUPT it. Its eye glows brighter and brighter for CHARGE_TIME ("attack"), with a
## ring showing how charged it is; if you deal it INTERRUPT_SHARE of its health during
## the charge it is knocked out of it, dazed for a moment (and takes extra damage). If
## not, it fires a fast, heavy ray-orb at you (EnemyShot style "nugget").
## Bursts and melts into a blue puddle (the set's "splat").

const ORBIT := 105.0
const CHARGE_TIME := 1.4
const INTERRUPT_SHARE := 0.25
const DAZE_TIME := 1.6
const DAZE_DMG := 1.5
const SHOT_SPEED := 165.0

var _taken := 0.0  # damage taken during the current charge
var _turn := 1.0
var _ring: Node2D


func _init_ai() -> void:
	state = "hover"
	state_t = randf_range(1.8, 2.8)
	_turn = 1.0 if randf() < 0.5 else -1.0
	_ring = Node2D.new()
	_ring.draw.connect(_draw_charge)
	add_child(_ring)


func take_damage(amount: float, dir := Vector2.ZERO, crit := false) -> void:
	if state == "dazed":
		amount *= DAZE_DMG
	super.take_damage(amount, dir, crit)
	if dead or state != "charge":
		return
	_taken += amount
	if _taken >= max_hp * INTERRUPT_SHARE:
		_interrupt()


func _interrupt() -> void:
	state = "dazed"
	state_t = DAZE_TIME
	alert.visible = false
	_ring.queue_redraw()
	Game.world.popup_text(hit_center() + Vector2(0, -22), "INTERRUPTED!", Color("ffcd75"), 10)
	Game.world.ring(hit_center(), 16.0, Color("ffcd75"), 0.3, 2.0)
	Sfx.play("freeze", 0.1, -6.0)


func _ai(delta: float) -> Vector2:
	state_t -= delta
	air = 7.0 + sin(t * 2.4 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"hover":
			if state_t <= 0.0:
				state = "charge"
				state_t = CHARGE_TIME
				_taken = 0.0
				alert.visible = true
				Sfx.play("charge", 0.0, -6.0)
				return Vector2.ZERO
			var v := to_p.normalized().orthogonal() * _turn * 0.7
			v += to_p.normalized() * clampf((to_p.length() - ORBIT) / 30.0, -1.0, 1.0)
			return v.normalized() * speed
		"charge":
			face = signf(to_p.x) if to_p.x != 0.0 else face
			_ring.queue_redraw()
			if randf() < 0.6:
				var c := hit_center() + Vector2(face * 6.0, 0)
				var q := c + Vector2.from_angle(randf() * TAU) * 16.0
				Game.world.burst(q, Color("5fd0ff"), 1, 40.0, 0.2, 1.5, 0.0, (c - q).normalized(), 0.2)
			if state_t <= 0.0:
				alert.visible = false
				_ring.queue_redraw()
				var d := (to_p + Vector2(0, Player.BODY_Y)).normalized()
				Game.world.spawn_enemy_shot(hit_center() + d * 12.0, d * SHOT_SPEED, contact_damage * 1.4, "nugget")
				Game.world.burst(hit_center() + d * 12.0, Color("5fd0ff"), 10, 80.0, 0.25, 2.0, 0.0, d, 0.4)
				Sfx.play("zap", 0.0, 0.0)
				squash = Vector2(0.8, 1.15)
				state = "hover"
				state_t = randf_range(2.4, 3.2)
			return Vector2.ZERO
		"dazed":
			sprite.position.x = sin(t * 30.0) * 0.8
			if randf() < 0.2:
				Game.world.burst(hit_center() + Vector2(randf_range(-8, 8), -12), Color("ffcd75"), 1, 20.0, 0.3, 1.5)
			if state_t <= 0.0:
				sprite.position.x = 0.0
				state = "hover"
				state_t = randf_range(1.2, 1.8)
			return Vector2.ZERO
	return Vector2.ZERO


## The charge meter: a ring that closes as the shot gets ready, and how close you are to
## interrupting it (the red part).
func _draw_charge() -> void:
	if state != "charge":
		return
	var c := Vector2(0, -tex_h * base_scale * 0.5 - air)
	var k := 1.0 - clampf(state_t / CHARGE_TIME, 0.0, 1.0)
	_ring.draw_arc(c, 20.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color(0.4, 0.85, 1.0, 0.9), 2.0)
	var hurt := clampf(_taken / (max_hp * INTERRUPT_SHARE), 0.0, 1.0)
	if hurt > 0.0:
		_ring.draw_arc(c, 23.5, -PI * 0.5, -PI * 0.5 + TAU * hurt, 32, Color(1.0, 0.8, 0.3, 0.9), 2.0)


func _anim_name() -> String:
	return "attack" if state == "charge" else "walk"


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("5fd0ff"), 12, 70.0, 0.45, 2.5, 40.0)
	Sfx.play("pop", 0.15, -4.0)
