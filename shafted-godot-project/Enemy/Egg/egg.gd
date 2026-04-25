extends CharacterBody2D

@export var hatched_enemy: PackedScene  # drag enemy.tscn here in Inspector
@export var hatch_time: float = 10.0   # seconds before auto-hatch
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hatch_timer: Timer = $HatchTimer

var max_health: float = 300.0
var current_health: float = 300.0
var is_dead: bool = false
var is_hatching: bool = false

func _ready():
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.play("idle")
	hatch_timer.wait_time = hatch_time
	hatch_timer.one_shot = true
	hatch_timer.timeout.connect(_on_hatch_timer_timeout)
	hatch_timer.start()

func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead or is_hatching:
		return
	current_health -= amount
	_show_damage_number(amount, is_crit)
	if current_health <= 0:
		is_dead = true
		hatch_timer.stop()
		sprite.play("egg_destory")
	else:
		sprite.play("hit")

func _on_hatch_timer_timeout() -> void:
	if is_dead:
		return
	is_hatching = true
	sprite.play("born")

func _on_sprite_animation_finished() -> void:
	if sprite.animation == "hit":
		sprite.play("idle")
	elif sprite.animation == "egg_destory":
		queue_free()
	elif sprite.animation == "born":
		_hatch()

func _hatch() -> void:
	if hatched_enemy:
		var enemy = hatched_enemy.instantiate()
		get_parent().add_child(enemy)
		# Use setup() so home_pos is set correctly at the hatch location
		if enemy.has_method("setup"):
			enemy.setup(global_position)
		else:
			enemy.global_position = global_position
	queue_free()

func _show_damage_number(amount: float, is_crit: bool = false) -> void:
	var label = Label.new()
	label.z_index = 10
	if is_crit:
		label.text = "✴ " + str(int(amount)) + " ✴"
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.RED)
		label.add_theme_constant_override("outline_size", 5)
		label.position = Vector2(randf_range(-10, 10), -50)
	else:
		label.text = str(int(amount))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.position = Vector2(randf_range(-10, 10), -40)
	add_child(label)
	var float_distance = -60 if is_crit else -40
	var duration = 1.0 if is_crit else 0.8
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + float_distance, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free).set_delay(duration)
