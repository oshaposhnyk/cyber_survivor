extends Node2D

@export var damage: float = 120.0
@export var beam_length: float = 1400.0
@export var beam_width: float = 16.0

var direction: Vector2 = Vector2.RIGHT
var alpha: float = 1.0
var beam_fired: bool = false

# Jagged lightning crackles along the beam
var lightning_segments: Array[Vector2] = []

func setup(p_origin: Vector2, p_direction: Vector2, p_damage: float) -> void:
	global_position = p_origin
	direction = p_direction.normalized()
	damage = p_damage
	if is_inside_tree() and not beam_fired:
		fire_beam()

func _ready() -> void:
	z_index = 18
	generate_lightning_arcs()
	if not beam_fired:
		fire_beam()
	var tween = create_tween()
	tween.tween_property(self, "alpha", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)

func generate_lightning_arcs() -> void:
	lightning_segments.clear()
	var steps = 18
	var step_len = beam_length / steps
	for i in range(steps + 1):
		var base_pt = direction * (i * step_len)
		var perp = Vector2(-direction.y, direction.x) * randf_range(-14.0, 14.0)
		lightning_segments.append(base_pt + perp)

func fire_beam() -> void:
	if beam_fired or not is_inside_tree():
		return
	beam_fired = true
	
	var world = get_world_2d()
	if not world:
		return
	var space_state = world.direct_space_state
	if not space_state:
		return
		
	# Raycast Query
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = SegmentShape2D.new()
	shape.a = Vector2.ZERO
	shape.b = direction * beam_length
	query.shape = shape
	query.collision_mask = 2 # Enemies
	query.transform = Transform2D(0.0, global_position)
	
	var results = space_state.intersect_shape(query, 128)
	var hit_list: Array[Node2D] = []
	for res in results:
		var collider = res.collider
		if collider and collider.is_in_group("enemies") and collider not in hit_list:
			hit_list.append(collider)
			if collider.has_method("take_damage"):
				collider.take_damage(damage, direction)
				
	AudioManager.play_sfx("railgun", 0.1)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var end_pt = direction * beam_length
	
	# 1. Broad outer energetic ionization aura
	var aura_col = Color(0.1, 1.0, 0.6, alpha * 0.4)
	draw_line(Vector2.ZERO, end_pt, aura_col, beam_width * 2.2)
	
	# 2. Main cyan/emerald beam glow
	var glow_col = Color(0.2, 0.95, 0.7, alpha * 0.85)
	draw_line(Vector2.ZERO, end_pt, glow_col, beam_width)
	
	# 3. Blinding white tachyon core
	var core_col = Color(1.0, 1.0, 1.0, alpha * 0.98)
	draw_line(Vector2.ZERO, end_pt, core_col, beam_width * 0.4)
	
	# 4. Crackling lightning arcs along the beam
	if lightning_segments.size() > 1:
		for i in range(lightning_segments.size() - 1):
			var p1 = lightning_segments[i]
			var p2 = lightning_segments[i+1]
			draw_line(p1, p2, Color(0.5, 1.0, 0.85, alpha * 0.9), 2.2)
			
	# 5. Expanding ring bursts along beam trajectory
	for i in range(1, 5):
		var ring_pos = direction * (i * (beam_length / 5.0))
		draw_arc(ring_pos, 16.0 * (1.5 - alpha), 0, TAU, 16, Color(0.2, 1.0, 0.7, alpha * 0.7), 2.0)
