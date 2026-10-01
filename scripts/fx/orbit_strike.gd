class_name OrbitStrike
extends Node2D
## One locked ground target, a readable warning, then one energy eruption.
## The caster dying or being removed cancels the pending strike.

var caster: Enemy
var radius := 28.0
var damage := 15.0
var warning_time := 1.1
var elapsed := 0.0
var fired := false
var warning: Telegraph


func _ready() -> void:
	warning = Telegraph.new()
	warning.radius = radius
	warning.dur = warning_time
	warning.color = Color("c8ff3a")
	add_child(warning)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or caster.dead or not is_instance_valid(Game.world):
		queue_free()
		return
	elapsed += delta
	if not fired and elapsed >= warning_time:
		fired = true
		var w := Game.world
		AnimFx.spawn(w.effects, "orbit_beam", "pop", global_position, radius * 2.0 / 190.0)
		w.ring(global_position, radius, Color("c8ff3a"), 0.35, 2.0)
		w.burst(global_position, Color("c8ff3a"), 10, 65.0, 0.4, 2.0)
		Sfx.play("zap", 0.1, -4.0)
		var p := w.player
		var off := p.global_position - global_position
		if not p.dead and Vector2(off.x, off.y / 0.75).length() < radius:
			p.take_damage(damage, global_position)
	if elapsed >= warning_time + 0.5:
		queue_free()
