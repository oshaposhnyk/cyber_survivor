extends Area2D

@export var speed: float = 380.0
@export var damage: float = 12.0
@export var lifetime: float = 3.0

var velocity: Vector2 = Vector2.ZERO

func setup(p_pos: Vector2, p_dir: Vector2, p_damage: float) -> void:
	global_position = p_pos
	velocity = p_dir.normalized() * speed
	rotation = p_dir.angle() + PI / 2.0
	damage = p_damage

func _ready() -> void:
	collision_layer = 8 # Layer 4: EnemyProjectiles
	collision_mask = 1  # Layer 1: Player

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
