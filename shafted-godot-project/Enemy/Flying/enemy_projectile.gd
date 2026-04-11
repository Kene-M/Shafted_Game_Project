extends Area2D

@export var projectile_speed: float = 200.0
@export var damage: float = 10.0
@export var lifetime: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var _lifetime_timer: float = 0.0
var _is_dying: bool = false


func _ready() -> void:
	z_index = 1
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Layer 3 = enemy, Mask 1 = world (walls), Mask 2 = player
	# Projectile is on enemy layer, detects world + player
	collision_layer = 4   # enemy layer so player attacks can't hit it mid-flight
	collision_mask = 3    # bits 1+2 = world walls + player

	body_entered.connect(_on_body_entered)
	sprite.play("shoted")
	rotation = direction.angle()


func _process(delta: float) -> void:
	if _is_dying:
		return
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		_start_death()
		return
	position += direction * projectile_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _is_dying:
		return
	# Only deal damage to the player, not walls
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_start_death()


func _start_death() -> void:
	_is_dying = true
	# Stop moving and stop detecting hits
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	# Reset rotation so explosion sprite faces up normally
	rotation = 0.0
	sprite.play("death")


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "death":
		queue_free()
