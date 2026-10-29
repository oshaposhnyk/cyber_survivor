extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var wave_manager = $WaveManager
@onready var camera: Camera2D = $Camera2D
@onready var hud = $HUD
@onready var skill_tree = $SkillTree
@onready var game_over_ui = $GameOverUI
@onready var space_grid: Node2D = $SpaceGrid

var shake_amount: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_manager.setup(self)
	wave_manager.wave_announced.connect(_on_wave_announced)
	GameManager.level_up_occurred.connect(_on_level_up)
	
	# Initial announcement
	hud.show_announcement("СЕКТОР 1: ЗАЧИСТКА", "Збирайте наніти та натискайте [ТАВ] для прокачки!")

func _process(delta: float) -> void:
	GameManager.add_time(delta)
	
	# Camera follow player
	if is_instance_valid(player):
		camera.global_position = camera.global_position.lerp(player.global_position, 10.0 * delta)

	# View rectangle for enemy LOD; margin keeps sprites at the edge at full rate
	EnemyBase.view_center = camera.get_screen_center_position()
	EnemyBase.view_half = get_viewport_rect().size * 0.5 / camera.zoom + Vector2(120.0, 120.0)
		
	# Screen shake
	if shake_amount > 0.0:
		camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		shake_amount = move_toward(shake_amount, 0.0, 30.0 * delta)
	else:
		camera.offset = Vector2.ZERO

func apply_screen_shake(amount: float) -> void:
	shake_amount = max(shake_amount, amount)

func _on_wave_announced(title: String, desc: String) -> void:
	hud.show_announcement(title, desc)
	apply_screen_shake(6.0)

func _on_level_up(_lvl: int, _pts: int) -> void:
	# Notification
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not skill_tree.visible and not game_over_ui.visible:
			skill_tree.open_tree()
