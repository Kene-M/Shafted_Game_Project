extends RigidBody2D

# How long before it auto-explodes
@export var fuse_time: float = 4.0
@export var explosion_damage: float = 40.0
@export var explosion_radius: float = 80.0
# Knockback applied to the bomb when hit by player
@export var hit_knockback: float = 300.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _fuse_timer: float = 0.0
var _is_exploding: bool = false


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	# RigidBody2D so it can be physically knocked around by player
	# Set gravity scale to 0 since this is a 2D top-down game
	gravity_scale = 0.0
	linear_damp = 5.0   # slows down after being knocked so it doesn't slide forever
	sprite.play("on_ground")


func _process(delta: float) -> void:
	if _is_exploding:
		return
	_fuse_timer += delta
	if _fuse_timer >= fuse_time:
		_explode()


func take_damage(_amount: float, _is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if _is_exploding:
		return
	# No HP — just gets knocked around
	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		apply_central_impulse(direction * hit_knockback)


func _explode() -> void:
	if _is_exploding:
		return
	_is_exploding = true
	linear_velocity = Vector2.ZERO
	# Disable collision so it doesn't interact while exploding
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# AoE damage
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2   # player layer
	var results := space.intersect_shape(query)
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage, false, global_position)

	sprite.play("explosion")


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "explosion":
		queue_free()
