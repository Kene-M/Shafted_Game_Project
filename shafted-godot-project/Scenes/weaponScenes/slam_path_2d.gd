extends Path2D

@export var base_damage: int = 0
@export var crit_damage: float = 1
@export var crit_chance: float = 0
@export var texture: Texture2D

signal attack_complete()

func _on_path_follow_2d_slam_complete() -> void:
	emit_signal("attack_complete")
	$PathFollow2D/Sprite2D.visible = false
	$Area2D/AnimatedSprite2D.visible = true
	$Area2D/AnimatedSprite2D.play("default")
	$Area2D/CollisionShape2D.set_deferred("disabled", false)
	await get_tree().create_timer(1.0).timeout
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	print("SLAM AREA TEST")
	if body.has_method("take_damage"):
		var cur_damage = base_damage
		var crit = false
		var crit_check: float = randf()
		if crit_check <= crit_chance:
			crit = true
			cur_damage *= crit_damage
		body.take_damage(cur_damage, crit, global_position)


func _on_animated_sprite_2d_animation_finished() -> void:
	$Area2D/AnimatedSprite2D.visible = false
