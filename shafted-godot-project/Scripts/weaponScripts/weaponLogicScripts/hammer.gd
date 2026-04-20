extends Node2D
var texture = load("res://Assets/Player/brown_greathammer.png")
var last_used = 0



	
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	var sprite = $"../AnimatedSprite2D/Sprite2D2"
	sprite.visible = true
	sprite.texture = texture
	sprite.scale = Vector2(6,6)
	var char = get_parent()
	char.cur_run = "run"
	if $"../AnimatedSprite2D".animation == "no_arms_run":
		$"../AnimatedSprite2D".play(char.cur_run)
	if $"../AnimatedSprite2D".flip_h == false:
		sprite.position = Vector2(37, 11)
	else:
		sprite.position = Vector2(-37, 11)
	print("INIT SWORD POS: ", sprite.position)
	sprite.rotation = 0

func _on_fire_projectile(direction, augment_vals) -> void:
	print(Time.get_ticks_msec() - last_used)
	if (Time.get_ticks_msec() - last_used > 1000) or last_used == 0:
		last_used = Time.get_ticks_msec()
		var sprite = $"../AnimatedSprite2D/Sprite2D2"
		var player = Autoload.main_char
		var swing = preload("res://Scenes/weaponScenes/slam_path_2d.tscn")
		var swing_inst = swing.instantiate()
		var anim_sprite = $"../AnimatedSprite2D"
		anim_sprite.play("attack")
		swing_inst.attack_complete.connect(_on_attack_complete)
		swing_inst.base_damage =  (300 + augment_vals[AugType.Type.ATKADD]) * augment_vals[AugType.Type.ATKMULT]
		swing_inst.crit_damage = 2
		swing_inst.crit_chance = 0.30
		swing_inst.texture = texture
		var char = get_parent()
		swing_inst.global_position = char.global_position
		get_tree().current_scene.add_child(swing_inst)
		sprite.visible = false
		swing_inst.rotation = direction.angle()
	
func _on_attack_complete():
	var sprite = $"../AnimatedSprite2D/Sprite2D2"
	sprite.visible = true
