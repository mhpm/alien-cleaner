class_name ArenaDialogue
extends Control
## Dialogue box for arena story beats (Dialogue Triggers, rescued crew, android parts):
## portrait on the speaker's side, name plate, typewriter text with each speaker's voice
## and line effects (shout, whisper, radio, thought). Lines queue up. Plain lines and
## normal conversations never pause the game and move on by themselves; a cinematic
## conversation (DialogueData.pause_game) pauses it and waits for a tap on each line.
## Drawing lives in DialogueBoxArt (shared with the editor preview).

const W := 300.0
const BOTTOM_GAP := 230.0  # from the bottom of the safe area, clear of the touch controls
const TOP_GAP := 64.0  # below the HUD top bar
const CPS := 38.0  # letters per second
const HOLD := 2.2

var hud: Hud
var _queue: Array[Dictionary] = []
var _cur: Dictionary = {}
var _shown := 0.0
var _t := 0.0
var _hold := 0.0
var _blip := 0.0
var _we_paused := false
var _controls_were := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps typing while a cinematic pauses the game
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	modulate.a = 0.0


## A single line (rescued crew, android parts, old triggers).
func show_line(speaker: String, text: String, portrait: Texture2D, color: Color) -> void:
	_queue.append({"speaker": speaker, "text": text, "portrait": portrait, "color": color,
		"side": DialogueSpeaker.Side.LEFT, "voice": 1.0, "size": 8, "effect": 0, "hold": 0.0,
		"speed": CPS, "pause": false, "top": false})
	if _cur.is_empty():
		_next()


## A whole conversation, line after line.
func play(data: DialogueData) -> void:
	for i in data.lines.size():
		if data.lines[i] != null and not data.lines[i].text.strip_edges().is_empty():
			_queue.append(data.line_info(i))
	if _cur.is_empty():
		_next()


func is_busy() -> bool:
	return not _cur.is_empty()


func _next() -> void:
	if _queue.is_empty():
		_cur = {}
		_set_paused(false)
		create_tween().tween_property(self, "modulate:a", 0.0, 0.25)
		return
	var first := _cur.is_empty()
	_cur = _queue.pop_front()
	_set_paused(bool(_cur.pause))
	_shown = 0.0
	_t = 0.0
	var hold := float(_cur.hold)
	_hold = hold if hold > 0.0 else HOLD + str(_cur.text).length() / 40.0
	_place()
	if first:
		create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	Sfx.play("alert" if int(_cur.effect) == DialogueLine.Effect.SHOUT else "select", 0.0, -8.0)
	if int(_cur.effect) == DialogueLine.Effect.SHOUT and hud != null:
		var w := hud.get_parent() as GameWorld
		if w != null:
			w.shake(0.25)
	queue_redraw()


func _place() -> void:
	var sz := DialogueBoxArt.box_size(_cur, W)
	if bool(_cur.top):
		set_anchors_preset(Control.PRESET_CENTER_TOP)
		offset_top = TOP_GAP
	else:
		set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		offset_top = -BOTTOM_GAP
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_bottom = offset_top + sz.y


func _set_paused(on: bool) -> void:
	if on == _we_paused:
		return
	if on and get_tree().paused:
		return  # somebody else paused (pause menu): leave it alone
	_we_paused = on
	get_tree().paused = on
	if hud != null and hud.controls != null:
		if on:
			_controls_were = hud.controls.enabled
			hud.controls.enabled = false
		else:
			hud.controls.enabled = _controls_were


func _speed() -> float:
	var s := float(_cur.get("speed", CPS))
	return s * (0.6 if int(_cur.effect) == DialogueLine.Effect.WHISPER else 1.0)


func _process(delta: float) -> void:
	if _cur.is_empty():
		return
	_t += delta
	var n := DialogueBoxArt.shown_text(_cur).length()
	if _shown < n:
		var before := int(_shown)
		_shown = minf(n, _shown + delta * _speed())
		_blip -= delta
		if int(_shown) != before and _blip <= 0.0 and int(_cur.effect) != DialogueLine.Effect.THINK:
			_blip = 0.06
			var v := float(_cur.voice) * randf_range(0.92, 1.08)
			Sfx.play_pitched("select", v, -30.0 if int(_cur.effect) == DialogueLine.Effect.WHISPER else -24.0)
	elif not bool(_cur.pause):
		_hold -= delta
		if _hold <= 0.0:
			_next()
	queue_redraw()


## Cinematic lines: a tap finishes the typing, the next tap moves on.
func _input(event: InputEvent) -> void:
	if _cur.is_empty() or not bool(_cur.pause) or not _we_paused:
		return
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or event.is_action_pressed("ui_accept") or event.is_action_pressed("ability")
	if not tap:
		return
	get_viewport().set_input_as_handled()
	if _shown < DialogueBoxArt.shown_text(_cur).length():
		_shown = DialogueBoxArt.shown_text(_cur).length()
	else:
		Sfx.play("select", 0.0, -14.0)
		_next()


func _exit_tree() -> void:
	_set_paused(false)


func _draw() -> void:
	if _cur.is_empty():
		return
	var typed := _shown >= DialogueBoxArt.shown_text(_cur).length()
	DialogueBoxArt.draw(self, _cur, W, _shown, _t, typed, bool(_cur.pause))
