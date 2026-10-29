extends EnemyBase

@export var salvo_interval: float = 3.5
var salvo_timer: float = 2.0

func _ready() -> void:
	super._ready()
	# Heavy unit is resistant to light knockback
	max_health = 450.0
	current_health = max_health

func _physics_process(delta: float) -> void:
	if stun_timer <= 0.0 and is_instance_valid(target_player):
		salvo_timer -= delta
		if salvo_timer <= 0.0:
			salvo_timer = salvo_interval
			fire_spread_salvo()
	super._physics_process(delta)

func fire_spread_salvo() -> void:
	if not is_instance_valid(target_player):
		return
		
	var laser_scene = preload("res://scenes/weapons/enemy_laser.tscn")
	var base_dir = (target_player.global_position - global_position).normalized()
	var angles = [-0.3, 0.0, 0.3]
	
	for ang in angles:
		var dir = base_dir.rotated(ang)
		var laser = laser_scene.instantiate()
		laser.setup(global_position, dir, 18.0)
		get_parent().add_child(laser)
		
	AudioManager.play_sfx("laser", 0.1, 2.0)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Heavy unit explosion
	EnemyBase.spawn_explosion(get_parent(), global_position, 90.0, Color(1.0, 0.3, 0.1), true)
	
	AudioManager.play_sfx("heavy_explosion", 0.05, 4.0)
	GameManager.add_kill()
	
	# Heavy unit drops rich loot
	for i in range(5):
		EnemyBase.spawn_pickup(get_parent(), global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1) # GOLD
	EnemyBase.spawn_pickup(get_parent(), global_position, 2) # REPAIR
	
	queue_free()
