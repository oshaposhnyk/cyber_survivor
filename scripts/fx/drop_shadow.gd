extends Sprite2D

# Drop shadow for a single large actor (player, boss). Copies the sibling body sprite
# and keeps a fixed world-space offset while the parent rotates.
# Swarm enemies do this inline in EnemyBase to avoid one _process call per enemy.

@export var source_path: NodePath = ^"../Sprite2D"
@export var world_offset: Vector2 = Vector2(14, 22)
@export var opacity: float = 0.45

var _source: Sprite2D

func _ready() -> void:
	_source = get_node_or_null(source_path)
	modulate = Color(0, 0, 0, opacity)
	show_behind_parent = true
	get_parent().move_child.call_deferred(self, 0)

func _process(_delta: float) -> void:
	if _source:
		texture = _source.texture
		scale = _source.scale
		rotation = _source.rotation
	position = world_offset.rotated(-get_parent().global_rotation)
