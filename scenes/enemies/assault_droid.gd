extends EnemyBase

@export var shoot_interval: float = 2.4
@export var shoot_range: float = 380.0

var shoot_timer: float = 1.0

func _physics_process(delta: float) -> void:
	if stun_timer <= 0.0 and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		shoot_timer -= delta
		if shoot_timer <= 0.0 and dist <= shoot_range:
			shoot_timer = shoot_interval
			fire_laser()
			
		# If far, advance; if close, strafe
		var to_player = (target_player.global_position - global_position).normalized()
		var move_dir = to_player
		if dist < 220.0:
			# Back away slightly or circle
			var perp = Vector2(-to_player.y, to_player.x)
			move_dir = perp * 0.7 - to_player * 0.3
			
		rotation = lerp_angle(rotation, to_player.angle() + PI / 2.0, 8.0 * delta)
		velocity = move_dir.normalized() * move_speed + knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
	else:
		super._physics_process(delta)

func fire_laser() -> void:
	if not is_instance_valid(target_player):
		return
	var laser_scene = preload("res://scenes/weapons/enemy_laser.tscn")
	var laser = laser_scene.instantiate()
	var dir = (target_player.global_position - global_position).normalized()
	laser.setup(global_position, dir, 14.0)
	get_parent().add_child(laser)
	AudioManager.play_sfx("laser", 0.3, -4.0)
