extends EnemyBase

var wiggle_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if stun_timer > 0.0:
		super._physics_process(delta)
		return
	update_status(delta)
		
	if not is_instance_valid(target_player):
		find_player()
		return
		
	var to_player = target_player.global_position - global_position
	
	if not keep_near_player(to_player):
		return
		
	wiggle_timer += delta * 6.0
	var base_dir = to_player.normalized()
	var perp = Vector2(-base_dir.y, base_dir.x) * sin(wiggle_timer) * 0.4
	var move_dir = (base_dir + perp).normalized()
	rotation = to_player.angle() + PI / 2.0
	
	velocity = move_dir * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	step_motion(delta)
	apply_contact(to_player, delta)
