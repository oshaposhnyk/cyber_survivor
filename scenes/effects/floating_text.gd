extends Node2D

@onready var label: Label = $Label

func setup(text: String, color: Color = Color.WHITE, scale_factor: float = 1.0) -> void:
	if not is_inside_tree():
		await ready
	label.text = text
	label.modulate = color
	scale = Vector2(scale_factor, scale_factor)
	
	var tween = create_tween().set_parallel(true)
	# Float upward
	tween.tween_property(self, "position:y", position.y - 45.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + randf_range(-15.0, 15.0), 0.75)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
