extends Area2D

enum ScrapType { BLUE, GOLD, REPAIR }

@export var type: ScrapType = ScrapType.BLUE

var target_player: Node2D = null
var current_speed: float = 0.0
var max_speed: float = 600.0
var acceleration: float = 900.0
var is_attracted: bool = false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 16 # Layer 5: Pickups
	collision_mask = 1  # Layer 1: Player
	setup_visuals()

func setup(p_type: ScrapType) -> void:
	type = p_type
	if is_inside_tree():
		setup_visuals()

func setup_visuals() -> void:
	if not sprite:
		return
	match type:
		ScrapType.BLUE:
			sprite.texture = preload("res://assets/sprites/pickups/scrap_blue.png")
			sprite.scale = Vector2(0.8, 0.8)
		ScrapType.GOLD:
			sprite.texture = preload("res://assets/sprites/pickups/scrap_gold.png")
			sprite.scale = Vector2(1.0, 1.0)
		ScrapType.REPAIR:
			sprite.texture = preload("res://assets/sprites/pickups/repair_core.png")
			sprite.scale = Vector2(1.1, 1.1)

func attract(player: Node2D) -> void:
	target_player = player
	is_attracted = true

func _physics_process(delta: float) -> void:
	if is_attracted and is_instance_valid(target_player):
		var direction = (target_player.global_position - global_position).normalized()
		var dist = global_position.distance_to(target_player.global_position)
		
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
		global_position += direction * current_speed * delta
		
		if dist < 22.0:
			collect()
	else:
		# Idle gentle rotation
		rotation += delta * 1.5

func collect() -> void:
	match type:
		ScrapType.BLUE:
			GameManager.add_scrap(1)
			AudioManager.play_sfx("scrap", 0.15)
		ScrapType.GOLD:
			GameManager.add_scrap(5)
			AudioManager.play_sfx("scrap", 0.05, 2.0)
		ScrapType.REPAIR:
			if is_instance_valid(target_player) and target_player.has_method("heal"):
				target_player.heal(30.0)
			AudioManager.play_sfx("upgrade_select")
			
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()
