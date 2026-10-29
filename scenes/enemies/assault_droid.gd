extends EnemyBase

@export var shoot_interval: float = 2.5
@export var shoot_range: float = 420.0

var shoot_timer: float = 1.0

func _physics_process(delta: float) -> void:
	if stun_timer > 0.0:
		super._physics_process(delta)
		return
		
	if not is_instance_valid(target_player):
		find_player()
		return
		
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	if dist > 2100.0:
		var wrap_angle = randf() * TAU
		global_position = target_player.global_position + Vector2(cos(wrap_angle), sin(wrap_angle)) * randf_range(950.0, 1150.0)
		return
		
	shoot_timer -= delta
	if shoot_timer <= 0.0 and dist <= shoot_range:
		shoot_timer = shoot_interval
		fire_laser()
		
	var to_dir = to_player.normalized()
	var move_dir = to_dir
	if dist < 240.0:
		var perp = Vector2(-to_dir.y, to_dir.x)
		move_dir = perp * 0.7 - to_dir * 0.3
		
	rotation = to_player.angle() + PI / 2.0
	velocity = move_dir.normalized() * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	
	var touching_player = (dist <= 42.0)
	if not touching_player:
		for i in range(get_slide_collision_count()):
			if get_slide_collision(i).get_collider() == target_player:
				touching_player = true
				break
				
	if touching_player and target_player.has_method("take_damage"):
		target_player.take_damage(contact_damage * delta * 2.8, global_position)

func fire_laser() -> void:
	if not is_instance_valid(target_player):
		return
	var laser_scene = preload("res://scenes/weapons/enemy_laser.tscn")
	var laser = laser_scene.instantiate()
	var dir = (target_player.global_position - global_position).normalized()
	laser.setup(global_position, dir, 12.0)
	get_parent().add_child(laser)
	if randf() < 0.2:
		AudioManager.play_sfx("laser", 0.3, -5.0)
