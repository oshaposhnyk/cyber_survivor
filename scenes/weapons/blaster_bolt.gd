extends Area2D

@export var speed: float = 800.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var pierce_count: int = 1
@export var can_chain: bool = false
@export var chain_targets_count: int = 2

var velocity: Vector2 = Vector2.ZERO
var hits_done: int = 0
var hit_enemies: Array[Node2D] = []

# Trailing plasma line history
var trail: Array[Vector2] = []

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_pierce: int = 1, p_chain: bool = false) -> void:
	global_position = p_position
	velocity = p_direction.normalized() * speed
	rotation = p_direction.angle() + PI / 2.0
	damage = p_damage
	pierce_count = p_pierce
	can_chain = p_chain

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2

func _physics_process(delta: float) -> void:
	trail.push_front(global_position)
	if trail.size() > 6:
		trail.pop_back()
		
	global_position += velocity * delta
	queue_redraw()
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _draw() -> void:
	# Draw glowing plasma tail behind the bolt
	if trail.size() > 1:
		for i in range(trail.size() - 1):
			var p1 = to_local(trail[i])
			var p2 = to_local(trail[i+1])
			var a = (1.0 - float(i) / trail.size()) * 0.7
			draw_line(p1, p2, Color(0.2, 0.8, 1.0, a), 3.0)
			draw_line(p1, p2, Color(1.0, 1.0, 1.0, a * 0.9), 1.2)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or body in hit_enemies:
		return
		
	hit_enemies.append(body)
	hits_done += 1
	
	if body.has_method("take_damage"):
		body.take_damage(damage, velocity.normalized())
		
	if can_chain:
		trigger_chain_lightning(body)
		
	if hits_done >= pierce_count:
		queue_free()

func trigger_chain_lightning(origin_enemy: Node2D) -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var chained: int = 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == origin_enemy or enemy in hit_enemies:
			continue
		if enemy.global_position.distance_to(origin_enemy.global_position) < 220.0:
			hit_enemies.append(enemy)
			chained += 1
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage * 0.8, (enemy.global_position - origin_enemy.global_position).normalized())
			spawn_chain_fx(origin_enemy.global_position, enemy.global_position)
			if chained >= chain_targets_count:
				break

func spawn_chain_fx(p1: Vector2, p2: Vector2) -> void:
	var line = Line2D.new()
	line.default_color = Color(0.3, 0.95, 1.0, 0.95)
	line.width = 3.5
	line.add_point(p1)
	# Jagged electric points
	var mid = (p1 + p2) * 0.5 + Vector2(randf_range(-18, 18), randf_range(-18, 18))
	line.add_point(mid)
	line.add_point(p2)
	get_parent().add_child(line)
	
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(line.queue_free)
