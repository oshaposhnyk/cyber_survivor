extends CharacterBody2D
class_name EnemyBase

@export var max_health: float = 30.0
@export var move_speed: float = 130.0
@export var contact_damage: float = 10.0
@export var scrap_count: int = 1
@export var gold_chance: float = 0.06
@export var repair_chance: float = 0.03
@export var score_points: int = 10

var current_health: float = 30.0
var knockback: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0
var is_dead: bool = false
var target_player: Node2D = null

# Swarm natural dispersal angle so enemies naturally envelop the player
var swarm_angle_offset: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2 # Layer 2: Enemies
	collision_mask = 1  # Layer 1: Player only (avoids O(N^2) physics collisions between thousands of enemies)
	current_health = max_health
	swarm_angle_offset = randf_range(-0.35, 0.35)
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
		return
		
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	# Wrap around if too far from player (keeps horde dense around screen)
	if dist > 2100.0:
		var wrap_angle = randf() * TAU
		global_position = target_player.global_position + Vector2(cos(wrap_angle), sin(wrap_angle)) * randf_range(950.0, 1150.0)
		return
		
	# Move toward player with slight swarm angle offset for natural surrounding behavior
	var move_dir = to_player.normalized().rotated(swarm_angle_offset)
	rotation = to_player.angle() + PI / 2.0
	
	velocity = move_dir * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	
	# Contact damage when close to player
	if dist < 32.0 and target_player.has_method("take_damage"):
		target_player.take_damage(contact_damage * delta * 3.5)

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	current_health -= amount
	knockback = knockback_dir * 160.0
	
	# Spawn damage number
	spawn_damage_text(amount)
	flash_hit()
	
	if current_health <= 0:
		die()

func flash_hit() -> void:
	if sprite:
		var orig = sprite.modulate
		sprite.modulate = Color(3.0, 0.4, 0.4)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", orig, 0.1)

func spawn_damage_text(amount: float) -> void:
	# Only spawn floating text for a sample of hits during huge swarms to keep rendering at 60 FPS
	if randf() > 0.4 and amount < 40.0:
		return
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-14, -4))
	var is_crit = amount >= 45.0
	var col = Color(1.0, 0.85, 0.2) if is_crit else Color(1.0, 1.0, 1.0)
	var sz = 1.3 if is_crit else 0.95
	get_parent().add_child(ft)
	ft.setup(str(int(amount)), col, sz)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Only play sound & explosion effect if near camera view
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = 26.0
	get_parent().add_child(exp_node)
	
	# Audio throttle during massive waves
	if randf() < 0.25:
		AudioManager.play_sfx("explosion", 0.3, -3.0)
		
	GameManager.add_kill()
	drop_loot()
	queue_free()

func drop_loot() -> void:
	var active_pickups = get_tree().get_nodes_in_group("pickups").size()
	
	# Check for repair core
	if randf() < repair_chance:
		var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
		var repair = scrap_scene.instantiate()
		repair.global_position = global_position
		repair.setup(2) # REPAIR
		get_parent().call_deferred("add_child", repair)
		return

	# Performance guard: if there are already 180+ pickup nodes on the ground,
	# auto-absorb directly to avoid overloading physics
	if active_pickups > 180:
		GameManager.add_scrap(scrap_count)
		return

	var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
	for i in range(scrap_count):
		var scrap = scrap_scene.instantiate()
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		scrap.global_position = global_position + offset
		var is_gold = randf() < gold_chance
		scrap.setup(1 if is_gold else 0)
		get_parent().call_deferred("add_child", scrap)
