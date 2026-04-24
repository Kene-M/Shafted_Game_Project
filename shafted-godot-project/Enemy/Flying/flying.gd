class_name Monster4
extends CharacterBody2D

# --- Movement ---
@export var fly_speed: float = 80.0
@export var preferred_range: float = 200.0
@onready var nav_agent: NavigationAgent2D = $Navigation/NavigationAgent2D

# --- Attack ---
@export var attack_cooldown: float = 2.0
@export var projectile_scene: PackedScene
@export var projectile_count: int = 3
@export var projectile_spread: float = 30.0
# Fire on this frame of the attack animation (0-indexed) so projectiles appear before anim ends
@export var fire_on_frame: int = 6

# --- Health ---
@export var knockback_strength: float = 150.0
var max_health: float = 800.0
var current_health: float = 800.0

# --- Corpse explosion ---
@export var corpse_explosion_delay: float = 3.0      # seconds after landing before detonation
@export var corpse_explosion_damage: float = 80.0
@export var corpse_explosion_radius: float = 100.0
@export var corpse_knockback_strength: float = 250.0  # knockback when hit while corpse
# Layer mask for what the explosion hits. Bit 1 = layer 1 (player typically),
# bit 2 = layer 2, etc. Set this to whatever layer your enemies are on.
# Example: 4 = layer 3 (enemies), 6 = layers 2+3, etc.
@export_flags_2d_physics var explosion_collision_mask: int = 4

# --- Fly visual ---
@export var fly_height: float = 40.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var shadow_node: Polygon2D = null
var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node = null
var home_pos: Vector2 = Vector2.ZERO

var is_dead: bool = false
var attack_timer: float = 0.0
var _has_fired: bool = false
var in_aggro_range: bool = false   # true when player is inside AggroRange circle
var _corpse_explosion_timer: float = 0.0   # counts down once landed; 0 = not started

enum State { IDLE, FLY, ATTACK, HIT, DEATH, CORPSE, CORPSE_DEATH }
var current_state: State = State.IDLE


func _ready() -> void:
	nav_agent.path_desired_distance = 4
	nav_agent.target_desired_distance = 4

	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	# Offset sprite upward to simulate flying
	sprite.position.y = -fly_height

	# Shadow — Polygon2D ellipse at ground level
	var shadow := Polygon2D.new()
	shadow.z_index = -1
	shadow.color = Color(0, 0, 0, 0.45)
	var points := PackedVector2Array()
	var num_points := 16
	for i in num_points:
		var angle := (float(i) / num_points) * TAU
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

	sprite.play("idle")


func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	home_pos = spawn_pos


func _physics_process(delta: float) -> void:
	# --- CORPSE: physics-pushable, ticks toward auto-explosion ---
	if current_state == State.CORPSE:
		# Apply knockback decay so slashes push the body and it slides to a stop
		if knockback_velocity.length() > 5.0:
			velocity = knockback_velocity
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600 * delta)
			move_and_slide()
		else:
			knockback_velocity = Vector2.ZERO
			velocity = Vector2.ZERO

		# Tick down toward auto-explosion
		_corpse_explosion_timer -= delta

		# Optional pre-explosion flash (uncomment to enable telegraphing)
		# if _corpse_explosion_timer < 1.0:
		#     var flash := sin(Time.get_ticks_msec() * 0.025) * 0.5 + 0.5
		#     sprite.modulate = Color(1.0, 1.0 - flash, 1.0 - flash)

		if _corpse_explosion_timer <= 0.0:
			_detonate_corpse()
		return

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

	if current_state in [State.HIT, State.ATTACK, State.DEATH, State.CORPSE_DEATH]:
		velocity = Vector2.ZERO
		return

	# No target — return home
	if target_node == null:
		if nav_agent.is_navigation_finished():
			_set_state(State.IDLE)
		else:
			_set_state(State.FLY)
			_move_along_nav()
		return

	var dist: float = global_position.distance_to(target_node.global_position)
	_update_facing(target_node.global_position.x - global_position.x)

	if in_aggro_range:
		# Player is in shoot range — close to preferred distance then hover and shoot
		if dist > preferred_range:
			_set_state(State.FLY)
			_move_along_nav()
		else:
			velocity = Vector2.ZERO
			if attack_timer <= 0.0:
				_set_state(State.ATTACK)
			else:
				_set_state(State.IDLE)
	else:
		# Player is between aggro and de-aggro range — chase to get back in aggro
		_set_state(State.FLY)
		_move_along_nav()


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
		State.ATTACK:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			_has_fired = false
			sprite.play("attack")
		State.HIT:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.play("hit")
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
			_play_death_fall()
		State.CORPSE:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			if shadow_node:
				shadow_node.visible = false
			sprite.play("corpse")
			# Start the auto-explosion countdown the moment we land
			_corpse_explosion_timer = corpse_explosion_delay
		State.CORPSE_DEATH:
			velocity = Vector2.ZERO
			sprite.speed_scale = 1.0
			sprite.modulate = Color.WHITE  # clear any flash tint
			sprite.play("death_explosion")


func _on_frame_changed() -> void:
	if sprite.animation == "attack" and sprite.frame == fire_on_frame and not _has_fired:
		_has_fired = true
		_fire_burst()
		attack_timer = attack_cooldown


func _play_death_fall() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", 0.0, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if shadow_node:
		tween.tween_property(shadow_node, "scale", Vector2(1.5, 1.5), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		"attack":
			_resume_state()
		"hit":
			_resume_state()
		"death":
			current_state = State.IDLE
			_set_state(State.CORPSE)
		"death_explosion":
			queue_free()


func _fire_burst() -> void:
	if projectile_scene == null or target_node == null:
		return
	var base_dir: Vector2 = (target_node.global_position - global_position).normalized()
	var step: float = projectile_spread / max(projectile_count - 1, 1) if projectile_count > 1 else 0.0
	var fire_origin: Vector2 = global_position + Vector2(0, -fly_height)

	for i in range(projectile_count):
		# Center index gets 0 offset — aimed straight at player
		var offset_index: int = i - (projectile_count / 2)
		var angle_offset: float = deg_to_rad(offset_index * step)
		var dir: Vector2 = base_dir.rotated(angle_offset)
		var proj = projectile_scene.instantiate()
		proj.direction = dir
		proj.z_index = 10
		get_parent().add_child(proj)
		proj.global_position = fire_origin  # must be set AFTER add_child so parent offset is applied correctly


func _resume_state() -> void:
	if is_dead:
		return
	if target_node:
		current_state = State.IDLE
		if in_aggro_range and attack_timer <= 0.0:
			_set_state(State.ATTACK)
		elif in_aggro_range:
			_set_state(State.IDLE)
		else:
			_set_state(State.FLY)
	else:
		current_state = State.IDLE
		_set_state(State.IDLE)


# --- Corpse detonation ---
func _detonate_corpse() -> void:
	# Trigger AOE damage on nearby enemies, then play explosion animation.
	# Tweak explosion_collision_mask in inspector to match your enemy layer.
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = corpse_explosion_radius
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.collision_mask = explosion_collision_mask
	var results := space.intersect_shape(query)
	for result in results:
		var body = result["collider"]
		if body == self:
			continue   # don't damage ourselves
		if body.has_method("take_damage"):
			# Match the standard take_damage signature: amount, is_crit, source_position
			body.take_damage(corpse_explosion_damage, global_position)

	is_dead = true
	current_state = State.IDLE
	_set_state(State.CORPSE_DEATH)


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
	in_aggro_range = true

func _on_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		in_aggro_range = false   # player left shoot range — chase but don't shoot

func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	if area.owner == target_node:
		target_node = null
		in_aggro_range = false


# --- Damage ---
func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	# CORPSE: don't take damage, but receive knockback so player slashes push the body
	if current_state == State.CORPSE:
		if source_position != Vector2.ZERO:
			var dir: Vector2 = (global_position - source_position).normalized()
			knockback_velocity = dir * corpse_knockback_strength
			AudioManager.play_enemy_hit(global_position)
		return

	if is_dead:
		return

	if current_state in [State.DEATH, State.CORPSE_DEATH]:
		return

	current_health -= amount
	_show_damage_number(amount, is_crit)

	if source_position != Vector2.ZERO:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0:
		AudioManager.play_enemy_death(global_position)
		is_dead = true
		velocity = Vector2.ZERO
		current_state = State.IDLE
		_set_state(State.DEATH)
		return

	AudioManager.play_enemy_hit(global_position)
	current_state = State.IDLE
	_set_state(State.HIT)


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
