@tool
class_name DialogueSpeaker
extends Resource
## One character of a DialogueData cast: who talks, with which face, colour and voice.

enum Side { LEFT, RIGHT }

@export var name := "MISSION CONTROL"
@export var portrait: Texture2D
@export var color := Color("73eff7")
## Where the portrait sits in the box (two people talking face each other).
@export var side := Side.LEFT
## Pitch of the typing blips (1 = normal; low = big/robotic, high = small/nervous).
@export_range(0.4, 2.2, 0.05) var voice := 1.0
