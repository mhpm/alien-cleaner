class_name FaultWave
extends Node2D
## DRILLBACK's FAULT LINES: cracks run out from its feet along `angles` (the boss draws the
## warning lanes), and after `warn` seconds a row of rock spikes erupts along each, from the
## boss outwards. The safe place is between two cracks.

const SPEED := 300.0  # how fast the eruption front runs outwards
const STEP := 18.0  # distance between spikes on a crack
const START := 24.0
const LENGTH := 150.0

var angles: Array[float] = []
var damage := 20.0
var warn := 0.9
var t := 0.0
var next_r := START


func _physics_process(delta: float) -> void:
	t += delta
	if t < warn:
		return
	var front := (t - warn) * SPEED + START
	while next_r <= front and next_r <= LENGTH:
		for a in angles:
			BossDrillback.spike_burst(global_position + Vector2.from_angle(a) * next_r, 0.2, damage, 10.0)
		next_r += STEP
	if next_r > LENGTH:
		queue_free()
