extends Node2D
@export var proj_speed = 1000

func _ready():
	var char = preload("res://Scenes/characterScenes/main_char.tscn")
	var char_inst = char.instantiate()
	char_inst.global_position = Vector2(0,0)
	char_inst.name = "PlayerChar"
	char_inst.min_speed = 50
	char_inst.max_speed = 300
	char_inst.dash_speed = 1000
	char_inst.scale = Vector2(0.4,0.4)
	add_child(char_inst)
	char_inst.connect("update_speed", _on_update_speed)
	

	

	

func _on_update_speed(speed) -> void:
	pass
	
