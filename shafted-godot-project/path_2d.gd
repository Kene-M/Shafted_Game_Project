extends Path2D
@export var base_damage: int = 0

signal attack_complete()

func _on_path_follow_2d_2_swing_complete() -> void:
	emit_signal("attack_complete")
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(base_damage, false)
