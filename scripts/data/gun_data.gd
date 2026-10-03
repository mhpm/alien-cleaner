class_name GunData
extends RefCounted
## The 10 weapons of the ARMORY. Bought with banked coins, one is equipped for the run
## and each has 3 levels (buying = Lv1). Every weapon fires its own way (`kind`, handled
## by GunFire) and they are all EQUALLY strong: none is an upgrade of another, each is a
## different way to play (its `role`). Weapons with no area effect hit a single alien a
## little harder; area / crowd-control ones a little softer. Any of them can clear every
## world with ATTACK levels and the run's upgrades. Art: assets/guns/gun_<n>.png (+ guns.json grip / tip) from
## tools/make_armory_assets.py; projectiles and effects next to them.
##
## `dmg` multiplies the run's base damage per hit, `rate` = seconds between shots (scaled
## by the run's fire_interval), `dps` = single-target damage per second in units of base
## damage (boss sizing; the crew POWER is the same for every weapon), `p` = the kind's parameters, `lv3` = what the
## weapon's level 3 adds (`mod` describes it).

const MAX_LEVEL := 3
const LEVEL_DMG := 0.2  # +20% damage per level above 1
const DIR := "res://assets/guns/"

const BASE_POWER := 130  # every weapon's POWER at level 1

const GUNS := [
	{"id": "pulse", "name": "PULSE BLASTER", "role": "PRECISION", "price": 0, "kind": "pulse",
		"color": "4fc3ff", "dmg": 1.25, "rate": 0.40, "speed": 260.0, "range": "Medium", "dps": 3.9,
		"ability": "STEADY AIM", "desc": "Fast, precise plasma shots. Every 4th shot is a critical that pierces 2 aliens.",
		"p": {"crit_every": 4, "crit_pierce": 2}, "lv3": {"crit_every": 3}, "mod": "Every 3rd shot crits"},
	{"id": "nova", "name": "NOVA SCATTER", "role": "CLOSE RANGE", "price": 400, "kind": "nova",
		"color": "5fb4ff", "dmg": 0.9, "rate": 0.62, "speed": 250.0, "range": "Short", "dps": 3.4,
		"ability": "SHOTGUN SHOVE", "desc": "Blasts a fan of 5 pellets that knock aliens far back.",
		"p": {"pellets": 5, "arc": 0.55, "push": 30.0, "life": 0.45}, "lv3": {"pellets": 7}, "mod": "7 pellets"},
	{"id": "drill", "name": "PLASMA DRILL", "role": "PIERCING", "price": 500, "kind": "drill",
		"color": "5fe6ff", "dmg": 1.45, "rate": 0.50, "speed": 340.0, "range": "Long", "dps": 3.6,
		"ability": "ARMOR BREAK", "desc": "A drill bolt that pierces every alien in line. Hit aliens take +25% damage.",
		"p": {"shred": 0.25, "shred_t": 3.0}, "lv3": {"shred": 0.4}, "mod": "Armor break +40%"},
	{"id": "spark", "name": "RICOCHET SPARK", "role": "RICOCHET", "price": 600, "kind": "spark",
		"color": "ffa030", "dmg": 1.5, "rate": 0.45, "speed": 240.0, "range": "Medium", "dps": 3.3,
		"ability": "CHAIN BOUNCE", "desc": "Sparks jump from alien to alien and bounce off walls.",
		"p": {"hops": 2, "bounces": 2, "hop_r": 95.0}, "lv3": {"hops": 4}, "mod": "Jumps 4 times"},
	{"id": "cryo", "name": "CRYO SPRAYER", "role": "CROWD CONTROL", "price": 700, "kind": "cryo",
		"color": "a8ecff", "dmg": 0.34, "rate": 0.2, "speed": 175.0, "range": "Short", "dps": 3.2,
		"ability": "DEEP FREEZE", "desc": "A short icy spray. Frozen aliens leave ice spikes that keep hurting whoever touches them.",
		"p": {"flakes": 3, "arc": 0.5, "life": 0.4, "chill": 5, "ice_dps": 0.55}, "lv3": {"chill": 3, "flakes": 4},
		"mod": "Freezes 2x faster"},
	{"id": "goo", "name": "TOXIC GOO LAUNCHER", "role": "AREA DAMAGE", "price": 800, "kind": "goo",
		"color": "7dff3a", "dmg": 1.3, "rate": 0.72, "speed": 0.0, "range": "Medium", "dps": 3.0,
		"ability": "CORROSION", "desc": "Lobs a toxic glob: splash damage plus an acid pool that melts aliens.",
		"p": {"splash": 24.0, "pool_r": 18.0, "pool_t": 2.5, "pool_dps": 1.2}, "lv3": {"pool_r": 26.0, "pool_t": 3.5},
		"mod": "Bigger, longer acid pools"},
	{"id": "graviton", "name": "GRAVITON CORE", "role": "GRAVITY", "price": 900, "kind": "graviton",
		"color": "c46bff", "dmg": 0.6, "rate": 1.05, "speed": 85.0, "range": "Medium", "dps": 3.0,
		"ability": "EVENT HORIZON", "desc": "A slow orb that drags aliens in, then collapses in an implosion.",
		"p": {"pull_r": 58.0, "boom_r": 40.0, "boom_dmg": 2.5, "fuse": 1.25}, "lv3": {"pull_r": 78.0, "boom_r": 52.0},
		"mod": "Huge pull and implosion"},
	{"id": "tesla", "name": "TESLA ARC", "role": "CHAIN STUN", "price": 1000, "kind": "tesla",
		"color": "6fd8ff", "dmg": 1.65, "rate": 0.5, "speed": 0.0, "range": "Medium", "dps": 3.0,
		"ability": "STORM CHAIN", "desc": "Instant lightning that chains through 4 aliens and stuns them.",
		"p": {"chains": 4, "chain_r": 78.0, "chain_k": 0.75, "stun": 0.35}, "lv3": {"chains": 7}, "mod": "Chains 7 aliens"},
	{"id": "rockets", "name": "ROCKET SWARM", "role": "HOMING", "price": 1100, "kind": "rockets",
		"color": "ff7a2a", "dmg": 0.5, "rate": 0.8, "speed": 165.0, "range": "Long", "dps": 3.2,
		"ability": "SEEKER VOLLEY", "desc": "A volley of homing micro-rockets that explode on impact.",
		"p": {"rockets": 3, "boom_r": 26.0, "boom_k": 0.6}, "lv3": {"rockets": 5}, "mod": "5 rockets per volley"},
	{"id": "solar", "name": "SOLAR LANCE", "role": "SNIPER", "price": 1200, "kind": "solar",
		"color": "ffc23a", "dmg": 2.2, "rate": 0.95, "speed": 0.0, "range": "Long", "dps": 3.4,
		"ability": "SUNBURN", "desc": "A charged laser that pierces everything, scorches the floor and makes aliens it kills burst into flame.",
		"p": {"len": 240.0, "width": 9.0, "burn_dps": 0.5, "burn_t": 2.0, "charge": 0.28,
			"scorch_t": 1.6, "scorch_dps": 0.8, "flare_r": 26.0, "flare_k": 0.9},
		"lv3": {"width": 13.0, "scorch_t": 2.8, "flare_r": 34.0}, "mod": "Wider beam, bigger flares"},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for g: Dictionary in GUNS:
		out.append(str(g.id))
	return out


static func index(id: String) -> int:
	for i in GUNS.size():
		if GUNS[i].id == id:
			return i
	return 0


static func gun(id: String) -> Dictionary:
	return GUNS[index(id)]


## The kind's parameters at `lv` (level 3 merges its "lv3" values).
static func params(id: String, lv: int) -> Dictionary:
	var g := gun(id)
	var p: Dictionary = (g.p as Dictionary).duplicate()
	if lv >= MAX_LEVEL:
		p.merge(g.lv3, true)
	return p


## Cryo Sprayer: seconds its ice spikes stay before shattering (longer each level).
static func ice_time(lv: int) -> float:
	return 2.0 + 1.5 * (clampi(lv, 1, MAX_LEVEL) - 1)


static func level_mult(lv: int) -> float:
	return 1.0 + LEVEL_DMG * (maxi(lv, 1) - 1)


static func icon(id: String) -> Texture2D:
	return load(DIR + "gun_%d.png" % (index(id) + 1))


static func color(id: String) -> Color:
	return Color(str(gun(id).color))


## Colour of the weapon's role tag (its own shot colour).
static func role_color(id: String) -> Color:
	return Color(str(gun(id).color)).lightened(0.15)


static func price(id: String) -> int:
	return int(gun(id).price)


## Coins to go from `lv` to lv + 1.
static func upgrade_cost(id: String, lv: int) -> int:
	var base := maxi(price(id), 250)
	return int(roundf(base * (0.4 if lv <= 1 else 0.8) / 50.0) * 50.0)


## Single-target damage per second, in units of the run's base damage.
static func dps(id: String, lv: int) -> float:
	return float(gun(id).dps) * level_mult(lv)


## The weapon's share of the crew POWER rating: the same for every weapon, by level.
static func power(_id: String, lv: int) -> int:
	return roundi(BASE_POWER * level_mult(lv))


static func rate_label(id: String) -> String:
	var r := float(gun(id).rate)
	if r < 0.3:
		return "Blazing"
	if r < 0.46:
		return "Very Fast"
	if r < 0.6:
		return "Fast"
	if r < 0.9:
		return "Medium"
	return "Slow"
