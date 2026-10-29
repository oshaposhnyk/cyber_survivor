extends EnemyBase

var primed: bool = false
var prime_timer: float = 0.55
var blink_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if primed:
		prime_timer -= delta
		blink_timer += delta * 25.0
		modulate = Color(3.0, 0.2, 0.2) if sin(blink_timer) > 0.0 else Color.WHITE
		if prime_timer <= 0.0:
			self_destruct()
		move_and_slide()
		return
		
	if stun_timer <= 0.0 and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist > 2100.0:
			var wrap_angle = randf() * TAU
			global_position = target_player.global_position + Vector2(cos(wrap_angle), sin(wrap_angle)) * randf_range(950.0, 1150.0)
			return
		if dist < 120.0 and not primed:
			prime_drone()
	super._physics_process(delta)

func prime_drone() -> void:
	primed = true
	move_speed *= 1.45
	AudioManager.play_sfx("missile", 0.3, 2.0)

func self_destruct() -> void:
	if is_dead:
		return
	is_dead = true
	
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = 80.0
	exp_node.blast_color = Color(1.0, 0.2, 0.1)
	get_parent().add_child(exp_node)
	
	AudioManager.play_sfx("heavy_explosion", 0.1, 2.0)
	
	# Damage player if in blast radius
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= 90.0 and target_player.has_method("take_damage"):
			var falloff = 1.0 - (dist / 90.0) * 0.5
			target_player.take_damage(35.0 * falloff)
			
	drop_loot()
	queue_free()
