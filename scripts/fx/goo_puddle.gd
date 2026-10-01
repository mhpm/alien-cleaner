class_name GooPuddle
extends Node2D
## A puddle of a boss's goo (STYLES: "red" = BIG RED, "hive" = HIVE QUEEN, "lava" = MAGMA DRAKE). Acid
## puddles (the bosses' mortars) bubble and burn the astronaut standing in them; the
## rest is just residue left where the goo splashed. Both dry up after `life` seconds.

const RED := "res://assets/sprites/enemies/big-red/big-red_elements/big-red_%03d.png"
const LAVA := "res://assets/sprites/enemies/magma_drake/die/image_%02d.png"
const HIVE := "res://assets/sprites/enemies/bosses/boss_2_elements/boss_2_%03d.png"
## style -> small puddles, the big one (the boss's melted body), bubble colour
const STYLES := {
	"red": {"small": [RED % 95, RED % 98], "big": RED % 82, "color": Color("ff4fd8")},
	"hive": {"small": [HIVE % 107, HIVE % 108, HIVE % 109], "big": HIVE % 121, "color": Color("c8ff3a")},
	# MAGMA DRAKE: the lava pool of its death frames
	"lava": {"small": [LAVA % 5], "big": LAVA % 5, "color": Color("ff8a2a")},
}
const TICK := 0.5

var style := "red"
var acid := false
var radius := 12.0
var life := 5.0
var damage := 6.0
var big := false  # the boss's own melted body (the widest art)
var t := 0.0
var tick_t := 0.0
var spr: Sprite2D


func _ready() -> void:
	var st: Dictionary = STYLES[style]
	var small: Array = st.small
	spr = Sprite2D.new()
	spr.texture = load(str(st.big) if big else str(small[randi() % small.size()]))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.offset = Vector2(0, -spr.texture.get_height() * 0.35)
	spr.flip_h = randf() < 0.5
	add_child(spr)
	var k := radius * 2.2 / spr.texture.get_width()
	spr.scale = Vector2(k, k) * 0.2
	spr.create_tween().tween_property(spr, "scale", Vector2(k, k), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	modulate.a = 0.95 if acid else 0.8


func _physics_process(delta: float) -> void:
	t += delta
	if t >= life:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.tween_callback(queue_free)
		return
	if not acid:
		return
	# bubbling
	if randf() < delta * 6.0:
		Game.world.burst(global_position + Vector2(randf_range(-radius, radius) * 0.7, randf_range(-3, 1)), STYLES[style].color, 1, 12.0, 0.5, 1.5, -40.0)
	tick_t -= delta
	var p := Game.world.player
	if tick_t <= 0.0 and not p.dead:
		var d := p.global_position - global_position
		if Vector2(d.x, d.y * 1.6).length() < radius:
			tick_t = TICK
			p.take_damage(damage, Vector2.INF, true)
