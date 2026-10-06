@tool
class_name RewardData
extends Resource
## What completing something gives (objectives, waves, nests, survivors, bosses,
## the arena itself). Everything is optional; an empty reward gives nothing.

@export var coins := 0
## XP gems dropped at the spot (feed the in-arena level-ups).
@export var xp := 0
## Share of max health restored (0-1).
@export_range(0.0, 1.0, 0.05) var heal := 0.0
## Offer an upgrade choice right away (like a level-up).
@export var upgrade := false
## Shown as a popup when given (empty = automatic).
@export var message := ""


func is_empty() -> bool:
	return coins <= 0 and xp <= 0 and heal <= 0.0 and not upgrade


## Short text for editor lists and result screens.
func describe() -> String:
	var parts: Array[String] = []
	if coins > 0:
		parts.append("%d coins" % coins)
	if xp > 0:
		parts.append("%d XP" % xp)
	if heal > 0.0:
		parts.append("heal %d%%" % roundi(heal * 100.0))
	if upgrade:
		parts.append("upgrade")
	return ", ".join(parts) if not parts.is_empty() else "—"
