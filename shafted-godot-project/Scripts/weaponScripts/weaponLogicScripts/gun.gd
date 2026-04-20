extends Node2D

func _ready() -> void:
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	
func init():
	var parent = get_parent()
	parent.connect("fire_projectile", _on_fire_projectile)
	var sprite = $"../AnimatedSprite2D/Sprite2D2"
	#var texture = load("res://Assets/Player/sword.png")
	#var new_atlas_texture := AtlasTexture.new()
	#new_atlas_texture.atlas = texture
	#new_atlas_texture.region = Rect2(901, 528, 998, 700)
	var texture = load("res://Assets/Player/testrifle.png")
	var char = get_parent()
	char.cur_run = "no_arms_run"
	if $"../AnimatedSprite2D".animation == "run":
		$"../AnimatedSprite2D".play(char.cur_run)
	sprite.visible = true
	sprite.texture = texture
	sprite.scale = Vector2(3.9, 3.9)
	if $"../AnimatedSprite2D".flip_h == false:
		sprite.position = Vector2(3, 9)
	else:
		sprite.position = Vector2(-3, 9)
	sprite.rotation = 0

func _on_fire_projectile(direction, augment_vals) -> void:
	print("Proj Fire")
	var projectile = preload("res://Scenes/weaponScenes/projectile.tscn")
	var proj_inst = projectile.instantiate()
	var char = get_parent()
	proj_inst.global_position = char.global_position
	get_tree().current_scene.add_child(proj_inst)
	proj_inst.direction = direction
	proj_inst.speed = 1000
	proj_inst.base_damage = (60 + augment_vals[AugType.Type.ATKADD]) * augment_vals[AugType.Type.ATKMULT]
	proj_inst.crit_damage = 1.5
	proj_inst.crit_chance = 0.25
	await get_tree().create_timer(1).timeout
	if is_instance_valid(proj_inst):
		proj_inst.queue_free()
