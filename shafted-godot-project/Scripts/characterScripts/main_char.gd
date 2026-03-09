extends CharacterBody2D
@export var speed = 0
@export var min_speed = 0
@export var max_speed = 0
@export var dash_speed = 0
@export var cur_direction = Vector2(0,0)
@export var dash_ticks = 0
@export var pre_dash_speed = 0
@export var ranged_weapons = ["none"]
@export var melee_weapons = ["none"]
@export var augments = []
@export var augment_vals = {
	AugType.Type.ATKADD: 0,
	AugType.Type.ATKMULT: 1,
	AugType.Type.HPADD: 0,
	AugType.Type.HPMULT: 1
}
@onready var ranged_weapon = "none"
@onready var melee_weapon = "none"

signal update_speed(speed: Vector2)
signal fire_projectile(direction: Vector2, augment_vals: Dictionary)

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
		fire_projectile.emit(dir_vector, augment_vals)
	
	if (Input.is_action_just_pressed("equipWeaponOne")):
		if melee_weapon == "none":
			pass
		else:
			var weapon = $Weapon
			var temp_lab = $TempWeaponLabel
			var weapon_script = load(melee_weapon)
			weapon.set_script(weapon_script)
			weapon.init()
			temp_lab.text = str(melee_weapon)
	if (Input.is_action_just_pressed("equipWeaponTwo")):
		if ranged_weapon == "none":
			pass
		else:
			var weapon = $Weapon
			var temp_lab = $TempWeaponLabel
			var weapon_script = load(ranged_weapon)
			weapon.set_script(weapon_script)
			weapon.init()
			temp_lab.text = str(ranged_weapon)
	
			
		
func _modify_augment_vals(aug: Augment, sub_val: bool):
	print("Modify Call")
	var temp_data = aug.data
	if sub_val == true:
		temp_data = -temp_data
	augment_vals[aug.type] += temp_data

func _on_area_2d_area_entered(area: Area2D) -> void:
	print("AREA ENTERED")
	match area.item_type:
		"Melee_Weapon":
			if melee_weapons.has(area.item_data) == false:
				melee_weapon = area.item_data
				melee_weapons.append(area.item_data)	
				
		"Ranged_Weapon":
			if ranged_weapons.has(area.item_data) == false:
				ranged_weapon = area.item_data
				ranged_weapons.append(area.item_data)
		"Augment":
			augments.append(area.aug)
			_modify_augment_vals(area.aug, false)
		_:
			pass
		
		
	


func _on_control_weapon_selected(path: String) -> void:
	var weapon = $Weapon
	var temp_lab = $TempWeaponLabel
	if path == "none":
		weapon.set_script(null)
		temp_lab.text = "none"
	else:
		var weapon_script = load(path)
		weapon.set_script(weapon_script)
		weapon.init()
		temp_lab.text = path
		
