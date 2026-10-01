extends Enemy
## ARCANE EYE: a floating spiked eye the Archmage summons. It drifts towards you and, once
## close, starts to glow ("arm") and bursts a moment later, hurting anything within BLAST_R.
## Shoot it first and it only pops.

const BLAST_R := 30.0
const ARM_DIST := 26.0
const ARM_TIME := 0.5


func _init_ai() -> void:
	state = "hunt"


func _ai(delta: float) -> Vector2:
	air = 6.0 + sin(t * 4.0 + phase) * 2.0
	var to_p := _to_player()
	match state:
		"hunt":
			if to_p.length() < ARM_DIST:
				state = "arm"
				state_t = ARM_TIME
				alert.visible = true
				Sfx.play("alert", 0.1, -6.0)
			return to_p.normalized() * speed * (0.85 + 0.2 * sin(t * 5.0 + phase))
		"arm":
			state_t -= delta
			var blink := sin(t * 40.0) > 0.0
			tint = Color(1.8, 1.2, 1.8) if blink else Color.WHITE
			squash = Vector2(1.0 + (ARM_TIME - state_t) * 0.5, 1.0 + (ARM_TIME - state_t) * 0.5)
			if state_t <= 0.0:
				_explode()
			return to_p.normalized() * speed * 0.3
	return Vector2.ZERO


func _contact() -> void:
	pass  # it bursts instead


func _explode() -> void:
	var w := Game.world
	var c := hit_center()
	w.ring(c, BLAST_R, Color("d43cff"), 0.3, 2.0, true)
	w.burst(c, Color("ff4fd8"), 14, 100.0, 0.45, 2.0)
	AnimFx.spawn(w.effects, "arch_boom", "pop", c, 0.3)
	Sfx.play("explode", 0.15, -8.0)
	var p := player()
	if not p.dead and (p.global_position + Vector2(0, Player.BODY_Y)).distance_to(c) < BLAST_R:
		p.take_damage(contact_damage * 1.3, c)
	dead = true  # burst: no reward
	targetable = false
	remove_from_group("enemies")
	queue_free()


func _on_death() -> void:
	Game.world.burst(hit_center(), Color("ff4fd8"), 6, 60.0, 0.3, 2.0)
