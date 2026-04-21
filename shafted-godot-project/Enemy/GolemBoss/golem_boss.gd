class_name GolemBoss
extends CharacterBody2D

## Mecha-stone Golem boss.
## State flow:
##   APPEAR -> IDLE -> (MELEE | RANGED | BLOCK | ARMOR_BUFF | LASER_STRAIGHT | LASER_CAST) -> IDLE -> DEATH
##
## Attack pattern by distance:
##   CLOSE  (≤ melee_range)      → charge & melee, occasional block
##   MEDIUM (≤ charge_range)     → charge toward player to get into melee, occasional ranged
##   FAR    (> charge_range)     → ranged shot or straight laser; rare spin laser
##
## Animations required on AnimatedSprite2D SpriteFrames:
##   idle, shoot, immune, melee, laser_cast, sheild_cast, death
##   (appear is optional — falls back to idle if missing)

# ─── Movement ───
@export var speed: float = 80.0
@export var melee_range: float = 140.0
@export var charge_range: float = 400.0    # distance at which boss prefers to charge into melee
@export var ranged_range: float = 700.0
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
@export var laser_max_range: float = 2500.0
@export var laser_beam_width: float = 14.0

# ─── Health / defense ───
@export var knockback_strength: float = 0.0
var max_health: float = 4500.0
var current_health: float = 4500.0
var is_dead: bool = false

var incoming_damage_mult: float = 1.0

var _armor_buff_66_done: bool = false
var _armor_buff_33_done: bool = false
var _armor_stacks: int = 0

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

# Laser runtime — shared between straight and sweep modes
var _laser_active: bool = false
var _laser_is_sweep: bool = false          # true = full spin, false = straight shot
var _laser_elapsed: float = 0.0
var _laser_tick_accum: float = 0.0
var _laser_direction_sign: float = 1.0
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

	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 400 * delta)
		move_and_slide()
		return
	else:
		knockback_velocity = Vector2.ZERO

	# Hard-lock states — animation plays out, no movement
	if current_state in [State.APPEAR, State.MELEE, State.RANGED, State.BLOCK,
						 State.ARMOR_BUFF, State.LASER_CAST, State.HIT, State.DEATH]:
		velocity = Vector2.ZERO
		return

	# Laser sweep (or straight) runs its own updater
	if current_state == State.LASER_SWEEP:
		velocity = Vector2.ZERO
		_update_laser(delta)
		return

	attack_timer -= delta

	if target_node == null:
		_set_state(State.IDLE)
		return

	_update_facing(target_node.global_position.x - global_position.x)
	var dist: float = global_position.distance_to(target_node.global_position)

	if attack_timer <= 0.0:
		var attack := _choose_attack(dist)
		if attack != State.IDLE:
			_set_state(attack)
			return

	# Movement logic:
	# - Within melee range: stand and wait for next attack window
	# - Within charge range: walk toward player aggressively to get into melee
	# - Beyond charge range: stand still (ranged / laser attacks handle this range)
	if dist <= melee_range:
		velocity = Vector2.ZERO
		_set_state(State.IDLE)
	elif dist <= charge_range:
		_set_state(State.WALK)
		_move_along_nav()
	else:
		velocity = Vector2.ZERO
		_set_state(State.IDLE)


func _choose_attack(dist: float) -> int:
	# HP-gated armor buffs fire exactly once at each threshold, top priority.
	var hp_frac := current_health / max_health
	if hp_frac <= 0.33 and not _armor_buff_33_done:
		_armor_buff_33_done = true
		return State.ARMOR_BUFF
	if hp_frac <= 0.66 and not _armor_buff_66_done:
		_armor_buff_66_done = true
		return State.ARMOR_BUFF

	# ── CLOSE: charge already brought us here, now swing ──
	if dist <= melee_range:
		if randf() < 0.15:
			return State.BLOCK
		return State.MELEE

	# ── MEDIUM: prefer to keep charging (handled in physics loop),
	#    but occasionally throw a ranged shot instead of purely chasing ──
	if dist <= charge_range:
		var roll := randf()
		if roll < 0.25 and dist <= ranged_range:
			return State.RANGED        # quick shot before closing
		# Otherwise return IDLE so physics loop keeps walking
		return State.IDLE

	# ── FAR: ranged or laser, very rare spin ──
	if dist <= ranged_range:
		var roll := randf()
		if roll < 0.08:
			# Rare spin laser — telegraph with laser_cast then full sweep
			_laser_is_sweep = true
			return State.LASER_CAST
		elif roll < 0.55:
			# Straight laser beam aimed at player
			_laser_is_sweep = false
			return State.LASER_CAST
		elif roll < 0.85:
			return State.RANGED
		else:
			return State.BLOCK

	# Out of all ranges — just block/wait
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
	# FIX: sprite default faces LEFT, so flip_h = false means facing left.
	# When player is to the RIGHT (horizontal_dir > 0), we flip to face right.
	if horizontal_dir < 0:
		facing_right = true
		sprite.flip_h = true    # flipped = facing right
	elif horizontal_dir > 0:
		facing_right = false
		sprite.flip_h = false   # not flipped = facing left (default)


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
			incoming_damage_mult = 0.0
			sprite.play("immune")
		State.ARMOR_BUFF:
			velocity = Vector2.ZERO
			sprite.play("sheild_cast")
		State.LASER_CAST:
			velocity = Vector2.ZERO
			# Play the cast wind-up. On finish, _on_sprite_animation_finished
			# will transition to LASER_SWEEP which starts the actual beam.
			sprite.play("laser_cast")
		State.LASER_SWEEP:
			velocity = Vector2.ZERO
			# Hold on the last frame of "immune" for the entire laser duration.
			# We set loop=false and pause on frame 0 after playing one cycle.
			sprite.play("immune")
			sprite.set_frame_and_progress(sprite.sprite_frames.get_frame_count("immune") - 1, 1.0)
			sprite.pause()
			incoming_damage_mult = 0.25
			_begin_laser()
		State.HIT:
			velocity = Vector2.ZERO
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("hit"):
				sprite.play("hit")
			else:
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
			# Block finishes normally. Laser sweep holds the last frame via pause()
			# so animation_finished only fires for block, not during laser.
			if current_state == State.BLOCK:
				incoming_damage_mult = 1.0
				attack_timer = attack_cooldown * 0.5
				_resume_after_attack()
		&"sheild_cast":
			_armor_stacks += 1
			attack_timer = attack_cooldown
			_resume_after_attack()
		&"laser_cast":
			# laser_cast wind-up done — begin the actual beam
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
# Laser — shared for both straight beam and full sweep
# ─────────────────────────────────────────────────────────────

func _begin_laser() -> void:
	_laser_active = true
	_laser_elapsed = 0.0
	_laser_tick_accum = 0.0
	_laser_direction_sign = -1.0 if randf() < 0.5 else 1.0

	if target_node:
		_laser_start_angle = (target_node.global_position - global_position).angle()
	else:
		_laser_start_angle = 0.0

	laser_pivot.rotation = _laser_start_angle
	laser_line.visible = true
	laser_ray.enabled = true
	laser_ray.target_position = Vector2(laser_max_range, 0)
	laser_line.width = laser_beam_width


func _update_laser(delta: float) -> void:
	_laser_elapsed += delta

	if _laser_is_sweep:
		# Full 360° rotation over laser_sweep_duration
		var t: float = clamp(_laser_elapsed / laser_sweep_duration, 0.0, 1.0)
		laser_pivot.rotation = _laser_start_angle + _laser_direction_sign * TAU * t
	else:
		# Straight beam — keep aimed at player, slight tracking
		if target_node:
			var target_angle := (target_node.global_position - global_position).angle()
			laser_pivot.rotation = lerp_angle(laser_pivot.rotation, target_angle, delta * 3.0)

	laser_ray.force_raycast_update()
	var beam_end_local: Vector2
	if laser_ray.is_colliding():
		beam_end_local = laser_pivot.to_local(laser_ray.get_collision_point())
	else:
		beam_end_local = Vector2(laser_max_range, 0)

	laser_line.points = PackedVector2Array([Vector2.ZERO, beam_end_local])

	_laser_tick_accum += delta
	if _laser_tick_accum >= laser_tick_interval:
		_laser_tick_accum = 0.0
		_try_laser_damage(beam_end_local)

	var duration := laser_sweep_duration if _laser_is_sweep else laser_sweep_duration * 0.4
	if _laser_elapsed >= duration:
		_end_laser()


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


func _end_laser() -> void:
	_laser_active = false
	laser_line.visible = false
	laser_line.points = PackedVector2Array()
	laser_ray.enabled = false
	incoming_damage_mult = 1.0
	# Longer cooldown after the big spin; shorter after a quick straight beam
	attack_timer = attack_cooldown * (2.0 if _laser_is_sweep else 1.2)
	# Resume sprite so idle plays again
	sprite.play("idle")
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
	if current_state == State.LASER_SWEEP:
		sprite.play("idle")
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
