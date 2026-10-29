extends Area2D

@export var speed: float = 400.0
@export var turn_speed: float = 6.0
@export var damage: float = 50.0
@export var aoe_radius: float = 60.0
@export var lifetime: float = 4.0
@export var pierce_count: int = 1
@export var is_valkyrie: bool = false

var current_direction: Vector2 = Vector2.UP
var target: Node2D = null
var hits: int = 0
var hit_enemies: Array[Node2D] = []

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_aoe: float = 60.0, p_valkyrie: bool = false) -> void:
	global_position = p_position
	current_direction = p_direction.normalized()
	damage = p_damage
	aoe_radius = p_aoe
	is_valkyrie = p_valkyrie
	if is_valkyrie:
		speed *= 1.3
		pierce_count = 2
		aoe_radius *= 1.5
	rotation = current_direction.angle() + PI / 2.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	find_closest_target()

func find_closest_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = 99999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			target = enemy

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		find_closest_target()
		
	if is_instance_valid(target):
		var desired_dir = (target.global_position - global_position).normalized()
		current_direction = current_direction.slerp(desired_dir, turn_speed * delta).normalized()
	
	rotation = current_direction.angle() + PI / 2.0
	global_position += current_direction * speed * delta
	
	lifetime -= delta
	if lifetime <= 0:
		explode()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or body in hit_enemies:
		return
	hit_enemies.append(body)
	hits += 1
	
	if body.has_method("take_damage"):
		body.take_damage(damage, current_direction)
		
	if hits >= pierce_count:
		explode()

func explode() -> void:
	# Spawn explosion effect
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = aoe_radius
	exp_node.blast_color = Color(1.0, 0.4, 0.1) if is_valkyrie else Color(1.0, 0.8, 0.2)
	get_parent().add_child(exp_node)
	
	AudioManager.play_sfx("explosion", 0.2)
	
	# AoE Damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			var falloff = 1.0 - (dist / aoe_radius) * 0.5
			if enemy.has_method("take_damage"):
				var push = (enemy.global_position - global_position).normalized()
				enemy.take_damage(damage * falloff, push)
				
	queue_free()
