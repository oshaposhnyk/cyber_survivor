extends Node

# Wave Director - controls escalating swarms, enemy types, mini-bosses

signal wave_announced(wave_name, description)

var main_scene: Node2D = null
var spawn_timer: float = 0.0
var current_wave_idx: int = 1
var elapsed: float = 0.0

# Special ambush wave timer
var ambush_timer: float = 45.0
var mech_boss_timer: float = 40.0
var boss_spawned: bool = false

# Timers for Champions, Space Hazards, and Data Caches
var champion_timer: float = 32.0
var hazard_timer: float = 12.0
var data_cache_timer: float = 48.0

# Hard cap on live enemies (performance, especially in the web build)
const MAX_CONCURRENT_ENEMIES: int = 1100
# Spawn ring just outside the visible area (viewport 1280x720 at camera zoom 0.72)
const SPAWN_DIST_MIN: float = 1050.0
const SPAWN_DIST_MAX: float = 1200.0
const BOSS_TIME: float = 150.0

# Vampire-Survivors-style pacing: the director keeps at least `min_alive` enemies
# on the field and tops up when below it. Values are interpolated between keys,
# so pressure grows smoothly instead of in jumps.
const PACING = [
	{"t": 0.0,   "min_alive": 15,   "interval": 0.9},
	{"t": 30.0,  "min_alive": 40,   "interval": 0.75},
	{"t": 60.0,  "min_alive": 70,   "interval": 0.6},
	{"t": 120.0, "min_alive": 130,  "interval": 0.5},
	{"t": 180.0, "min_alive": 200,  "interval": 0.42},
	{"t": 240.0, "min_alive": 300,  "interval": 0.35},
	# Final stretch: hordes, like the last minutes of a Vampire Survivors stage
	{"t": 300.0, "min_alive": 450,  "interval": 0.28},
	{"t": 360.0, "min_alive": 700,  "interval": 0.2},
	{"t": 400.0, "min_alive": 950,  "interval": 0.15},
	{"t": 420.0, "min_alive": 1100, "interval": 0.12},
]

const WAVES = [
	{
		"index": 1,
		"name": "Сектор 1: Розвідка",
		"desc": "Поодинокі дрони-розвідники. Збирайте брухт і прокачуйте корабель.",
		"start_time": 0.0,
		"types": ["drone"],
		"weights": [1.0]
	},
	{
		"index": 2,
		"name": "Сектор 2: Павутинний Прорив",
		"desc": "Швидкі боти-павуки заходять з флангів.",
		"start_time": 45.0,
		"types": ["drone", "spider"],
		"weights": [0.65, 0.35]
	},
	{
		"index": 3,
		"name": "Сектор 3: Штурмовий Натиск",
		"desc": "Штурмові дроїди ведуть лазерний вогонь. Щитоносці прикривають рій куполом.",
		"start_time": 120.0,
		"types": ["drone", "spider", "assault", "kamikaze", "shield"],
		"weights": [0.38, 0.34, 0.13, 0.11, 0.04]
	},
	{
		"index": 4,
		"name": "Сектор 4: Меха-Титани",
		"desc": "Важкі бойові мехи на підході.",
		"start_time": 210.0,
		"types": ["drone", "spider", "assault", "kamikaze", "shield"],
		"weights": [0.28, 0.29, 0.19, 0.19, 0.05]
	},
	{
		"index": 5,
		"name": "Сектор 5: Нульовий Протокол",
		"desc": "Максимальна загроза. Протримайтеся до евакуації.",
		"start_time": 300.0,
		"types": ["drone", "spider", "assault", "kamikaze", "shield", "mech"],
		"weights": [0.31, 0.29, 0.17, 0.16, 0.04, 0.03]
	}
]

var enemy_scenes = {
	"drone": preload("res://scenes/enemies/drone.tscn"),
	"spider": preload("res://scenes/enemies/spider_bot.tscn"),
	"assault": preload("res://scenes/enemies/assault_droid.tscn"),
	"kamikaze": preload("res://scenes/enemies/kamikaze.tscn"),
	"mech": preload("res://scenes/enemies/mech_walker.tscn"),
	"shield": preload("res://scenes/enemies/shield_bearer.tscn")
}

func setup(p_main: Node2D) -> void:
	main_scene = p_main

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
		
	elapsed = GameManager.time_survived
	check_wave_progression()
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var pace = get_pacing()
		spawn_timer = pace["interval"]
		spawn_enemy_wave(get_current_wave_config(), int(pace["min_alive"]))
		
	# Dreadnought Titan Boss event
	if elapsed >= BOSS_TIME and not boss_spawned:
		boss_spawned = true
		spawn_dreadnought_boss()
		
	# Periodic Ambush Circle Swarms
	ambush_timer -= delta
	if ambush_timer <= 0.0:
		ambush_timer = randf_range(40.0, 50.0) if elapsed < 300.0 else randf_range(18.0, 24.0)
		trigger_ambush_ring()
		
	# Periodic Mech Titans in late sectors
	if current_wave_idx >= 4:
		mech_boss_timer -= delta
		if mech_boss_timer <= 0.0:
			mech_boss_timer = 35.0 if elapsed < 330.0 else 14.0
			spawn_specific_enemy("mech", 1)

	# Elite Champions timer
	champion_timer -= delta
	if champion_timer <= 0.0:
		champion_timer = randf_range(34.0, 48.0)
		spawn_champion()

	# Arena Space Hazards (Volatile Reactors)
	hazard_timer -= delta
	if hazard_timer <= 0.0:
		hazard_timer = 18.0
		maintain_hazards()

	# Dynamic In-Run Event: Data Cache Drop Pod
	data_cache_timer -= delta
	if data_cache_timer <= 0.0:
		data_cache_timer = randf_range(65.0, 85.0)
		spawn_data_cache()

func get_pacing() -> Dictionary:
	var prev = PACING[0]
	for key in PACING:
		if elapsed < key["t"]:
			var k = (elapsed - prev["t"]) / max(key["t"] - prev["t"], 0.001)
			return {"min_alive": lerpf(prev["min_alive"], key["min_alive"], k), "interval": lerpf(prev["interval"], key["interval"], k)}
		prev = key
	return prev

# Enemy toughness grows with time so the swarm keeps pace with the player's upgrades
func get_hp_mult() -> float:
	var late = max(0.0, elapsed - 240.0) / 60.0
	return 1.0 + elapsed / 60.0 * 0.35 + min(late * late * 0.7, 3.5)

func get_current_wave_config() -> Dictionary:
	var active_cfg = WAVES[0]
	for cfg in WAVES:
		if elapsed >= cfg["start_time"]:
			active_cfg = cfg
	return active_cfg

func check_wave_progression() -> void:
	var cfg = get_current_wave_config()
	if cfg["index"] != current_wave_idx:
		current_wave_idx = cfg["index"]
		GameManager.current_wave = current_wave_idx
		GameManager.wave_changed.emit(current_wave_idx, cfg["name"])
		wave_announced.emit(cfg["name"], cfg["desc"])
		
		# Boss spawn at start of Sector 4 & 5
		if current_wave_idx >= 4:
			spawn_specific_enemy("mech", 1 if current_wave_idx == 4 else 2)
			
	# Victory condition check at 7 minutes (420s)
	if elapsed >= 420.0 and GameManager.current_state == GameManager.State.PLAYING:
		GameManager.trigger_game_over(true)

func spawn_enemy_wave(cfg: Dictionary, min_alive: int) -> void:
	if not is_instance_valid(GameManager.player_node):
		return
		
	var active_count = EnemyRegistry.count()
	if active_count >= MAX_CONCURRENT_ENEMIES:
		return
	
	# Below the target: top up quickly (capped per tick). At or above: steady trickle.
	var deficit = min_alive - active_count
	var batch_count = clampi(deficit, 0, 8 + current_wave_idx * 8) if deficit > 0 else 1 + int(elapsed / 120.0)
	batch_count = min(batch_count, MAX_CONCURRENT_ENEMIES - active_count)
	var types: Array = cfg["types"]
	var weights: Array = cfg["weights"]
	var player_pos = GameManager.player_node.global_position
	
	for i in range(batch_count):
		# Pick type
		var roll = randf()
		var accum = 0.0
		var chosen_type = types[0]
		for w_idx in range(types.size()):
			accum += weights[w_idx]
			if roll <= accum:
				chosen_type = types[w_idx]
				break
		
		# Spread around the whole screen edge, like Vampire Survivors
		var angle = randf() * TAU
		spawn_at(chosen_type, player_pos + Vector2(cos(angle), sin(angle)) * randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX))

func spawn_at(type_key: String, pos: Vector2) -> void:
	var enemy = enemy_scenes[type_key].instantiate()
	enemy.global_position = pos
	enemy.max_health *= get_hp_mult()
	enemy.contact_damage *= 1.0 + elapsed / 60.0 * 0.12
	main_scene.add_child(enemy)

func trigger_ambush_ring() -> void:
	if not is_instance_valid(GameManager.player_node):
		return
	var player_pos = GameManager.player_node.global_position
	var ring_count = min(24 + current_wave_idx * 14 + int(max(0.0, elapsed - 240.0) * 0.8), MAX_CONCURRENT_ENEMIES - EnemyRegistry.count())
	var enemy_type = "drone" if current_wave_idx <= 2 else ("kamikaze" if randf() < 0.35 else "spider")
	
	for i in range(ring_count):
		var ang = (TAU / ring_count) * i
		spawn_at(enemy_type, player_pos + Vector2(cos(ang), sin(ang)) * randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX))

func spawn_specific_enemy(type_key: String, count: int = 1) -> void:
	if not enemy_scenes.has(type_key) or not is_instance_valid(GameManager.player_node):
		return
		
	var player_pos = GameManager.player_node.global_position
	for i in range(count):
		var angle = randf() * TAU
		spawn_at(type_key, player_pos + Vector2(cos(angle), sin(angle)) * randf_range(SPAWN_DIST_MIN, SPAWN_DIST_MAX))

func spawn_dreadnought_boss() -> void:
	if not is_instance_valid(GameManager.player_node) or not is_instance_valid(main_scene):
		return
		
	var boss_scene = preload("res://scenes/enemies/boss_titan.tscn")
	var boss = boss_scene.instantiate()
	var spawn_ang = randf() * TAU
	boss.global_position = GameManager.player_node.global_position + Vector2(cos(spawn_ang), sin(spawn_ang)) * 620.0
	main_scene.call_deferred("add_child", boss)
	
	AudioManager.play_sfx("emp_blast", 0.05, 3.0)
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_announcement"):
		hud.show_announcement("ЧЕРВОНИЙ РІВЕНЬ ЗАГРОЗИ", "Виявлено дредноут «LEVIATHAN-01»")

func spawn_champion() -> void:
	if not is_instance_valid(GameManager.player_node) or not is_instance_valid(main_scene):
		return
	var candidates = ["assault", "spider", "mech", "shield"]
	var t = candidates.pick_random()
	var ang = randf() * TAU
	var pos = GameManager.player_node.global_position + Vector2(cos(ang), sin(ang)) * randf_range(700.0, 950.0)
	var enemy = enemy_scenes[t].instantiate()
	enemy.global_position = pos
	enemy.max_health *= get_hp_mult()
	enemy.contact_damage *= 1.0 + elapsed / 60.0 * 0.12
	main_scene.add_child(enemy)
	if enemy.has_method("make_champion"):
		enemy.make_champion()
		
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_announcement"):
		hud.show_announcement("ЕЛІТНИЙ ЧЕМПІОН", "Знищіть чемпіона для отримання граві-магніту!")

func maintain_hazards() -> void:
	if not is_instance_valid(GameManager.player_node) or not is_instance_valid(main_scene):
		return
	var hazards = get_tree().get_nodes_in_group("hazards")
	if hazards.size() >= 4:
		return
	var reactor_scene = preload("res://scenes/objects/volatile_reactor.tscn")
	var r = reactor_scene.instantiate()
	var ang = randf() * TAU
	r.global_position = GameManager.player_node.global_position + Vector2(cos(ang), sin(ang)) * randf_range(500.0, 800.0)
	main_scene.call_deferred("add_child", r)

func spawn_data_cache() -> void:
	if not is_instance_valid(GameManager.player_node) or not is_instance_valid(main_scene):
		return
	var caches = get_tree().get_nodes_in_group("data_caches")
	if caches.size() >= 1:
		return
	var cache_scene = preload("res://scenes/objects/data_cache.tscn")
	var cache = cache_scene.instantiate()
	var ang = randf() * TAU
	cache.global_position = GameManager.player_node.global_position + Vector2(cos(ang), sin(ang)) * randf_range(600.0, 850.0)
	main_scene.call_deferred("add_child", cache)
	
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_announcement"):
		hud.show_announcement("ДАНІ ПОСТАЧАННЯ", "Утримуйте зону контейнера для отримання апгрейду!")
