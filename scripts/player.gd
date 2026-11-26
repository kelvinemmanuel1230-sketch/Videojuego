class_name Player
extends CharacterBody2D

## Momentum-based platformer controller inspired by Fancy Pants Adventures:
## run with inertia, variable-height jumps, dash and a four-step attack combo.

signal landed
signal dash_started(invulnerable: bool)
signal attack_started(step: int)
signal attack_hit(body: Node2D)
signal health_changed(current: int, maximum: int)
signal died

# --- Horizontal movement ----------------------------------------------------
const MAX_SPEED: float = 330.0
const GROUND_ACCEL: float = 2600.0
const GROUND_FRICTION: float = 3000.0
const AIR_ACCEL: float = 1700.0
const AIR_FRICTION: float = 450.0
const ATTACK_MOVE_SPEED: float = 140.0
const ATTACK_MOVE_ACCEL: float = 1100.0
const ATTACK_FRICTION: float = 4200.0
const ATTACK_LUNGE: float = 80.0
const ATTACK_MOVE_PULSE_INTERVAL: float = 1.0

# --- Gravity and jumping -----------------------------------------------------
const GRAVITY: float = 1800.0
const FALL_MULTIPLIER: float = 1.5
const MAX_FALL_SPEED: float = 950.0
const JUMP_VELOCITY: float = -900.0
const JUMP_CUT: float = 0.45
const COYOTE_TIME: float = 0.1
const JUMP_BUFFER_TIME: float = 0.12

# --- Dash -------------------------------------------------------------------
const DASH_SPEED: float = 600.0
const DASH_DURATION: float = 0.32
const DASH_COOLDOWN: float = 0.50
const DASH_INVULN_TIME: float = 5.0
# Capa 1 = mundo/jugador, capa 2 = enemigos.
const COLLISION_MASK_NORMAL: int = 3
const COLLISION_MASK_NO_ENEMIES: int = 1

# --- Attack combo -----------------------------------------------------------
const ATTACK_MAX_STEP: int = 4
const ATTACK_SPEED_SCALE: float = 2.0
const ATTACK_COMBO_WINDOW: float = 0.45
const ATTACK_HIT_START_RATIO: float = 0.25
const ATTACK_HIT_END_RATIO: float = 0.70
const ATTACK_HITBOX_X: float = 48.0
const ATTACK_HITBOX_Y: float = -2.0
const ATTACK_ANIMATIONS: Array = [&"attack1", &"attack2", &"attack3", &"attack4"]

const JUMP_ANIMATION: StringName = &"jump"
const FALL_ANIMATION: StringName = &"fall"
const LAND_ANIMATION: StringName = &"land"
const DASH_ANIMATION: StringName = &"dash"
const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"
const HIT_1_ANIMATION: StringName = &"hit1"
const HIT_2_ANIMATION: StringName = &"hit2"
const HIT_COMBO_RESET_TIME: float = 1.0

# --- Health -----------------------------------------------------------------
const MAX_HEALTH: int = 10
const HURT_INVULN_TIME: float = 1.5

## Half of the collision box height; enemies compare it with the feet.
const HALF_HEIGHT: float = 43.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var _coyote: float = 0.0
var _buffer: float = 0.0
var _dash_time: float = 0.0
var _dash_cd: float = 0.0
var _dash_invuln_time: float = 0.0
var _dash_invuln_available: bool = true
var _facing: int = 1
var _was_on_floor: bool = true
var _was_in_air: bool = false
var _idle_time: float = 0.0
var _invuln: float = 0.0
var _health: int = MAX_HEALTH
var _dead: bool = false
var _input_locked: bool = false
var _invuln_dash_active: bool = false
var _no_cut: float = 0.0
var _hit_combo_step: int = 0
var _hit_reset_timer: float = 0.0
var _hit_anim_time: float = 0.0

var _attack_step: int = 0
var _attack_time: float = 0.0
var _attack_duration: float = 0.0
var _attack_queued: bool = false
var _attack_combo_window: float = 0.0
var _attack_hit_active: bool = false
var _attack_hit_bodies: Array[Node2D] = []
var _attack_move_pulse_time: float = 0.0
var _attack_move_enabled: bool = true


func _ready() -> void:
	collision_mask = COLLISION_MASK_NORMAL
	_attack_hitbox.monitoring = false
	_attack_shape.disabled = true
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(RUN_ANIMATION):
		_sprite.play(RUN_ANIMATION)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timers(delta)
	if not Input.is_action_pressed("attack"):
		_attack_queued = false
	_advance_attack(delta)

	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER_TIME

	var dir: float = Input.get_axis("move_left", "move_right")
	if _dash_time <= 0.0 and not is_zero_approx(dir):
		_facing = int(signf(dir))

	if _dash_time > 0.0:
		_apply_dash(delta)
	else:
		_try_dash(dir, on_floor)
		if _dash_time > 0.0:
			_apply_dash(delta)
		else:
			_apply_gravity(delta)
			if _attack_time > 0.0:
				_apply_attack_movement(dir, delta)
			else:
				_apply_horizontal(dir, on_floor, delta)
				_try_jump()
			_try_attack()

	_cut_jump()

	move_and_slide()
	if _attack_hit_active:
		_check_attack_overlaps()

	var now_floor: bool = is_on_floor()
	if now_floor and not _was_on_floor:
		landed.emit()
		_was_in_air = true
	_was_on_floor = now_floor

	_update_visuals(now_floor, delta)


# --- Per-frame helpers ------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_dash_time = maxf(_dash_time - delta, 0.0)
	if _invuln_dash_active and _dash_time <= 0.0:
		_invuln_dash_active = false
		collision_mask = COLLISION_MASK_NORMAL
	_dash_invuln_time = maxf(_dash_invuln_time - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_no_cut = maxf(_no_cut - delta, 0.0)
	_hit_anim_time = maxf(_hit_anim_time - delta, 0.0)
	if _hit_reset_timer > 0.0:
		_hit_reset_timer = maxf(_hit_reset_timer - delta, 0.0)
		if _hit_reset_timer <= 0.0:
			_hit_combo_step = 0
	if _attack_time > 0.0:
		_attack_move_pulse_time += delta
		if _attack_move_pulse_time >= ATTACK_MOVE_PULSE_INTERVAL:
			_attack_move_pulse_time -= ATTACK_MOVE_PULSE_INTERVAL
			_attack_move_enabled = not _attack_move_enabled
	else:
		_attack_move_pulse_time = 0.0
		_attack_move_enabled = true
	if _attack_combo_window > 0.0:
		_attack_combo_window = maxf(_attack_combo_window - delta, 0.0)
		if _attack_combo_window <= 0.0 and _attack_time <= 0.0:
			_attack_step = 0


func _apply_dash(delta: float) -> void:
	velocity.x = float(_facing) * DASH_SPEED
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, 0.0, 1400.0 * delta)


func _apply_gravity(delta: float) -> void:
	var g: float = GRAVITY
	if velocity.y > 0.0:
		g *= FALL_MULTIPLIER
	velocity.y = minf(velocity.y + g * delta, MAX_FALL_SPEED)


func _apply_horizontal(dir: float, on_floor: bool, delta: float) -> void:
	var accel: float = GROUND_ACCEL if on_floor else AIR_ACCEL
	var friction: float = GROUND_FRICTION if on_floor else AIR_FRICTION
	if not is_zero_approx(dir):
		velocity.x = move_toward(velocity.x, dir * MAX_SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_attack_movement(dir: float, delta: float) -> void:
	if not _attack_move_enabled or is_zero_approx(dir):
		velocity.x = move_toward(velocity.x, 0.0, ATTACK_FRICTION * delta)
	else:
		velocity.x = move_toward(
			velocity.x, dir * ATTACK_MOVE_SPEED, ATTACK_MOVE_ACCEL * delta
		)


func _try_jump() -> void:
	if _buffer <= 0.0 or _coyote <= 0.0:
		return
	velocity.y = JUMP_VELOCITY
	_buffer = 0.0
	_coyote = 0.0


func _cut_jump() -> void:
	if _no_cut > 0.0:
		return
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT


func _try_dash(dir: float, on_floor: bool) -> void:
	if not Input.is_action_just_pressed("spin") or _dash_cd > 0.0:
		return
	if not is_zero_approx(dir):
		_facing = int(signf(dir))
	_cancel_attack()
	_dash_time = DASH_DURATION
	_dash_cd = DASH_COOLDOWN
	velocity.x = float(_facing) * DASH_SPEED
	if not on_floor:
		velocity.y = maxf(velocity.y, 0.0)

	var invulnerable: bool = _dash_invuln_available
	if invulnerable:
		_dash_invuln_available = false
		_dash_invuln_time = DASH_INVULN_TIME
		_invuln_dash_active = true
		collision_mask = COLLISION_MASK_NO_ENEMIES
	dash_started.emit(invulnerable)


# --- Attack combo -----------------------------------------------------------

func _try_attack() -> void:
	if not Input.is_action_pressed("attack"):
		_attack_queued = false
		return
	if _attack_time > 0.0:
		_attack_queued = true
		return
	if _attack_step > 0 and _attack_step < ATTACK_MAX_STEP and _attack_combo_window > 0.0:
		_start_attack(_attack_step + 1)
		return
	_start_attack(1)


func _start_attack(step: int) -> void:
	_attack_step = clampi(step, 1, ATTACK_MAX_STEP)
	_attack_duration = _get_animation_duration(ATTACK_ANIMATIONS[_attack_step - 1]) / ATTACK_SPEED_SCALE
	_attack_time = _attack_duration
	_attack_queued = false
	_attack_combo_window = 0.0
	_attack_hit_bodies.clear()
	var attack_dir: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(attack_dir):
		_facing = int(signf(attack_dir))
		if _attack_move_enabled:
			velocity.x += float(_facing) * ATTACK_LUNGE
	_buffer = 0.0
	_set_attack_hitbox(false)
	_sprite.speed_scale = ATTACK_SPEED_SCALE
	_sprite.rotation = 0.0
	_sprite.position.y = 0.0
	_set_animation(ATTACK_ANIMATIONS[_attack_step - 1])
	attack_started.emit(_attack_step)


func _advance_attack(delta: float) -> void:
	if _attack_time <= 0.0:
		return
	_attack_time = maxf(_attack_time - delta, 0.0)
	_update_attack_hitbox()
	if _attack_time > 0.0:
		return

	_set_attack_hitbox(false)
	_sprite.speed_scale = 1.0
	if _attack_queued:
		var next_step: int = 1 if _attack_step >= ATTACK_MAX_STEP else _attack_step + 1
		_start_attack(next_step)
	else:
		_attack_combo_window = ATTACK_COMBO_WINDOW


func _update_attack_hitbox() -> void:
	var elapsed: float = _attack_duration - _attack_time
	var ratio: float = clampf(elapsed / maxf(_attack_duration, 0.001), 0.0, 1.0)
	_set_attack_hitbox(ratio >= ATTACK_HIT_START_RATIO and ratio <= ATTACK_HIT_END_RATIO)
	if _attack_hit_active:
		_attack_hitbox.position = Vector2(
			ATTACK_HITBOX_X * float(_facing), ATTACK_HITBOX_Y
		)


func _set_attack_hitbox(active: bool) -> void:
	if active == _attack_hit_active:
		return
	_attack_hit_active = active
	_attack_hitbox.monitoring = active
	_attack_shape.disabled = not active
	if active:
		_attack_hitbox.position = Vector2(
			ATTACK_HITBOX_X * float(_facing), ATTACK_HITBOX_Y
		)
		_attack_hit_bodies.clear()
		_check_attack_overlaps()


func _check_attack_overlaps() -> void:
	for body in _attack_hitbox.get_overlapping_bodies():
		_register_attack_hit(body)


func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	_register_attack_hit(body)


func _register_attack_hit(body: Node2D) -> void:
	if not _attack_hit_active or not _can_be_hit(body):
		return
	if _attack_hit_bodies.has(body):
		return
	_attack_hit_bodies.append(body)
	attack_hit.emit(body)


func _can_be_hit(body: Node2D) -> bool:
	if body == null or body == self:
		return false
	if body.is_in_group("enemy") or body.is_in_group("enemies"):
		return true
	# El TileMap usa StaticBody2D: no debe contar como objetivo del ataque.
	return body is CharacterBody2D or body is RigidBody2D


func _cancel_attack() -> void:
	_set_attack_hitbox(false)
	_sprite.speed_scale = 1.0
	_attack_time = 0.0
	_attack_duration = 0.0
	_attack_queued = false
	_attack_combo_window = 0.0
	_attack_step = 0
	_attack_move_pulse_time = 0.0
	_attack_move_enabled = true


# --- Health and state -------------------------------------------------------

func bounce(force: float) -> void:
	velocity.y = -force
	_coyote = 0.0
	_dash_time = 0.0
	_no_cut = 0.3
	_cancel_attack()


func get_half_height() -> float:
	return HALF_HEIGHT


func hurt(from_position: Vector2, amount: int = 1) -> void:
	if _dead or _dash_invuln_time > 0.0 or _invuln > 0.0:
		return
	_invuln = HURT_INVULN_TIME
	_dash_time = 0.0
	_cancel_attack()
	var away: float = signf(global_position.x - from_position.x)
	if is_zero_approx(away):
		away = -1.0
	velocity.x = away * 260.0
	velocity.y = -340.0
	_play_hit_animation()
	_health = maxi(_health - maxi(amount, 0), 0)
	health_changed.emit(_health, MAX_HEALTH)
	if _health <= 0:
		die()


func _play_hit_animation() -> void:
	if _hit_reset_timer <= 0.0:
		_hit_combo_step = 0
	var hit_anim: StringName = HIT_1_ANIMATION if _hit_combo_step == 0 else HIT_2_ANIMATION
	_hit_combo_step = (_hit_combo_step + 1) % 2
	_hit_reset_timer = HIT_COMBO_RESET_TIME
	_sprite.speed_scale = 1.0
	_sprite.rotation = 0.0
	_sprite.position.y = 0.0
	_sprite.play(hit_anim)
	_hit_anim_time = _get_animation_duration(hit_anim)


func _get_animation_duration(animation: StringName) -> float:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation):
		return 0.2
	var frame_count: int = _sprite.sprite_frames.get_frame_count(animation)
	var fps: float = maxf(_sprite.sprite_frames.get_animation_speed(animation), 0.001)
	var duration: float = 0.0
	for i in frame_count:
		duration += _sprite.sprite_frames.get_frame_duration(animation, i) / fps
	return maxf(duration, 0.05)


func heal(amount: int) -> void:
	if _dead or _health >= MAX_HEALTH:
		return
	_health = mini(_health + amount, MAX_HEALTH)
	health_changed.emit(_health, MAX_HEALTH)


func get_health() -> int:
	return _health


func get_max_health() -> int:
	return MAX_HEALTH


## Compatibilidad con código antiguo: ya no concede invulnerabilidad al recibir daño.
func is_spinning() -> bool:
	return _dash_time > 0.0


func is_dashing() -> bool:
	return _dash_time > 0.0


func is_attacking() -> bool:
	return _attack_time > 0.0


func get_attack_step() -> int:
	return _attack_step


func is_invulnerable() -> bool:
	return _dash_invuln_time > 0.0 or _invuln > 0.0


func is_dead() -> bool:
	return _dead


## Bloquea movimiento y ataques durante los diálogos del jefe.
func set_dialogue_locked(locked: bool) -> void:
	_input_locked = locked
	if locked:
		_cancel_attack()
		_attack_queued = false
		velocity = Vector2.ZERO
		_invuln_dash_active = false
		collision_mask = COLLISION_MASK_NORMAL
	set_physics_process(not locked and not _dead)
	set_process_unhandled_input(not locked and not _dead)


func die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	_cancel_attack()
	_dash_time = 0.0
	_invuln_dash_active = false
	collision_mask = COLLISION_MASK_NORMAL
	set_physics_process(false)
	died.emit()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_sprite, "rotation", 1.6, 0.35)
	tween.tween_property(_sprite, "modulate:a", 0.25, 0.7)


func _update_visuals(now_floor: bool, _delta: float) -> void:
	_sprite.flip_h = _facing < 0
	_sprite.modulate.a = 1.0

	if _dash_time > 0.0:
		if _sprite.animation != DASH_ANIMATION:
			_set_animation(DASH_ANIMATION)
		return

	if _hit_anim_time > 0.0:
		return

	if _attack_time > 0.0:
		var attack_anim: StringName = ATTACK_ANIMATIONS[_attack_step - 1]
		if _sprite.animation != attack_anim:
			_set_animation(attack_anim)
		return

	_sprite.rotation = 0.0
	_sprite.position.y = 0.0

	if not now_floor:
		# Transición: al empezar a bajar (desde jump) reproducir land una vez, luego fall
		if velocity.y < 0.0:
			_set_animation(JUMP_ANIMATION)
		else:
			if _sprite.animation == JUMP_ANIMATION:
				if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(LAND_ANIMATION):
					_set_animation(LAND_ANIMATION)
				else:
					_set_animation(FALL_ANIMATION)
			elif _sprite.animation == LAND_ANIMATION:
				if not _sprite.is_playing():
					_set_animation(FALL_ANIMATION)
			elif _sprite.animation == FALL_ANIMATION:
				pass
			else:
				_set_animation(FALL_ANIMATION)
		return

	if _was_in_air:
		_was_in_air = false
		# Plan recomendado: al tocar suelo ir directo a run/idle (sin land de aterrizaje)

	var speed: float = absf(velocity.x)
	if speed > 25.0:
		_idle_time = 0.0
		_sprite.speed_scale = clampf(speed / MAX_SPEED, 0.55, 1.7)
		_set_animation(RUN_ANIMATION)
	else:
		if _sprite.animation != IDLE_ANIMATION:
			_set_animation(IDLE_ANIMATION)


func _set_animation(animation: StringName) -> void:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation):
		return
	if _sprite.animation == animation and _sprite.is_playing():
		return
	_sprite.play(animation)
