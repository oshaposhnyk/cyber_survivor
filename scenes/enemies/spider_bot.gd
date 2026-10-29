extends EnemyBase

var wiggle_timer: float = 0.0

func _physics_process(delta: float) -> void:
	wiggle_timer += delta * 6.0
	if stun_timer <= 0.0 and is_instance_valid(target_player):
		var base_dir = (target_player.global_position - global_position).normalized()
		var perp = Vector2(-base_dir.y, base_dir.x) * sin(wiggle_timer) * 0.4
		var move_dir = (base_dir + perp).normalized()
		rotation = lerp_angle(rotation, move_dir.angle() + PI / 2.0, 10.0 * delta)
		velocity = move_dir * move_speed + knockback
		knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		
		for i in range(get_slide_collision_count()):
			var col = get_slide_collision(i)
			var collider = col.get_collider()
			if collider and collider.is_in_group("player") and collider.has_method("take_damage"):
				collider.take_damage(contact_damage * delta * 4.0)
	else:
		super._physics_process(delta)
