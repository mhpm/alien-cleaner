class_name StickyGoo
extends Node2D
## A patch of sticky goo (the Martian Bean Cruiser's globs, BLOBULUS's bombs and geysers): it
## doesn't hurt (unless `damage` > 0), but while the astronaut stands in it they are slowed
## (Player.stick), and the slow lasts a moment after stepping out. Dries up after `life`
## seconds. BLOBULUS can `detonate` the patches it left: they flash, then erupt in geysers.

const RADIUS := 15.0
const TICK := 0.6

var life := 5.0
var t := 0.0
var radius := RADIUS
var base := Color(0.45, 0.85, 0.15)  # body, glint, rim and highlight colours
var light := Color(0.65, 1.0, 0.3)
var rim := Color(0.25, 0.55, 0.05)
var glint := Color(0.9, 1.0, 0.7)
var damage := 0.0  # > 0: it also burns whoever stands in it, every TICK
var tag := ""  # who left it ("blobulus")
var fuse := -1.0  # detonating: counts down, then erupts and is gone
var blast_dmg := 0.0
var tick_t := 0.0


func _ready() -> void:
	add_to_group("sticky_goo")


## BLOBULUS's slime colours.
func slime_colors() -> void:
	base = Color(0.3, 0.35, 0.95)
	light = Color(0.35, 0.8, 1.0)
	rim = Color(0.12, 0.1, 0.5)
	glint = Color(0.8, 1.0, 0.7)


## Flash for `delay` seconds, then erupt as a geyser (damage `dmg`).
func detonate(delay: float, dmg: float) -> void:
	fuse = delay
	blast_dmg = dmg


func _physics_process(delta: float) -> void:
	t += delta
	if fuse >= 0.0:
		fuse -= delta
		if fuse <= 0.0:
			BossBlobulus.geyser(global_position, blast_dmg, radius * 1.3)
			queue_free()
			return
	if t >= life:
		queue_free()
		return
	var p := Game.world.player
	if not p.dead:
		var off := p.global_position - global_position
		if Vector2(off.x, off.y / 0.6).length() < radius:
			p.stick(0.5)
			tick_t -= delta
			if damage > 0.0 and tick_t <= 0.0:
				tick_t = TICK
				p.take_damage(damage, Vector2.INF, true)
	queue_redraw()


func _draw() -> void:
	var a := clampf((life - t) / 0.8, 0.0, 1.0) * clampf(t / 0.15, 0.0, 1.0)
	var wob := 1.0 + sin(t * 4.0) * 0.04
	var hot := 1.0 if fuse >= 0.0 and fmod(t, 0.16) < 0.08 else 0.0  # about to erupt
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(wob, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(base, 0.45 * a).lerp(Color.WHITE, hot * 0.6))
	draw_circle(Vector2(-3, -2), radius * 0.7, Color(light, 0.45 * a).lerp(Color.WHITE, hot * 0.6))
	draw_circle(Vector2(-5, -5), radius * 0.22, Color(glint, 0.6 * a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(rim, 0.7 * a), 1.5)
