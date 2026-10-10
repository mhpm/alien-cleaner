class_name SeedTank
extends Node2D
## World 8 (BIODOME) objective, placed by Explore ("tanks": n) in the middle of roomy halls:
## a glass SEED TANK with the last plants of the dome. Aliens that are not busy with the
## astronaut and come within LURE_R march on it (Enemy.lure) and every alien gnawing at it
## (within DANGER_R) drains DRAIN of its health a second; it mends slowly when nobody is
## near. At 0 the glass bursts: "SEED TANK LOST". When the final fight starts, every tank
## still standing HARVESTS (Explore.final_harvest): it heals the astronaut HEAL of max
## health and gives coins. Its foot is solid (Explore adds it to the walls).
## Art: the plant tanks of tools/w8_build_kit_ref.webp (make_forge_walls.py w8 -> prop_<n>).

const SCALE := 0.36
const FOOT := 0.35  # bottom share of the picture that is solid
const LURE_R := 230.0
const DANGER_R := 30.0
const DRAIN := 3.5  # % a second per alien
const REGEN := 1.5  # % a second with nobody near
const MAX_LURED := 10
const HEAL := 0.12
const COL := Color("8cff7a")

var hp := 100.0
var lost := false
var art := 0
var sprite: Sprite2D
var _tick := 0.0
var _hit := 0.0
var _lured := 0


func _ready() -> void:
	add_to_group("seed_tanks")
	sprite = Sprite2D.new()
	sprite.texture = SeedTank.tex(art)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.centered = false
	var ts := sprite.texture.get_size()
	sprite.offset = Vector2(-ts.x * 0.5, -ts.y)
	sprite.scale = Vector2.ONE * SCALE
	add_child(sprite)


static var _tex := {}


static func tex(k: int) -> Texture2D:
	if not _tex.has(k):
		var img := (load("res://assets/rooms/w8/build/prop_%d.png" % k) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_tex[k] = ImageTexture.create_from_image(img)
	return _tex[k]


## Solid rect of a tank standing with its bottom centre at `at`.
static func foot(k: int, at: Vector2) -> Rect2:
	var sz := SeedTank.tex(k).get_size() * SCALE
	var h := sz.y * FOOT
	return Rect2(at.x - sz.x * 0.4, at.y - h, sz.x * 0.8, h)


## DefendCore-like: aliens on their way to it give up once it is gone.
func is_resolved() -> bool:
	return lost


func _process(delta: float) -> void:
	if lost:
		return
	_hit = maxf(0.0, _hit - delta)
	_tick -= delta
	if _tick > 0.0:
		return
	var step := 0.25 - _tick
	_tick = 0.25
	var w := Game.world
	if w == null or w.player == null:
		return
	var gnaw := 0
	for e in w.enemies_near(global_position, DANGER_R + 20.0):
		if not e.dead and not e.is_boss and not e.anchored and e.global_position.distance_to(global_position) < DANGER_R:
			gnaw += 1
	if gnaw > 0:
		hp -= DRAIN * gnaw * step
		_hit = 0.3
		if randf() < 0.6:
			w.burst(global_position + Vector2(randf_range(-8, 8), -20), Color("bff4ff"), 3, 40.0, 0.3, 2.0)
		if hp <= 0.0:
			_lose()
			return
	else:
		hp = minf(100.0, hp + REGEN * step)
	if w.survival != null and w.survival.fence == null:
		_lure(w)
	queue_redraw()


## Aliens nearby that are not fighting the astronaut turn on the tank.
func _lure(w: GameWorld) -> void:
	if _lured >= MAX_LURED:
		_lured = 0  # recount now and then: the lured ones die or break off
	var p := w.player.global_position
	for e in w.enemies_near(global_position, LURE_R):
		if _lured >= MAX_LURED:
			break
		if e.dead or e.is_boss or e.anchored or e.lure != null:
			continue
		if e.global_position.distance_to(global_position) < LURE_R and e.global_position.distance_to(p) > Enemy.LURE_BREAK * 1.5:
			e.lure = self
			_lured += 1


func _lose() -> void:
	lost = true
	hp = 0.0
	var w := Game.world
	w.burst(global_position + Vector2(0, -24), Color("bff4ff"), 30, 120.0, 0.6, 2.5)
	w.burst(global_position + Vector2(0, -24), COL, 14, 80.0, 0.6, 2.0, 60.0)
	w.shake(0.4)
	Sfx.play("explode", 0.3, -4.0)
	sprite.modulate = Color(0.45, 0.4, 0.45)
	queue_redraw()
	if w.explore != null:
		w.explore.tank_lost(self)


## The final fight: a standing tank heals the astronaut.
func harvest() -> void:
	if lost:
		return
	var w := Game.world
	var heal := float(Game.stats.max_hp) * HEAL
	Game.heal(heal)
	w.burst(global_position + Vector2(0, -24), COL, 24, 100.0, 0.6, 2.5, -40.0)


func _draw() -> void:
	if lost or hp >= 99.5:
		return
	var w := 34.0
	var y := -sprite.texture.get_height() * SCALE - 8.0
	draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.7))
	var col := COL if hp > 50.0 else (Color("ffcd75") if hp > 25.0 else Color("ff5566"))
	if _hit > 0.0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		col = Color.WHITE
	draw_rect(Rect2(-w * 0.5, y, w * hp / 100.0, 4), col)
