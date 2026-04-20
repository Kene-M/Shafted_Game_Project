extends AnimatableBody2D
@export var speed = 0
@export var direction: Vector2 = Vector2(0,0)
@export var base_damage: int = 0
@export var crit_damage: float = 1
@export var crit_chance: float = 0
@onready var sprite = $Sprite2D

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	position += (direction * speed) * delta
	$Sprite2D.rotation = (direction * speed).angle()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		var cur_damage = base_damage
		var crit = false
		var crit_check: float = randf()
		if crit_check <= crit_chance:
			crit = true
			cur_damage *= crit_damage
		body.take_damage(cur_damage, crit)
	queue_free()
