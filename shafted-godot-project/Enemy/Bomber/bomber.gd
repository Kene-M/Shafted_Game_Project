class_name Bomber
extends CharacterBody2D

# --- Movement ---
@export var speed: float = 120.0
@export var contact_distance: float = 25.0   # how close before explosion triggers
@onready var nav_agent: NavigationAgent2D = $Navigation/NavigationAgent2D

# --- Combat ---
@export var explosion_damage: float = 50.0
@export var explosion_radius: float = 70.0
@export var knockback_strength: float = 400.0

# --- Death bomb ---
@export var bomb_scene: PackedScene

# --- Health ---
var max_health: float = 300.0
var current_health: float = 300.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node = null
var home_pos: Vector2 = Vector2.ZERO

var is_dead: bool = false

enum State { WALK, EXPLODE, DEATH }
var current_state: State = State.WALK


func _ready() -> void:
	home_pos = global_position
	nav_agent.path_desired_distance = 4
	nav_agent.target_desired_distance = 4

	sprite.animation_finished.connect(_on_sprite_animation_finished)

	var recalc_timer: Timer = $Navigation/RecalculateTimer
	recalc_timer.wait_time = 0.3
	recalc_timer.autostart = true
	recalc_timer.timeout.connect(_on_recalculate_timer_timeout)
	recalc_timer.start()

	var aggro: Area2D = $Aggro/AggroRange
	var deaggro: Area2D = $Aggro/DeAggroRange
	aggro.area_entered.connect(_on_aggro_range_area_entered)
	deaggro.area_exited.connect(_on_de_aggro_range_area_exited)

	sprite.speed_scale = 1.5
	sprite.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	else:
		knockback_velocity = Vector2.ZERO

	if current_state in [State.EXPLODE, State.DEATH]:
		velocity = Vector2.ZERO
		return

	if target_node == null:
		if nav_agent.is_navigation_finished():
			velocity = Vector2.ZERO
		else:
			_move_along_nav()
		return

	var dist: float = global_position.distance_to(target_node.global_position)
	if dist <= contact_distance:
		_set_state(State.EXPLODE)
		return

	_move_along_nav()


func _move_along_nav() -> void:
	if nav_agent.is_navigation_finished():
		return
	var axis: Vector2 = to_local(nav_agent.get_next_path_position()).normalized()
	if abs(axis.x) > 0.1:
		_update_facing(axis.x)
	velocity = axis * speed
	move_and_slide()


func _update_facing(horizontal_dir: float) -> void:
	if horizontal_dir > 0:
		facing_right = true
		sprite.flip_h = true
	elif horizontal_dir < 0:
		facing_right = false
		sprite.flip_h = false


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.WALK:
			sprite.speed_scale = 1.5
			sprite.play("walk")
		State.EXPLODE:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("explosion")
		State.DEATH:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("death")


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		"explosion":
			_do_explosion_damage()
			_spawn_bomb()
			queue_free()
		"death":
			_spawn_bomb()
			queue_free()


func _do_explosion_damage() -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 2
	var results := space.intersect_shape(query)
	for result in results:
		var body = result["collider"]
		if body.has_method("take_damage"):
			body.take_damage(explosion_damage, false, global_position)


func _spawn_bomb() -> void:
	if bomb_scene == null:
		return
	var bomb = bomb_scene.instantiate()
	# Spawn opposite to facing direction so it rolls away from death position
	var offset_x: float = -30.0 if facing_right else 30.0
	bomb.global_position = global_position + Vector2(offset_x, 0)
	get_parent().add_child(bomb)


# --- Navigation ---
func recalc_path() -> void:
	if target_node:
		nav_agent.target_position = target_node.global_position
	else:
		nav_agent.target_position = home_pos

func _on_recalculate_timer_timeout() -> void:
	recalc_path()


# --- Aggro ---
func _on_aggro_range_area_entered(area: Area2D) -> void:
	target_node = area.owner

func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		target_node = null


# --- Damage ---
func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	if current_state in [State.EXPLODE, State.DEATH]:
		return

	current_health -= amount
	_show_damage_number(amount, is_crit)

	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0:
		is_dead = true
		velocity = Vector2.ZERO
		current_state = State.WALK
		_set_state(State.DEATH)


func _show_damage_number(amount: float, is_crit: bool = false) -> void:
	var label := Label.new()
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
	var float_distance: float = -60.0 if is_crit else -40.0
	var duration: float = 1.0 if is_crit else 0.8
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + float_distance, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free).set_delay(duration)
