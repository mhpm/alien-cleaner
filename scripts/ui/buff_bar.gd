class_name BuffBar
extends Control
## HUD row of the player's active timed power-ups: the item icon with a draining bar
## underneath (blinks in the last 2 seconds).

const ICON := 22.0
const GAP := 5.0

var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var w := Game.world
	if w == null or w.player == null:
		return
	var x := 0.0
	for k: String in w.player.buffs:
		var left := float(w.player.buffs[k])
		var item: Dictionary = CollectibleData.ITEMS.get(k, {})
		var total := float(item.get("buff", 1.0))
		var col: Color = item.get("color", Color.WHITE)
		var a := 1.0 if left > 2.0 or fmod(t, 0.3) < 0.2 else 0.35
		draw_rect(Rect2(x - 1, -1, ICON + 2, ICON + 7), Color(0.04, 0.05, 0.1, 0.55 * a))
		var tex := CollectibleData.tex(k)
		var k2 := ICON / maxf(tex.get_width(), tex.get_height())
		var sz := tex.get_size() * k2
		draw_texture_rect(tex, Rect2(Vector2(x, 0) + (Vector2.ONE * ICON - sz) * 0.5, sz), false, Color(1, 1, 1, a))
		draw_rect(Rect2(x, ICON + 2, ICON, 3), Color(0, 0, 0, 0.6 * a))
		draw_rect(Rect2(x, ICON + 2, ICON * clampf(left / total, 0.0, 1.0), 3), Color(col, a))
		x += ICON + GAP
