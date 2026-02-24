extends AnimatableBody2D
@export var speed = 0
@export var direction = Vector2(0,0)
@export var base_damage: int = 0
@onready var sprite = $Sprite2D

func _physics_process(delta: float) -> void:
	position += (direction * speed) * delta


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(base_damage, false)
	queue_free()
