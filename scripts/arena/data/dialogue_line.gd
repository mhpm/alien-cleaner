@tool
class_name DialogueLine
extends Resource
## One line of a DialogueData: who says it (index in the cast), what, and how.

## NORMAL plain · SHOUT bigger, shaking, red flash · WHISPER dim and slow ·
## RADIO static and jitter (comms) · THINK grey, in brackets, no blips.
enum Effect { NORMAL, SHOUT, WHISPER, RADIO, THINK }
## Pixel font sizes (crisp at 8 / 16 / 24).
const SIZES := [8, 12, 16, 24]
const SIZE_NAMES := ["S", "M", "L", "XL"]
const EFFECT_NAMES := ["Normal", "Shout!", "Whisper…", "Radio", "Thought"]

@export var speaker := 0
@export_multiline var text := ""
## Index in SIZES.
@export_range(0, 3) var size := 0
@export var effect := Effect.NORMAL
## Seconds it stays once typed (0 = automatic by length). In cinematic mode the
## player taps to continue instead.
@export_range(0.0, 15.0, 0.1) var hold := 0.0
## Optional face for this line only (a different expression); empty = the speaker's.
@export var portrait: Texture2D


func font_size() -> int:
	return SIZES[clampi(size, 0, SIZES.size() - 1)]
