@tool
class_name SecurityCamera
extends ArenaScenery
## A security camera mounted on a wall (`mount_height` up its face). Its cone of light
## lies on the floor and sweeps from side to side; a LED blinks while it watches.
## Walk into the cone and it locks on: the light turns red and follows the astronaut;
## stay seen for `lock_time` and it sounds the ALARM: a squad (`alarm_squad`) is called
## in around the camera, then it keeps staring for `alarm_cooldown` before sweeping again.
## Stray bullets can break it (`health`): sparks, and the cone goes dark for good.
## The alarm fires "alarm_raised" (AlienPack ALARM reinforcements) and sends the calm
## placed aliens within ALARM_HEARD to search where it saw the astronaut.
## TURNING CAMERA: a picture with `views` frames side by side (8 = one every 45°, the
## first facing right, clockwise: tools/make_security_cam.py) shows the frame of the way
## it is aiming, and the light leaves from that frame's red lens (`view_lens`).
## Costs one Polygon2D per camera (its 12 points moved each frame) and a distance check.

const IDLE_COL := Color(1.0, 0.93, 0.6)
const SEEN_COL := Color(1.0, 0.25, 0.2)
const TURN := 2.6  # rad/s while tracking
const ARC_STEPS := 10

enum State { WATCH, TRACK, ALARM, BROKEN }

## Height of the lens on the wall face (the cone starts on the floor below it).
@export_range(0.0, 80.0, 1.0) var mount_height := 26.0:
	set(value):
		mount_height = value
		_refresh()
@export_range(20.0, 400.0, 1.0) var view_range := 130.0
@export_range(10.0, 120.0, 1.0) var fov_deg := 38.0
## Centre of the sweep: 90 = down the screen, 0 = right, 180 = left.
@export_range(-180.0, 180.0, 1.0) var facing_deg := 90.0
@export_range(0.0, 90.0, 1.0) var sweep_deg := 40.0
@export_range(1.0, 20.0, 0.5) var sweep_time := 5.0
@export_range(0.2, 5.0, 0.1) var lock_time := 1.1
@export_range(1.0, 60.0, 1.0) var alarm_cooldown := 7.0
@export var alarm_squad: Array[SpawnEntry] = []
@export_range(1, 12) var squad_size := 3
@export_range(1.0, 500.0, 1.0) var health := 30.0
@export_group("Turning")
## Views of the camera side by side in the picture (1 = a still picture). With 8 the
## first looks right (0°) and they go clockwise every 45°: E, SE, S, SW, W, NW, N, NE.
@export_range(1, 16) var views := 1:
	set(value):
		views = maxi(1, value)
		columns = views  # (refreshes the sprite)
## Where the red lens is in each view: pixels of one frame from its bottom centre (the
## feet, before `mount_height` lifts the camera; scaled with `width`). The light starts
## there. Empty = the feet. tools/make_security_cam.py writes them to cam_8dir.json.
@export var view_lens := PackedVector2Array():
	set(value):
		view_lens = value
		queue_redraw()

var state := State.WATCH
var _world: GameWorld
var _director: Node
## Calm placed aliens (AlienMind) this close to the alarm go and look where it saw you.
const ALARM_HEARD := 420.0
var _cone: Polygon2D
var _led: Polygon2D
var _angle := 0.0
var _t := 0.0
var _lock := 0.0
var _alarm_t := 0.0
var _hp := 0.0
var _rng := RandomNumberGenerator.new()
var _view := -1
var _light_behind := false


class Hitbox:
	extends StaticBody2D
	var cam: SecurityCamera

	func bullet_hit(dmg: float) -> void:
		cam.hurt(dmg)


func _refresh() -> void:
	super._refresh()
	if sprite != null:
		sprite.position.y = -mount_height
		if views > 1:  # editing: the view it faces at rest
			sprite.frame = view_for(deg_to_rad(facing_deg))
			sprite.flip_h = false  # its views already face every way (a mirror would move the lens)


## A turning camera picks its frame from the aim, it never plays them as an animation.
func is_animated() -> bool:
	return views <= 1 and super.is_animated()


func palette_icon() -> Texture2D:
	if views <= 1 or texture == null:
		return super.palette_icon()
	var one := AtlasTexture.new()
	one.atlas = texture
	one.region = Rect2(Vector2(frame_size().x * view_for(PI * 0.5), 0), frame_size())  # looking down
	return one


## The view (frame) facing `angle` (radians, 0 = right, clockwise).
func view_for(angle: float) -> int:
	if views <= 1:
		return 0
	return int(roundf(wrapf(angle, 0.0, TAU) / (TAU / views))) % views


## The lens of a view relative to this node (the camera lifted by `mount_height`).
func lens_at(view: int) -> Vector2:
	var k := width / frame_size().x if texture != null else 1.0
	var l := view_lens[view] * k if view >= 0 and view < view_lens.size() else Vector2.ZERO
	return l + Vector2(0, -mount_height)


func activate(director: Node) -> void:
	super.activate(director)
	_world = director.get("world") as GameWorld
	_director = director
	_hp = health
	_rng.randomize()
	_t = _rng.randf() * sweep_time  # cameras never sweep in sync
	_angle = deg_to_rad(facing_deg)
	# ONE light: a cone from the lens (reddish there) spreading onto the floor. It is the
	# camera's child (sorted with it), so it starts on the lens even over the wall's face.
	_cone = Polygon2D.new()
	var cols := PackedColorArray([Color(1, 0.45, 0.4, 0.7)])
	for i in ARC_STEPS + 1:
		cols.append(Color(1, 1, 1, 0.06))
	_cone.vertex_colors = cols
	var pts := PackedVector2Array()
	pts.resize(ARC_STEPS + 2)  # (a packed array property is a copy: fill one, then assign it)
	_cone.polygon = pts
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cone.material = add
	_cone.modulate = IDLE_COL  # (vertex colours replace `color`: tint through modulate)
	add_child(_cone, false, Node.INTERNAL_MODE_FRONT)  # next to the sprite, to go in front of / behind it
	_led = Polygon2D.new()
	_led.polygon = PackedVector2Array([Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(1.5, 1.5), Vector2(-1.5, 1.5)])
	_led.position = Vector2(0, -mount_height - frame_size().y * width / frame_size().x * 0.5)
	_led.visible = views <= 1  # a turning camera's own red lens is its light
	add_child(_led)
	_aim_light()
	var box := Hitbox.new()
	box.cam = self
	box.collision_layer = 1
	box.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(maxf(10.0, width * 0.7), 8)
	cs.shape = shape
	cs.position = Vector2(0, 4)  # just in front of the wall, where shots arrive
	box.add_child(cs)
	add_child(box)
	set_process(true)


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint() or _world == null or state == State.BROKEN:
		return
	_t += delta
	var face := deg_to_rad(facing_deg)
	var reach := deg_to_rad(sweep_deg + fov_deg * 0.5)
	var p := _world.player
	var to := (p.global_position - global_position) if p != null else Vector2.INF
	var seen := p != null and not p.dead and to.length() < view_range \
		and absf(angle_difference(_angle, to.angle())) < deg_to_rad(fov_deg) * 0.5 \
		and absf(angle_difference(face, to.angle())) < reach
	match state:
		State.WATCH:
			_angle = rotate_toward(_angle, face + sin(_t * TAU / sweep_time) * deg_to_rad(sweep_deg), delta * 1.5)
			if seen:
				state = State.TRACK
				_lock = 0.0
				Sfx.play("charge", 0.05, -8.0)
		State.TRACK:
			_follow(to, face, reach, delta)
			_lock += delta if seen else -delta * 1.5
			if _lock <= 0.0:
				state = State.WATCH
			elif _lock >= lock_time:
				_sound_alarm()
		State.ALARM:
			_follow(to, face, reach, delta)
			_alarm_t -= delta
			if _alarm_t <= 0.0:
				state = State.WATCH
	_aim_light()
	var lock_k := clampf(_lock / lock_time, 0.0, 1.0) if state == State.TRACK else (1.0 if state == State.ALARM else 0.0)
	var col := IDLE_COL.lerp(SEEN_COL, lock_k)
	if state == State.ALARM and fmod(_t, 0.3) < 0.15:
		col = col.darkened(0.45)
	_cone.modulate = col
	var blink := 0.12 if state != State.WATCH else 0.9
	_led.color = (Color("a7f070") if state == State.WATCH else SEEN_COL) if fmod(_t, blink * 2.0) < blink else Color(0.1, 0.1, 0.12)


## Turns the picture to the aim and points the light: its tip is that view's lens, its
## far edge an arc on the floor `view_range` away (measured from below the lens).
func _aim_light() -> void:
	var v := view_for(_angle)
	if v != _view:
		_view = v
		if views > 1:
			sprite.frame = v
	var lens := lens_at(_view if views > 1 else -1)
	var floor_at := Vector2(lens.x, 0.0)
	var half := deg_to_rad(fov_deg) * 0.5
	var pts := _cone.polygon
	pts[0] = lens
	for i in ARC_STEPS + 1:
		pts[i + 1] = floor_at + Vector2.from_angle(_angle - half + 2.0 * half * i / ARC_STEPS) * view_range
	_cone.polygon = pts
	# looking away (up the screen): the lens is behind the body, so is the light
	var behind := views > 1 and Vector2.from_angle(_angle).y < -0.5
	if behind != _light_behind:
		_light_behind = behind
		move_child(_cone, 0 if behind else -1)  # (internal children: indices count inside their group)


func _follow(to: Vector2, face: float, reach: float, delta: float) -> void:
	var want := to.angle()
	var off := clampf(angle_difference(face, want), -reach, reach)
	_angle = rotate_toward(_angle, face + off, delta * TURN)


func _sound_alarm() -> void:
	state = State.ALARM
	_alarm_t = alarm_cooldown
	_lock = lock_time
	Sfx.play("alert", 0.0, -2.0)
	_world.shake(3.0)
	_world.popup_text(global_position + Vector2(0, -mount_height - 18), "INTRUDER!", SEEN_COL, 12)
	# the base hears it: AlienPacks waiting for an alarm come in, calm aliens close by search
	if _director != null:
		_director.call("fire", "alarm_raised", object_id, PackedStringArray(["alarm"]))
	AlienMind.raise_alarm(get_tree(), _world.player.global_position, ALARM_HEARD)
	if alarm_squad.is_empty():
		return
	var dir := Vector2.from_angle(_angle)
	for i in squad_size:
		var e := SpawnEntry.pick(alarm_squad, _rng)
		if e == null:
			continue
		var at := global_position + dir * _rng.randf_range(40.0, view_range * 0.6) \
			+ dir.orthogonal() * _rng.randf_range(-30.0, 30.0)
		_world.spawn_with_marker(e.enemy_id, at, 0.7 + i * 0.15)


func hurt(dmg: float) -> void:
	if state == State.BROKEN or _world == null:
		return
	_hp -= dmg
	_world.burst(global_position + Vector2(0, -mount_height), Color("ffcd75"), 4, 40.0, 0.25, 1.5)
	if _hp > 0.0:
		return
	state = State.BROKEN
	Sfx.play("zap", 0.1, -4.0)
	_world.burst(global_position + Vector2(0, -mount_height), Color("73eff7"), 14, 70.0, 0.5, 2.0)
	_world.popup_text(global_position + Vector2(0, -mount_height - 18), "CAMERA DOWN", Color("73eff7"), 10)
	_cone.queue_free()
	_led.color = Color(0.1, 0.1, 0.12)
	sprite.modulate = Color(0.55, 0.55, 0.6)
	set_process(false)


func _redraws_on_selection() -> bool:
	return true  # (unlike plain scenery, its cone is a detail)


func _draw() -> void:
	super._draw()
	if not Engine.is_editor_hint() or not show_details():
		return
	# the cone's reach and sweep, editor only
	var col := Color(1.0, 0.85, 0.3, 0.7)
	for a: float in [facing_deg - sweep_deg - fov_deg * 0.5, facing_deg + sweep_deg + fov_deg * 0.5]:
		draw_line(Vector2.ZERO, Vector2.from_angle(deg_to_rad(a)) * view_range, col, 1.0)
	var prev := Vector2.ZERO
	for i in 13:
		var a := deg_to_rad(lerpf(facing_deg - sweep_deg - fov_deg * 0.5, facing_deg + sweep_deg + fov_deg * 0.5, i / 12.0))
		var pt := Vector2.from_angle(a) * view_range
		if i > 0:
			draw_line(prev, pt, col, 1.0)
		prev = pt
