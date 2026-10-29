extends Area2D

@export var orbit_radius: float = 100.0
@export var orbit_speed: float = 2.4
@export var contact_damage: float = 40.0
@export var fire_cooldown: float = 0.95

var player: Node2D = null
var current_angle: float = 0.0
var shoot_timer: float = 0.0
var is_bastion: bool = false
# Doctrine damage multiplier, set by the player when drones are rebuilt
var damage_mult: float = 1.0
var pulse_time: float = 0.0

# --- Visual-only ---
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const SPARK_TEX := preload("res://assets/sprites/fx/spark_star.png")
const EMBERS := 3
var shot_flash: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func setup(p_player: Node2D, p_initial_angle: float, p_bastion: bool = false) -> void:
	player = p_player
	current_angle = p_initial_angle
	is_bastion = p_bastion
	if is_bastion:
		contact_damage *= 1.6
		orbit_radius *= 1.25

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
		
	pulse_time += delta * 4.0
	if shot_flash > 0.0:
		shot_flash = maxf(0.0, shot_flash - delta * 8.0)
	current_angle += orbit_speed * delta
	var target_pos = player.global_position + Vector2(cos(current_angle), sin(current_angle)) * orbit_radius
	global_position = target_pos
	rotation = current_angle + PI / 2.0
	
	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = fire_cooldown
		shoot_at_nearest_enemy()
		
	queue_redraw()

func _draw() -> void:
	# 1. Micro-thruster plume at the back of the drone (additive via node material)
	var plume_len = randf_range(6.0, 12.0)
	var plume_col = Color(0.2, 0.9, 1.0, 0.85) if not is_bastion else Color(0.2, 1.0, 0.5, 0.9)
	draw_line(Vector2(0, 10), Vector2(0, 10 + plume_len), plume_col, 3.0)
	draw_circle(Vector2(0, 10 + plume_len * 0.4), 2.5, Color(1, 1, 1, 0.9))
	if shot_flash > 0.0:
		var fs := 34.0 * shot_flash
		draw_texture_rect(GLOW_TEX, Rect2(Vector2(0, -12) - Vector2(fs, fs) * 0.5, Vector2(fs, fs)), false, Color(plume_col, shot_flash))

	# 2. Nanite Bastion: each drone draws its share of one burning ring around the player
	if is_bastion and is_instance_valid(player):
		_draw_bastion_ring()

func _draw_bastion_ring() -> void:
	var c := to_local(player.global_position)
	var n: int = maxi(1, player.spawned_drones.size()) if "spawned_drones" in player else 1
	var span := TAU / float(n)
	# Global angle phi maps to local angle phi - rotation; this drone sits at current_angle
	var mid := current_angle - rotation
	var a0 := mid - span * 0.5
	var a1 := mid + span * 0.5 + 0.02
	var pulse := 0.5 + 0.5 * sin(pulse_time)
	var r := orbit_radius
	# Outer haze (synergy magenta), burning body (nanite green), white-hot core
	draw_arc(c, r, a0, a1, 24, Color(1.0, 0.3, 0.85, 0.14 + 0.08 * pulse), 20.0)
	draw_arc(c, r, a0, a1, 24, Color(0.15, 1.0, 0.45, 0.6 + 0.25 * pulse), 9.0)
	draw_arc(c, r, a0, a1, 24, Color(0.7, 1.0, 0.75, 0.7), 2.0)
	# Embers drifting along the ring: deterministic, no per-ember state
	for i in EMBERS:
		var t := fmod(pulse_time * 0.15 + float(i) / EMBERS, 1.0)
		var ang := a0 + span * t
		var wob := sin(pulse_time * 2.0 + i * 1.7) * 6.0
		var p := c + Vector2(cos(ang), sin(ang)) * (r + wob)
		var es := 10.0 + 6.0 * sin(pulse_time + i)
		draw_texture_rect(SPARK_TEX, Rect2(p - Vector2(es, es) * 0.5, Vector2(es, es)), false, Color(0.6, 1.0, 0.7, 0.9))
	# Faint tether so each drone still reads as linked to the ship
	draw_line(Vector2.ZERO, c, Color(0.2, 1.0, 0.6, 0.12 + 0.1 * pulse), 1.5)

func shoot_at_nearest_enemy() -> void:
	var found = EnemyRegistry.nearest(global_position, 1, 380.0)
	var closest_enemy: Node2D = found[0] if found.size() > 0 else null

	if closest_enemy:
		var dir = (closest_enemy.global_position - global_position).normalized()
		var bolt_scene = preload("res://scenes/weapons/blaster_bolt.tscn")
		var bolt = bolt_scene.instantiate()
		bolt.setup(global_position, dir, 22.0 * damage_mult, 1, false)
		get_parent().add_child(bolt)
		shot_flash = 1.0
		# Silent drone fire to prevent audio clutter

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		var push = (body.global_position - global_position).normalized()
		body.take_damage(contact_damage * damage_mult, push)
