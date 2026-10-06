extends Node
## scenes/arena_play.tscn: the shipped game scene running an arena (ArenaWorld +
## arena HUD), without changing scenes/game.tscn.


func _ready() -> void:
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.set_script(load("res://scripts/arena/runtime/arena_world.gd"))
	game.get_node("HUD").set_script(load("res://scripts/arena/runtime/arena_hud.gd"))
	add_child(game)
