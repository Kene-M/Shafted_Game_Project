class_name Enemy
extends CharacterBody2D

@export var speed = 50
@export var nav_agent: NavigationAgent2D
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var attack_damage: float = 10.0
@export var knockback_strength: float = 200.0
@export var attack_hit_frame: int = 2  # frame damage fires (0-indexed, attack has 5 frames)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node = null
var home_pos = Vector2.ZERO

var max_health: float = 1000.0
var current_health: float = 1000.0
var is_dead: bool = false
var is_hitting: bool = false
var attack_timer: float = 0.0
var _has_hit_this_swing: bool = false

enum State { IDLE, WALK, ATTACK, HIT, DEATH }
var current_state: State = State.IDLE

func _ready():
	nav_agent.path_desired_distance = 4
	nav_agent.target_desired_distance = 4
	home_pos = global_position  # ← add this line
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	var recalc_timer: Timer = $Navigation/RecalculateTimer
	recalc_timer.wait_time = 0.3
	recalc_timer.autostart = true
	recalc_timer.timeout.connect(_on_recalculate_timer_timeout)
	recalc_timer.start()
	sprite.play("idle")


func _physics_process(delta):
	if is_dead:
		return

	# Knockback takes priority over everything
	if knockback_velocity.length() > 5.0:
		print("applying knockback: ", knockback_velocity)
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	else:
		knockback_velocity = Vector2.ZERO

	attack_timer -= delta

	if target_node:
		var dist = global_position.distance_to(target_node.global_position)
		if dist <= attack_range:
			_update_facing(target_node.global_position.x - global_position.x)
			if current_state != State.HIT:
				_set_state(State.ATTACK)
			return

	if nav_agent.is_navigation_finished():
		if current_state != State.HIT:
			_set_state(State.IDLE)
		return

	if current_state != State.HIT:
		_set_state(State.WALK)

	var axis = to_local(nav_agent.get_next_path_position()).normalized()
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
		State.IDLE:
			velocity = Vector2.ZERO
			sprite.play("idle")
		State.WALK:
			sprite.play("walk")
		State.ATTACK:
			velocity = Vector2.ZERO
			if not sprite.is_playing() or sprite.animation != "attack":
				_has_hit_this_swing = false
				sprite.play("attack")
		State.HIT:
			sprite.play("hit")
		State.DEATH:
			sprite.play("death")

func _on_frame_changed() -> void:
	if sprite.animation == "attack" and sprite.frame == attack_hit_frame and not _has_hit_this_swing:
		_has_hit_this_swing = true
		if attack_timer <= 0.0 and target_node:
			if target_node.has_method("take_damage"):
				target_node.take_damage(attack_damage, global_position)
			attack_timer = attack_cooldown

func _on_sprite_animation_finished() -> void:
	if sprite.animation == "hit":
		is_hitting = false
		_resume_state()
	elif sprite.animation == "attack":
		_resume_state()
	elif sprite.animation == "death":
		queue_free()

func _resume_state() -> void:
	if is_dead:
		return
	if target_node:
		var dist = global_position.distance_to(target_node.global_position)
		if dist <= attack_range:
			current_state = State.IDLE
			_set_state(State.ATTACK)
		else:
			current_state = State.IDLE
			_set_state(State.WALK)
	else:
		current_state = State.IDLE
		_set_state(State.IDLE)

func recalc_path():
	if target_node:
		nav_agent.target_position = target_node.global_position
	else:
		nav_agent.target_position = home_pos

func _on_recalculate_timer_timeout():
	recalc_path()

func _on_aggro_range_area_entered(area):
	target_node = area.owner

func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		target_node = null

func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
	current_health -= amount
	_show_damage_number(amount, is_crit)

	print("source_position: ", source_position)
	print("global_position: ", global_position)

	if source_position != Vector2.ZERO:
		var direction = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength
		print("knockback_velocity set to: ", knockback_velocity)
	else:
		print("knockback skipped - source_position is ZERO")

	if current_health <= 0:
		AudioManager.play_enemy_death(global_position)
		_die()
			
	else:
		AudioManager.play_enemy_hit(global_position)
		is_hitting = true
		current_state = State.IDLE
		_set_state(State.HIT)

func _die() -> void:
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
	is_dead = true
	velocity = Vector2.ZERO
	current_state = State.IDLE
	_set_state(State.DEATH)

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
