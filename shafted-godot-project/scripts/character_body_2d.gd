extends CharacterBody2D
@export var speed = 300
@export var cur_direction = Vector2(0,0)
@export var dash_ticks = 0
@export var pre_dash_speed = 0

signal update_speed(speed: Vector2)
signal fire_projectile(direction: Vector2)

func _physics_process(delta):
	var direction = Input.get_vector("left","right","up","down")
	if (direction != Vector2(0,0)):
		cur_direction = direction
		if (speed < 700):
			speed += 80
		if (dash_ticks != 0):
			dash_ticks -= 1
			if dash_ticks == 60:
				speed = pre_dash_speed
			elif dash_ticks > 60:
				speed = 3000
		elif Input.is_action_just_pressed("dash"):
			dash_ticks = 70
			pre_dash_speed = speed
			speed = 3000
		velocity = direction * speed
	if (direction == Vector2(0,0)) and (speed > 300):
		speed -= 80
		velocity = cur_direction * speed
	elif (direction == Vector2(0,0)) and (speed <= 300):
		velocity = Vector2(0,0)
	
		
		
	update_speed.emit(velocity)
	move_and_slide()
	
	if (Input.is_action_just_pressed("fire")):
		var mouse_pos = get_global_mouse_position()
		var dir_vector = global_position.direction_to(mouse_pos)
		fire_projectile.emit(dir_vector)
		
