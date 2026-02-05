extends AnimatableBody2D
@export var speed = 0
@export var direction = Vector2(0,0)
@onready var sprite = $Sprite2D

func _physics_process(delta: float) -> void:
	position += (direction * speed) * delta
