class_name SuitRig
extends Node2D
## The astronaut assembled from the equipped gear: one layer per slot, all parts share
## the same 300x380 canvas (tools/make_suit_parts.py) so any mix lines up.
## Origin = feet. Used by the Player (weapon drawn separately so it can aim) and by
## the CHARACTER screen preview.

const ANCHOR := Vector2(130, 376)
const LAYERS := ["backpack", "legs", "armor", "arms", "helmet", "weapon"]
## Weapon part: grip pivot and muzzle tip in canvas pixels.
const GUN_PIVOT := Vector2(170, 238)
const GUN_TIP := Vector2(262, 252)

var with_weapon := true
var parts: Dictionary = {}


func _init(weapon := true) -> void:
	with_weapon = weapon


func _ready() -> void:
	for slot: String in LAYERS:
		if slot == "weapon" and not with_weapon:
			continue
		var s := Sprite2D.new()
		s.centered = false
		s.offset = -ANCHOR
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(s)
		parts[slot] = s
	refresh()


## Re-read Game.gear_equipped (call after buying / equipping).
func refresh() -> void:
	for slot: String in parts:
		(parts[slot] as Sprite2D).texture = Art.suit_tex(variant(slot), slot)


static func variant(slot: String) -> String:
	return GearData.variant_of(str(Game.gear_equipped[slot]))


func set_layer_material(m: Material) -> void:
	for s: Sprite2D in parts.values():
		s.material = m


static func gun_base_angle() -> float:
	return (GUN_TIP - GUN_PIVOT).angle()


static func gun_length() -> float:
	return (GUN_TIP - GUN_PIVOT).length()
