extends Node2D

@export var damage: float = 120.0
@export var beam_length: float = 1200.0
@export var beam_width: float = 12.0

var direction: Vector2 = Vector2.RIGHT
var alpha: float = 1.0

func setup(p_origin: Vector2, p_direction: Vector2, p_damage: float) -> void:
	global_position = p_origin
	direction = p_direction.normalized()
	damage = p_damage
	
	# Detect all enemies intersecting the beam line
	var space_state = get_world_2d().direct_space_state
	var end_point = p_origin + direction * beam_length
	
	# Query all intersecting bodies in Layer 2 (Enemies)
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = SegmentShape2D.new()
	shape.a = Vector2.ZERO
	shape.b = direction * beam_length
	query.shape = shape
	query.collision_mask = 2 # Enemies
	query.transform = Transform2D(0.0, p_origin)
	
	var results = space_state.intersect_shape(query, 64)
	var hit_list: Array[Node2D] = []
	for res in results:
		var collider = res.collider
		if collider and collider.is_in_group("enemies") and collider not in hit_list:
			hit_list.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(damage, direction)
				
	AudioManager.play_sfx("railgun", 0.1)

func _ready() -> void:
	z_index = 15
	var tween = create_tween()
	tween.tween_property(self, "alpha", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var end_pt = direction * beam_length
	# Outer glow
	var glow_col = Color(0.1, 1.0, 0.6, alpha * 0.7)
	draw_line(Vector2.ZERO, end_pt, glow_col, beam_width)
	# Inner bright core
	var core_col = Color(1.0, 1.0, 1.0, alpha * 0.95)
	draw_line(Vector2.ZERO, end_pt, core_col, beam_width * 0.4)
