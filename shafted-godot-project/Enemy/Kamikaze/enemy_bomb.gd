extends Area2D

# How fast the bomb falls downward (positive Y = down in Godot)
@export var fall_speed: float = 150.0
# How far it falls before detonating (simulates dropping from fly height)
@export var fall_distance: float = 80.0
@export var explosion_damage: float = 30.0
@export var explosion_radius: float = 60.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _fallen: float = 0.0
var _is_exploding: bool = false
var _start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_start_pos = global_position
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	# Bomb is on enemy layer, detects world + player
	collision_layer = 4
	collision_mask = 3
	body_entered.connect(_on_body_entered)
	sprite.play("falling")


func _process(delta: float) -> void:
	if _is_exploding:
		return

	# Move downward
	position.y += fall_speed * delta
	_fallen += fall_speed * delta

	if _fallen >= fall_distance:
		_detonate()


func _on_body_entered(body: Node2D) -> void:
	if _is_exploding:
		return
	_detonate()


func _detonate() -> void:
	if _is_exploding:
		return
	_is_exploding = true
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# AoE damage
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2   # player layer only
	var results := space.intersect_shape(query)
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage, false, global_position)

	sprite.play("explosion_ground")


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "explosion_ground":
		queue_free()
