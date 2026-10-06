@tool
class_name Arena
extends Node2D
## Root of an arena built with the Arena Editor (addons/aliens_cleaner_arena_editor).
## Saved as an ordinary scene (scenes/arenas/arena_world_NN_level_NN.tscn) so everything
## stays editable in Godot. The fixed child layers below keep each kind of object in one
## place: the editor drops palette items into the right layer, and validation and the
## arena runtime (ArenaWorld / ArenaDirector) find them without searching the whole tree.
##
##   Terrain/Floor, Environment, Details   TileMapLayers painted with arena_terrain.tres
##   Walls                                 TileMapLayer; its tiles carry collision
##   Hazards                               HazardArea (acid, radiation, fire...)
##   Obstacles, Decorations                props (ArenaProp) and floor decals (ArenaDecal)
##   GameplayObjects                       PlayerSpawn, survivors, nests, android parts, exits...
##   Objectives, EnemySpawners, Pickups, Triggers, Navigation
##   Bounds                                ArenaBounds: the playable rectangle
## Metadata, missions and waves are in `data` (ArenaData).

## World units per terrain tile; the 64 px atlases are drawn at TERRAIN_SCALE.
const TILE := 32.0
const TERRAIN_SCALE := 0.5
const TERRAIN := ["Floor", "Environment", "Details"]
## name -> {"type": class to create, "y_sort": sorts its children by their feet}
const LAYERS := {
	"Terrain": {"type": "Node2D"},
	"Walls": {"type": "TileMapLayer"},
	"Hazards": {"type": "Node2D"},
	"Obstacles": {"type": "Node2D", "y_sort": true},
	"Decorations": {"type": "Node2D", "y_sort": true},
	"GameplayObjects": {"type": "Node2D", "y_sort": true},
	"Objectives": {"type": "Node2D"},
	"EnemySpawners": {"type": "Node2D"},
	"Pickups": {"type": "Node2D"},
	"Triggers": {"type": "Node2D"},
	"Navigation": {"type": "Node2D"},
}
const BOUNDS := "Bounds"

## Metadata, difficulty, objectives and waves (Inspector, or the dock's MISSIONS / WAVES).
@export var data: ArenaData:
	set(value):
		data = value
		if is_inside_tree():
			for node in find_children("*", "ArenaProp", true, false):
				node.queue_redraw()


## Arenas saved before ArenaData kept their metadata on the root: move it into `data`
## when such a scene loads (it is saved in the new format next time).
const LEGACY := ["arena_id", "display_name", "world_id", "level_id", "prop_theme"]


func _set(property: StringName, value: Variant) -> bool:
	if str(property) in LEGACY:
		if data == null:
			data = ArenaData.new()
		data.set(property, value)
		return true
	return false


func get_layer(layer_name: String) -> Node:
	if layer_name in TERRAIN:
		return get_node_or_null(NodePath("Terrain/" + layer_name))
	return get_node_or_null(NodePath(layer_name))


func get_bounds() -> ArenaBounds:
	return get_node_or_null(NodePath(BOUNDS)) as ArenaBounds


func prop_theme() -> String:
	return data.prop_theme if data != null else "ship"


## Every ArenaObject of the arena (optionally of one class, e.g. "AlienNest").
func objects(class_filter := "ArenaObject") -> Array[ArenaObject]:
	var out: Array[ArenaObject] = []
	for n in find_children("*", class_filter, true, false):
		out.append(n as ArenaObject)
	return out


## The object with this object_id, or null.
func find_object(id: String) -> ArenaObject:
	if id.is_empty():
		return null
	for o in objects():
		if o.object_id == id:
			return o
	return null


## Layers the standard structure expects but this scene lacks ("Terrain/Floor" style paths).
func missing_layers() -> Array[String]:
	var out: Array[String] = []
	for layer_name: String in LAYERS:
		if get_node_or_null(NodePath(layer_name)) == null:
			out.append(layer_name)
	for layer_name: String in TERRAIN:
		if get_node_or_null(NodePath("Terrain/" + layer_name)) == null:
			out.append("Terrain/" + layer_name)
	if get_bounds() == null:
		out.append(BOUNDS)
	return out


## The arena an object belongs to (its nearest Arena ancestor), or null.
static func of(node: Node) -> Arena:
	var n := node
	while n != null:
		if n is Arena:
			return n
		n = n.get_parent()
	return null
