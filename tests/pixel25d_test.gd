extends Node
## Pixel 2.5D prototype check (in a window, not headless): plays
## scenes/prototype_pixel25d.tscn and saves user://pixel25d_test_*.png
##   on     = low-res pixel render, the office at the start
##   off    = the same moment with the normal render
##   lab    = the specimen lab, cameras sweeping
##   spotted = standing in a camera's cone: it locks on and sounds the alarm
##   bay    = the storage bay and the alien breach, fighting
## and fails if a camera never raised the alarm.
##   godot --path . res://tests/pixel25d_test.tscn

var proto: Node
var world: GameWorld


func _ready() -> void:
	proto = (load("res://scenes/prototype_pixel25d.tscn") as PackedScene).instantiate()
	add_child(proto)
	ArenaSession.invincible = true
	await _wait(3.5)
	world = proto.get("_world") as GameWorld
	await _shot("on")
	proto.call("toggle")
	await _wait(0.3)
	await _shot("off")
	proto.call("toggle")
	_go(Vector2(330, 250))
	await _wait(1.0)
	await _shot("lab")
	var cam: SecurityCamera = null
	for n in world.entities.get_children():
		if n is SecurityCamera and n.object_id == "cam_1":
			cam = n
	# a turning camera follows the astronaut: its frame matches the aim and the light
	# leaves that frame's red lens
	var turned := true
	for spot: Vector2 in [Vector2(-60, 70), Vector2(0, 80), Vector2(60, 70)]:
		_go(cam.global_position + spot)
		cam.set("_angle", spot.angle())  # (its sweep starts at random: look at the astronaut now)
		await _wait(0.9)
		await _shot("aim_%d" % int(spot.x))
		turned = turned and _light_on_lens(cam)
	var alarmed := cam.state == SecurityCamera.State.ALARM
	await _shot("spotted")
	_go(Vector2(320, 430))
	await _wait(4.0)
	await _shot("bay")
	print("PIXEL25D TEST: camera alarm %s, turning view + light from the lens %s -> %s" % [
		"OK" if alarmed else "FAILED (state %d)" % cam.state, "OK" if turned else "FAILED",
		ProjectSettings.globalize_path("user://")])
	get_tree().quit(0 if alarmed and turned else 1)


func _light_on_lens(cam: SecurityCamera) -> bool:
	if cam.views <= 1:
		return true
	var view := cam.view_for(cam.get("_angle"))
	var cone: Polygon2D = cam.get("_cone")
	var start := cone.polygon[0]  # the tip of the only light
	var extra := cam.get_children(true).filter(func(n: Node) -> bool: return n is Polygon2D and n != cone and (n as Polygon2D).visible)
	var ok := cam.sprite.frame == view and start.distance_to(cam.lens_at(view)) < 0.5 and extra.is_empty()
	print("  aim %.0f° view %d frame %d light from %s lens %s %s" % [rad_to_deg(cam.get("_angle")), view,
		cam.sprite.frame, start, cam.lens_at(view), "ok" if ok else "MISMATCH"])
	return ok


func _go(at: Vector2) -> void:
	world.player.global_position = at
	world.camera.reset_smoothing()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs).timeout


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://pixel25d_test_%s.png" % tag)
