class_name BomberBomb
extends Node2D
## A bomb of the BOMBER DRONE (kit bomber_bomb.png): flies an arc from the drone in the air
## to a point on the ground (nose along the way it moves, shadow under it) and blows up
## there (BomberDrone.blast). `mine`: if no alien is close when it lands it stays as a
## blinking proximity mine (MINE_TIME, goes off when an alien comes within MINE_R).
## `small` = a cluster bomblet (smaller, hops a short way).

const TEX := preload("res://assets/ui/upgrades/kit/bomber_bomb.png")
const ART_ANGLE := 0.9  # the art's nose points down-right
const MINE_TIME := 6.0
const MINE_R := 16.0

var drone: BomberDrone
var from := Vector2.ZERO  # in the air
var to := Vector2.ZERO  # on the ground
var ground_from := Vector2.ZERO
var time := 0.6
var arc := 30.0
var size := 9.0
var radius := 26.0
var damage := 10.0
var mega := false
var mine := false
var cluster := 0  # bomblets scattered by the blast
var t := 0.0
var landed := false
var sprite: Sprite2D
var shadow: Sprite2D
var _scan := 0.0


func _ready() -> void:
	shadow = Sprite2D.new()
	shadow.texture = Art.tex("shadow")
	shadow.modulate.a = 0.45
	shadow.top_level = true
	add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = TEX
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (size / TEX.get_width())
	add_child(sprite)
	global_position = from


func _physics_process(delta: float) -> void:
	if drone == null or not is_instance_valid(drone):
		queue_free()
		return
	t += delta
	if landed:
		_mine(delta)
		return
	var u := minf(t / time, 1.0)
	var prev := global_position
	var flat := from.lerp(to, u)
	global_position = flat - Vector2(0, arc * sin(PI * u))
	var g := ground_from.lerp(to, u)
	shadow.global_position = g
	shadow.scale = Vector2(0.5, 0.35) * (size / 9.0) * (0.6 + 0.4 * u)
	var v := global_position - prev
	if v.length() > 0.01:
		sprite.rotation = v.angle() - ART_ANGLE
	if u >= 1.0:
		if mine and not _alien_near(radius * 0.8):
			_arm()
		else:
			_boom()


func _arm() -> void:
	landed = true
	t = 0.0
	sprite.rotation = -ART_ANGLE + PI * 0.5  # lies on the ground nose down
	shadow.global_position = global_position + Vector2(0, 2)
	Sfx.play("alert", 0.1, -16.0)


func _mine(delta: float) -> void:
	# blinks faster as it runs out
	var k := t / MINE_TIME
	var blink := sin(t * (8.0 + 20.0 * k)) > 0.0
	sprite.modulate = Color(1.8, 0.6, 0.4) if blink else Color.WHITE
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.1
		if _alien_near(MINE_R):
			_boom()
			return
	if t >= MINE_TIME:
		_boom()


func _alien_near(r: float) -> bool:
	for e in Game.world.enemies_near(global_position, r):
		if e.targetable and e.global_position.distance_to(global_position) < r + e.radius:
			return true
	return false


func _boom() -> void:
	drone.blast(landed_pos(), radius, damage, mega, cluster)
	queue_free()


func landed_pos() -> Vector2:
	return to if not landed else global_position
