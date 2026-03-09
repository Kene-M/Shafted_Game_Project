extends Node2D



func _ready() -> void:
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)

func _on_fire_projectile(direction, augment_vals) -> void:
	var sprite = $Sprite2D2
	var swing = preload("res://Scenes/swing_path_2d.tscn")
	var swing_inst = swing.instantiate()
	swing_inst.attack_complete.connect(_on_attack_complete)
	swing_inst.base_damage =  (100 + augment_vals[AugType.Type.ATKADD]) * augment_vals[AugType.Type.ATKMULT]
	swing_inst.crit_damage = 2
	swing_inst.crit_chance = 0.30
	var char = get_parent()
	add_child(swing_inst)
	sprite.visible = false
	swing_inst.rotation = direction.angle()
	
func _on_attack_complete():
	var sprite = $Sprite2D2
	sprite.visible = true
	
	
