@tool
class_name DialogueBoxArt
extends RefCounted
## Draws the arena dialogue box. Shared by the game (ArenaDialogue) and the Arena
## Editor's live preview, so what you edit is exactly what plays.
## `info` = DialogueData.line_info(): speaker, text, portrait, color, side, size, effect.

const FONT: FontFile = preload("res://fonts/minecraft/Minecraft.ttf")
const PAD := 6.0
const FACE := 34.0  # portrait square
const TAB_H := 11.0  # name plate above the box
const TEXT := Color("e8f4ff")
const MAX_LINES := 6


static func shown_text(info: Dictionary) -> String:
	var t := str(info.get("text", ""))
	match int(info.get("effect", 0)):
		DialogueLine.Effect.SHOUT:
			return t.to_upper()
		DialogueLine.Effect.THINK:
			return "(" + t + ")"
	return t


static func _text_x(info: Dictionary) -> float:
	return PAD + FACE + PAD if info.get("portrait") != null and int(info.get("side", 0)) == DialogueSpeaker.Side.LEFT else PAD + 2.0


static func _text_w(info: Dictionary, width: float) -> float:
	var face := FACE + PAD if info.get("portrait") != null else 0.0
	return width - face - PAD * 2.0 - 2.0


static func box_size(info: Dictionary, width: float) -> Vector2:
	var fs := int(info.get("size", 8))
	var tsz := FONT.get_multiline_string_size(shown_text(info), HORIZONTAL_ALIGNMENT_LEFT, _text_w(info, width), fs, MAX_LINES)
	var body := maxf(FACE + PAD * 2.0 if info.get("portrait") != null else 0.0, tsz.y + PAD * 2.0 + 4.0)
	return Vector2(width, TAB_H + maxf(body, 26.0))


## `shown` letters typed, `t` seconds since the line began, `waiting` = fully typed.
## `base` places the box on `ci` (the editor preview zooms it).
static func draw(ci: CanvasItem, info: Dictionary, width: float, shown: float, t: float, waiting: bool, tap_hint := false, base := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(base)
	var col: Color = info.get("color", Color("73eff7"))
	var effect := int(info.get("effect", 0))
	var right := int(info.get("side", 0)) == DialogueSpeaker.Side.RIGHT
	var full := box_size(info, width)
	var box := Rect2(0, TAB_H, width, full.y - TAB_H)
	var shake := Vector2.ZERO
	if effect == DialogueLine.Effect.SHOUT:
		var k := 1.6 if t < 0.6 else 0.7
		shake = Vector2(sin(t * 71.0), cos(t * 53.0)) * k
	# box
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.09, 0.9)
	if effect == DialogueLine.Effect.SHOUT and t < 0.25:
		sb.bg_color = sb.bg_color.lerp(Color(0.5, 0.05, 0.08, 0.92), 1.0 - t / 0.25)
	elif effect == DialogueLine.Effect.RADIO:
		sb.bg_color = Color(0.02, 0.07, 0.06, 0.9)
	sb.border_color = Color(col, 0.45) if effect in [DialogueLine.Effect.THINK, DialogueLine.Effect.WHISPER] else col
	sb.set_border_width_all(2 if effect == DialogueLine.Effect.SHOUT else 1)
	sb.set_corner_radius_all(4)
	ci.draw_style_box(sb, Rect2(box.position + shake * 0.5, box.size))
	# name plate on the speaker's side
	var who := str(info.get("speaker", "")).to_upper()
	if not who.is_empty():
		var nw := FONT.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10.0
		var nx := width - nw - 8.0 if right else 8.0
		var plate := StyleBoxFlat.new()
		plate.bg_color = col.darkened(0.15)
		plate.set_corner_radius_all(3)
		plate.corner_radius_bottom_left = 0
		plate.corner_radius_bottom_right = 0
		ci.draw_style_box(plate, Rect2(nx, 1, nw, TAB_H))
		ci.draw_string(FONT, Vector2(nx + 5, TAB_H - 2), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.03, 0.05, 0.1))
	# portrait: slides in, bobs while talking
	var tex: Texture2D = info.get("portrait")
	if tex != null:
		var slide := clampf(t / 0.18, 0.0, 1.0)
		var fx := width - PAD - FACE if right else PAD
		fx += (1.0 - slide) * (14.0 if right else -14.0)
		var talking := not waiting and effect != DialogueLine.Effect.THINK
		var bob := -absf(sin(t * 14.0)) * 1.5 if talking else 0.0
		var frame := Rect2(fx, box.position.y + PAD, FACE, FACE)
		ci.draw_rect(frame, Color(col, 0.16))
		ci.draw_rect(frame, Color(col, 0.6 * slide), false, 1.0)
		var ts := tex.get_size()
		var k := (FACE - 2.0) / maxf(ts.x, ts.y)
		var sz := ts * k
		var face_col := Color(1, 1, 1, slide)
		if effect == DialogueLine.Effect.RADIO:
			face_col = Color(0.7, 1.0, 0.85, slide * (0.75 + 0.25 * sin(t * 37.0)))
		elif effect == DialogueLine.Effect.THINK:
			face_col = Color(0.75, 0.78, 0.85, slide)
		var at := frame.position + Vector2((FACE - sz.x) * 0.5, FACE - sz.y - 1.0 + bob)
		if right:  # face the other speaker
			ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(at.x * 2.0 + sz.x, 0)))
		ci.draw_texture_rect(tex, Rect2(at, sz), false, face_col)
		ci.draw_set_transform_matrix(base)
	# text (typewriter)
	var fs := int(info.get("size", 8))
	var text := shown_text(info).left(int(shown))
	var tx := _text_x(info)
	var tcol := TEXT
	match effect:
		DialogueLine.Effect.WHISPER:
			tcol = Color(TEXT, 0.62)
		DialogueLine.Effect.THINK:
			tcol = Color("aab4c8")
		DialogueLine.Effect.RADIO:
			tcol = Color("c8ffe4")
			if fmod(t * 3.0, 2.3) < 0.08:
				shake.x += 1.5
		DialogueLine.Effect.SHOUT:
			tcol = Color("ffe0d8")
	var origin := Vector2(tx, box.position.y + PAD + fs) + shake
	if effect == DialogueLine.Effect.WHISPER:  # slanted
		ci.draw_set_transform_matrix(base * Transform2D(Vector2(1, 0), Vector2(-0.18, 1), Vector2(origin.y * 0.18, 0)))
	ci.draw_multiline_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, _text_w(info, width), fs, MAX_LINES, tcol)
	ci.draw_set_transform_matrix(base)
	# radio static
	if effect == DialogueLine.Effect.RADIO:
		var y := box.position.y + 2.0
		while y < box.end.y - 2.0:
			ci.draw_line(Vector2(2, y), Vector2(width - 2, y), Color(0.6, 1, 0.8, 0.05), 1.0)
			y += 3.0
		var noise := int(t * 20.0)
		for i in 10:
			var h := hash(noise * 31 + i)
			ci.draw_rect(Rect2(2.0 + float(h % 1000) / 1000.0 * (width - 6.0), box.position.y + 2.0 + float((h / 1000) % 1000) / 1000.0 * (box.size.y - 5.0), 2, 1), Color(0.7, 1, 0.85, 0.3))
	# "next" arrow
	if waiting and fmod(t * 2.5, 2.0) < 1.3:
		var ax := 10.0 if right and tex != null else width - 12.0
		var ay := box.end.y - 6.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 4), Vector2(ax + 5, ay - 1.5), Vector2(ax, ay + 1)]), col)
		if tap_hint:
			var hint := "TAP"
			var hw := FONT.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			ci.draw_string(FONT, Vector2(ax + (8.0 if right and tex != null else -hw - 3.0), ay + 1.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col, 0.8))
