extends Node2D

func _ready() -> void:
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)

func _on_fire_projectile(direction) -> void:
	var projectile = preload("res://scenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	var char = get_parent()
	add_child(proj_inst)
	proj_inst.direction = direction
	proj_inst.speed = 1000
	await get_tree().create_timer(1).timeout
	proj_inst.queue_free()
