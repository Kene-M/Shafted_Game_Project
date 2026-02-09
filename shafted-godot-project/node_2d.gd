extends Node2D
@onready var label = $Label
@onready var label2 = $Label2
@onready var char = $CharacterBody2D
@export var proj_speed = 1000

func _ready():
	char.connect("update_speed", _on_update_speed)
	char.connect("fire_projectile", _on_fire_projectile)
	label.text = "0"
	var projectile = preload("res://projectile.tscn")
	var proj_inst = projectile.instantiate()
	proj_inst.global_position = Vector2(0,0)
	add_child(proj_inst)

	

func _on_update_speed(speed) -> void:
	label.text = str(speed)
	
func _on_fire_projectile(direction) -> void:
	label2.text = "_on_fire_projectile called"
	var projectile = preload("res://projectile.tscn")
	var proj_inst = projectile.instantiate()
	proj_inst.global_position = char.position
	add_child(proj_inst)
	proj_inst.direction = direction
	proj_inst.speed = 1000
	await get_tree().create_timer(1).timeout
	proj_inst.queue_free()
