extends Node

# Wave Director - controls escalating swarms, enemy types, mini-bosses

signal wave_announced(wave_name, description)

var main_scene: Node2D = null
var spawn_timer: float = 0.0
var current_wave_idx: int = 1
var elapsed: float = 0.0

# Special ambush wave timer
var ambush_timer: float = 20.0
var mech_boss_timer: float = 40.0

# Maximum active concurrent enemies to ensure stable 60 FPS even during massive hordes
const MAX_CONCURRENT_ENEMIES: int = 1600

const WAVES = [
	{
		"index": 1,
		"name": "Сектор 1: Дронова Зачистка",
		"desc": "Скупчення розвідувальних дронів. Збирайте нанітний брухт та прокачуйте системи!",
		"start_time": 0.0,
		"interval": 0.6,
		"batch_min": 6,
		"batch_max": 10,
		"types": ["drone"],
		"weights": [1.0]
	},
	{
		"index": 2,
		"name": "Сектор 2: Павутинний Прорив",
		"desc": "Швидкісні боти-павуки проривають периметр! Збільшена щільність ворогів.",
		"start_time": 60.0,
		"interval": 0.45,
		"batch_min": 14,
		"batch_max": 24,
		"types": ["drone", "spider"],
		"weights": [0.55, 0.45]
	},
	{
		"index": 3,
		"name": "Сектор 3: Штурмовий Натиск",
		"desc": "Увага! Штурмові андроїди відкрили лазерний вогонь. Дрони-камікадзе наближаються!",
		"start_time": 150.0,
		"interval": 0.35,
		"batch_min": 25,
		"batch_max": 45,
		"types": ["drone", "spider", "assault", "kamikaze"],
		"weights": [0.35, 0.35, 0.15, 0.15]
	},
	{
		"index": 4,
		"name": "Сектор 4: Протокол Меха-Титан",
		"desc": "ТРИВОГА! Зафіксовано важких бойових мехів-титанів на підході!",
		"start_time": 240.0,
		"interval": 0.30,
		"batch_min": 40,
		"batch_max": 70,
		"types": ["drone", "spider", "assault", "kamikaze"],
		"weights": [0.3, 0.3, 0.2, 0.2]
	},
	{
		"index": 5,
		"name": "Сектор 5: Нульовий Протокол - ТИСЯЧНИЙ ОВЕРДРАЙВ",
		"desc": "МАКСИМАЛЬНА ЗАГРОЗА! Нескінченні армади бойових автоматонів!",
		"start_time": 300.0, # 5 хвилин
		"interval": 0.22,
		"batch_min": 60,
		"batch_max": 110,
		"types": ["drone", "spider", "assault", "kamikaze", "mech"],
		"weights": [0.35, 0.30, 0.18, 0.15, 0.02]
	}
]

var enemy_scenes = {
	"drone": preload("res://scenes/enemies/drone.tscn"),
	"spider": preload("res://scenes/enemies/spider_bot.tscn"),
	"assault": preload("res://scenes/enemies/assault_droid.tscn"),
	"kamikaze": preload("res://scenes/enemies/kamikaze.tscn"),
	"mech": preload("res://scenes/enemies/mech_walker.tscn")
}

func setup(p_main: Node2D) -> void:
	main_scene = p_main

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
		
	elapsed = GameManager.time_survived
	check_wave_progression()
	
	spawn_timer -= delta
	var current_cfg = get_current_wave_config()
	if spawn_timer <= 0.0:
		spawn_timer = current_cfg["interval"]
		spawn_enemy_wave(current_cfg)
		
	# Periodic Ambush Circle Swarms
	ambush_timer -= delta
	if ambush_timer <= 0.0:
		ambush_timer = randf_range(22.0, 32.0)
		trigger_ambush_ring()
		
	# Periodic Mech Titans in late sectors
	if current_wave_idx >= 4:
		mech_boss_timer -= delta
		if mech_boss_timer <= 0.0:
			mech_boss_timer = 35.0
			spawn_specific_enemy("mech", 1)

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

func spawn_enemy_wave(cfg: Dictionary) -> void:
	if not is_instance_valid(GameManager.player_node):
		return
		
	var active_count = get_tree().get_nodes_in_group("enemies").size()
	if active_count >= MAX_CONCURRENT_ENEMIES:
		return
		
	var batch_count = randi_range(cfg["batch_min"], cfg["batch_max"])
	var types: Array = cfg["types"]
	var weights: Array = cfg["weights"]
	
	# Spawn a cluster of enemies from an incoming vector
	var base_angle = randf() * TAU
	var base_dist = randf_range(850.0, 1050.0)
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
				
		var scene: PackedScene = enemy_scenes[chosen_type]
		var enemy = scene.instantiate()
		
		# Cluster around the incoming vector with dispersion
		var offset = Vector2(randf_range(-140, 140), randf_range(-140, 140))
		var angle = base_angle + randf_range(-0.4, 0.4)
		var spawn_pos = player_pos + Vector2(cos(angle), sin(angle)) * base_dist + offset
		enemy.global_position = spawn_pos
		
		main_scene.add_child(enemy)

func trigger_ambush_ring() -> void:
	if not is_instance_valid(GameManager.player_node):
		return
	var player_pos = GameManager.player_node.global_position
	var ring_count = 35 + current_wave_idx * 15
	var enemy_type = "spider" if current_wave_idx <= 2 else ("kamikaze" if randf() < 0.35 else "drone")
	var scene: PackedScene = enemy_scenes[enemy_type]
	
	for i in range(ring_count):
		var ang = (TAU / ring_count) * i
		var dist = randf_range(900.0, 1050.0)
		var enemy = scene.instantiate()
		enemy.global_position = player_pos + Vector2(cos(ang), sin(ang)) * dist
		main_scene.add_child(enemy)

func spawn_specific_enemy(type_key: String, count: int = 1) -> void:
	if not enemy_scenes.has(type_key) or not is_instance_valid(GameManager.player_node):
		return
		
	var scene: PackedScene = enemy_scenes[type_key]
	var player_pos = GameManager.player_node.global_position
	
	for i in range(count):
		var enemy = scene.instantiate()
		var angle = randf() * TAU
		var dist = randf_range(900.0, 1050.0)
		enemy.global_position = player_pos + Vector2(cos(angle), sin(angle)) * dist
		main_scene.add_child(enemy)
