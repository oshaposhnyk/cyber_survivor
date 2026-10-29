extends Area2D

# Quantum Core Boss Drop (Giant Experience Cache)
# Gives massive experience (+500 XP) and triggers celebratory cyber fanfare

var target_player: Node2D = null
var is_attracted: bool = false
var move_speed: float = 380.0
var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("pickups")
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	queue_redraw()
	
	if is_attracted and is_instance_valid(target_player):
		var dir = (target_player.global_position - global_position).normalized()
		global_position += dir * move_speed * delta
		move_speed += 400.0 * delta
		
		if global_position.distance_to(target_player.global_position) < 28.0:
			collect()
	else:
		rotation += delta * 2.0

func _draw() -> void:
	# Glowing aura and diffraction burst
	var pulse = 0.8 + 0.25 * sin(pulse_time)
	var rad = 28.0 * pulse
	draw_circle(Vector2.ZERO, rad, Color(1.0, 0.85, 0.2, 0.3))
	draw_arc(Vector2.ZERO, rad + 4.0, 0, TAU, 24, Color(0.2, 0.9, 1.0, 0.7), 2.5)
	
	# Core diffraction star spikes
	for i in range(4):
		var ang = pulse_time * 0.5 + float(i) * (PI / 2.0)
		var p1 = Vector2(cos(ang), sin(ang)) * (rad + 12.0)
		draw_line(Vector2.ZERO, p1, Color(1.0, 1.0, 1.0, 0.8), 2.0)

func attract(player_node: Node2D) -> void:
	target_player = player_node
	is_attracted = true

func collect() -> void:
	# Massive 500 XP boost
	GameManager.add_scrap(500)
	AudioManager.play_sfx("victory", 0.05, 2.0)
	
	# Big floating text announcement
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(0, -35)
	get_parent().add_child(ft)
	ft.setup("+++ КВАНТОВЕ ЯДРО: +500 ДОСВІДУ! +++", Color(1.0, 0.85, 0.2), 2.2)
	
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()
