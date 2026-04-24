class_name Monster5
extends CharacterBody2D

# --- Movement ---
@export var fly_speed: float = 90.0
@export var hover_offset: Vector2 = Vector2(0, -60)
@export var hover_tolerance: float = 20.0
@onready var nav_agent: NavigationAgent2D = $Navigation/NavigationAgent2D

# --- Bomb ---
@export var bomb_scene: PackedScene
@export var bomb_cooldown: float = 4.0
@export var bomb_drop_range: float = 150.0
@export var bomb_spawn_offset: Vector2 = Vector2(0, 0)

# --- Health / Combat ---
@export var knockback_strength: float = 300.0
@export var explosion_damage: float = 60.0
@export var explosion_radius: float = 80.0
var max_health: float = 600.0
var current_health: float = 600.0

# --- Fly visual ---
@export var fly_height: float = 50.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var shadow_node: Polygon2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node = null
var home_pos: Vector2 = Vector2.ZERO

var is_dead: bool = false
var bomb_timer: float = 0.0
var in_aggro_range: bool = false

enum State { IDLE, FLY, DROP_BOMB, EXPLOSION }
var current_state: State = State.IDLE


func _ready() -> void:
	nav_agent.path_desired_distance = 4
	nav_agent.target_desired_distance = 4

	sprite.animation_finished.connect(_on_sprite_animation_finished)

	sprite.position.y = -fly_height

	# Shadow
	var shadow := Polygon2D.new()
	shadow.z_index = -1
	shadow.color = Color(0, 0, 0, 0.45)
	var points := PackedVector2Array()
	for i in 16:
		var angle := (float(i) / 16.0) * TAU
		points.append(Vector2(cos(angle) * 20.0, sin(angle) * 8.0))
	shadow.polygon = points
	add_child(shadow)
	shadow_node = shadow

	var recalc_timer: Timer = $Navigation/RecalculateTimer
	recalc_timer.wait_time = 0.3
	recalc_timer.autostart = true
	recalc_timer.timeout.connect(_on_recalculate_timer_timeout)
	recalc_timer.start()

	var aggro: Area2D = $Aggro/AggroRange
	var deaggro: Area2D = $Aggro/DeAggroRange
	aggro.area_entered.connect(_on_aggro_range_area_entered)
	aggro.area_exited.connect(_on_aggro_range_area_exited)
	deaggro.area_exited.connect(_on_de_aggro_range_area_exited)

	sprite.play("fly")


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

	bomb_timer -= delta

	if current_state in [State.DROP_BOMB, State.EXPLOSION]:
		velocity = Vector2.ZERO
		return

	if target_node == null:
		if nav_agent.is_navigation_finished():
			_set_state(State.IDLE)
		else:
			_set_state(State.FLY)
			_move_along_nav()
		return

	var hover_target: Vector2 = target_node.global_position + hover_offset
	var dist_to_hover: float = global_position.distance_to(hover_target)
	var dist_to_player: float = global_position.distance_to(target_node.global_position)

	_update_facing(target_node.global_position.x - global_position.x)

	if dist_to_hover > hover_tolerance:
		_set_state(State.FLY)
		_move_along_nav()
	else:
		velocity = Vector2.ZERO
		_set_state(State.IDLE)
		if bomb_timer <= 0.0 and dist_to_player <= bomb_drop_range:
			_set_state(State.DROP_BOMB)


func _move_along_nav() -> void:
	if nav_agent.is_navigation_finished():
		return
	var axis: Vector2 = to_local(nav_agent.get_next_path_position()).normalized()
	if abs(axis.x) > 0.1:
		_update_facing(axis.x)
	velocity = axis * fly_speed
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
			sprite.speed_scale = 1.0
			sprite.play("idle")
		State.FLY:
			sprite.speed_scale = 1.0
			sprite.play("fly")
		State.DROP_BOMB:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("idle")
			_drop_bomb()
		State.EXPLOSION:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			if shadow_node:
				shadow_node.visible = false
			sprite.play("explosion")


func _drop_bomb() -> void:
	bomb_timer = bomb_cooldown
	if bomb_scene == null:
		current_state = State.IDLE
		_set_state(State.IDLE)
		return
	var bomb = bomb_scene.instantiate()
	bomb.z_index = 10
	get_parent().add_child(bomb)
	bomb.global_position = global_position + Vector2(sprite.position.x, sprite.position.y) + bomb_spawn_offset  # must be set AFTER add_child
	await get_tree().create_timer(0.3).timeout
	if not is_dead:
		current_state = State.IDLE
		_set_state(State.FLY)


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
			body.take_damage(explosion_damage,global_position)


func _on_sprite_animation_finished() -> void:
	if sprite.animation == "explosion":
		_do_explosion_damage()
		queue_free()


# --- Navigation ---
func recalc_path() -> void:
	if target_node:
		nav_agent.target_position = target_node.global_position + hover_offset
	else:
		nav_agent.target_position = home_pos

func _on_recalculate_timer_timeout() -> void:
	recalc_path()


# --- Aggro ---
func _on_aggro_range_area_entered(area: Area2D) -> void:
	target_node = area.owner
	in_aggro_range = true

func _on_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		in_aggro_range = false

func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		target_node = null
		in_aggro_range = false


# --- Damage ---
func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	if current_state == State.EXPLOSION:
		return

	current_health -= amount
	_show_damage_number(amount, is_crit)
	if current_health > 0:                                   
		AudioManager.play_enemy_hit(global_position)         

	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0:
		AudioManager.play_enemy_death(global_position) 
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
		_set_state(State.EXPLOSION)


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
