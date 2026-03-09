extends StaticBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_fx: AnimatedSprite2D = $AnimatedSprite2D/HitFX
var max_health := 100.0
var health := max_health

func _ready() -> void:
	sprite.play("Idle")
	hit_fx.visible = false
	hit_fx.animation_finished.connect(_on_hit_fx_finished)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

func take_damage(amount: float, is_crit: bool = false, player_pos: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	_show_damage_number(amount, is_crit)
	_play_hit()
	if health <= 0:
		health = max_health

func _play_hit() -> void:
	sprite.play("hit")
	hit_fx.visible = true
	hit_fx.play("hit_fx")

func _on_sprite_animation_finished() -> void:
	if sprite.animation == "hit":
		sprite.play("Idle")

func _on_hit_fx_finished() -> void:
	hit_fx.visible = false

func _process(_delta: float) -> void:
	pass

func _show_damage_number(amount: float, is_crit: bool = false) -> void:
	var label = Label.new()
	label.z_index = 10

	if is_crit:
		label.text = "✴ " + str(int(amount)) + " ✴"
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", Color.WHITE)        # white text
		label.add_theme_color_override("font_outline_color", Color.RED)  # red outline to make it pop
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
