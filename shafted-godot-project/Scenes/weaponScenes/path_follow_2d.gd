extends PathFollow2D

signal thrust_complete()

var speed = 200



func _ready():
	$Sprite2D.texture = get_parent().texture
	$Sprite2D.rotation = -45
	$Sprite2D.scale = Vector2(2, 2)

func _process(delta):
	progress += delta * speed
	if progress_ratio == 1:
		emit_signal("thrust_complete")
	
