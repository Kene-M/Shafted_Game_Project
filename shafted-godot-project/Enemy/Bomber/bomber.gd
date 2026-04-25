class_name Bomber
extends CharacterBody2D

# --- Movement ---
@export var speed: float = 120.0
@onready var contact_distance: float = 65.0
@onready var nav_agent: NavigationAgent2D = $Navigation/NavigationAgent2D

# --- Combat ---
@export var explosion_damage: float = 50.0
@export var knockback_strength: float = 400.0

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


func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	home_pos = spawn_pos


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

	if target_node:
		var dist: float = global_position.distance_to(target_node.global_position)
		if dist <= contact_distance:
			_update_facing(target_node.global_position.x - global_position.x)
			_set_state(State.EXPLODE)
			return

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
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
			AudioManager.play_explosion(global_position)
			_do_explosion_damage()  # deal damage immediately when explosion starts
		State.DEATH:
			var rec_paths = [
				"res://Scenes/itemScenes/resource_1.tscn",
				"res://Scenes/itemScenes/resource_2.tscn",
				"res://Scenes/itemScenes/ resource_3.tscn",
				"res://Scenes/itemScenes/resource_4.tscn",
				"res://Scenes/itemScenes/resource_5.tscn"
			]
			var resource = load(rec_paths.pick_random())
			var resource_inst = resource.instantiate()
			get_parent().add_child(resource_inst)
			resource_inst.global_position = global_position
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("death")


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		"explosion":
			queue_free()
		"death":
			queue_free()


func _do_explosion_damage() -> void:
	if target_node and target_node.has_method("take_damage"):
		target_node.take_damage(explosion_damage, global_position)


# --- Navigation ---
func recalc_path() -> void:
	if target_node:
		var dir: Vector2 = (global_position - target_node.global_position).normalized()
		nav_agent.target_position = target_node.global_position + dir * 20.0
	else:
		nav_agent.target_position = home_pos

func _on_recalculate_timer_timeout() -> void:
	recalc_path()


# --- Aggro ---
func _on_aggro_range_area_entered(area: Area2D) -> void:
	target_node = area.get_parent()

func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.get_parent() == target_node:
		target_node = null


# --- Damage ---
func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	if current_state in [State.EXPLODE, State.DEATH]:
		return

	current_health -= amount
	_show_damage_number(amount, is_crit)
	if current_health > 0:                                   # ADD
		AudioManager.play_enemy_hit(global_position)

	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0:
		AudioManager.play_enemy_death(global_position) 
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
