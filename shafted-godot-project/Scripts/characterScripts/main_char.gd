extends CharacterBody2D
@export var min_speed = 0
@export var max_speed = 0
@export var dash_speed = 0
@export var cur_direction = Vector2(0,0)
@export var max_dash_ticks = 0
@export var pre_dash_speed = 0
@export var ranged_weapons = []
@export var melee_weapons = []
@export var augments = []
@export var augment_vals = {
	AugType.Type.ATKADD: 0,
	AugType.Type.ATKMULT: 1,
	AugType.Type.HPADD: 1000,
	AugType.Type.HPMULT: 1,
	AugType.Type.SPDADD: 300
}
@onready var resource_inv: Array = [0,0,0,0,0]
@onready var ranged_weapon
@onready var melee_weapon
@onready var in_item_area = false
@onready var cur_item_area = null
@onready var max_health: float = 1000
@onready var cur_health: float = 1000
@onready var knockback_velocity: Vector2 = Vector2.ZERO
@onready var knockback_strength: float = 50
@onready var dash_ticks = 0
@onready var speed = 0

signal update_speed(speed: Vector2)
signal fire_projectile(direction: Vector2, augment_vals: Dictionary)


func _ready() -> void:
	$AnimatedSprite2D.play("default")
	max_health = augment_vals[AugType.Type.HPADD]
	var no_weapon = WeaponResource.new()
	no_weapon.weapon_name = "No Weapon"
	no_weapon.weapon_script = "res://Scripts/weaponScripts/weaponLogicScripts/no_weapon.gd"
	ranged_weapons.append(no_weapon)
	melee_weapons.append(no_weapon)
	ranged_weapon = no_weapon
	melee_weapon = no_weapon
	Autoload.main_char = self
	$TempHealthNum.text = str(max_health)

func _physics_process(delta):
	max_health = augment_vals[AugType.Type.HPADD]
	max_speed = augment_vals[AugType.Type.SPDADD]
	$TempHealthNum.text = str(max_health)
	#Death Logic
	if (cur_health <= 0):
		var death_screen_scene = load("res://Scenes/death_menu.tscn")
		var death_screen_inst = death_screen_scene.instantiate()
		get_parent().add_child(death_screen_inst)
		queue_free()
	#Knockback Logic (written by Dhruv)
	if knockback_velocity.length() > 5.0:
		print("applying knockback: ", knockback_velocity)
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	else:
		knockback_velocity = Vector2.ZERO
		
	#Movement Logic
	#Get direction based on player input
	var direction = Input.get_vector("left","right","up","down")
	if (direction != Vector2(0,0)):
		if $AnimatedSprite2D.animation == "default":
			$AnimatedSprite2D.play("run")
		if direction.x < 0:
			$AnimatedSprite2D.flip_h = false
		else:
			$AnimatedSprite2D.flip_h = true
		cur_direction = direction
		if (speed < max_speed):
			speed += 80
		if (dash_ticks != 0):
			dash_ticks -= 1
			print(max_dash_ticks*0.75)
			if dash_ticks == (ceil(max_dash_ticks*(0.75))):
				speed = pre_dash_speed
			elif dash_ticks > (ceil(max_dash_ticks*(0.75))):
				speed = dash_speed
		elif Input.is_action_just_pressed("dash"):
			dash_ticks = max_dash_ticks
			pre_dash_speed = speed
			speed = dash_speed
		velocity = direction * speed
	if (direction == Vector2(0,0)) and (speed > min_speed):
		speed -= 80
		velocity = cur_direction * speed
	elif (direction == Vector2(0,0)) and (speed <= min_speed):
		velocity = Vector2(0,0)	
		if $AnimatedSprite2D.animation == "run":
			$AnimatedSprite2D.play("default")
	update_speed.emit(velocity)
	$temp_vel_label.text = str(velocity)
	move_and_slide()
	
	#Weapon Use Logic
	if (Input.is_action_just_pressed("fire")):
		var mouse_pos = get_global_mouse_position()
		var dir_vector = global_position.direction_to(mouse_pos)
		fire_projectile.emit(dir_vector, augment_vals)
	if (Input.is_action_just_pressed("equipWeaponOne")):
		var weapon = $Weapon
		var weapon_script = load(melee_weapon.weapon_script)
		weapon.set_script(weapon_script)
		weapon.init()
	if (Input.is_action_just_pressed("equipWeaponTwo")):
		var weapon = $Weapon
		var weapon_script = load(ranged_weapon.weapon_script)
		weapon.set_script(weapon_script)
		weapon.init()
	
	#Item Interaction Logic
	if ((in_item_area == true) and (Input.is_action_just_pressed("interact"))):
		match cur_item_area.item_type:
			"Melee_Weapon":
				if melee_weapons.has(cur_item_area.weapon_data) == false:
					melee_weapon = cur_item_area.weapon_data
					melee_weapons.append(cur_item_area.weapon_data)	
					cur_item_area.get_parent().queue_free()
					#cur_item_area = null
					#in_item_area = false
					#$InteractLabel.visible = true
			"Ranged_Weapon":
				if ranged_weapons.has(cur_item_area.weapon_data) == false:
					ranged_weapon = cur_item_area.weapon_data
					ranged_weapons.append(cur_item_area.weapon_data)
					cur_item_area.get_parent().queue_free()
					#cur_item_area = null
					#in_item_area = false
					#$InteractLabel.visible = true
			"Augment":
				augments.append(cur_item_area.aug)
				_modify_augment_vals(cur_item_area.aug, false)
				cur_item_area.get_parent().queue_free()
				#cur_item_area = null
				#in_item_area = false
				#$InteractLabel.visible = true
			"Resource":
				resource_inv[cur_item_area.type] += 1
				cur_item_area.get_parent().queue_free()
			_:
				#cur_item_area = null
				#in_item_area = false
				#$InteractLabel.visible = true
				pass
	
func take_damage(damage: float, source_position: Vector2 = Vector2.ZERO):
	cur_health -= damage
	$TempHealthBar.size = Vector2((cur_health / 10), $TempHealthBar.size.y)
	#Knockback logic (written by Dhruv)
	if source_position != Vector2.ZERO:
		var direction = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength
		print("knockback_velocity set to: ", knockback_velocity)
	else:
		print("knockback skipped - source_position is ZERO")			
		
func _modify_augment_vals(aug: Augment, sub_val: bool):
	print("Modify Call")
	var temp_data = aug.data
	if sub_val == true:
		temp_data = -temp_data
	augment_vals[aug.type] += temp_data

func _on_area_2d_area_entered(area: Area2D) -> void:
	$InteractLabel.visible = true
	in_item_area = true
	cur_item_area = area
		
func _on_area_2d_area_exited(area: Area2D) -> void:
	$InteractLabel.visible = false
	in_item_area = false
	cur_item_area = null		

func add_augment(aug: Augment):
	augments.append(aug)
	_modify_augment_vals(aug, false)
	
