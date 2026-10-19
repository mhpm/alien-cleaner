class_name AlienMind
extends RefCounted
## An alien that has not noticed the astronaut yet (placed arena aliens: AlienPack).
## Enemy asks it every frame (`tick`): while it answers true the mind moves the alien
## (`steer`) and the alien never attacks; once ALERT the alien's own AI (chase, shoot,
## its special attacks) runs as usual.
##   CALM        its routine moves it (stand guard, wander, patrol, sleep), it looks
##               (`sight` within `fov` of where it faces, walls block the view) and
##               listens (`hearing`, all around; a sleeper only listens, closer)
##   SUSPICIOUS  "?": it saw something, stops and turns to look; `notice_time` more of
##               seeing the astronaut makes it ALERT, losing him calms it down
##   ALERT       "!": hunting. Friends within `call_radius` are called in. Losing the
##               astronaut (out of sight, faster beyond `give_up`) for `forget_time` -> SEARCH
##   SEARCH      "?": walks to where it last saw him, looks around, then RETURNs home
## Getting hurt, a friend's call or a security camera's alarm skip straight to ALERT /
## SEARCH. A new calm behaviour = a new Routine subclass (+ an entry in `make_routine`).

enum State { CALM, SUSPICIOUS, ALERT, SEARCH, RETURN }
enum Kind { GUARD, WANDER, PATROL, SLEEP }

const GROUP := "alien_minds"  # every enemy with a mind (calls for help, alarms)
const LOOK_EVERY := 0.15  # perception checks per alien (staggered)
const STROLL := 0.45  # calm walking speed (x the alien's speed)
const PATROL_PACE := 0.7  # a patrol walks with purpose
const SEARCH_TIME := 4.0
const SLEEP_HEARING := 0.55  # a sleeper hears this much of `hearing`, and never sees
## The arena's stealth (PlayerRules.alien_senses): every mind sees and hears this much.
## ArenaWorld sets it and puts it back to 1 when the arena closes.
static var senses := 1.0

var enemy: Enemy
var routine: Routine
var state := State.CALM
var home := Vector2.ZERO
var facing := Vector2.DOWN
var sight := 150.0
var fov := deg_to_rad(110.0)
var hearing := 45.0
var notice_time := 0.5
var call_radius := 140.0
var give_up := 320.0
var forget_time := 3.0

var _look_t := 0.0
var _sees := false
var _notice := 0.0
var _lost := 0.0
var _target := Vector2.ZERO  # SEARCH: where it last saw him; RETURN: home
var _state_t := 0.0
var _mark: Mark


## A calm behaviour: how the alien moves (and where it faces) before it notices anyone.
class Routine:
	extends RefCounted
	var mind: AlienMind

	func steer(_delta: float) -> Vector2:
		return Vector2.ZERO

	func can_see() -> bool:
		return true

	func mark() -> String:
		return ""

	## Back home after a search: start over.
	func reset() -> void:
		pass


## Stands at its post and looks around (its facing sweeps slowly left and right).
class GuardRoutine:
	extends Routine
	var base := Vector2.DOWN
	var sweep := deg_to_rad(50.0)
	var t := 0.0

	func steer(delta: float) -> Vector2:
		t += delta
		var to_home := mind.home - mind.enemy.global_position
		if to_home.length() > 6.0:  # pushed off its post
			return mind.walk_to(mind.home)
		mind.look(base.rotated(sin(t * 0.7) * sweep))
		return Vector2.ZERO


## Strolls between random spots of its area, pausing a little at each.
class WanderRoutine:
	extends Routine
	var radius := 90.0
	var spot := Vector2.ZERO
	var pause := 0.0

	func steer(delta: float) -> Vector2:
		var e := mind.enemy
		if pause > 0.0:
			pause -= delta
			return Vector2.ZERO
		if spot == Vector2.ZERO or e.global_position.distance_to(spot) < 6.0 or e.hit_wall:
			pause = randf_range(0.6, 2.2)
			spot = mind.home + Vector2.from_angle(randf() * TAU) * randf_range(0.2, 1.0) * radius
			spot = Game.world.room.open_near(spot)  # on reachable floor (Room.walk_mask)
			return Vector2.ZERO
		return mind.walk_to(spot)

	func reset() -> void:
		spot = Vector2.ZERO


## Walks a path of points (around its home), in a loop or back and forth.
class PatrolRoutine:
	extends Routine
	var points: PackedVector2Array = []  # world positions
	var loop := true
	var wait := 0.8
	var i := 0
	var dir := 1
	var pause := 0.0

	func steer(delta: float) -> Vector2:
		if points.size() < 2:
			return Vector2.ZERO
		if pause > 0.0:
			pause -= delta
			mind.look(mind.facing.rotated(delta * 1.5))
			return Vector2.ZERO
		var p := points[i]
		if mind.enemy.global_position.distance_to(p) < 6.0:
			pause = wait
			if loop:
				i = (i + 1) % points.size()
			else:
				if i + dir < 0 or i + dir >= points.size():
					dir = -dir
				i += dir
			return Vector2.ZERO
		return mind.walk_to(p, PATROL_PACE)

	func reset() -> void:
		var best := INF
		for k in points.size():  # carry on from the nearest point
			var d := mind.enemy.global_position.distance_to(points[k])
			if d < best:
				best = d
				i = k


## Asleep: never moves, never sees; only hears the astronaut close by ("z").
class SleepRoutine:
	extends Routine

	func can_see() -> bool:
		return false

	func mark() -> String:
		return "z"


## The "?", "!" or "z" over its head (redrawn only when it changes).
class Mark:
	extends Node2D
	var text := ""
	var color := Color.WHITE
	var t := 0.0

	func show_text(s: String, c: Color) -> void:
		if s == text and c == color:
			return
		text = s
		color = c
		t = 0.0
		visible = not s.is_empty()
		queue_redraw()

	## A tiny speech bubble with the symbol (rects only: cheap, drawn when it changes).
	func _draw() -> void:
		if text.is_empty():
			return
		var f := UiTheme.FONT
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var box := Rect2(-maxf(w, 5.0) * 0.5 - 3.0, -10.0, maxf(w, 5.0) + 6.0, 11.0)
		var ink := Color(0.08, 0.08, 0.14)
		draw_rect(box.grow(1.0), ink)
		draw_rect(box, color)  # the bubble takes the state's colour, the symbol is dark
		draw_rect(Rect2(-1.5, box.end.y, 3.0, 2.0), ink)  # the bubble's tail
		draw_rect(Rect2(-0.5, box.end.y, 1.0, 1.0), color)
		if text == "!":  # drawn by hand: the pixel font's "!" loses its dot this small
			draw_rect(Rect2(-1.0, -8.5, 2.0, 5.0), ink)
			draw_rect(Rect2(-1.0, -2.5, 2.0, 2.0), ink)
			return
		for dx: float in [0.0, 1.0]:  # bold
			draw_string(f, Vector2(-w * 0.5 + dx - 0.5, -2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)


static func make_routine(kind: int) -> Routine:
	match kind:
		Kind.WANDER:
			return WanderRoutine.new()
		Kind.PATROL:
			return PatrolRoutine.new()
		Kind.SLEEP:
			return SleepRoutine.new()
	return GuardRoutine.new()


## Puts this mind in charge of `e` (call once, right after the alien is created).
func attach(e: Enemy, r: Routine) -> AlienMind:
	enemy = e
	routine = r
	r.mind = self
	home = e.global_position
	_look_t = randf() * LOOK_EVERY
	e.mind = self
	e.add_to_group(GROUP)
	_mark = Mark.new()
	_mark.position = Vector2(0, -e.tex_h * e.base_scale - 7.0)
	e.add_child(_mark)
	_show_mark()
	return self


## Enemy._physics_process: true while the mind moves the alien (it has not noticed the
## astronaut, or lost him and is searching / going home).
func tick(delta: float) -> bool:
	_state_t += delta
	_look_t -= delta
	if _look_t <= 0.0:
		_look_t = LOOK_EVERY
		_sees = _perceive()
	_mark.position.y = -enemy.tex_h * enemy.base_scale - 7.0 + sin(_state_t * 6.0) * 1.0
	match state:
		State.CALM:
			if _sees:
				_enter(State.SUSPICIOUS)
		State.SUSPICIOUS:
			var p := enemy.player()
			look(p.global_position - enemy.global_position)
			_notice += delta if _sees else -delta * 0.8
			if _notice >= notice_time or (_sees and enemy.global_position.distance_to(p.global_position) < hearing):
				alert()
			elif _notice <= -0.6:
				_notice = 0.0
				_enter(State.CALM)
		State.ALERT:
			var p := enemy.player()
			if p.dead:
				_go_search(home)
			elif _sees or enemy.global_position.distance_to(p.global_position) < give_up * 0.5:
				_lost = 0.0
				_target = p.global_position
			else:
				# out of sight or too far: it keeps hunting a little (it knows where he went)
				_lost += delta * (2.0 if enemy.global_position.distance_to(p.global_position) > give_up else 1.0)
				if _lost >= forget_time:
					_go_search(_target)
			return false
		State.SEARCH:
			if _sees:
				alert()
				return false
			if enemy.global_position.distance_to(_target) < 8.0 or _state_t > SEARCH_TIME:
				_enter(State.RETURN)
		State.RETURN:
			if _sees:
				_enter(State.SUSPICIOUS)
			elif enemy.global_position.distance_to(home) < 8.0:
				routine.reset()
				_enter(State.CALM)
	return true


## Velocity while the mind is in charge.
func steer(delta: float) -> Vector2:
	match state:
		State.CALM:
			return routine.steer(delta)
		State.SEARCH:
			if enemy.global_position.distance_to(_target) < 8.0:
				look(facing.rotated(delta * 3.0))
				return Vector2.ZERO
			return walk_to(_target, 0.75)
		State.RETURN:
			return walk_to(home)
	return Vector2.ZERO


func walk_to(at: Vector2, pace := STROLL) -> Vector2:
	var to := at - enemy.global_position
	if to.length() < 1.0:
		return Vector2.ZERO
	look(to)
	return to.normalized() * enemy.speed * pace


func look(dir: Vector2) -> void:
	if dir.length() < 0.01:
		return
	facing = dir.normalized()
	if absf(facing.x) > 0.2:
		enemy.face = signf(facing.x)


func is_alert() -> bool:
	return state == State.ALERT


## "!": hunting from now on; friends close by come too.
func alert(call_friends := true) -> void:
	if state == State.ALERT:
		return
	_target = enemy.player().global_position
	_lost = 0.0
	_enter(State.ALERT)
	Game.world.popup_text(enemy.hit_center() + Vector2(0, -10), "!", Color("ff5566"), 10)
	if call_friends and call_radius > 0.0:
		for n in enemy.get_tree().get_nodes_in_group(GROUP):
			var other := (n as Enemy).mind if n is Enemy else null
			if other != null and other != self and not other.is_alert() \
					and other.enemy.global_position.distance_to(enemy.global_position) <= call_radius:
				other.alert(false)


## Hurt by the astronaut: no more doubts.
func on_hurt() -> void:
	alert()


## A security camera sounded the alarm: calm aliens within `radius` of `at` go and look.
static func raise_alarm(tree: SceneTree, at: Vector2, radius: float) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		var m := (n as Enemy).mind if n is Enemy else null
		if m != null and not m.is_alert() and m.enemy.global_position.distance_to(at) <= radius:
			m._go_search(at)


func _go_search(at: Vector2) -> void:
	_target = at
	_enter(State.SEARCH)


func _enter(s: State) -> void:
	state = s
	_state_t = 0.0
	_show_mark()


func _show_mark() -> void:
	match state:
		State.CALM:
			_mark.show_text(routine.mark(), Color("94b0c2"))
		State.SUSPICIOUS, State.SEARCH:
			_mark.show_text("?", Color("ffcd75"))
		State.ALERT:
			_mark.show_text("!", Color("ff5566"))
		State.RETURN:
			_mark.show_text("", Color.WHITE)


## Does it notice the astronaut now? Hearing all around (a sleeper less), sight within
## its field of view; both need a clear line (walls and solid props block).
func _perceive() -> bool:
	var p := enemy.player()
	if p == null or p.dead:
		return false
	var to := p.global_position - enemy.global_position
	var d := to.length()
	var sleeping := state == State.CALM and not routine.can_see()
	var ear := hearing * senses * (SLEEP_HEARING if sleeping else 1.0)
	var in_view := not sleeping and d <= sight * senses and absf(angle_difference(facing.angle(), to.angle())) <= fov * 0.5
	if d > ear and not in_view:
		return false
	var q := PhysicsRayQueryParameters2D.create(enemy.global_position, p.global_position, 1)
	return enemy.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
