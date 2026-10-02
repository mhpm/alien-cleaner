class_name BlobBomb
extends Node2D
## BLOBULUS's swell bomb: lobbed in an arc, it lands, and its glowing core SWELLS (the orb
## frames play over the fuse, a circle on the floor shows the blast) until it bursts: damage,
## a ring of droplets and a patch of sticky goo that slows whoever walks through it.

const FLIGHT := 0.5
const FUSE := 1.3
const BLAST_R := 34.0

var damage := 20.0
var delay := 0.0  # seconds before it leaves the boss's hand
var from := Vector2.ZERO
var land := Vector2.ZERO
var burn := false  # the goo it leaves burns too (furious boss)
var state := "fly"
var t := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	add_to_group("blob_bombs")
	sprite = Art.make_anim("blob_orb", 0.16)
	sprite.animation = "grow"
	sprite.frame = 0
	sprite.pause()
	add_child(sprite)
	position = from
	t = -delay
	visible = false


func _physics_process(delta: float) -> void:
	t += delta
	if t < 0.0:
		return
	visible = true
	match state:
		"fly":
			var k := clampf(t / FLIGHT, 0.0, 1.0)
			position = from.lerp(land, k) + Vector2(0, -sin(k * PI) * 44.0)
			if k >= 1.0:
				state = "swell"
				t = 0.0
				position = land + Vector2(0, -5)
				var tg := Telegraph.new()
				tg.position = land
				tg.radius = BLAST_R
				tg.dur = FUSE
				tg.color = Color("5fd0ff")
				Game.world.decals.add_child(tg)
				Sfx.play("pop", 0.0, -6.0)
		"swell":
			var k := clampf(t / FUSE, 0.0, 1.0)
			sprite.frame = mini(4, int(k * 5.0))
			sprite.scale = Vector2.ONE * (0.16 + 0.1 * k) * (1.0 + sin(t * 24.0) * 0.05 * k)
			if t >= FUSE:
				_boom()


func _boom() -> void:
	var w := Game.world
	AnimFx.spawn(w.effects, "blob_pop", "pop", land + Vector2(0, -6), 0.3)
	w.burst(land, Color("5fd0ff"), 14, 110.0, 0.45, 2.5, 80.0)
	w.ring(land, BLAST_R, Color("b8ff3a"), 0.3, 2.0)
	w.shake(0.35)
	Sfx.play("explode", 0.3, -5.0)
	var p := w.player
	if not p.dead:
		var off := p.global_position - land
		if Vector2(off.x, off.y / 0.75).length() < BLAST_R:
			p.take_damage(damage, land)
			p.knock += off.normalized() * 160.0
	for i in 6:
		var d := Vector2.from_angle(TAU * i / 6.0 + randf())
		w.spawn_enemy_shot(land + d * 8.0, d * 70.0, damage * 0.3, "blob_drop")
	BossBlobulus.goo(land, 22.0, 5.0, damage * 0.25 if burn else 0.0)
	queue_free()
