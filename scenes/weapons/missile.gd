extends Area2D

@export var speed: float = 430.0
@export var turn_speed: float = 6.5
@export var damage: float = 50.0
@export var aoe_radius: float = 65.0
@export var lifetime: float = 4.0
@export var pierce_count: int = 1
@export var is_valkyrie: bool = false

var current_direction: Vector2 = Vector2.UP
var target: Node2D = null
var hits: int = 0
var hit_enemies: Array[Node2D] = []

# Exhaust particle trail history (in global coords)
var trail: Array[Dictionary] = []

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_aoe: float = 65.0, p_valkyrie: bool = false) -> void:
	global_position = p_position
	current_direction = p_direction.normalized()
	damage = p_damage
	aoe_radius = p_aoe
	is_valkyrie = p_valkyrie
	if is_valkyrie:
		speed *= 1.35
		pierce_count = 2
		aoe_radius *= 1.5
	rotation = current_direction.angle() + PI / 2.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	find_closest_target()

func find_closest_target() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var closest_dist: float = 99999.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			target = enemy

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		find_closest_target()
		
	if is_instance_valid(target):
		var desired_dir = (target.global_position - global_position).normalized()
		current_direction = current_direction.slerp(desired_dir, turn_speed * delta).normalized()
	
	rotation = current_direction.angle() + PI / 2.0
	global_position += current_direction * speed * delta
	
	# Spawn trail puff at tail
	var tail_pos = global_position - current_direction * 14.0
	trail.push_front({
		"pos": tail_pos,
		"alpha": 1.0,
		"radius": randf_range(3.0, 5.0),
		"color": Color(1.0, 0.4, 0.1) if is_valkyrie else Color(1.0, 0.75, 0.2)
	})
	if trail.size() > 16:
		trail.pop_back()
		
	for p in trail:
		p["alpha"] -= delta * 3.5
		p["radius"] += delta * 4.0
		
	queue_redraw()
	
	lifetime -= delta
	if lifetime <= 0:
		explode()

func _draw() -> void:
	# Draw Rocket Plume & Smoke Trail
	for p in trail:
		if p["alpha"] > 0.0:
			var rel = to_local(p["pos"])
			var c: Color = p["color"]
			draw_circle(rel, p["radius"], Color(c.r, c.g, c.b, p["alpha"] * 0.45))
			
	# Core tail thruster glow
	var flare_col = Color(1.0, 0.9, 0.5, 0.9) if not is_valkyrie else Color(0.3, 0.9, 1.0, 0.9)
	draw_circle(Vector2(0, 12), randf_range(3.0, 5.5), flare_col)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or body in hit_enemies:
		return
	hit_enemies.append(body)
	hits += 1
	
	if body.has_method("take_damage"):
		body.take_damage(damage, current_direction)
		
	if hits >= pierce_count:
		explode()

func explode() -> void:
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	var exp_node = exp_scene.instantiate()
	exp_node.global_position = global_position
	exp_node.max_radius = aoe_radius
	exp_node.blast_color = Color(1.0, 0.35, 0.1) if is_valkyrie else Color(1.0, 0.75, 0.2)
	get_parent().add_child(exp_node)
	
	AudioManager.play_sfx("explosion", 0.2)
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= aoe_radius:
			var falloff = 1.0 - (dist / aoe_radius) * 0.5
			if enemy.has_method("take_damage"):
				var push = (enemy.global_position - global_position).normalized()
				enemy.take_damage(damage * falloff, push)
				
	queue_free()
