extends Area2D

# Magnet Beacon Super-Pickup
# Dropped by Champion Bots. Pulls ALL scrap on the entire battlefield to the player!

var target_player: Node2D = null
var is_attracted: bool = false
var move_speed: float = 340.0
var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse_time += delta * 4.5
	queue_redraw()
	
	if is_attracted and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * move_speed * delta
		move_speed += 360.0 * delta
		if global_position.distance_to(target_player.global_position) < 24.0:
			collect()
	else:
		rotation += delta * 2.2

func _draw() -> void:
	var pulse = 0.85 + 0.25 * sin(pulse_time * 2.0)
	var rad = 24.0 * pulse
	
	# 1. Swirling Gravitational Rings
	draw_arc(Vector2.ZERO, rad + 6.0, 0, TAU, 24, Color(0.2, 0.9, 1.0, 0.5), 1.5)
	draw_arc(Vector2.ZERO, rad * 0.6, 0, TAU, 18, Color(0.9, 0.3, 1.0, 0.6), 1.5)
	
	# 2. Counter-Rotating Cyber Diamond
	var rot_d = pulse_time * 1.5
	var d_pts = PackedVector2Array([
		Vector2(0, -rad).rotated(rot_d),
		Vector2(rad * 0.75, 0).rotated(rot_d),
		Vector2(0, rad).rotated(rot_d),
		Vector2(-rad * 0.75, 0).rotated(rot_d)
	])
	draw_polygon(d_pts, PackedColorArray([Color(0.4, 0.1, 0.9, 0.35)]))
	draw_polyline(d_pts, Color(0.2, 0.95, 1.0, 0.9), 2.2)
	draw_line(d_pts[3], d_pts[0], Color(0.2, 0.95, 1.0, 0.9), 2.2)
	
	# 3. Orbiting Gravitational Influx Motes
	for i in range(4):
		var ma = -pulse_time * 3.0 + float(i) * (PI * 0.5)
		var mote_r = lerpf(rad + 12.0, rad * 0.4, fmod(pulse_time * 1.2 + i * 0.25, 1.0))
		var mp = Vector2(cos(ma), sin(ma)) * mote_r
		draw_circle(mp, 2.2, Color(1.0, 1.0, 1.0, 0.85))
		
	# 4. Pure White Quantum Nucleus
	draw_circle(Vector2.ZERO, rad * 0.32, Color(1.0, 1.0, 1.0, 0.95))

func attract(player_node: Node2D) -> void:
	target_player = player_node
	is_attracted = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target_player = body
		collect()

func collect() -> void:
	# Magnetize ALL pickups in the scene!
	var player = target_player if is_instance_valid(target_player) else GameManager.player_node
	if is_instance_valid(player):
		var pickups = get_tree().get_nodes_in_group("pickups")
		for p in pickups:
			if is_instance_valid(p) and p != self and p.has_method("attract"):
				p.attract(player)
				
	AudioManager.play_sfx("emp_blast", 0.08, 3.0)
	
	# Full-screen HUD cyan flash
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("_flash_edges"):
		hud._flash_edges(Color(0.2, 0.95, 1.0), 0.7)
	
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(0, -25)
	get_parent().add_child(ft)
	ft.setup("ГРАВІ-МАГНІТ: ВЕСЬ БРУХТ ЗІБРАНО!", Color(0.2, 0.95, 1.0), 2.0)
	
	queue_free()
