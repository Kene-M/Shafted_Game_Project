extends ColorRect
const max_x: float = 228.86

func _ready():
	Autoload.main_char.dash_changed.connect(_on_dash_changed)

func _on_dash_changed(max_ticks: float, ticks: float):
	var percent = (ticks/max_ticks)
	var sub_val = max_x * percent
	size.x = max_x - sub_val
