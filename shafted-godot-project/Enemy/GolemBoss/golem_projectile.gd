extends Area2D

## Stone-arm projectile fired by the Mecha-stone Golem during its ranged attack.
## Same API as the flying enemy's projectile: set `direction`, parent adds it
## to the scene, it travels until it hits a wall or the player.

@export var projectile_speed: float = 260.0
@export var damage: float = 20.0
@export var lifetime: float = 3.5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var direction: Vector2 = Vector2.RIGHT
var _lifetime_timer: float = 0.0
var _is_dying: bool = false


func _ready() -> void:
	sprite.animation_finished.connect(_on_sprite_animation_finished)

	# Layer 4 = enemy; Mask 3 = world (walls) + player.
	collision_layer = 4
	collision_mask = 3

	body_entered.connect(_on_body_entered)

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("fly"):
		sprite.play("fly")
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
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	_start_death()


func _start_death() -> void:
	_is_dying = true
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	rotation = 0.0
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		queue_free()


func _on_sprite_animation_finished() -> void:
	if sprite.animation == &"death":
		queue_free()
