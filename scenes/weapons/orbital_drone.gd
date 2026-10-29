extends Area2D

@export var orbit_radius: float = 95.0
@export var orbit_speed: float = 2.2
@export var contact_damage: float = 35.0
@export var fire_cooldown: float = 1.0

var player: Node2D = null
var current_angle: float = 0.0
var shoot_timer: float = 0.0
var is_bastion: bool = false
var contact_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_player: Node2D, p_initial_angle: float, p_bastion: bool = false) -> void:
	player = p_player
	current_angle = p_initial_angle
	is_bastion = p_bastion
	if is_bastion:
		contact_damage *= 1.5
		orbit_radius *= 1.2

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
		
	current_angle += orbit_speed * delta
	var target_pos = player.global_position + Vector2(cos(current_angle), sin(current_angle)) * orbit_radius
	global_position = target_pos
	rotation = current_angle + PI / 2.0
	
	# Autonomous shooting
	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = fire_cooldown
		shoot_at_nearest_enemy()
		
	# Bastion effect
	if is_bastion:
		queue_redraw()

func _draw() -> void:
	if is_bastion and is_instance_valid(player):
		# Draw glowing energy tether to player
		var rel_player = to_local(player.global_position)
		draw_line(Vector2.ZERO, rel_player, Color(0.2, 1.0, 0.6, 0.4), 2.0)

func shoot_at_nearest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var closest_dist: float = 350.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_enemy = enemy
			
	if closest_enemy:
		var dir = (closest_enemy.global_position - global_position).normalized()
		var bolt_scene = preload("res://scenes/weapons/blaster_bolt.tscn")
		var bolt = bolt_scene.instantiate()
		bolt.setup(global_position, dir, 20.0, 1, false)
		get_parent().add_child(bolt)
		AudioManager.play_sfx("laser", 0.2, -4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var push = (body.global_position - global_position).normalized()
		body.take_damage(contact_damage, push)
