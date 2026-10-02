class_name EnemyData
extends RefCounted
## Alien definitions. Add a new alien by adding an entry here (and an `ai` branch
## in enemy.gd, or a custom `script` for bosses).

const TYPES := {
	# Available for future worlds; deliberately not assigned to existing waves.
	"orbit_warden": {
		"name": "ORBIT WARDEN", "hp": 2600.0, "speed": 28.0, "damage": 24.0, "coins": 120, "cost": 0,
		"radius": 21.0, "art": "orbit_warden", "scale": 0.38, "ai": "boss", "shoots": true,
		"color": Color("c8ff3a"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_orbit_warden.gd",
	},
	"orbit_raider": {
		"name": "Orbit Raider", "hp": 58.0, "speed": 24.0, "damage": 11.0, "coins": 5, "cost": 4,
		"radius": 11.0, "art": "orbit_warden", "scale": 0.19, "ai": "orbit", "shoots": true,
		"color": Color("c8ff3a"), "kb": 0.8,
		"script": "res://scripts/enemies/orbit_raider.gd",
	},
	"orbit_spawn": {
		"name": "Orbit Hatchling", "hp": 16.0, "speed": 35.0, "damage": 7.0, "coins": 1, "cost": 1,
		"radius": 6.0, "art": "orbit_spawn", "scale": 0.24, "ai": "chaser",
		"color": Color("c8ff3a"), "kb": 1.3,
	},
	"slime": {
		"name": "Slime", "hp": 30.0, "speed": 22.0, "damage": 10.0, "coins": 2, "cost": 1,
		"radius": 10.1, "art": "green", "scale": 0.34, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.0,
	},
	"runner": {
		"name": "Runner", "hp": 22.0, "speed": 28.0, "damage": 12.0, "coins": 2, "cost": 2,
		"radius": 9.1, "art": "pink", "scale": 0.335, "ai": "runner",
		"color": Color("f0447a"), "kb": 1.2,
	},
	"spitter": {
		"name": "Spitter", "hp": 26.0, "speed": 20.0, "damage": 10.0, "coins": 3, "cost": 2,
		"radius": 9.0, "art": "blue", "scale": 0.333, "ai": "spitter", "shoots": true,
		"color": Color("41a6f6"), "kb": 1.0,
	},
	"droid": {
		"name": "Droid", "hp": 28.0, "speed": 24.0, "damage": 10.0, "coins": 3, "cost": 2,
		"radius": 8.7, "art": "droid", "scale": 0.26, "ai": "droid", "shoots": true,
		"color": Color("73eff7"), "kb": 1.0,
	},
	"ufo": {
		"name": "UFO", "hp": 45.0, "speed": 26.0, "damage": 9.0, "coins": 5, "cost": 3,
		"radius": 10.9, "art": "ufo", "scale": 0.326, "ai": "ufo", "shoots": true,
		"color": Color("a7f070"), "kb": 0.7,
	},
	# dropped by the UFO through a portal (not in the random pools)
	"ufo_alien": {
		"name": "Greenie", "hp": 10.0, "speed": 38.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 6.5, "art": "ufo_alien", "scale": 0.286, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.4,
	},
	"octopus": {
		"name": "Octo", "hp": 34.0, "speed": 30.0, "damage": 9.0, "coins": 4, "cost": 3,
		"radius": 9.7, "art": "octopus", "scale": 0.278, "ai": "octopus", "shoots": true,
		"color": Color("41a6f6"), "kb": 1.0,
	},
	# floating one-eyed octopus: pulse nova, lunge, crawls when hurt (enemies/eyeclops.gd)
	"eyeclops": {
		"name": "Eyeclops", "hp": 42.0, "speed": 26.0, "damage": 10.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "eyeclops", "scale": 0.138, "ai": "eyeclops", "shoots": true,
		"color": Color("d43cff"), "kb": 0.9,
		"script": "res://scripts/enemies/eyeclops.gd",
	},
	# orange goo mass: flings slimelets, bursts into 3 when cleaned (enemies/splitter.gd)
	"splitter": {
		"name": "Slime Splitter", "hp": 60.0, "speed": 18.0, "damage": 12.0, "coins": 5, "cost": 4,
		"radius": 12.4, "art": "splitter", "scale": 0.248, "ai": "splitter",
		"color": Color("ff9f1c"), "kb": 0.6,
		"script": "res://scripts/enemies/splitter.gd",
	},
	# the splitter's offspring: a small one-eyed slime that just chases
	"splitlet": {
		"name": "Slimelet", "hp": 14.0, "speed": 34.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 5.0, "art": "splitlet", "scale": 0.2, "ai": "chaser",
		"color": Color("ff9f1c"), "kb": 1.4,
	},
	# creeping carnivorous plant: roots to spit globs or lash a pulling tongue (enemies/tentacle_plant.gd)
	"tentacle_plant": {
		"name": "Tentacle Plant", "hp": 55.0, "speed": 14.0, "damage": 12.0, "coins": 5, "cost": 4,
		"radius": 10.3, "art": "tentacle_plant", "scale": 0.217, "ai": "plant", "shoots": true,
		"color": Color("ff3c6e"), "kb": 0.5,
		"script": "res://scripts/enemies/tentacle_plant.gd",
	},
	# hooded octopus mage: homing orbs, ground runes, blinks away (enemies/octo_wizard.gd)
	"octo_wizard": {
		"name": "Octo-Wizard", "hp": 38.0, "speed": 24.0, "damage": 10.0, "coins": 5, "cost": 3,
		"radius": 9.2, "art": "octo_wizard", "scale": 0.184, "ai": "wizard", "shoots": true,
		"color": Color("9b3cff"), "kb": 1.0,
		"script": "res://scripts/enemies/octo_wizard.gd",
	},
	"mini_slime": {
		"name": "Slimelet", "hp": 12.0, "speed": 34.0, "damage": 6.0, "coins": 1, "cost": 1,
		"radius": 5.0, "art": "green", "scale": 0.16, "ai": "chaser",
		"color": Color("a7f070"), "kb": 1.4,
	},
	# tough one-eyed brute that never shoots: chases and lunges (enemies/big_red.gd)
	# world 4: big purple saucer, cannon bursts and rams (enemies/ufo_gunship.gd)
	"gunship": {
		"name": "UFO Gunship", "hp": 75.0, "speed": 20.0, "damage": 11.0, "coins": 6, "cost": 4,
		"radius": 13.0, "art": "gunship", "scale": 0.26, "ai": "gunship", "shoots": true,
		"color": Color("ff4fd8"), "kb": 0.5,
		"script": "res://scripts/enemies/ufo_gunship.gd",
	},
	# world 4: small quick pink saucer that circles you spitting comets (enemies/ufo_scout.gd)
	"scout": {
		"name": "UFO Scout", "hp": 24.0, "speed": 34.0, "damage": 9.0, "coins": 3, "cost": 2,
		"radius": 8.9, "art": "scout", "scale": 0.241, "ai": "scout", "shoots": true,
		"color": Color("ff5fa8"), "kb": 1.2,
		"script": "res://scripts/enemies/ufo_scout.gd",
	},
	# world 4: jellyfish saucer, leaves floating spore mines and stings up close (enemies/jelly_pod.gd)
	"jelly_pod": {
		"name": "Jelly Pod", "hp": 48.0, "speed": 18.0, "damage": 10.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "jelly_pod", "scale": 0.231, "ai": "jelly", "shoots": true,
		"color": Color("ff3cf0"), "kb": 0.8,
		"script": "res://scripts/enemies/jelly_pod.gd",
	},
	# world 4: floating spiked mine, spits fireballs, arms and blows up next to you (enemies/spike_mine.gd)
	"spike_mine": {
		"name": "Spike Mine", "hp": 36.0, "speed": 22.0, "damage": 12.0, "coins": 4, "cost": 3,
		"radius": 11.1, "art": "spike_mine", "scale": 0.233, "ai": "mine", "shoots": true,
		"color": Color("ff7a2a"), "kb": 0.9,
		"script": "res://scripts/enemies/spike_mine.gd",
	},
	# world 4 (tools/enemies_w4_ref.webp): bunny in a comet pod, hops at you and flings comets (enemies/comet_hopper.gd)
	"comet_hopper": {
		"name": "Comet Hopper", "hp": 32.0, "speed": 30.0, "damage": 11.0, "coins": 3, "cost": 2,
		"radius": 9.9, "art": "comet_hopper", "scale": 0.267, "ai": "hopper",
		"color": Color("ff8a2a"), "kb": 1.0,
		"script": "res://scripts/enemies/comet_hopper.gd",
	},
	# ringed bug, throws its ring like a boomerang (enemies/ring_bug.gd)
	"ring_bug": {
		"name": "Saturn Ring Bug", "hp": 40.0, "speed": 26.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 10.4, "art": "ring_bug", "scale": 0.277, "ai": "ring_bug", "shoots": true,
		"color": Color("ffb030"), "kb": 0.9,
		"script": "res://scripts/enemies/ring_bug.gd",
	},
	# spiked drill pod: circles, fires drill blasts or drills in (enemies/drill_orbiter.gd)
	"drill_orbiter": {
		"name": "Drill Orbiter", "hp": 44.0, "speed": 30.0, "damage": 12.0, "coins": 4, "cost": 3,
		"radius": 11.7, "art": "drill_orbiter", "scale": 0.318, "ai": "drill", "shoots": true,
		"color": Color("5fb8ff"), "kb": 0.8,
		"script": "res://scripts/enemies/drill_orbiter.gd",
	},
	# pink puffer saucer: star-bubble novas, bursts into bubbles (enemies/nova_puffer.gd)
	"nova_puffer": {
		"name": "Nova Puffer", "hp": 52.0, "speed": 18.0, "damage": 10.0, "coins": 5, "cost": 3,
		"radius": 11.8, "art": "nova_puffer", "scale": 0.284, "ai": "nova", "shoots": true,
		"color": Color("ff4fd8"), "kb": 0.8,
		"script": "res://scripts/enemies/nova_puffer.gd",
	},
	# world 4 drones (tools/drones_w4_ref.webp): spinning blades, crescents that curve in (enemies/blade_drone.gd)
	"blade_drone": {
		"name": "Cyclone Drone", "hp": 34.0, "speed": 34.0, "damage": 11.0, "coins": 3, "cost": 2,
		"radius": 11.1, "art": "blade_drone", "scale": 0.31, "ai": "blade", "shoots": true,
		"color": Color("ffb030"), "kb": 1.0,
		"script": "res://scripts/enemies/blade_drone.gd",
	},
	# tesla orbs; two close together are joined by a lightning arc (enemies/tesla_drone.gd)
	"tesla_drone": {
		"name": "Tesla Drone", "hp": 38.0, "speed": 24.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 11.1, "art": "tesla_drone", "scale": 0.3, "ai": "tesla", "shoots": true,
		"color": Color("5fb8ff"), "kb": 0.9,
		"script": "res://scripts/enemies/tesla_drone.gd",
	},
	# crab-legged cargo bot, salvos of homing rockets (enemies/crab_drone.gd)
	"crab_drone": {
		"name": "Cargo Crab", "hp": 70.0, "speed": 22.0, "damage": 12.0, "coins": 5, "cost": 4,
		"radius": 13.0, "art": "crab_drone", "scale": 0.353, "ai": "crab", "shoots": true,
		"color": Color("ff9a3a"), "kb": 0.5,
		"script": "res://scripts/enemies/crab_drone.gd",
	},
	# crystal satellite, locks on and fires a straight prism beam (enemies/prism_drone.gd)
	"prism_drone": {
		"name": "Prism Satellite", "hp": 40.0, "speed": 22.0, "damage": 11.0, "coins": 5, "cost": 3,
		"radius": 11.7, "art": "prism_drone", "scale": 0.311, "ai": "prism", "shoots": true,
		"color": Color("ff4fd8"), "kb": 0.8,
		"script": "res://scripts/enemies/prism_drone.gd",
	},
	# world 4, second sheet (tools/enemies_w4b_ref.webp): rock saucer, lobs meteors that burst into rocks (enemies/meteor_peeper.gd)
	"meteor_peeper": {
		"name": "Meteor Peeper", "hp": 46.0, "speed": 22.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 10.0, "art": "meteor_peeper", "scale": 0.26, "ai": "peeper", "shoots": true,
		"color": Color("ff8a2a"), "kb": 0.8,
		"script": "res://scripts/enemies/meteor_peeper.gd",
	},
	# brain in a dome, keeps away and puffs homing bubbles (enemies/bubble_brain.gd)
	"bubble_brain": {
		"name": "Bubble Brain", "hp": 34.0, "speed": 26.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 9.0, "art": "bubble_brain", "scale": 0.25, "ai": "brain", "shoots": true,
		"color": Color("5fd0ff"), "kb": 1.0,
		"script": "res://scripts/enemies/bubble_brain.gd",
	},
	# one-eyed jellyfish bell, pulses after you and fires bubble chains (enemies/bell_cruiser.gd)
	"bell_cruiser": {
		"name": "Tentacle Bell", "hp": 50.0, "speed": 22.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 10.0, "art": "bell_cruiser", "scale": 0.23, "ai": "bell", "shoots": true,
		"color": Color("ff5fe0"), "kb": 0.8,
		"script": "res://scripts/enemies/bell_cruiser.gd",
	},
	# hopping seed pod, lobs acid goo that leaves puddles (enemies/goo_hopper.gd)
	"goo_hopper": {
		"name": "Goo Seed Hopper", "hp": 40.0, "speed": 28.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 10.0, "art": "goo_hopper", "scale": 0.21, "ai": "goo_hop",
		"color": Color("a7f070"), "kb": 0.9,
		"script": "res://scripts/enemies/goo_hopper.gd",
	},
	# world 4, third sheet (tools/enemies_w4c_ref.webp): zips sideways, triple bursts (enemies/nebula_pod.gd)
	"nebula_pod": {
		"name": "Nebula Pod", "hp": 36.0, "speed": 26.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 9.5, "art": "nebula_pod", "scale": 0.27, "ai": "nebula_pod", "shoots": true,
		"color": Color("b05cff"), "kb": 1.0,
		"script": "res://scripts/enemies/nebula_pod.gd",
	},
	# sniper: tracking line, then one very fast orb (enemies/ring_eye.gd)
	"ring_eye": {
		"name": "Ring-Eye Shuttle", "hp": 34.0, "speed": 26.0, "damage": 12.0, "coins": 4, "cost": 3,
		"radius": 9.5, "art": "ring_eye", "scale": 0.27, "ai": "sniper", "shoots": true,
		"color": Color("5fd0ff"), "kb": 1.0,
		"script": "res://scripts/enemies/ring_eye.gd",
	},
	# spotter: radar pings that call bubble strikes on you (enemies/puddle_radar.gd)
	"puddle_radar": {
		"name": "Puddle Radar", "hp": 44.0, "speed": 18.0, "damage": 11.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "puddle_radar", "scale": 0.25, "ai": "radar", "shoots": true,
		"color": Color("ff5fe0"), "kb": 0.8,
		"script": "res://scripts/enemies/puddle_radar.gd",
	},
	# fast little goo pod: rushes, spits, leaves an acid puddle when it dies (enemies/comet_baby.gd)
	"comet_baby": {
		"name": "Comet Baby", "hp": 20.0, "speed": 38.0, "damage": 10.0, "coins": 2, "cost": 2,
		"radius": 9.0, "art": "comet_baby", "scale": 0.23, "ai": "baby",
		"color": Color("a7f070"), "kb": 1.3,
		"script": "res://scripts/enemies/comet_baby.gd",
	},
	# world 4, fourth sheet (tools/enemies_w4d_ref.webp): bubbles orbiting it, flung all at once (enemies/tadpole_saucer.gd)
	"tadpole_saucer": {
		"name": "Orbit Tadpole", "hp": 42.0, "speed": 24.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 9.5, "art": "tadpole_saucer", "scale": 0.26, "ai": "tadpole", "shoots": true,
		"color": Color("5fe6ff"), "kb": 0.9,
		"script": "res://scripts/enemies/tadpole_saucer.gd",
	},
	# reads your path and hops into it, plasma fan (enemies/plasma_pupil.gd)
	"plasma_pupil": {
		"name": "Plasma Pupil", "hp": 38.0, "speed": 26.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 9.5, "art": "plasma_pupil", "scale": 0.25, "ai": "pupil", "shoots": true,
		"color": Color("ff4fd8"), "kb": 1.0,
		"script": "res://scripts/enemies/plasma_pupil.gd",
	},
	# hides behind aliens, big homing bubble that bursts into 8 (enemies/tentacle_pod.gd)
	"tentacle_pod": {
		"name": "Bubble Tentacle Pod", "hp": 46.0, "speed": 22.0, "damage": 11.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "tentacle_pod", "scale": 0.23, "ai": "tentacle_pod", "shoots": true,
		"color": Color("7fc8ff"), "kb": 0.8,
		"script": "res://scripts/enemies/tentacle_pod.gd",
	},
	# clam that shuts when focused and answers with a pearl fan (enemies/pearl_flyer.gd)
	"pearl_flyer": {
		"name": "Slime Pearl Flyer", "hp": 60.0, "speed": 22.0, "damage": 11.0, "coins": 5, "cost": 4,
		"radius": 10.5, "art": "pearl_flyer", "scale": 0.24, "ai": "pearl", "shoots": true,
		"color": Color("c8ff3a"), "kb": 0.7,
		"script": "res://scripts/enemies/pearl_flyer.gd",
	},
	# world 4, fifth sheet (tools/enemies_w4e_ref.webp): flies in formation, squad volleys (enemies/martian_scout.gd)
	"martian_scout": {
		"name": "Martian Scout", "hp": 30.0, "speed": 30.0, "damage": 10.0, "coins": 3, "cost": 2,
		"radius": 9.0, "art": "martian_scout", "scale": 0.28, "ai": "formation", "shoots": true,
		"color": Color("ff4fb8"), "kb": 1.0,
		"script": "res://scripts/enemies/martian_scout.gd",
	},
	# tethered orb joined by a sweeping ray (enemies/cyclops_pod.gd)
	"cyclops_pod": {
		"name": "Cyclops Ray Pod", "hp": 42.0, "speed": 26.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 9.5, "art": "cyclops_pod", "scale": 0.26, "ai": "tether", "shoots": true,
		"color": Color("5fd8ff"), "kb": 0.9,
		"script": "res://scripts/enemies/cyclops_pod.gd",
	},
	# gravity orb that pulls you in, then bursts (enemies/tentacle_orbiter.gd)
	"tentacle_orbiter": {
		"name": "Tentacle Orbiter", "hp": 46.0, "speed": 22.0, "damage": 11.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "tentacle_orbiter", "scale": 0.26, "ai": "gravity", "shoots": true,
		"color": Color("c060ff"), "kb": 0.8,
		"script": "res://scripts/enemies/tentacle_orbiter.gd",
	},
	# strafing runs leaving acid slime trails (enemies/slime_comet.gd)
	"slime_comet": {
		"name": "Slime Comet Ship", "hp": 40.0, "speed": 32.0, "damage": 11.0, "coins": 4, "cost": 3,
		"radius": 10.0, "art": "slime_comet", "scale": 0.3, "ai": "strafe", "shoots": true,
		"color": Color("a7f070"), "kb": 0.9,
		"script": "res://scripts/enemies/slime_comet.gd",
	},
	# world 4, sixth sheet (tools/enemies_w4f_ref.webp): dodges your bullets (enemies/blink_saucer.gd)
	"blink_saucer": {
		"name": "Astro Blink", "hp": 32.0, "speed": 30.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 9.0, "art": "blink_saucer", "scale": 0.245, "ai": "dodger", "shoots": true,
		"color": Color("ff6fc8"), "kb": 1.0,
		"script": "res://scripts/enemies/blink_saucer.gd",
	},
	# lobs sticky goo across your path that slows you (enemies/bean_cruiser.gd)
	"bean_cruiser": {
		"name": "Bean Cruiser", "hp": 44.0, "speed": 24.0, "damage": 10.0, "coins": 4, "cost": 3,
		"radius": 10.0, "art": "bean_cruiser", "scale": 0.225, "ai": "goo_trap", "shoots": true,
		"color": Color("a7f070"), "kb": 0.8,
		"script": "res://scripts/enemies/bean_cruiser.gd",
	},
	# charges a heavy shot that you can interrupt (enemies/nugget_ship.gd)
	"nugget_ship": {
		"name": "Ray-Eye Nugget", "hp": 48.0, "speed": 22.0, "damage": 12.0, "coins": 5, "cost": 3,
		"radius": 10.0, "art": "nugget_ship", "scale": 0.245, "ai": "charger", "shoots": true,
		"color": Color("5fd0ff"), "kb": 0.8,
		"script": "res://scripts/enemies/nugget_ship.gd",
	},
	# healer: hides behind aliens and heals them (enemies/goo_lantern.gd)
	"goo_lantern": {
		"name": "Goo Lantern", "hp": 40.0, "speed": 24.0, "damage": 9.0, "coins": 6, "cost": 4,
		"radius": 10.0, "art": "goo_lantern", "scale": 0.215, "ai": "healer", "shoots": true,
		"color": Color("c060ff"), "kb": 0.9,
		"script": "res://scripts/enemies/goo_lantern.gd",
	},
	"big_red": {
		"name": "Big Red", "hp": 85.0, "speed": 17.0, "damage": 14.0, "coins": 5, "cost": 4,
		"radius": 12.6, "art": "big_red", "scale": 0.151, "ai": "chaser",
		"color": Color("ff4f9a"), "kb": 0.5,
		"script": "res://scripts/enemies/big_red.gd",
	},
	"gloop_brute": {
		"name": "GLOOP BRUTE", "hp": 560.0, "speed": 34.0, "damage": 20.0, "coins": 25, "cost": 0,
		"radius": 17.0, "art": "pink", "scale": 0.58, "ai": "boss",
		"color": Color("c75bd6"), "kb": 0.12, "boss": true, "tint": Color(0.9, 0.62, 1.3), "power_core": true,
		"script": "res://scripts/enemies/boss_brute.gd",
	},
	"slime_king": {
		"name": "THE SLIME KING", "hp": 1000.0, "speed": 48.0, "damage": 22.0, "coins": 60, "cost": 0,
		"radius": 21.0, "art": "green", "scale": 0.72, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.05, "boss": true,
		"script": "res://scripts/enemies/boss_king.gd",
	},
	# world 1 final boss: fought inside the electric fence (enemies/boss_big_red.gd)
	"big_red_boss": {
		"name": "BIG RED", "hp": 1500.0, "speed": 30.0, "damage": 22.0, "coins": 80, "cost": 0,
		"radius": 22.0, "art": "big_red", "scale": 0.3, "ai": "boss",
		"color": Color("ff4f9a"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_big_red.gd",
	},
	# world 2 final boss: fought inside the electric fence (enemies/boss_hive_queen.gd)
	"hive_queen": {
		"name": "HIVE QUEEN", "hp": 2200.0, "speed": 30.0, "damage": 22.0, "coins": 100, "cost": 0,
		"radius": 24.0, "art": "hive_queen", "scale": 0.36, "ai": "boss",
		"color": Color("c8ff3a"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_hive_queen.gd",
	},
	# the queen's goo egg: hatches greenies unless broken in time (enemies/hive_egg.gd)
	"hive_egg": {
		"name": "Hive Egg", "hp": 45.0, "speed": 0.0, "damage": 0.0, "coins": 1, "cost": 1,
		"radius": 9.0, "art": "hive_egg", "scale": 0.16, "ai": "egg",
		"color": Color("c8ff3a"), "kb": 0.0,
		"script": "res://scripts/enemies/hive_egg.gd",
	},
	# crystal guard that shields the queen while it stands (enemies/hive_guard.gd)
	"hive_guard": {
		"name": "Crystal Guard", "hp": 320.0, "speed": 0.0, "damage": 14.0, "coins": 3, "cost": 3,
		"radius": 11.7, "art": "hive_guard", "scale": 0.213, "ai": "guard", "shoots": true,
		"color": Color("b35cff"), "kb": 0.0,
		"script": "res://scripts/enemies/hive_guard.gd",
	},
	# world 2 mini boss (room 20): giant hive octopus
	"brood_mother": {
		"name": "BROOD MOTHER", "hp": 1400.0, "speed": 30.0, "damage": 20.0, "coins": 40, "cost": 0,
		"radius": 17.0, "art": "octopus", "scale": 0.6, "ai": "boss",
		"color": Color("c75bd6"), "kb": 0.1, "boss": true, "tint": Color(1.25, 0.6, 1.25), "power_core": true,
		"script": "res://scripts/enemies/boss_brood.gd",
	},
	# world 3 final boss: fought inside the electric fence (enemies/boss_archmage.gd)
	"archmage": {
		"name": "VOID ARCHMAGE", "hp": 2800.0, "speed": 32.0, "damage": 24.0, "coins": 120, "cost": 0,
		"radius": 20.0, "art": "archmage", "scale": 0.27, "ai": "boss",
		"color": Color("d43cff"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_archmage.gd",
	},
	# world 4 final boss: a cyan alien in a big saucer (enemies/boss_zorp.gd)
	"zorp": {
		"name": "COMMANDER ZORP", "hp": 3200.0, "speed": 34.0, "damage": 26.0, "coins": 140, "cost": 0,
		"radius": 20.0, "art": "zorp", "scale": 0.3, "ai": "boss",
		"color": Color("5fe6ff"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_zorp.gd",
	},
	# drone Zorp launches: circles you, dashes and bursts (enemies/zorp_drone.gd)
	"zorp_drone": {
		"name": "Zorp Drone", "hp": 16.0, "speed": 46.0, "damage": 12.0, "coins": 1, "cost": 2,
		"radius": 6.0, "art": "zorp_drone", "scale": 0.34, "ai": "drone",
		"color": Color("5fe6ff"), "kb": 1.2,
		"script": "res://scripts/enemies/zorp_drone.gd",
	},
	# world 4 mini boss (wave 11): little lava dragon (enemies/boss_magma.gd)
	"magma_drake": {
		"name": "MAGMA DRAKE", "hp": 1600.0, "speed": 32.0, "damage": 22.0, "coins": 80, "cost": 0,
		"radius": 16.0, "art": "magma_drake", "scale": 0.4, "ai": "boss",
		"color": Color("ff8a2a"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_magma.gd",
	},
	# world 3 mini boss (wave 8): toxic lantern pufferfish (enemies/boss_angler.gd)
	"toxic_angler": {
		"name": "TOXIC ANGLER", "hp": 1500.0, "speed": 34.0, "damage": 22.0, "coins": 80, "cost": 0,
		"radius": 16.0, "art": "toxic_angler", "scale": 0.36, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_angler.gd",
	},
	# world 2 mini boss (wave 9): drill-nosed rock armadillo (enemies/boss_drillback.gd)
	"drillback": {
		"name": "DRILLBACK", "hp": 1500.0, "speed": 38.0, "damage": 22.0, "coins": 80, "cost": 0,
		"radius": 17.0, "art": "drillback", "scale": 0.36, "ai": "boss",
		"color": Color("d98a3c"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_drillback.gd",
	},
	# world 1 mini boss (wave 8): one-eyed slime king (enemies/boss_blobulus.gd)
	"blobulus": {
		"name": "BLOBULUS", "hp": 1500.0, "speed": 32.0, "damage": 22.0, "coins": 80, "cost": 0,
		"radius": 17.0, "art": "blobulus", "scale": 0.33, "ai": "boss",
		"color": Color("5fd0ff"), "kb": 0.0, "boss": true,
		"script": "res://scripts/enemies/boss_blobulus.gd",
	},
	# the little floating eyes BLOBULUS splits into (enemies/blobling.gd)
	"blobling": {
		"name": "Blobling", "hp": 22.0, "speed": 56.0, "damage": 12.0, "coins": 1, "cost": 2,
		"radius": 8.0, "art": "blobling", "scale": 0.43, "ai": "blobling",
		"color": Color("5fd0ff"), "kb": 1.0,
		"script": "res://scripts/enemies/blobling.gd",
	},
	# eye the Archmage summons: floats to you and bursts (enemies/arcane_eye.gd)
	"arcane_eye": {
		"name": "Arcane Eye", "hp": 18.0, "speed": 42.0, "damage": 14.0, "coins": 1, "cost": 2,
		"radius": 6.0, "art": "arcane_eye", "scale": 0.17, "ai": "eye",
		"color": Color("d43cff"), "kb": 1.2,
		"script": "res://scripts/enemies/arcane_eye.gd",
	},
	# world 2 final boss (room 30): the alien mothership
	"mothership": {
		"name": "THE MOTHERSHIP", "hp": 2400.0, "speed": 34.0, "damage": 22.0, "coins": 100, "cost": 0,
		"radius": 20.0, "art": "ufo", "scale": 0.62, "ai": "boss",
		"color": Color("a7f070"), "kb": 0.0, "boss": true, "tint": Color(1.15, 0.85, 0.85),
		"script": "res://scripts/enemies/boss_mothership.gd",
	},
}


static func create(id: String) -> Enemy:
	var def: Dictionary = TYPES[id]
	var e: Enemy
	if def.has("script"):
		var scr: GDScript = load(def.script)
		e = scr.new() as Enemy
	else:
		e = Enemy.new()
	e.setup(id)
	return e
