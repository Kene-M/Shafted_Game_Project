extends CharacterBody2D
@export var MAX_SPEED = 300
@export var ACCELERATION = 1500
@export var FRICTION = 1200
@export var ATTACK_DAMAGE = 25.0
@export var ATTACK_COOLDOWN = 0.4
@export var ATTACK_RANGE = 25.0
@export var CRIT_CHANCE = 0.2
@export var CRIT_MULTIPLIER = 2.0
@onready var axis = Vector2.ZERO
var can_attack := true
var is_attacking := false
var facing := Vector2.RIGHT

func _ready() -> void:
	print("Player ready - collision layer: ", collision_layer)

func _physics_process(delta):
	move(delta)
	handle_attack_input()

func handle_attack_input():
	if Input.is_action_just_pressed("attack") and can_attack:
		perform_attack()

func perform_attack():
	is_attacking = true
	can_attack = false
	var is_crit = randf() < CRIT_CHANCE
	var damage = ATTACK_DAMAGE * (CRIT_MULTIPLIER if is_crit else 1.0)
	var space = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = ATTACK_RANGE
	query.shape = shape
	query.transform = Transform2D(0, global_position + facing * ATTACK_RANGE)
	query.collision_mask = 4
	query.exclude = [self]
	var results = space.intersect_shape(query)
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			body.take_damage(damage, is_crit, global_position)
	$Sprite2D.modulate = Color(1.5, 1.5, 1.5)
	await get_tree().create_timer(0.1).timeout
	$Sprite2D.modulate = Color(1, 1, 1)
	is_attacking = false
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true

func update_hitbox_position():
	var current_axis = get_input_axis()
	if current_axis.x != 0:
		facing.x = sign(current_axis.x)
		facing.y = 0
	elif current_axis.y != 0:
		facing.y = sign(current_axis.y)
		facing.x = 0

func get_input_axis():
	axis.x = int(Input.is_action_pressed("moveRight")) - int(Input.is_action_pressed("moveLeft"))
	axis.y = int(Input.is_action_pressed("moveDown")) - int(Input.is_action_pressed("moveUp"))
	return axis.normalized()

func move(delta):
	axis = get_input_axis()
	update_hitbox_position()
	if axis == Vector2.ZERO:
		apply_friction(FRICTION * delta)
	else:
		apply_movement(axis * ACCELERATION * delta)
	move_and_slide()

func apply_friction(amount):
	if velocity.length() > amount:
		velocity -= velocity.normalized() * amount
	else:
		velocity = Vector2.ZERO

func apply_movement(accel):
	velocity += accel
	velocity = velocity.limit_length(MAX_SPEED)
