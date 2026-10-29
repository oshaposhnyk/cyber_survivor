extends EnemyBase

var wiggle_timer: float = 0.0

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
		
	wiggle_timer += delta * 6.0
	var base_dir = to_player.normalized()
	var perp = Vector2(-base_dir.y, base_dir.x) * sin(wiggle_timer) * 0.4
	var move_dir = (base_dir + perp).normalized()
	rotation = to_player.angle() + PI / 2.0
	
	velocity = move_dir * move_speed + knockback
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
