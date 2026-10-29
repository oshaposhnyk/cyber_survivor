extends EnemyBase

# One three-way salvo per token, after the aim telegraph
func _spawned() -> void:
	super._spawned()
	shoot_interval = 3.5
	shoot_range = 520.0
	burst_count = 1
	shot_damage = 18.0
	fire_cooldown = 2.0

func _tick(delta: float) -> void:
	if stun_timer <= 0.0 and is_instance_valid(target_player):
		update_fire(delta, global_position.distance_to(target_player.global_position))
	super._tick(delta)

func _fire_volley(dir: Vector2) -> void:
	for ang in [-0.3, 0.0, 0.3]:
		_spawn_laser(dir.rotated(ang), shot_damage)
	AudioManager.play_sfx("laser", 0.1, 2.0)

# Heavy unit explosion; kill credit, hack effects and loot run in EnemyBase.die()
func _death_fx() -> void:
	EnemyBase.spawn_explosion(world, global_position, 90.0, Color(1.0, 0.3, 0.1), true)
	AudioManager.play_sfx("heavy_explosion", 0.05, 4.0)

# Heavy unit drops rich loot (plus the beacon when it is a champion)
func drop_loot() -> void:
	_drop_champion_reward()
	for i in range(5):
		EnemyBase.spawn_pickup(world, global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1) # GOLD
	EnemyBase.spawn_pickup(world, global_position, 2) # REPAIR
