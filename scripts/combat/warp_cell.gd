class_name WarpCell
extends Node2D
## World 7 (WARP NEXUS) objective, placed by Explore ("warp_cells": n) in the far corners
## of the map (the cells furthest from the start, mazes first): a floating warp energy
## cell. Walk into it to take it: "WARP CELL n/m" and the nexus answers with a WARP
## AMBUSH (drones warp in round you, marked circles first). Taking them all charges the
## gate (Explore.gate_charged): the WARP OVERSEER arrives with GATE_HP of its health and
## cannot warp. Glows (DarkLights.glow) so it can be spotted from afar.

const PICK_R := 18.0
const AMBUSH := ["laser_drone", "saw_drone", "spider_bot", "gravity_sentinel"]
const AMBUSH_N := 3
const COL := Color("5fd0ff")

var t := 0.0
var taken := false
var sprite: Sprite2D
var _tick := 0.0


func _ready() -> void:
	add_to_group("warp_cells")
	sprite = Sprite2D.new()
	sprite.texture = Art.frames("gravity_well").get_frame_texture("fly", 0)
	sprite.scale = Vector2.ONE * 0.16
	sprite.position = Vector2(0, -14)
	add_child(sprite)
	t = randf() * TAU
	DarkLights.glow(self)
	sprite.use_parent_material = true


func _process(delta: float) -> void:
	if taken:
		return
	t += delta
	sprite.position.y = -14.0 + sin(t * 2.4) * 3.0
	sprite.rotation += delta * 1.5
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.08
	var w := Game.world
	if w == null or w.player == null or w.player.dead:
		return
	if randf() < 0.5:
		w.burst(global_position + Vector2(randf_range(-6, 6), -14), COL, 1, 18.0, 0.6, 1.5, -30.0)
	if w.player.global_position.distance_to(global_position) < PICK_R:
		_take()


func _take() -> void:
	taken = true
	var w := Game.world
	w.burst(global_position + Vector2(0, -14), COL, 30, 120.0, 0.6, 2.5)
	w.ring(global_position, 30.0, COL, 0.4, 3.0)
	w.hud.tint_flash(COL, 0.25, 0.4)
	Sfx.play("coin", 0.4, 0.0)
	_ambush()
	if w.explore != null:
		w.explore.cell_taken(self)
	queue_free()


## Drones warp in round the astronaut, each marked by a circle first.
func _ambush() -> void:
	var w := Game.world
	var s := w.survival
	var m := Vector2(s._hp_mult(), s._dmg_mult()) if s != null else Vector2.ONE
	var p := w.player.global_position
	for i in AMBUSH_N:
		var id: String = AMBUSH[randi() % AMBUSH.size()]
		var at := w.room.open_near(p + Vector2.from_angle(TAU * i / AMBUSH_N + randf()) * randf_range(80.0, 110.0))
		w.telegraph_circle(at, 16.0, 0.8)
		w.get_tree().create_timer(0.8, false).timeout.connect(WarpCell.warp_in.bind(id, at, m))


static func warp_in(id: String, at: Vector2, m: Vector2) -> void:
	var w := Game.world
	if w == null or w.player == null or w.player.dead:
		return
	w.burst(at, COL, 14, 70.0, 0.4, 2.0)
	w.spawn_enemy(id, at, m.x, 1.0, false, true, m.y)
