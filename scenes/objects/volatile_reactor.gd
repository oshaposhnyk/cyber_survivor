extends CharacterBody2D

# Volatile Space Reactor / Fuel Pod Hazard
# Floating explosive interactive obstacle. Detonates in a huge radius when destroyed!

@export var max_health: float = 140.0
var current_health: float = 140.0
var is_dead: bool = false
var hit_flash: float = 0.0
var pulse_time: float = 0.0
var drift_dir: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _enter_tree() -> void:
	# Add to EnemyRegistry so that weapons like railgun, missiles, or chain lightning can interact with it
	EnemyRegistry.register(self)

func _exit_tree() -> void:
	EnemyRegistry.unregister(self)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hazards")
	collision_layer = 2 # Layer 2: Enemies
	collision_mask = 1  # Layer 1: Player
	current_health = max_health
	drift_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(12.0, 24.0)

func _physics_process(delta: float) -> void:
	pulse_time += delta * 3.0
	rotation += delta * 0.4
	velocity = drift_dir
	move_and_slide()
	queue_redraw()
	
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0 and sprite:
			sprite.modulate = Color.WHITE

func _draw() -> void:
	# Warning hazard ring
	var pulse = (sin(pulse_time) + 1.0) * 0.5
	var col = Color(1.0, 0.45 + pulse * 0.4, 0.1, 0.8)
	draw_arc(Vector2.ZERO, 26.0 + pulse * 4.0, 0, TAU, 16, col, 2.0)
	# Core glow
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.3, 0.05, 0.25 + pulse * 0.25))

func take_damage(amount: float, _source_pos: Vector2 = Vector2.ZERO) -> void:
	current_health -= amount
	hit_flash = 0.1
	if sprite:
		sprite.modulate = Color(3.0, 0.6, 0.2)
	if current_health <= 0.0:
		detonate()

func detonate() -> void:
	if is_dead:
		return
	is_dead = true
	# Massive chain reaction explosion
	var main = get_parent()
	if main and main.has_method("apply_screen_shake"):
		main.apply_screen_shake(12.0)
		
	# Deal massive 500 damage to all nearby enemies in 240px radius
	var victims = EnemyRegistry.in_radius(global_position, 240.0)
	for e in victims:
		if is_instance_valid(e) and e != self and e.has_method("take_damage"):
			var dist = global_position.distance_to(e.global_position)
			var falloff = clampf(1.0 - (dist / 240.0), 0.3, 1.0)
			e.take_damage(500.0 * falloff)
			if e.has_method("apply_slow"):
				e.apply_slow(1.5, 0.3)
				
	# Spawn explosion VFX
	var expl_scene = preload("res://scenes/effects/explosion.tscn")
	var expl = expl_scene.instantiate()
	expl.global_position = global_position
	expl.scale = Vector2(2.5, 2.5)
	main.add_child(expl)
	AudioManager.play_sfx("heavy_explosion", 0.05, 3.0)
	
	# Drop bonus scraps
	var scrap_scene = preload("res://scenes/pickups/nanite_scrap.tscn")
	for i in range(4):
		var s = scrap_scene.instantiate()
		s.global_position = global_position + Vector2(randf_range(-25, 25), randf_range(-25, 25))
		s.setup(1) # Gold scrap
		main.call_deferred("add_child", s)
		
	queue_free()
