extends Sprite2D

@onready var parent_sprite = $"../AnimatedSprite2D"

func _process(delta):
	global_position = parent_sprite.global_position
