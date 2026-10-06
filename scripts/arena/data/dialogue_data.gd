@tool
class_name DialogueData
extends Resource
## A conversation for the arena dialogue box: a cast of characters and the lines they
## say in order. Edited with the Arena Editor's Dialogue Editor (double-click a Dialogue
## Trigger, or "Open Dialogue Editor" in its Inspector). Played by ArenaDialogue.

enum Placement { BOTTOM, TOP }

@export var cast: Array[DialogueSpeaker] = []
@export var lines: Array[DialogueLine] = []
## Cinematic: the game pauses and the player taps to go to the next line.
@export var pause_game := false
## Typing speed, letters per second.
@export_range(8.0, 120.0, 1.0) var speed := 38.0
@export var placement := Placement.BOTTOM


func speaker_of(line: DialogueLine) -> DialogueSpeaker:
	if line == null or cast.is_empty():
		return null
	return cast[clampi(line.speaker, 0, cast.size() - 1)]


## A line ready for ArenaDialogue / the editor preview.
func line_info(i: int) -> Dictionary:
	var line := lines[i]
	var who := speaker_of(line)
	return {
		"speaker": who.name if who != null else "",
		"text": line.text,
		"portrait": line.portrait if line.portrait != null else (who.portrait if who != null else null),
		"color": who.color if who != null else Color("73eff7"),
		"side": who.side if who != null else DialogueSpeaker.Side.LEFT,
		"voice": who.voice if who != null else 1.0,
		"size": line.font_size(),
		"effect": line.effect,
		"hold": line.hold,
		"speed": speed,
		"pause": pause_game,
		"top": placement == Placement.TOP,
	}


## An independent copy (new speakers and lines; pictures are shared).
func copy() -> DialogueData:
	var d := DialogueData.new()
	for p in ["pause_game", "speed", "placement"]:
		d.set(p, get(p))
	for s in cast:
		var c := DialogueSpeaker.new()
		if s != null:
			for p in ["name", "portrait", "color", "side", "voice"]:
				c.set(p, s.get(p))
		d.cast.append(c)
	for l in lines:
		var c := DialogueLine.new()
		if l != null:
			for p in ["speaker", "text", "size", "effect", "hold", "portrait"]:
				c.set(p, l.get(p))
		d.lines.append(c)
	return d


func is_empty() -> bool:
	return lines.all(func(l: DialogueLine) -> bool: return l == null or l.text.strip_edges().is_empty())


## Short text for the editor canvas ("3 lines · ACE, DOC").
func summary() -> String:
	var names: Array[String] = []
	for s in cast:
		if s != null and not names.has(s.name):
			names.append(s.name)
	return "%d line%s · %s" % [lines.size(), "" if lines.size() == 1 else "s", ", ".join(names)]
