extends PathFollow2D

signal slam_complete()

var min_speed = 100
var speed = 100
var max_speed = 300
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
	progress += delta * speed
	if progress_ratio == 1:
		emit_signal("slam_complete")
