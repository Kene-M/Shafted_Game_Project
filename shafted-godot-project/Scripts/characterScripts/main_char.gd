extends CharacterBody2D
@export var speed = 0
@export var min_speed = 0
@export var max_speed = 0
@export var dash_speed = 0
@export var cur_direction = Vector2(0,0)
@export var dash_ticks = 0
@export var pre_dash_speed = 0
@export var weapons = []

signal update_speed(speed: Vector2)
signal fire_projectile(direction: Vector2)

func _physics_process(delta):
	var direction = Input.get_vector("left","right","up","down")
	if (direction != Vector2(0,0)):
		cur_direction = direction
		if (speed < max_speed):
			speed += 80
		if (dash_ticks != 0):
			dash_ticks -= 1
			if dash_ticks == 60:
				speed = pre_dash_speed
			elif dash_ticks > 60:
				speed = dash_speed
		elif Input.is_action_just_pressed("dash"):
			dash_ticks = 70
			pre_dash_speed = speed
			speed = dash_speed
		velocity = direction * speed
	if (direction == Vector2(0,0)) and (speed > min_speed):
		speed -= 80
		velocity = cur_direction * speed
	elif (direction == Vector2(0,0)) and (speed <= min_speed):
		velocity = Vector2(0,0)
	
		
		
	update_speed.emit(velocity)
	move_and_slide()
	
	if (Input.is_action_just_pressed("fire")):
		var mouse_pos = get_global_mouse_position()
		var dir_vector = global_position.direction_to(mouse_pos)
		fire_projectile.emit(dir_vector)
	
	if (Input.is_action_just_pressed("equipWeaponOne")):
		if weapons.size() == 0:
			pass
		else:
			var weapon = $Weapon
			var temp_lab = $TempWeaponLabel
			var weapon_script = load(weapons[0])
			weapon.set_script(weapon_script)
			weapon.init()
			temp_lab.text = str(weapons[0])
			
		


func _on_area_2d_area_entered(area: Area2D) -> void:
	var type = type_string(typeof(area.item_data))
	if type == "String":
		weapons.append(area.item_data)
	
