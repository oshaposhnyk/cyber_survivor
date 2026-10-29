extends CharacterBody2D
class_name EnemyBase

@export var max_health: float = 30.0
@export var move_speed: float = 120.0
@export var contact_damage: float = 10.0
@export var scrap_count: int = 1
@export var gold_chance: float = 0.05
@export var repair_chance: float = 0.03
@export var score_points: int = 10

var current_health: float = 30.0
var knockback: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0
var is_dead: bool = false
var target_player: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2 # Layer 2: Enemies
	collision_mask = 3  # Layer 1: Player, Layer 2: Enemies
	current_health = max_health
	find_player()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Handle EMP Stun
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		modulate = Color(0.4, 0.8, 1.0) if fmod(stun_timer, 0.2) < 0.1 else Color.WHITE
		return
	else:
		modulate = Color.WHITE

	if not is_instance_valid(target_player):
		find_player()
		
	var move_dir = Vector2.ZERO
	if is_instance_valid(target_player):
		move_dir = (target_player.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, move_dir.angle() + PI / 2.0, 10.0 * delta)
		
	# Handle movement & knockback
	velocity = move_dir * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	
	# Check contact with player
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage * delta * 4.0)

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	current_health -= amount
	knockback = knockback_dir * 180.0
	
	# Spawn floating damage number
	spawn_damage_text(amount)
	
	# Flash red
	flash_hit()
	
	if current_health <= 0:
		die()

func flash_hit() -> void:
	if sprite:
		var orig = sprite.modulate
		sprite.modulate = Color(2.5, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", orig, 0.1)

func spawn_damage_text(amount: float) -> void:
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(randf_range(-12, 12), randf_range(-16, -6))
	var is_crit = amount >= 45.0
	var col = Color(1.0, 0.85, 0.2) if is_crit else Color(1.0, 1.0, 1.0)
	var sz = 1.3 if is_crit else 1.0
	get_parent().add_child(ft)
	ft.setup(str(int(amount)), col, sz)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Spawn explosion effect
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = 28.0
	get_parent().add_child(exp_node)
	
	AudioManager.play_sfx("explosion", 0.25, -2.0)
	GameManager.add_kill()
	
	# Drop Scrap
	drop_loot()
	queue_free()

func drop_loot() -> void:
	var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
	
	# Check for repair core
	if randf() < repair_chance:
		var repair = scrap_scene.instantiate()
		repair.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		repair.setup(1 if randf() < 0.5 else 2) # REPAIR
		get_parent().call_deferred("add_child", repair)
		return

	# Drop normal or gold scrap
	for i in range(scrap_count):
		var scrap = scrap_scene.instantiate()
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		scrap.global_position = global_position + offset
		var is_gold = randf() < gold_chance
		scrap.setup(1 if is_gold else 0) # 1: GOLD, 0: BLUE
		get_parent().call_deferred("add_child", scrap)
