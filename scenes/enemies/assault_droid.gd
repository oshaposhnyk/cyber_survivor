extends EnemyBase

# Burst of 3 shots after a 0.4 s aim telegraph (EnemyBase.update_fire)
func _tick(delta: float) -> void:
	if is_dead:
		return
	if stun_timer > 0.0:
		super._tick(delta)
		return
	update_status(delta)
		
	if not is_instance_valid(target_player):
		find_player()
		return
		
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	if not keep_near_player(to_player):
		return
		
	update_fire(delta, dist)
		
	var to_dir = to_player.normalized()
	var move_dir = to_dir
	if dist < 240.0:
		var perp = Vector2(-to_dir.y, to_dir.x)
		move_dir = perp * 0.7 - to_dir * 0.3
		
	face(to_player.angle() + PI / 2.0)
	velocity = move_dir.normalized() * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	step_motion(delta)
	apply_contact(to_player, delta)
