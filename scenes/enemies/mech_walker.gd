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
	# Heavy boss explosion
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = 90.0
	exp_node.blast_color = Color(1.0, 0.3, 0.1)
	get_parent().add_child(exp_node)
	
	AudioManager.play_sfx("explosion", 0.05, 5.0)
	GameManager.add_kill()
	
	# Boss drops rich loot
	var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
	for i in range(5):
		var gold = scrap_scene.instantiate()
		gold.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		gold.setup(1) # GOLD
		get_parent().call_deferred("add_child", gold)
		
	var rep = scrap_scene.instantiate()
	rep.global_position = global_position
	rep.setup(2) # REPAIR
	get_parent().call_deferred("add_child", rep)
	
	queue_free()
