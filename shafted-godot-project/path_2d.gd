extends Path2D
@export var base_damage: int = 0
@export var crit_damage: float = 1
@export var crit_chance: float = 0

signal attack_complete()

func _on_path_follow_2d_2_swing_complete() -> void:
	emit_signal("attack_complete")
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var cur_damage = base_damage
		var crit = false
		var crit_check: float = randf()
		if crit_check <= crit_chance:
			crit = true
			cur_damage *= crit_damage
		body.take_damage(cur_damage, crit, global_position)
