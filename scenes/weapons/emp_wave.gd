extends Node2D

@export var max_radius: float = 240.0
@export var damage: float = 60.0
@export var stun_duration: float = 2.5
@export var is_apocalypse: bool = false

var current_radius: float = 0.0
var alpha: float = 1.0
var hit_enemies: Array[Node2D] = []

func setup(p_origin: Vector2, p_radius: float, p_damage: float, p_stun: float, p_apocalypse: bool = false) -> void:
	global_position = p_origin
	max_radius = p_radius
	damage = p_damage
	stun_duration = p_stun
	is_apocalypse = p_apocalypse
	if is_apocalypse:
		max_radius = 800.0 # Screen-wide
		damage *= 2.0
		stun_duration = 4.0

func _ready() -> void:
	z_index = 12
	AudioManager.play_sfx("emp_blast", 0.05, 3.0 if is_apocalypse else 0.0)
	
	var duration = 0.55 if not is_apocalypse else 0.8
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_radius", max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "alpha", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _physics_process(_delta: float) -> void:
	queue_redraw()
	
	# Detect enemies inside current wave radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= current_radius:
			hit_enemies.append(enemy)
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(stun_duration)
			if enemy.has_method("take_damage"):
				var push = (enemy.global_position - global_position).normalized()
				enemy.take_damage(damage, push)

func _draw() -> void:
	var ring_col = Color(0.9, 0.2, 1.0, alpha) if not is_apocalypse else Color(1.0, 0.2, 0.6, alpha)
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 48, ring_col, 5.0)
	var fill_col = Color(ring_col.r, ring_col.g, ring_col.b, alpha * 0.15)
	draw_circle(Vector2.ZERO, current_radius, fill_col)
