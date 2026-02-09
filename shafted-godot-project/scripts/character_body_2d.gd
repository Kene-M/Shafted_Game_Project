extends CharacterBody2D
@export var speed = 300
@export var cur_direction = Vector2(0,0)

signal update_speed(speed: Vector2)
signal fire_projectile(direction: Vector2)

func _physics_process(delta):
	var direction = Input.get_vector("left","right","up","down")
	if (direction != Vector2(0,0)):
		cur_direction = direction
		if (speed < 700):
			speed += 80
		#update_speed.emit(speed)
		velocity = direction * speed
	if (direction == Vector2(0,0)) and (speed > 300):
		speed -= 80
		velocity = cur_direction * speed
	elif (direction == Vector2(0,0)) and (speed <= 300):
		velocity = Vector2(0,0)
	
		
		#speed = 600
		#update_speed.emit(0)
	update_speed.emit(velocity)
	move_and_slide()
	
	if (Input.is_action_just_pressed("fire")):
		var mouse_pos = get_global_mouse_position()
		var dir_vector = global_position.direction_to(mouse_pos)
		fire_projectile.emit(dir_vector)
		
