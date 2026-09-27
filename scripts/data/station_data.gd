class_name StationData
extends RefCounted
## Space stations: big painted maps the camera scrolls over. Built by
## tools/make_station.py -> assets/stations/<id>.webp + <id>_walk.png (walk grid).
## All coordinates are in ART PIXELS of the painted map; `scale` turns them into world
## units. A level in WorldData uses a station with {"station": "<id>"}.
##   start    where the astronaut arrives
##   exit     the exit door (blocked until every sector is clean; walk into it to leave)
##   sectors  rooms to clean: entering a dirty one seals it with energy barriers and
##            runs its waves (same format as WorldData rooms: fixed / budget / pool,
##            optional "boss" and "upgrade")

const DIR := "res://assets/stations/"
const CELL := 16  # art px per walk-grid cell (tools/make_station.py CELL)

const STATIONS := {
	"station01": {
		"name": "ORBITAL DOCK 01", "scale": 0.35,
		"start": Vector2(505, 1392),
		"exit": Rect2(466, 48, 78, 88), "light": Rect2(478, 24, 56, 12),
		"sectors": [
			{"name": "ARRIVAL HALL", "rect": Rect2(312, 1040, 272, 352),
				"waves": [{"fixed": {"slime": 3}}, {"fixed": {"slime": 2, "runner": 1}}]},
			{"name": "CENTRAL PLAZA", "rect": Rect2(312, 640, 424, 400),
				"waves": [{"fixed": {"slime": 2, "spitter": 1, "droid": 1}}, {"budget": 5, "pool": ["slime", "runner", "spitter"]}],
				"upgrade": true},
			{"name": "HANGAR", "rect": Rect2(744, 500, 280, 250),
				"waves": [{"fixed": {"ufo": 1, "runner": 2}}, {"budget": 5, "pool": ["slime", "runner", "droid"]}]},
			{"name": "COMMAND DECK", "rect": Rect2(320, 136, 440, 414),
				"waves": [{"fixed": {"octopus": 1, "slime": 2, "runner": 1}}], "boss": "gloop_brute", "upgrade": true},
		],
	},
}


static func get_def(id: String) -> Dictionary:
	return STATIONS[id]
