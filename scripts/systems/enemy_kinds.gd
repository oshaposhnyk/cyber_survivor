class_name EnemyKinds
extends RefCounted

# Swarm enemy definitions (were the drone/spider/... .tscn scenes).
# texture and sprite_scale drive the MultiMesh quad; hit_radius was the collision circle.
# z: draw layer of the kind (mechs sat above the rest of the swarm).

const KINDS := {
	"drone": {
		"script": preload("res://scenes/enemies/enemy_base.gd"),
		"texture": preload("res://assets/sprites/enemies/scout_drone.png"),
		"sprite_scale": 0.5, "hit_radius": 18.0, "z": 6,
		"max_health": 18.0, "move_speed": 175.0, "contact_damage": 8.0,
		"scrap_count": 1, "gold_chance": 0.05, "repair_chance": 0.02, "score_points": 10,
	},
	"spider": {
		"script": preload("res://scenes/enemies/spider_bot.gd"),
		"texture": preload("res://assets/sprites/enemies/spider_bot.png"),
		"sprite_scale": 0.55, "hit_radius": 22.0, "z": 6,
		"max_health": 38.0, "move_speed": 135.0, "contact_damage": 10.0,
		"scrap_count": 2, "gold_chance": 0.08, "repair_chance": 0.03, "score_points": 20,
	},
	"assault": {
		"script": preload("res://scenes/enemies/assault_droid.gd"),
		"texture": preload("res://assets/sprites/enemies/assault_droid.png"),
		"sprite_scale": 0.65, "hit_radius": 26.0, "z": 6,
		"max_health": 75.0, "move_speed": 105.0, "contact_damage": 14.0,
		"scrap_count": 3, "gold_chance": 0.15, "repair_chance": 0.06, "score_points": 40,
	},
	"kamikaze": {
		"script": preload("res://scenes/enemies/kamikaze.gd"),
		"texture": preload("res://assets/sprites/enemies/kamikaze_drone.png"),
		"sprite_scale": 0.55, "hit_radius": 22.0, "z": 6,
		"max_health": 25.0, "move_speed": 210.0, "contact_damage": 25.0,
		"scrap_count": 2, "gold_chance": 0.12, "repair_chance": 0.05, "score_points": 30,
	},
	"mech": {
		"script": preload("res://scenes/enemies/mech_walker.gd"),
		"texture": preload("res://assets/sprites/enemies/heavy_mech.png"),
		"sprite_scale": 1.15, "hit_radius": 44.0, "z": 7,
		"max_health": 500.0, "move_speed": 65.0, "contact_damage": 25.0,
		"scrap_count": 6, "gold_chance": 0.5, "repair_chance": 0.25, "score_points": 250,
	},
	"shield": {
		"script": preload("res://scenes/enemies/shield_bearer.gd"),
		"texture": preload("res://assets/sprites/enemies/shield_bearer.png"),
		"sprite_scale": 0.8, "hit_radius": 32.0, "z": 6,
		"max_health": 220.0, "move_speed": 72.0, "contact_damage": 16.0,
		"scrap_count": 4, "gold_chance": 0.3, "repair_chance": 0.08, "score_points": 80,
	},
}

# Stat keys copied onto a new unit
const STATS := ["max_health", "move_speed", "contact_damage", "scrap_count", "gold_chance", "repair_chance", "score_points", "hit_radius"]
