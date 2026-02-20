extends Path2D


func _on_path_follow_2d_2_swing_complete() -> void:
	queue_free()
