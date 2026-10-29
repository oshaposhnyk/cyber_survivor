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
	var pulse = 0.85 + 0.25 * sin(pulse_time)
	var rad = 22.0 * pulse
	# Rotating cyan & purple diamond
	var col = Color(0.2, 0.9, 1.0, 0.8)
	var pts = PackedVector2Array([
		Vector2(0, -rad), Vector2(rad * 0.8, 0), Vector2(0, rad), Vector2(-rad * 0.8, 0)
	])
	draw_polygon(pts, PackedColorArray([Color(0.5, 0.2, 1.0, 0.35)]))
	draw_polyline(pts, col, 2.5)
	draw_line(Vector2(-rad * 0.8, 0), Vector2(0, -rad), col, 2.5)
	draw_circle(Vector2.ZERO, rad * 0.35, Color(1.0, 1.0, 1.0, 0.9))

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
	
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(0, -25)
	get_parent().add_child(ft)
	ft.setup("ГРАВІ-МАГНІТ: ВЕСЬ БРУХТ ЗІБРАНО!", Color(0.2, 0.9, 1.0), 2.0)
	
	queue_free()
