class_name HoloDecoy
extends Node2D
## The kid's hologram (DecoyAbility): a flickering cyan copy of him that lures the aliens
## around it (Enemy.lure; `lure_break` 0 = they stay on it even with him close by) for
## LIFE seconds, then bursts, hurting and shoving the aliens next to it.

const LIFE := 3.0
const LURE_R := 150.0
const LURE_EVERY := 0.25  # seconds between calling more aliens over
const MAX_LURED := 40
const BLAST_R := 48.0
const BLAST_DMG := 2.0  # x the crew's base damage
const BLAST_PUSH := 200.0
const COLOR := Color("73eff7")
const HOLO := Color(0.55, 1.25, 1.6, 0.7)

var lure_break := 0.0  # Enemy._lure_break: the astronaut never wins them back early
var life := LIFE
var done := false
var _lure_t := 0.0
var _lured := 0
var _body: AnimatedSprite2D


## Looks like the astronaut right now: same frames, pose, size and facing.
func copy_look(a: Astronaut) -> void:
	_body = AnimatedSprite2D.new()
	_body.sprite_frames = a.body.sprite_frames
	_body.animation = a.body.animation
	_body.frame = a.body.frame
	_body.offset = a.body.offset
	_body.flip_h = a.body.flip_h
	_body.scale = a.body.scale
	_body.position = a.body.position
	_body.texture_filter = a.body.texture_filter
	_body.modulate = HOLO
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_body.material = add
	add_child(_body)


func _ready() -> void:
	var w := Game.world
	w.ring(global_position + Vector2(0, Player.BODY_Y), 16.0, COLOR, 0.3, 2.5)
	w.burst(global_position + Vector2(0, Player.BODY_Y), COLOR, 12, 60.0, 0.4, 1.8)


func is_resolved() -> bool:
	return done


func _physics_process(delta: float) -> void:
	if done:
		return
	life -= delta
	# flickers, faster as it runs out
	var rate := lerpf(6.0, 26.0, 1.0 - life / LIFE)
	_body.modulate.a = HOLO.a * (0.55 + 0.45 * absf(sin(life * rate)))
	_body.position.x = (randf() - 0.5) * 1.5 if randf() < 0.08 else 0.0
	_lure_t -= delta
	if _lure_t <= 0.0:
		_lure_t = LURE_EVERY
		_call_aliens()
	if life <= 0.0:
		detonate()


func _call_aliens() -> void:
	for e in Game.world.enemies_near(global_position, LURE_R):
		if _lured >= MAX_LURED:
			return
		if e.is_boss or e.anchored or not e.targetable or e.lure == self:
			continue
		if e.global_position.distance_to(global_position) <= LURE_R:
			e.lure = self
			_lured += 1


## Bursts now: hurts and shoves the aliens close to it, then fades away.
func detonate() -> void:
	if done:
		return
	done = true
	var w := Game.world
	var c := global_position + Vector2(0, Player.BODY_Y)
	w.ring(c, BLAST_R, COLOR, 0.3, 3.0, true)
	w.burst(c, COLOR, 22, 130.0, 0.45, 2.2)
	w.burst(c, Color.WHITE, 8, 80.0, 0.3, 1.5)
	w.shake(0.25)
	Sfx.play("blast", 0.1, -4.0)
	for e in w.enemies_near(global_position, BLAST_R):
		var d := e.global_position - global_position
		if not e.targetable or d.length() > BLAST_R + e.radius:
			continue
		e.take_damage(float(Game.stats.damage) * BLAST_DMG, d.normalized())
		e.push(d.normalized() * BLAST_PUSH)
	var tw := create_tween()
	tw.tween_property(_body, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)
