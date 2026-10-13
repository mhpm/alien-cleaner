class_name RunStats
extends RefCounted
## The crew member's stats this run against how they started it (Game.base_stats() = the
## character with its ARMORY / SHOP levels, before any upgrade, chest or rescued crew):
## what the pause menu shows as "value  +gain". Pure data, no UI.

## id, label, how to read it from a stats Dictionary, how to print it, whether its gain
## reads as a share ("+20%") instead of points ("+30"), and whether a lower value is the
## better one (cooldowns).
const ROWS := [
	{"id": "life", "label": "LIFE", "key": "max_hp", "fmt": "int"},
	{"id": "attack", "label": "ATTACK", "key": "damage", "fmt": "int", "share": true},
	{"id": "rate", "label": "FIRE RATE", "key": "fire_rate", "fmt": "rate"},
	{"id": "speed", "label": "SPEED", "key": "move_speed", "fmt": "int", "share": true},
	{"id": "crit", "label": "CRIT", "key": "crit", "fmt": "pct"},
	{"id": "shots", "label": "SHOTS", "key": "shot_count", "fmt": "int"},
	{"id": "pierce", "label": "PIERCE", "key": "pierce", "fmt": "int"},
	{"id": "blast", "label": "BLAST", "key": "blast_cooldown", "fmt": "secs", "lower": true},
]
const GAIN := Color("5ee84c")  # a stat that got better
const LOSS := Color("ff6b6b")


## One entry per ROWS: {id, label, value (text), gain (text, "" = unchanged), better (bool)}.
static func rows(now: Dictionary, start: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in ROWS:
		var a := _read(start, str(r.key))
		var b := _read(now, str(r.key))
		var lower := bool(r.get("lower", false))
		var better := b < a if lower else b > a
		out.append({
			"id": r.id, "label": r.label,
			"value": _fmt(b, str(r.fmt)),
			"gain": _gain(a, b, str(r.fmt), bool(r.get("share", false))),
			"better": better,
		})
	return out


## The stat `key` of `s` (a few are derived: shots per second, shots per trigger pull).
static func _read(s: Dictionary, key: String) -> float:
	match key:
		"fire_rate":
			return 1.0 / maxf(0.01, GunFire.interval(s))
		"shot_count":
			return float(int(s.get("shots", 1)) + 2 * int(s.get("spread", 0)))
	return float(s.get(key, 0.0))


static func _fmt(v: float, fmt: String) -> String:
	match fmt:
		"rate":
			return "%.1f/s" % v
		"pct":
			return "%d%%" % roundi(v * 100.0)
		"secs":
			return "%.1fs" % v
	return str(roundi(v))


## "+18%", "+2", "-1.0s"... "" when it did not change.
static func _gain(a: float, b: float, fmt: String, share: bool) -> String:
	if is_equal_approx(a, b):
		return ""
	match fmt:
		"rate":
			return "%+d%%" % roundi((b / maxf(0.001, a) - 1.0) * 100.0)
		"pct":
			return "%+d%%" % roundi((b - a) * 100.0)
		"secs":
			return "%+.1fs" % (b - a)
	if share and a > 0.0:
		return "%+d%%" % roundi((b / a - 1.0) * 100.0)
	return "%+d" % roundi(b - a)
