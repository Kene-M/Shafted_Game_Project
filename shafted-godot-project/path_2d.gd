extends Path2D

signal attack_complete()

func _on_path_follow_2d_2_swing_complete() -> void:
	emit_signal("attack_complete")
	queue_free()
