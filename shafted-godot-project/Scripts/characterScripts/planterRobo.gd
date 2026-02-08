extends CharacterBody2D

@export var speed = 60.0
@export var wander_time = 2.0  # Time before changing direction

var direction = Vector2.ZERO
var timer = 0.0

func _ready():
	randomize()
	pick_random_direction()
	# Just play the animation once - it will loop automatically
	$AnimatedSprite2D.play("planterBot:3") 

func _physics_process(delta):
	timer += delta
	
	# Change direction periodically
	if timer >= wander_time:
		pick_random_direction()
		timer = 0.0
	
	# Move the robot
	velocity = direction * speed
	move_and_slide()
	
	# Animation plays continuously, no need to control it based on movement

func pick_random_direction():
	# Random angle
	var angle = randf() * TAU
	direction = Vector2(cos(angle), sin(angle))
	
	# Optional: Sometimes stop moving (but animation still plays)
	if randf() < 0.2:  # 20% chance to pause movement
		direction = Vector2.ZERO
