extends Area2D

@export var orbit_radius: float = 100.0
@export var orbit_speed: float = 2.4
@export var contact_damage: float = 40.0
@export var fire_cooldown: float = 0.95

var player: Node2D = null
var current_angle: float = 0.0
var shoot_timer: float = 0.0
var is_bastion: bool = false
var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_player: Node2D, p_initial_angle: float, p_bastion: bool = false) -> void:
	player = p_player
	current_angle = p_initial_angle
	is_bastion = p_bastion
	if is_bastion:
		contact_damage *= 1.6
		orbit_radius *= 1.25

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
		
	pulse_time += delta * 4.0
	current_angle += orbit_speed * delta
	var target_pos = player.global_position + Vector2(cos(current_angle), sin(current_angle)) * orbit_radius
	global_position = target_pos
	rotation = current_angle + PI / 2.0
	
	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = fire_cooldown
		shoot_at_nearest_enemy()
		
	queue_redraw()

func _draw() -> void:
	# 1. Micro-thruster plume at the back of drone
	var plume_len = randf_range(6.0, 12.0)
	var plume_col = Color(0.2, 0.9, 1.0, 0.85) if not is_bastion else Color(0.2, 1.0, 0.5, 0.9)
	draw_line(Vector2(0, 10), Vector2(0, 10 + plume_len), plume_col, 3.0)
	draw_circle(Vector2(0, 10 + plume_len * 0.4), 2.5, Color(1, 1, 1, 0.9))
	
	# 2. Nanite Bastion resonant shield ring & lightning tether
	if is_bastion and is_instance_valid(player):
		var rel_player = to_local(player.global_position)
		var a = 0.4 + 0.2 * sin(pulse_time)
		draw_line(Vector2.ZERO, rel_player, Color(0.2, 1.0, 0.6, a), 2.5)
		# Ambient energy arc
		var mid = rel_player * 0.5 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		draw_line(Vector2.ZERO, mid, Color(0.6, 1.0, 0.8, a * 0.8), 1.5)
		draw_line(mid, rel_player, Color(0.6, 1.0, 0.8, a * 0.8), 1.5)

func shoot_at_nearest_enemy() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_enemy: Node2D = null
	var closest_dist: float = 380.0
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
		bolt.setup(global_position, dir, 22.0, 1, false)
		get_parent().add_child(bolt)
		AudioManager.play_sfx("laser", 0.25, -5.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var push = (body.global_position - global_position).normalized()
		body.take_damage(contact_damage, push)
