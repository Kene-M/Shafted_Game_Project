class_name GolemBoss
extends CharacterBody2D

## Mecha-stone Golem boss.
## State flow:
##   APPEAR -> IDLE -> (MELEE | RANGED | BLOCK | ARMOR_BUFF | LASER) -> IDLE -> DEATH
## Animations required on AnimatedSprite2D SpriteFrames:
##   idle, glow, shoot, immune, melee, laser_cast, sheild_cast, death
##   (appear is optional — falls back to idle if missing)

# ─── Movement ───
@export var speed: float = 35.0
@export var melee_range: float = 140.0
@export var ranged_range: float = 650.0
@onready var nav_agent: NavigationAgent2D = $Navigation/NavigationAgent2D

# ─── Attack timing / tuning ───
@export var attack_cooldown: float = 2.2
@export var melee_damage: float = 25.0
@export var melee_hit_frame: int = 5         # 0-indexed; frame the punch lands
@export var ranged_fire_frame: int = 6       # 0-indexed; frame the projectile spawns
@export var projectile_scene: PackedScene

# ─── Laser attack ───
@export var laser_damage_per_tick: float = 15.0
@export var laser_tick_interval: float = 0.15
@export var laser_sweep_duration: float = 4.0
@export var laser_max_range: float = 2500.0   # extends beyond any room; raycast stops at walls
@export var laser_beam_width: float = 14.0

# ─── Health / defense ───
@export var knockback_strength: float = 0.0   # bosses don't get knocked around
var max_health: float = 4500.0
var current_health: float = 4500.0
var is_dead: bool = false

# Damage multipliers (0.0 = immune, 1.0 = normal). Applied in take_damage.
var incoming_damage_mult: float = 1.0

# HP-gated one-shot flags so armor buff fires exactly once at each threshold.
var _armor_buff_66_done: bool = false
var _armor_buff_33_done: bool = false
var _armor_stacks: int = 0   # each stack reduces damage further

# ─── Internal state ───
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var laser_pivot: Node2D = $LaserPivot
@onready var laser_line: Line2D = $LaserPivot/LaserLine
@onready var laser_ray: RayCast2D = $LaserPivot/LaserRay

var knockback_velocity: Vector2 = Vector2.ZERO
var facing_right: bool = false
var target_node: Node2D = null
var home_pos: Vector2 = Vector2.ZERO

var attack_timer: float = 0.0
var _has_hit_this_swing: bool = false
var _has_fired_this_ranged: bool = false

# Laser sweep runtime
var _laser_active: bool = false
var _laser_elapsed: float = 0.0
var _laser_tick_accum: float = 0.0
var _laser_direction_sign: float = 1.0   # 1 = clockwise, -1 = counter-clockwise
var _laser_start_angle: float = 0.0

enum State { APPEAR, IDLE, WALK, MELEE, RANGED, BLOCK, ARMOR_BUFF, LASER_CAST, LASER_SWEEP, HIT, DEATH }
var current_state: State = State.APPEAR


func _ready() -> void:
	nav_agent.path_desired_distance = 8
	nav_agent.target_desired_distance = 8

	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	var recalc_timer: Timer = $Navigation/RecalculateTimer
	if not recalc_timer.timeout.is_connected(_on_recalculate_timer_timeout):
		recalc_timer.timeout.connect(_on_recalculate_timer_timeout)

	var aggro: Area2D = $Aggro/AggroRange
	var deaggro: Area2D = $Aggro/DeAggroRange
	if not aggro.area_entered.is_connected(_on_aggro_range_area_entered):
		aggro.area_entered.connect(_on_aggro_range_area_entered)
	if not deaggro.area_exited.is_connected(_on_de_aggro_range_area_exited):
		deaggro.area_exited.connect(_on_de_aggro_range_area_exited)

	laser_line.visible = false
	laser_ray.enabled = false

	if sprite.sprite_frames and sprite.sprite_frames.has_animation("appear"):
		sprite.play("appear")
	else:
		# No appear animation — skip straight to idle next frame
		current_state = State.APPEAR
		call_deferred("_set_state", State.IDLE)


func setup(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	home_pos = spawn_pos


# ─────────────────────────────────────────────────────────────
# Physics / AI loop
# ─────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Knockback (effectively disabled for boss but kept for the pattern)
	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	else:
		knockback_velocity = Vector2.ZERO

	# Hard-lock states play their animation and return
	if current_state in [State.APPEAR, State.MELEE, State.RANGED, State.BLOCK,
						 State.ARMOR_BUFF, State.LASER_CAST, State.HIT, State.DEATH]:
		velocity = Vector2.ZERO
		return

	# Laser sweep runs in its own updater
	if current_state == State.LASER_SWEEP:
		velocity = Vector2.ZERO
		_update_laser_sweep(delta)
		return

	attack_timer -= delta

	# No target yet — stand at home idling
	if target_node == null:
		_set_state(State.IDLE)
		return

	_update_facing(target_node.global_position.x - global_position.x)
	var dist: float = global_position.distance_to(target_node.global_position)

	# Attack decision when cooldown ready
	if attack_timer <= 0.0:
		var attack := _choose_attack(dist)
		if attack != State.IDLE:
			_set_state(attack)
			return

	# Otherwise walk toward target until in melee range
	if dist > melee_range:
		_set_state(State.WALK)
		_move_along_nav()
	else:
		velocity = Vector2.ZERO
		_set_state(State.IDLE)


func _choose_attack(dist: float) -> int:
	# HP-gated armor buffs take priority.
	var hp_frac := current_health / max_health
	if hp_frac <= 0.33 and not _armor_buff_33_done:
		_armor_buff_33_done = true
		return State.ARMOR_BUFF
	if hp_frac <= 0.66 and not _armor_buff_66_done:
		_armor_buff_66_done = true
		return State.ARMOR_BUFF

	# Close range: melee, with occasional block-bait
	if dist <= melee_range:
		if randf() < 0.2:
			return State.BLOCK
		return State.MELEE

	# Mid/long range: mix ranged, laser, and block
	var roll := randf()
	if roll < 0.35 and dist <= ranged_range:
		return State.LASER_CAST
	elif roll < 0.80 and dist <= ranged_range:
		return State.RANGED
	else:
		return State.BLOCK


func _move_along_nav() -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
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


# ─────────────────────────────────────────────────────────────
# State / animation dispatch
# ─────────────────────────────────────────────────────────────

func _set_state(new_state: int) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			_play_anim_or_fallback("idle")
		State.WALK:
			# No walk anim on the sheet — reuse idle. Body still moves.
			_play_anim_or_fallback("idle")
		State.MELEE:
			velocity = Vector2.ZERO
			_has_hit_this_swing = false
			sprite.play("melee")
		State.RANGED:
			velocity = Vector2.ZERO
			_has_fired_this_ranged = false
			sprite.play("shoot")
		State.BLOCK:
			velocity = Vector2.ZERO
			incoming_damage_mult = 0.0   # immune while blocking
			sprite.play("immune")
		State.ARMOR_BUFF:
			velocity = Vector2.ZERO
			sprite.play("sheild_cast")
		State.LASER_CAST:
			velocity = Vector2.ZERO
			sprite.play("laser_cast")
		State.LASER_SWEEP:
			velocity = Vector2.ZERO
			# Hold the guard anim for the full sweep.
			sprite.play("immune")
			incoming_damage_mult = 0.25   # armored but not fully invincible during sweep
			_begin_laser_sweep()
		State.HIT:
			velocity = Vector2.ZERO
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
				sprite.play("hit")
			else:
				# No hit animation — resume immediately so boss doesn't freeze
				call_deferred("_resume_after_attack")
		State.DEATH:
			velocity = Vector2.ZERO
			sprite.play("death")


func _on_frame_changed() -> void:
	match sprite.animation:
		&"melee":
			if sprite.frame == melee_hit_frame and not _has_hit_this_swing:
				_has_hit_this_swing = true
				_try_melee_hit()
		&"shoot":
			if sprite.frame == ranged_fire_frame and not _has_fired_this_ranged:
				_has_fired_this_ranged = true
				_fire_projectile()


func _on_sprite_animation_finished() -> void:
	match sprite.animation:
		&"appear":
			_set_state(State.IDLE)
		&"melee":
			attack_timer = attack_cooldown
			_resume_after_attack()
		&"shoot":
			attack_timer = attack_cooldown
			_resume_after_attack()
		&"immune":
			# Only treat as a full block finish if we weren't actually mid laser-sweep.
			if current_state == State.BLOCK:
				incoming_damage_mult = 1.0
				attack_timer = attack_cooldown * 0.5
				_resume_after_attack()
		&"sheild_cast":
			_armor_stacks += 1
			attack_timer = attack_cooldown
			_resume_after_attack()
		&"laser_cast":
			_set_state(State.LASER_SWEEP)
		&"death":
			queue_free()
		&"hit":
			_resume_after_attack()


func _resume_after_attack() -> void:
	if is_dead:
		return
	if current_state == State.LASER_SWEEP:
		return
	current_state = State.IDLE
	_set_state(State.IDLE)


# ─────────────────────────────────────────────────────────────
# Melee
# ─────────────────────────────────────────────────────────────

func _try_melee_hit() -> void:
	if target_node == null:
		return
	if global_position.distance_to(target_node.global_position) <= melee_range * 1.1:
		if target_node.has_method("take_damage"):
			target_node.take_damage(melee_damage, global_position)


# ─────────────────────────────────────────────────────────────
# Ranged
# ─────────────────────────────────────────────────────────────

func _fire_projectile() -> void:
	if projectile_scene == null or target_node == null:
		return
	var proj = projectile_scene.instantiate()
	var dir: Vector2 = (target_node.global_position - global_position).normalized()
	proj.direction = dir
	proj.z_index = 10
	get_parent().add_child(proj)
	proj.global_position = global_position + dir * 60.0


# ─────────────────────────────────────────────────────────────
# Laser sweep: rotates a raycast around the boss for laser_sweep_duration
# seconds. Damages the player when the ray's path crosses them, stops the
# visible beam at the first wall hit.
# ─────────────────────────────────────────────────────────────

func _begin_laser_sweep() -> void:
	_laser_active = true
	_laser_elapsed = 0.0
	_laser_tick_accum = 0.0
	_laser_direction_sign = -1.0 if randf() < 0.5 else 1.0
	# Start aimed at the player so it feels deliberate, not random.
	if target_node:
		_laser_start_angle = (target_node.global_position - global_position).angle()
	else:
		_laser_start_angle = 0.0

	laser_pivot.rotation = _laser_start_angle
	laser_line.visible = true
	laser_ray.enabled = true
	laser_ray.target_position = Vector2(laser_max_range, 0)
	laser_line.width = laser_beam_width


func _update_laser_sweep(delta: float) -> void:
	_laser_elapsed += delta
	var t: float = clamp(_laser_elapsed / laser_sweep_duration, 0.0, 1.0)
	# Full revolution around the boss.
	laser_pivot.rotation = _laser_start_angle + _laser_direction_sign * TAU * t

	laser_ray.force_raycast_update()
	var beam_end_local: Vector2
	if laser_ray.is_colliding():
		var world_hit: Vector2 = laser_ray.get_collision_point()
		beam_end_local = laser_pivot.to_local(world_hit)
	else:
		beam_end_local = Vector2(laser_max_range, 0)

	laser_line.points = PackedVector2Array([Vector2.ZERO, beam_end_local])

	_laser_tick_accum += delta
	if _laser_tick_accum >= laser_tick_interval:
		_laser_tick_accum = 0.0
		_try_laser_damage(beam_end_local)

	if _laser_elapsed >= laser_sweep_duration:
		_end_laser_sweep()


func _try_laser_damage(beam_end_local: Vector2) -> void:
	if target_node == null:
		return
	# Point-to-segment test in pivot-local space.
	var player_local: Vector2 = laser_pivot.to_local(target_node.global_position)
	var seg_start := Vector2.ZERO
	var seg_end := beam_end_local
	var closest := Geometry2D.get_closest_point_to_segment(player_local, seg_start, seg_end)
	var hit_radius: float = laser_beam_width * 0.5 + 16.0   # + player half-size fudge
	if player_local.distance_to(closest) <= hit_radius:
		if target_node.has_method("take_damage"):
			target_node.take_damage(laser_damage_per_tick, global_position)


func _end_laser_sweep() -> void:
	_laser_active = false
	laser_line.visible = false
	laser_line.points = PackedVector2Array()
	laser_ray.enabled = false
	incoming_damage_mult = 1.0
	attack_timer = attack_cooldown * 1.5
	current_state = State.IDLE
	_set_state(State.IDLE)


# ─────────────────────────────────────────────────────────────
# Navigation / aggro
# ─────────────────────────────────────────────────────────────

func recalc_path() -> void:
	if target_node:
		nav_agent.target_position = target_node.global_position
	else:
		nav_agent.target_position = home_pos


func _on_recalculate_timer_timeout() -> void:
	recalc_path()


func _on_aggro_range_area_entered(area: Area2D) -> void:
	if target_node == null:
		target_node = area.owner


func _on_de_aggro_range_area_exited(area: Area2D) -> void:
	# Boss never loses aggro once engaged; intentionally empty.
	pass


# ─────────────────────────────────────────────────────────────
# Damage
# ─────────────────────────────────────────────────────────────

func take_damage(amount: float, is_crit: bool = false, source_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	var final_amount: float = amount * incoming_damage_mult
	# Each armor stack shaves 25% more.
	if _armor_stacks > 0:
		final_amount *= pow(0.75, float(_armor_stacks))

	if final_amount <= 0.0:
		_show_damage_number(0.0, false)
		return

	current_health -= final_amount
	_show_damage_number(final_amount, is_crit)

	if source_position != Vector2.ZERO and knockback_strength > 0.0:
		var direction: Vector2 = (global_position - source_position).normalized()
		knockback_velocity = direction * knockback_strength

	if current_health <= 0.0:
		_die()
		return

	# Don't interrupt big moves.
	if current_state in [State.MELEE, State.RANGED, State.LASER_CAST, State.LASER_SWEEP,
						 State.ARMOR_BUFF, State.BLOCK, State.APPEAR, State.DEATH]:
		return

	current_state = State.IDLE
	_set_state(State.HIT)


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	_laser_active = false
	laser_line.visible = false
	laser_ray.enabled = false
	current_state = State.IDLE   # clear guard so _set_state actually transitions
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
		label.position = Vector2(randf_range(-10, 10), -80)
	else:
		label.text = str(int(amount))
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.position = Vector2(randf_range(-10, 10), -70)
	add_child(label)
	var float_distance: float = -60.0 if is_crit else -40.0
	var duration: float = 1.0 if is_crit else 0.8
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + float_distance, duration)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_callback(label.queue_free).set_delay(duration)


# ─────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────

func _play_anim_or_fallback(anim_name: String, fallback: String = "idle") -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames and sprite.sprite_frames.has_animation(fallback):
		sprite.play(fallback)
