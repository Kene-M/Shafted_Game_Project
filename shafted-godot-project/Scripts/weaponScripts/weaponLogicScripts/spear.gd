extends Node2D
var texture = load("res://Assets/Player/purple_spear2.png")


func _ready() -> void:
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	var sprite = $Sprite2D2
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)
	sprite.rotation = 0

func _on_fire_projectile(direction, augment_vals) -> void:
	var sprite = $Sprite2D2
	var player = Autoload.main_char
	var thrust = preload("res://Scenes/weaponScenes/thrust_path_2d.tscn")
	var thrust_inst = thrust.instantiate()
	var anim_sprite = $"../AnimatedSprite2D"
	anim_sprite.play("attack")
	thrust_inst.attack_complete.connect(_on_attack_complete)
	thrust_inst.base_damage =  (100 + augment_vals[AugType.Type.ATKADD]) * augment_vals[AugType.Type.ATKMULT]
	thrust_inst.crit_damage = 2
	thrust_inst.crit_chance = 0.30
	thrust_inst.texture = texture
	var char = get_parent()
	add_child(thrust_inst)
	sprite.visible = false
	thrust_inst.rotation = direction.angle()
	
func _on_attack_complete():
	var sprite = $Sprite2D2
	sprite.visible = true
