class_name HeartShot
extends Bullet
## The girl's heart (HeartShotAbility): flies like any shot (Bullet: walls, aliens by
## distance, its sprite pulsing) and charms the first alien it hits (Charm.apply).

const SIZE := 9.0  # world units across
const HIT_R := 5.0
const LIFE := 1.4

var charm_time := 5.0

static var _frames: SpriteFrames


func _ready() -> void:
	hit_r = HIT_R
	life = LIFE
	pop_color = Charm.COLOR
	var tex := HeartShotAbility.heart_tex()
	base_scale = SIZE / maxf(1.0, tex.get_width())
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _heart_frames(tex)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.play("fly")
	add_child(sprite)


static func _heart_frames(tex: Texture2D) -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.add_animation("fly")
		_frames.add_frame("fly", tex)
	return _frames


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if randf() < 0.5:
		Game.world.burst(global_position, Charm.COLOR, 1, 12.0, 0.3, 1.2)


func _hit_enemy(e: Enemy) -> void:
	e.take_damage(damage, dir)
	if Charm.apply(e, charm_time):
		Game.world.popup_text(e.hit_center() + Vector2(0, -10), "CHARMED!", Charm.COLOR, 8)


func _pop() -> void:
	if Game.world != null:
		Game.world.burst(global_position, pop_color, 8, 50.0, 0.3, 1.8)
	queue_free()
