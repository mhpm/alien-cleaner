class_name HunterBlade
extends Node2D
## One boomerang blade of the HUNTER DRONE (kit hunter_blade.png, spinning). Flies a
## teardrop loop out from the drone and back to it (the drone moves: the way home follows
## it), cutting every alien it passes (each alien at most once per HIT_EVERY). In "ring"
## mode it first circles the astronaut as a buzzsaw (PINWHEEL), then loops out.
## The drone itself can fly a loop too (its whirl sprite): `tex` / `size` set by HunterDrone.

const TEX := preload("res://assets/ui/upgrades/kit/hunter_blade.png")
const HIT_EVERY := 0.3
const SPIN := 22.0  # rad/s
const GHOSTS := 3  # trail copies

var drone: HunterDrone
var tex: Texture2D = TEX
var size := 13.0  # world units
var hit_r := 9.0
var damage := 6.0
var dir := Vector2.RIGHT  # toward the far end of the loop
var length := 95.0
var width := 38.0  # how wide the loop swings (signed: which side)
var time := 1.1  # seconds for the whole loop
var ring_time := 0.0  # PINWHEEL: seconds circling the astronaut first
var ring_r := 34.0
var ring_a := 0.0
var split := false  # level 5: at the far end it fires a slash wave
var t := 0.0
var sprite: Sprite2D
var ghosts: Array[Sprite2D] = []
var hits := {}
var _split_done := false
var start := Vector2.INF  # where the loop began (it ends at the drone, wherever it is then)


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in GHOSTS:
		var g := Sprite2D.new()
		g.texture = tex
		g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		g.material = add
		g.modulate = Color(1.0, 0.3, 0.3, 0.35 - 0.1 * i)
		g.top_level = true
		add_child(g)
		ghosts.append(g)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	var k := size / float(tex.get_width())
	sprite.scale = Vector2.ONE * k
	for g in ghosts:
		g.scale = sprite.scale


## Where the blade is at loop progress u (0 = at the drone, 0.5 = far end, 1 = back).
func loop_point(home: Vector2, u: float) -> Vector2:
	var side := dir.orthogonal()
	return home + dir * length * sin(PI * u) + side * width * sin(TAU * u) * 0.5


func _physics_process(delta: float) -> void:
	if drone == null or not is_instance_valid(drone) or drone.player == null:
		queue_free()
		return
	t += delta
	var home := drone.hand()
	var prev := global_position
	if t < ring_time:
		# PINWHEEL: a buzzsaw circling the astronaut, then off on its loop
		ring_a += delta * 7.0
		var c := drone.player.global_position + Vector2(0, -8)
		global_position = c + Vector2(cos(ring_a), sin(ring_a) * 0.75) * ring_r
		dir = (global_position - c).normalized()
	else:
		var u := (t - ring_time) / time
		if u >= 1.0:
			drone.catch_blade(self)
			queue_free()
			return
		if start == Vector2.INF:
			start = global_position if ring_time > 0.0 else home
		global_position = loop_point(start.lerp(home, u), u)
		if split and not _split_done and u >= 0.5:
			_split_done = true
			drone.slash_wave(global_position, dir)
	sprite.rotation += SPIN * delta
	var step := global_position - prev  # trail copies fall behind along the way it moves
	for i in ghosts.size():
		ghosts[i].global_position = global_position - step * (i + 1) * 1.6
		ghosts[i].rotation = sprite.rotation - 0.5 * (i + 1)
	_cut()


func _cut() -> void:
	var now := t
	for e in Game.world.enemies_near(global_position, hit_r + 10.0):
		if not e.targetable:
			continue
		if global_position.distance_to(e.hit_center()) > e.radius + hit_r:
			continue
		var id := e.get_instance_id()
		if now - float(hits.get(id, -9.0)) < HIT_EVERY:
			continue
		hits[id] = now
		var crit := randf() < float(Game.stats.crit)
		e.take_damage(damage * (float(Game.stats.crit_mult) if crit else 1.0), dir * 0.3, crit)
		Game.world.burst(e.hit_center(), Color("ff4a4a"), 3, 60.0, 0.2, 1.5)
		Sfx.play("hit", 0.25, -12.0)
