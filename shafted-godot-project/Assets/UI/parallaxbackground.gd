extends ParallaxBackground

@export var scroll_speed: float = 60.0

func _process(delta: float) -> void:
	scroll_offset.x += scroll_speed * delta
