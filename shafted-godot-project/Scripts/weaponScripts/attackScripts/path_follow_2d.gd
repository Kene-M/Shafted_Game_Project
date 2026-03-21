extends PathFollow2D

signal swing_complete()

var speed = 200



func _ready():
	$Sprite2D.texture = get_parent().texture
	$Sprite2D.rotation = -45
	$Sprite2D.scale = Vector2(1.5, 1.5)

func _process(delta):
	progress += delta * speed
	if progress_ratio == 1:
		emit_signal("swing_complete")
	
