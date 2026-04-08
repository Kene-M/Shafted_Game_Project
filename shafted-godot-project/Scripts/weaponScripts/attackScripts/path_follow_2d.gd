extends PathFollow2D

signal swing_complete()

var min_speed = 150
var speed = 150
var max_speed = 400


func _ready():
	$Sprite2D.texture = get_parent().texture
	$Sprite2D.rotation = -45
	$Sprite2D.scale = Vector2(1.5, 1.5)

func _process(delta):
	if progress_ratio <= 0.5:
		if speed < max_speed:
			speed += 35
	else:
		if speed > min_speed:
			speed -= 35
	progress += delta * speed
	if progress_ratio == 1:
		emit_signal("swing_complete")
	
