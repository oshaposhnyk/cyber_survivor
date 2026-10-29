extends Node

# Wave Director - controls escalating swarms, enemy types, mini-bosses

signal wave_announced(wave_name, description)

var main_scene: Node2D = null
var spawn_timer: float = 0.0
var current_wave_idx: int = 1
var boss_spawned_w4: bool = false
var boss_spawned_w5: bool = false
var elapsed: float = 0.0

const WAVES = [
	{
		"index": 1,
		"name": "Сектор 1: Дронова Зачистка",
		"desc": "Скупчення розвідувальних дронів. Збирайте нанітний брухт та прокачуйте системи!",
		"start_time": 0.0,
		"interval": 1.2,
		"types": ["drone"],
		"weights": [1.0]
	},
	{
		"index": 2,
		"name": "Сектор 2: Павутинний Прорив",
		"desc": "Швидкісні боти-павуки проривають периметр! Збільшена щільність ворогів.",
		"start_time": 60.0,
		"interval": 0.9,
		"types": ["drone", "spider"],
		"weights": [0.6, 0.4]
	},
	{
		"index": 3,
		"name": "Сектор 3: Штурмовий Натиск",
		"desc": "Увага! Штурмові андроїди відкрили лазерний вогонь. Дрони-камікадзе наближаються!",
		"start_time": 150.0,
		"interval": 0.65,
		"types": ["drone", "spider", "assault", "kamikaze"],
		"weights": [0.35, 0.35, 0.15, 0.15]
	},
	{
		"index": 4,
		"name": "Сектор 4: Протокол Меха-Титан",
		"desc": "ТРИВОГА! Зафіксовано важкого бойового крокуючого меха!",
		"start_time": 240.0,
		"interval": 0.5,
		"types": ["drone", "spider", "assault", "kamikaze"],
		"weights": [0.3, 0.3, 0.2, 0.2]
	},
	{
		"index": 5,
		"name": "Сектор 5: Нульовий Протокол - Овердрайв",
		"desc": "МАКСИМАЛЬНА ЗАГРОЗА! Нескінченні армади бойових автоматонів!",
		"start_time": 330.0,
		"interval": 0.35,
		"types": ["drone", "spider", "assault", "kamikaze", "mech"],
		"weights": [0.25, 0.25, 0.25, 0.2, 0.05]
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
		
		# Boss spawn at Wave 4
		if current_wave_idx == 4 and not boss_spawned_w4:
			boss_spawned_w4 = true
			spawn_specific_enemy("mech")
			
	# Victory condition check at 7 minutes (420s)
	if elapsed >= 420.0 and GameManager.current_state == GameManager.State.PLAYING:
		GameManager.trigger_game_over(true)

func spawn_enemy_wave(cfg: Dictionary) -> void:
	if not is_instance_valid(GameManager.player_node):
		return
		
	# Select enemy type based on weights
	var types: Array = cfg["types"]
	var weights: Array = cfg["weights"]
	var roll = randf()
	var accum = 0.0
	var chosen_type = types[0]
	for i in range(types.size()):
		accum += weights[i]
		if roll <= accum:
			chosen_type = types[i]
			break
			
	spawn_specific_enemy(chosen_type)
	
	# In late waves, spawn in pairs or triplets
	if current_wave_idx >= 3 and randf() < 0.4:
		spawn_specific_enemy(types[0])
	if current_wave_idx >= 5 and randf() < 0.3:
		spawn_specific_enemy(types[1])

func spawn_specific_enemy(type_key: String) -> void:
	if not enemy_scenes.has(type_key) or not is_instance_valid(GameManager.player_node):
		return
		
	var scene: PackedScene = enemy_scenes[type_key]
	var enemy = scene.instantiate()
	
	# Spawn in ring around player (750 to 850 px away)
	var angle = randf() * TAU
	var dist = randf_range(720.0, 850.0)
	var spawn_pos = GameManager.player_node.global_position + Vector2(cos(angle), sin(angle)) * dist
	enemy.global_position = spawn_pos
	
	main_scene.add_child(enemy)
