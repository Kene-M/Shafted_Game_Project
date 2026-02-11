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
	char_inst.connect("fire_projectile", _on_fire_projectile)

	var projectile = preload("res://scenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	proj_inst.global_position = Vector2(0,0)
	add_child(proj_inst)

	

func _on_update_speed(speed) -> void:
	pass
	
func _on_fire_projectile(direction) -> void:
	var projectile = preload("res://scenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	var char = get_node("PlayerChar")
	proj_inst.global_position = char.position
	add_child(proj_inst)
	proj_inst.direction = direction
	proj_inst.speed = 1000
	await get_tree().create_timer(1).timeout
	proj_inst.queue_free()
