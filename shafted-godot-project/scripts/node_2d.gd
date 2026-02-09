extends Node2D
@onready var label = $Label
@onready var label2 = $Label2
@export var proj_speed = 1000

func _ready():
	var char = preload("res://scenes/character_body_2d.tscn")
	var char_inst = char.instantiate()
	char_inst.global_position = Vector2(0,0)
	char_inst.name = "PlayerChar"
	add_child(char_inst)
	char_inst.connect("update_speed", _on_update_speed)
	char_inst.connect("fire_projectile", _on_fire_projectile)
	label.text = "0"
	var projectile = preload("res://scenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	proj_inst.global_position = Vector2(0,0)
	add_child(proj_inst)

	

func _on_update_speed(speed) -> void:
	label.text = str(speed)
	
func _on_fire_projectile(direction) -> void:
	label2.text = "_on_fire_projectile called"
	var projectile = preload("res://scenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	var char = get_node("PlayerChar")
	proj_inst.global_position = char.position
	add_child(proj_inst)
	proj_inst.direction = direction
	proj_inst.speed = 1000
	await get_tree().create_timer(1).timeout
	proj_inst.queue_free()
