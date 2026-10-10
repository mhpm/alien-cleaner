class_name MartianAlly
extends Node2D
## Martian UFO upgrade (UpgradeData "martian"): a little ally that always orbits the
## astronaut and shoots green plasma (MartianShot) at the nearest alien. Its level
## (Game.stats.martian, UpgradeData.MARTIAN_LV) adds shots, fire rate and chaining shots,
## up to a fan of 5 at level 5 (an abduction beam is still coded, off: MARTIAN_LV "beam").
## Pops little emotes above its dome (kit face_*.png). Art: kit martian*.png.

const KIT := "res://assets/ui/upgrades/kit/"
const UFO_TEX := preload("res://assets/ui/upgrades/kit/martian.png")
const BEAM_TEX := preload("res://assets/ui/upgrades/kit/martian_beam.png")
const BEAM_RING := Vector2(84, 165)  # beam art: centre of the ring on the ground
const BEAM_UFO_W := 123.0  # beam art: saucer width in px
const WIDTH := 20.0  # saucer width in world units
const HOVER := 22.0  # height of the saucer over its shadow
const ORBIT := Vector2(36.0, 18.0)
const RANGE := 150.0
const BEAM_TIME := 1.8
const BEAM_CD := 6.0
const BEAM_R := 20.0

var player: Player
var lv := 1
var ufo: Sprite2D
var beam: Sprite2D
var shadow: Sprite2D
var face: Sprite2D
var face_tw: Tween
var ground := Vector2.ZERO  # world point under the saucer
var a := 0.0
var t := 0.0
var fire_t := 0.8
var beam_cd := 3.0
var beam_state := 0  # 0 orbiting, 1 flying to the target, 2 beaming
var beam_t := 0.0
var beam_at := Vector2.ZERO
var tick_t := 0.0
var kills := 0
var chat_t := 12.0
var boss_seen := 0
var last_hp := -1.0


func setup(p: Player) -> void:
	player = p
	top_level = true
	ground = p.global_position
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.scale = Vector2(0.9, 0.7)
	shadow.modulate.a = 0.6
	add_child(shadow)
	ufo = Sprite2D.new()
	ufo.texture = UFO_TEX
	ufo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ufo.scale = Vector2.ONE * (WIDTH / UFO_TEX.get_width())
	add_child(ufo)
	beam = Sprite2D.new()
	beam.texture = BEAM_TEX
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	beam.centered = false
	beam.offset = -BEAM_RING
	beam.scale = Vector2.ONE * (WIDTH / BEAM_UFO_W)
	beam.visible = false
	add_child(beam)
	face = Sprite2D.new()
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	face.visible = false
	add_child(face)
	Game.hp_changed.connect(_on_hp)
	last_hp = float(Game.stats.hp)
	emote("happy")


func set_level(n: int) -> void:
	if n > lv:
		emote("happy")
		Game.world.ring(ufo.global_position, 10.0, Color("7dff8a"), 0.3, 2.0)
	lv = n


func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		visible = false
		return
	visible = true
	t += delta
	a += delta * 2.2
	var d: Dictionary = UpgradeData.MARTIAN_LV[clampi(lv, 1, 5) - 1]
	var orbit := player.global_position + Vector2(cos(a) * ORBIT.x, sin(a) * ORBIT.y)
	match beam_state:
		0:
			ground = ground.lerp(orbit, 1.0 - exp(-10.0 * delta))
			if bool(d.beam):
				beam_cd -= delta
				if beam_cd <= 0.0:
					_start_beam()
		1:
			ground = ground.move_toward(beam_at, 190.0 * delta)
			if ground.distance_to(beam_at) < 1.0:
				beam_state = 2
				beam_t = BEAM_TIME
				ufo.visible = false
				beam.visible = true
				beam.modulate = Color(2.0, 2.0, 2.0)
				beam.create_tween().tween_property(beam, "modulate", Color.WHITE, 0.2)
				Sfx.play("charge", 0.05, -6.0)
		2:
			_beam(delta)
	global_position = ground
	# behind the astronaut on the far half of the orbit
	show_behind_parent = beam_state == 0 and sin(a) < 0.0
	var bob := sin(t * 5.0) * 1.5
	ufo.position = Vector2(0, -HOVER + bob)
	ufo.rotation = cos(a) * -0.12 if beam_state == 0 else 0.0
	shadow.scale = Vector2(0.9, 0.7) * (1.0 - bob * 0.04)
	face.position = Vector2(0, -HOVER - 15.0 + bob)
	if beam_state == 0:
		_shoot(delta, d)
	_chatter(delta)


func _shoot(delta: float, d: Dictionary) -> void:
	fire_t -= delta
	if fire_t > 0.0:
		return
	var from := ufo.global_position
	var target := _nearest(from, RANGE)
	if target == null:
		fire_t = 0.15
		return
	fire_t = float(d.rate)
	var aim := (target.hit_center() - from).normalized()
	var n := int(d.shots)
	var dmg := float(Game.stats.damage) * 0.75
	for i in n:
		var dir := aim
		var off := Vector2.ZERO
		if n == 2:
			off = aim.orthogonal() * (i - 0.5) * 5.0
		elif n >= 3:  # a fan centred on the target (level 5: five shots)
			dir = aim.rotated((i - (n - 1) * 0.5) * (0.2 if n == 3 else 0.24))
		var s := MartianShot.new()
		s.dir = dir
		s.damage = dmg
		s.chain = int(d.chain)
		s.martian = self
		Game.world.effects.add_child(s)
		s.global_position = from + off + dir * 4.0
	Sfx.play("shoot", 0.25, -13.0)
	Game.world.burst(from + aim * 5.0, Color("7dff8a"), 2, 30.0, 0.15, 1.5, 0.0, aim, 0.6)
	ufo.scale = Vector2.ONE * (WIDTH / UFO_TEX.get_width()) * 1.12
	ufo.create_tween().tween_property(ufo, "scale", Vector2.ONE * (WIDTH / UFO_TEX.get_width()), 0.15)


## Level 5: fly over the biggest crowd of aliens nearby.
func _start_beam() -> void:
	var best: Enemy = null
	var best_n := -1
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable or e.global_position.distance_to(player.global_position) > RANGE * 0.8:
			continue
		var n := 0
		for other in Game.world.enemy_cache:
			if is_instance_valid(other) and (other as Node2D).global_position.distance_to(e.global_position) < BEAM_R * 1.5:
				n += 1
		if n > best_n:
			best_n = n
			best = e
	if best == null:
		beam_cd = 0.5
		return
	beam_at = best.global_position
	beam_state = 1
	emote("angry")


func _beam(delta: float) -> void:
	beam_t -= delta
	beam.modulate.a = 0.85 + sin(t * 30.0) * 0.15
	beam.position.y = sin(t * 5.0) * 1.0
	tick_t -= delta
	if tick_t <= 0.0:
		tick_t = 0.2
		var dmg := float(Game.stats.damage) * 0.45
		for node in Game.world.enemy_cache:
			if not is_instance_valid(node):
				continue
			var e := node as Enemy
			if e == null or not e.targetable:
				continue
			var to := beam_at - e.global_position
			if to.length() < BEAM_R + e.radius:
				e.stun(0.35)
				e.push(to.normalized() * 40.0)  # sucked toward the middle of the beam
				e.take_damage(dmg, Vector2.ZERO)
				Game.world.burst(e.hit_center(), Color("7dff8a"), 2, 30.0, 0.35, 1.5, -40.0)
				if e.dead:
					on_kill()
		Game.world.burst(beam_at + Vector2(randf_range(-10, 10), 0), Color("b6ffb0"), 2, 20.0, 0.5, 1.5, -60.0)
	if beam_t <= 0.0:
		beam_state = 0
		beam_cd = BEAM_CD
		beam.visible = false
		ufo.visible = true


func _nearest(from: Vector2, reach: float) -> Enemy:
	var best: Enemy = null
	var best_d := reach
	for node in Game.world.enemy_cache:
		if not is_instance_valid(node):
			continue
		var e := node as Enemy
		if e == null or not e.targetable:
			continue
		var d := from.distance_to(e.hit_center())
		if d < best_d:
			best_d = d
			best = e
	return best


func on_kill() -> void:
	kills += 1
	if kills % 15 == 0:
		emote("wink")


func _on_hp() -> void:
	var hp := float(Game.stats.hp)
	if last_hp >= 0.0 and hp < last_hp - 0.5:
		emote("angry")
	last_hp = hp


## Idle chatter, and a surprised "!" when a boss shows up.
func _chatter(delta: float) -> void:
	chat_t -= delta
	if chat_t <= 0.0:
		chat_t = randf_range(14.0, 22.0)
		emote("neutral" if randf() < 0.5 else "happy")
	if int(t * 2.0) != int((t - delta) * 2.0):
		for node in Game.world.enemy_cache:
			if not is_instance_valid(node):
				continue
			var e := node as Enemy
			if e != null and e.is_boss and e.get_instance_id() != boss_seen:
				boss_seen = e.get_instance_id()
				emote("surprise")
				break


## Pop a face above the dome for a moment: surprise, angry, neutral, happy, wink.
func emote(mood: String) -> void:
	if face == null:
		return
	face.texture = load(KIT + "face_%s.png" % mood)
	var k := 11.0 / face.texture.get_height()
	face.visible = true
	face.scale = Vector2.ZERO
	face.modulate.a = 1.0
	if face_tw != null:
		face_tw.kill()
	face_tw = face.create_tween()
	face_tw.tween_property(face, "scale", Vector2.ONE * k, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	face_tw.tween_interval(1.2)
	face_tw.tween_property(face, "modulate:a", 0.0, 0.3)
	face_tw.tween_callback(func() -> void: face.visible = false)
	chat_t = maxf(chat_t, 6.0)
