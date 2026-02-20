extends PathFollow2D

signal swing_complete()

var speed = 200



func _ready():
	pass

func _process(delta):
	progress += delta * speed
	if progress_ratio == 1:
		emit_signal("swing_complete")
	
