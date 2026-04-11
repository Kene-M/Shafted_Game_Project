class_name Brooder
extends CharacterBody2D

# --- Stats ---
@export var speed: float = 50.0
@export var run_speed: float = 90.0
@export var nav_agent: NavigationAgent2D
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 15.0
@export var knockback_strength: float = 200.0

# --- Flee / Lay ---
@export var flee_distance: float = 200.0    # how far to run before laying
@export var lay_time: float = 5.0           # how long the lay_spawn animation lasts in seconds
@export var hatched_egg: PackedScene        # drag egg.tscn here in Inspector

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

const LAY_SPAWN_FRAME_COUNT: int = 15

var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node = null
var home_pos: Vector2 = Vector2.ZERO
var flee_target: Vector2 = Vector2.ZERO

var max_health: float = 1500.0
var current_health: float = 1500.0
var is_dead: bool = false
var is_frightened: bool = false
var attack_timer: float = 0.0

enum State { IDLE, WALK, FRIGHT, ATTACK, RUN, LAY_SPAWN, SPAWN, DEATH }
var current_state: State = State.IDLE


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

	sprite.play("lay_prepare")


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

	attack_timer -= delta

	# Locked states — wait for animation callback
	if current_state in [State.FRIGHT, State.LAY_SPAWN, State.SPAWN, State.DEATH]:
		velocity = Vector2.ZERO
		return

	if is_frightened:
		_handle_frightened_logic()
		return

	# Normal chase / attack — mirrors enemy.gd
	if target_node:
		var dist: float = global_position.distance_to(target_node.global_position)
		if dist <= attack_range:
			_update_facing(target_node.global_position.x - global_position.x)
			if current_state != State.FRIGHT:
				_set_state(State.ATTACK)
			return

	if nav_agent.is_navigation_finished():
		if current_state != State.FRIGHT:
			_set_state(State.IDLE)
		return

	if current_state != State.FRIGHT:
		_set_state(State.WALK)

	var axis = to_local(nav_agent.get_next_path_position()).normalized()
	if abs(axis.x) > 0.1:
		_update_facing(axis.x)
	velocity = axis * speed
	move_and_slide()


func _handle_frightened_logic() -> void:
	# Arrived at flee destination — start lay sequence
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		current_state = State.IDLE
		_set_state(State.LAY_SPAWN)
		return

	# Still running toward flee_target
	_set_state(State.RUN)
	var axis = to_local(nav_agent.get_next_path_position()).normalized()
	if abs(axis.x) > 0.1:
		_update_facing(axis.x)
	velocity = axis * run_speed
	move_and_slide()


func _pick_flee_target() -> void:
	var desired: Vector2
	if not is_frightened and target_node:
		# First flee — go directly away from the player
		var flee_dir: Vector2 = (global_position - target_node.global_position).normalized()
		desired = global_position + flee_dir * flee_distance
	else:
		# Subsequent eggs — pick a random nearby direction so it doesn't keep hitting the same wall
		var random_dir: Vector2 = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		desired = global_position + random_dir * (flee_distance * 0.5)

	var map: RID = nav_agent.get_navigation_map()
	flee_target = NavigationServer2D.map_get_closest_point(map, desired)
	nav_agent.target_position = flee_target


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
		State.IDLE:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("lay_prepare")
		State.WALK:
			sprite.speed_scale = 1.0
			sprite.play("walk")
		State.FRIGHT:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("fright")
		State.ATTACK:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			if not sprite.is_playing() or sprite.animation != "attack":
				sprite.play("attack")
		State.RUN:
			sprite.speed_scale = 1.0
			sprite.play("run")
		State.LAY_SPAWN:
			velocity = Vector2.ZERO
			# Read actual FPS from the resource so no manual export variable needed
			# desired_fps = frames / seconds  →  e.g. 15 / 5 = 3fps
			# speed_scale  = desired_fps / actual_fps  →  e.g. 3 / 10 = 0.3
			var actual_fps: float = sprite.sprite_frames.get_animation_speed("lay_spawn")
			var desired_fps: float = LAY_SPAWN_FRAME_COUNT / lay_time
			sprite.speed_scale = desired_fps / actual_fps
			sprite.play("lay_spawn")
		State.SPAWN:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("spawn")
		State.DEATH:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("death")


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		"fright":
			_resume_after_fright()
		"attack":
			if attack_timer <= 0.0 and target_node:
				if target_node.has_method("take_damage"):
					target_node.take_damage(attack_damage, global_position)
				attack_timer = attack_cooldown
			_resume_state()
		"lay_spawn":
			# Chain directly into spawn at normal speed
			current_state = State.IDLE
			_set_state(State.SPAWN)
		"spawn":
			# Drop the egg, reset frightened, return to normal behavior
			_spawn_egg()
			_pick_flee_target()
			current_state = State.IDLE
			_set_state(State.RUN)
			sprite.speed_scale = 1.0
		"death":
			queue_free()


func _resume_after_fright() -> void:
	if is_dead:
		return
	current_state = State.IDLE
	if is_frightened:
		_handle_frightened_logic()
	else:
		_resume_state()


func _resume_state() -> void:
	if is_dead:
		return
	if is_frightened:
		current_state = State.IDLE
		_handle_frightened_logic()
		return
	if target_node:
		var dist: float = global_position.distance_to(target_node.global_position)
		current_state = State.IDLE
		if dist <= attack_range:
			_set_state(State.ATTACK)
		else:
			_set_state(State.WALK)
	else:
		current_state = State.IDLE
		_set_state(State.IDLE)


func _spawn_egg() -> void:
	if hatched_egg:
		var egg = hatched_egg.instantiate()
		# Offset behind the nester based on facing direction, dropped at feet level
		var behind_offset: Vector2 = Vector2(-18 if facing_right else 18, 10)
		egg.global_position = global_position + behind_offset
		get_parent().add_child(egg)


# --- Navigation ---
func recalc_path() -> void:
	if is_frightened:
		nav_agent.target_position = flee_target
	elif target_node:
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

	# Don't interrupt the lay/spawn sequence
	if current_state in [State.LAY_SPAWN, State.SPAWN]:
		current_health -= amount
		_show_damage_number(amount, is_crit)
		if current_health <= 0:
			_die()
		return

	current_health -= amount
	_show_damage_number(amount, is_crit)

	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0:
		_die()
		return

	# Latch frightened once HP crosses 30% and immediately pick flee destination
	if not is_frightened and current_health <= max_health * 0.3:
		is_frightened = true
		_pick_flee_target()

	current_state = State.IDLE
	_set_state(State.FRIGHT)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	sprite.speed_scale = 1.0
	current_state = State.IDLE
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
