extends ColorRect
const max_x: float = 487.0

func _ready():
	$"../../../../../GolemBoss".health_changed.connect(_on_health_changed)

func _on_health_changed(max_health: float, cur_health: float):
	var percent = (cur_health/max_health)
	var size_val = max_x * percent
	size.x = size_val
	print("H BAR SIZE: ", size.x)
