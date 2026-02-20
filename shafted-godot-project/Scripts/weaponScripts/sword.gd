extends Node2D



func _ready() -> void:
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)

func _on_fire_projectile(direction) -> void:
	var swing = load("res://Scenes/swing_path_2d.tscn")
	var swing_inst = swing.instantiate()
	var char = get_parent()
	add_child(swing_inst)
	swing_inst.rotation = direction.angle()
	#await get_tree().create_timer(1).timeout
