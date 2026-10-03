class_name SurvivorData
extends RefCounted
## Crew members to rescue in the EXPLORE maps (Survivor). Stand next to one for
## RESCUE_TIME to save them; each one thanks you with a bonus that fits their job.
## Art: assets/sprites/survivors/<id>_sad.png / <id>_happy.png (tools/make_survivors.py).

const RESCUE_TIME := 10.0  # seconds standing next to a survivor
const RESCUE_R := 30.0  # how close (world units)
const DIR := "res://assets/sprites/survivors/"

const CREW := [
	{"id": "pilot", "name": "PILOT", "color": Color("ff9a3a"), "gift": "+12% move speed"},
	{"id": "scientist", "name": "SCIENTIST", "color": Color("ff5a7a"), "gift": "+15% damage"},
	{"id": "engineer", "name": "ENGINEER", "color": Color("ffb020"), "gift": "+15% fire rate"},
	{"id": "medic", "name": "MEDIC", "color": Color("ff4a4a"), "gift": "+20 max HP, full heal"},
	{"id": "agent", "name": "AGENT", "color": Color("41a6f6"), "gift": "+8% critical chance"},
	{"id": "ace", "name": "ACE PILOT", "color": Color("ff5a4a"), "gift": "+8% speed and fire rate"},
	{"id": "mechanic", "name": "MECHANIC", "color": Color("ffb020"), "gift": "BLAST recharges 30% faster"},
	{"id": "botanist", "name": "BOTANIST", "color": Color("5ee84c"), "gift": "+25 max HP, heal 25"},
	{"id": "comms", "name": "COMMS OFFICER", "color": Color("b07aff"), "gift": "Pulls in gems and coins"},
	{"id": "guard", "name": "SECURITY", "color": Color("6f86b8"), "gift": "+10% damage, harder shoves"},
	{"id": "chef", "name": "CHEF", "color": Color("ff9a5a"), "gift": "Full heal, +15 max HP"},
	{"id": "navigator", "name": "NAVIGATOR", "color": Color("5fb4ff"), "gift": "Critical hits +50% stronger"},
	{"id": "nurse", "name": "NURSE", "color": Color("ff6a8a"), "gift": "+10 max HP, heal 40%"},
	{"id": "chemist", "name": "CHEMIST", "color": Color("7dff3a"), "gift": "Cleaned aliens burst"},
	{"id": "miner", "name": "MINER", "color": Color("ffcd3a"), "gift": "Shots pierce +1 alien"},
]

## Shouted while waiting (bubbles over their head).
const HELP := ["HELP!", "HELP!!", "HELP ME!", "OVER HERE!", "PLEASE!", "SAVE ME!", "DON'T LEAVE ME!", "HURRY!"]
## Said while you are rescuing them.
const HOLD := ["HURRY!", "THEY'RE COMING!", "ALMOST...", "STAY WITH ME!", "I KNEW IT!", "QUICK!"]
## Gratitude when saved.
const THANKS := ["THANK YOU!", "MY HERO!", "YOU SAVED ME!", "I OWE YOU!", "THANKS, CAPTAIN!", "YOU CAME!"]


static func tex(i: int, happy: bool) -> Texture2D:
	return load(DIR + "%s_%s.png" % [CREW[i].id, "happy" if happy else "sad"])


## Their thank-you gift to the run.
static func reward(i: int) -> void:
	var s := Game.stats
	match str(CREW[i].id):
		"pilot":
			s.move_speed = float(s.move_speed) * 1.12
		"scientist":
			s.damage = float(s.damage) * 1.15
		"engineer":
			s.fire_interval = float(s.fire_interval) / 1.15
		"medic":
			s.max_hp = float(s.max_hp) + 20.0
			s.hp = s.max_hp
		"agent":
			s.crit = float(s.crit) + 0.08
		"ace":
			s.move_speed = float(s.move_speed) * 1.08
			s.fire_interval = float(s.fire_interval) / 1.08
		"mechanic":
			s.blast_cooldown = float(s.blast_cooldown) * 0.7
		"botanist":
			s.max_hp = float(s.max_hp) + 25.0
			s.hp = minf(float(s.hp) + 25.0, float(s.max_hp))
		"comms":
			s.magnet = true
			s.magnet_lvl = int(s.get("magnet_lvl", 0)) + 2
		"guard":
			s.damage = float(s.damage) * 1.1
			s.knockback = float(s.knockback) * 1.4
		"chef":
			s.max_hp = float(s.max_hp) + 15.0
			s.hp = s.max_hp
		"navigator":
			s.crit_mult = float(s.crit_mult) + 0.5
		"nurse":
			s.max_hp = float(s.max_hp) + 10.0
			s.hp = minf(float(s.hp) + float(s.max_hp) * 0.4, float(s.max_hp))
		"chemist":
			s.death_explode = true
			s.explode_lvl = maxi(int(s.get("explode_lvl", 0)), 2)
		"miner":
			s.pierce = int(s.pierce) + 1
	Game.hp_changed.emit()
