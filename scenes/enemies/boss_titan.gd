extends CharacterBody2D

# Dreadnought Titan Boss "LEVIATHAN-01"
# Massive health, multi-phase attacks, drops Quantum Core with +500 XP

@export var max_health: float = 1800.0
@export var move_speed: float = 95.0
@export var contact_damage: float = 24.0

var current_health: float = 1800.0
var knockback: Vector2 = Vector2.ZERO
var is_dead: bool = false
var target_player: Node2D = null

# Attack Timers
var laser_timer: float = 2.0
var radial_timer: float = 3.5
var missile_timer: float = 4.0

var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2 # Layer 2: Enemies
	collision_mask = 1  # Layer 1: Player
	current_health = max_health
	find_player()
	
	# Connect to HUD boss health bar
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar("ДРЕДНОУТ-ТИТАН «LEVIATHAN-01»", max_health)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	pulse_time += delta * 3.0
	queue_redraw()
	
	if not is_instance_valid(target_player):
		find_player()
		return
		
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	# Rotate towards player
	rotation = lerp_angle(rotation, to_player.angle() + PI / 2.0, 4.0 * delta)
	
	# Phase speed boost when enraged
	var cur_speed = move_speed
	if current_health < max_health * 0.3:
		cur_speed *= 1.35
		
	var move_dir = to_player.normalized()
	velocity = move_dir * cur_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	
	# Contact damage with player
	var touching = (dist <= 52.0)
	if not touching:
		for i in range(get_slide_collision_count()):
			if get_slide_collision(i).get_collider() == target_player:
				touching = true
				break
	if touching and target_player.has_method("take_damage"):
		target_player.take_damage(contact_damage * delta * 2.5, global_position)
		
	# Attack 1: Dual Heavy Lasers (All Phases)
	laser_timer -= delta
	if laser_timer <= 0.0:
		laser_timer = 2.4
		fire_heavy_lasers()
		
	# Attack 2: Radial 8-Way Plasma Burst (Phase 2 & 3: HP < 65%)
	if current_health < max_health * 0.65:
		radial_timer -= delta
		if radial_timer <= 0.0:
			radial_timer = 3.6
			fire_radial_burst()
			
	# Attack 3: Homing Cluster Missiles (Phase 3: HP < 30%)
	if current_health < max_health * 0.3:
		missile_timer -= delta
		if missile_timer <= 0.0:
			missile_timer = 4.2
			fire_boss_missiles()

func fire_heavy_lasers() -> void:
	if not is_instance_valid(target_player):
		return
	var laser_scene = preload("res://scenes/weapons/enemy_laser.tscn")
	var base_dir = (target_player.global_position - global_position).normalized()
	
	var offsets = [-0.18, 0.18]
	for off in offsets:
		var dir = base_dir.rotated(off)
		var laser = laser_scene.instantiate()
		var spawn_pt = global_position + dir * 30.0
		laser.setup(spawn_pt, dir, 16.0)
		get_parent().add_child(laser)
	AudioManager.play_sfx("laser", 0.1, 1.0)

func fire_radial_burst() -> void:
	var bolt_scene = preload("res://scenes/weapons/blaster_bolt.tscn")
	var count = 8
	for i in range(count):
		var ang = (TAU / count) * i + pulse_time * 0.2
		var dir = Vector2(cos(ang), sin(ang))
		var bolt = bolt_scene.instantiate()
		bolt.setup(global_position + dir * 36.0, dir, 14.0, 1, false)
		get_parent().add_child(bolt)
	AudioManager.play_sfx("laser", 0.15, -2.0)

func fire_boss_missiles() -> void:
	if not is_instance_valid(target_player):
		return
	var missile_scene = preload("res://scenes/weapons/missile.tscn")
	for i in range(3):
		var launch_dir = (target_player.global_position - global_position).normalized().rotated(randf_range(-0.5, 0.5))
		var m = missile_scene.instantiate()
		m.setup(global_position, launch_dir, 28.0, 70.0, false)
		m.target = target_player
		get_parent().add_child(m)
	AudioManager.play_sfx("missile", 0.1)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	current_health -= amount
	knockback = knockback_dir * 30.0 # High poise / low knockback
	
	# Flash red
	if sprite:
		sprite.modulate = Color(3.0, 0.5, 0.5)
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.45, 0.45), 0.1)
		
	# Update HUD boss health bar
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(current_health)
		
	if current_health <= 0.0:
		die()

func _draw() -> void:
	# Enraged Red Energy Shield Ring
	var a = 0.4 + 0.2 * sin(pulse_time)
	var col = Color(1.0, 0.2, 0.1, a)
	draw_arc(Vector2.ZERO, 46.0, 0, TAU, 24, col, 2.5)
	
	# Orbiting Targeting Reticle
	var ret_ang = pulse_time * 1.5
	var p = Vector2(cos(ret_ang), sin(ret_ang)) * 52.0
	draw_circle(p, 4.0, Color(1.0, 0.8, 0.2, a))

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Multi-stage explosions across chassis
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	for i in range(4):
		var exp_node = exp_scene.instantiate()
		exp_node.global_position = global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35))
		exp_node.max_radius = 85.0
		exp_node.blast_color = Color(1.0, randf_range(0.2, 0.6), 0.1)
		get_parent().call_deferred("add_child", exp_node)
		
	AudioManager.play_sfx("heavy_explosion", 0.05, 5.0)
	GameManager.add_kill()
	
	# Hide Boss Bar in HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()
	if hud and hud.has_method("show_announcement"):
		hud.show_announcement("ТИТАН-ДРЕДНОУТ ЗНИЩЕНИЙ!", "ЗДОБУТО КВАНТОВИЙ СУПЕР-ЧЕСТ (+500 ДОСВІДУ)")
		
	# DROP GIGANTIC QUANTUM CORE (+500 XP)
	var core_scene = preload("res://scenes/pickups/quantum_core.tscn")
	var core = core_scene.instantiate()
	core.global_position = global_position
	get_parent().call_deferred("add_child", core)
	
	# Drop rich surrounding loot
	var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
	for i in range(8):
		var gold = scrap_scene.instantiate()
		gold.global_position = global_position + Vector2(randf_range(-45, 45), randf_range(-45, 45))
		gold.setup(1) # Gold
		get_parent().call_deferred("add_child", gold)
		
	for i in range(2):
		var rep = scrap_scene.instantiate()
		rep.global_position = global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35))
		rep.setup(2) # Repair core
		get_parent().call_deferred("add_child", rep)
		
	queue_free()
