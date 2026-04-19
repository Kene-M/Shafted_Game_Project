extends PathFollow2D

signal thrust_complete()

var min_speed = 250
var speed = 250
var max_speed = 500
var negative = false


func _ready():
	$Sprite2D.texture = get_parent().texture
	$Sprite2D.rotation = 44.8
	$Sprite2D.scale = Vector2(2.5, 2.5)

func _process(delta):
	if progress_ratio <= 0.5:
		if speed < max_speed:
			speed += 35
	else:
		if speed > min_speed:
			speed -= 35
	if !negative:
		progress += delta * speed
	else:
		progress -= delta * speed
	if progress_ratio == 1:
		negative = true
	elif progress_ratio <= 0.1 and negative == true:
		emit_signal("thrust_complete")
	
