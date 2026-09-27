class_name AnimFx
extends AnimatedSprite2D
## One-shot animated effect from a sliced sprite set (impacts, dust, glob bursts).

static func spawn(parent: Node, set_name: String, anim: String, pos: Vector2, s: float, rot := 0.0) -> AnimFx:
	var f := AnimFx.new()
	f.sprite_frames = Art.frames(set_name)
	f.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	f.offset = Art.anchor_offset(set_name)
	f.position = pos
	f.rotation = rot
	f.scale = Vector2.ONE * s
	f.animation_finished.connect(f.queue_free)
	parent.add_child(f)
	f.play(anim)
	return f
