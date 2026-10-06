@tool
extends Control
## The WAVES timeline: one block per wave, width by its expected length (pause + the
## time its aliens take to come out, or its survive time), height of the bar by how
## many aliens it sends. Gold notch = elites, red skull = boss, the bottom stripe colour
## = how it ends. Gives the arena's pacing at a glance.

const COMPLETION_COLORS := [Color("73eff7"), Color("ffcd75"), Color("c75bd6"), Color("a7f070"), Color("41a6f6"), Color("ff5566")]

var page  # waves_page.gd


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	if page == null or page.arena == null or page.arena.data == null or page.arena.data.waves.is_empty():
		draw_string(get_theme_default_font(), Vector2(8, size.y * 0.55), "No waves yet: Add Wave", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.5))
		return
	var waves: Array = page.arena.data.waves
	var lengths: Array[float] = []
	var sizes: Array[int] = []
	var total := 0.0
	var biggest := 1
	for w: WaveData in waves:
		if w == null:
			lengths.append(1.0)
			sizes.append(0)
			continue
		var n: int = page.wave_size(w)
		var secs := w.delay_before + (w.target if w.completion == WaveData.Completion.SURVIVE_TIME else maxf(8.0, absi(n) * 1.1))
		lengths.append(secs)
		sizes.append(n)
		total += secs
		biggest = maxi(biggest, absi(n))
	var font := get_theme_default_font()
	var x := 2.0
	var bar_h := size.y - 18.0
	for i in waves.size():
		var w: WaveData = waves[i]
		var wd := maxf(18.0, (size.x - 4.0 - waves.size() * 2.0) * lengths[i] / maxf(total, 1.0))
		var r := Rect2(x, 2, wd, size.y - 4)
		draw_rect(r, Color(0.12, 0.16, 0.24))
		if w != null:
			var n := sizes[i]
			var k := 1.0 if n < 0 else float(n) / biggest
			var h := bar_h * clampf(k, 0.12, 1.0)
			draw_rect(Rect2(x + 2, 2 + bar_h - h + 2, wd - 4, h), Color(1.0, 0.42, 0.3, 0.75))
			draw_rect(Rect2(x, size.y - 6, wd, 4), COMPLETION_COLORS[w.completion])
			if w.elite_count > 0:
				draw_rect(Rect2(x + wd - 7, 4, 5, 5), Color("ffcd75"))
			if not w.boss_id.is_empty():
				draw_circle(Vector2(x + wd * 0.5, 10), 5.0, Color("ff5566"))
			var label := "%d: %s" % [i + 1, "∞" if n < 0 else str(n)]
			draw_string(font, Vector2(x + 3, size.y - 9), label, HORIZONTAL_ALIGNMENT_LEFT, wd - 4, 11, Color.WHITE)
		x += wd + 2.0
	draw_string(font, Vector2(size.x - 70, 12), "~%ds" % int(total), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
