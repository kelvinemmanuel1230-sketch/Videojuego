class_name Player
extends CharacterBody2D

## Momentum-based platformer controller inspired by Fancy Pants Adventures:
## run with inertia, variable-height jumps and a spin roll.

signal landed
signal spin_started
signal health_changed(current: int, maximum: int)
signal died

# --- Horizontal movement ----------------------------------------------------
const MAX_SPEED: float = 330.0
const GROUND_ACCEL: float = 2600.0
const GROUND_FRICTION: float = 3000.0
const AIR_ACCEL: float = 1700.0
const AIR_FRICTION: float = 450.0

# --- Gravity and jumping ----------------------------------------------------
const GRAVITY: float = 1800.0
const FALL_MULTIPLIER: float = 1.5
const MAX_FALL_SPEED: float = 950.0
const JUMP_VELOCITY: float = -900.0
const JUMP_CUT: float = 0.45
const COYOTE_TIME: float = 0.1
const JUMP_BUFFER_TIME: float = 0.12

# --- Dash -----------------------------------------------------
const SPIN_SPEED: float = 300
const SPIN_DURATION: float = 0.32
const SPIN_COOLDOWN: float = 0.50

const RUN_ANIMATION: StringName = &"run"
const START_JUMP_ANIMATION: StringName = &"start-jump"
const JUMP_ANIMATION: StringName = &"jump"
const FALL_ANIMATION: StringName = &"fall"
const LAND_ANIMATION: StringName = &"land"
const IDLE_ANIMATION: StringName = &"idle"
const HIT_1_ANIMATION: StringName = &"hit1"
const HIT_2_ANIMATION: StringName = &"hit2"
const HIT_COMBO_RESET_TIME: float = 1.0

# --- Health -----------------------------------------------------------------
const MAX_HEALTH: int = 5
const INVULN_TIME: float = 1.2

## Half of the collision box height; springs and enemies compare it with the feet.
const HALF_HEIGHT: float = 43.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote: float = 0.0
var _buffer: float = 0.0
var _spin_time: float = 0.0
var _spin_cd: float = 0.0
var _dash_time: float = 0.0
var _facing: int = 1
var _was_on_floor: bool = true
var _was_in_air: bool = false
var _idle_time: float = 0.0
var _invuln: float = 0.0
var _health: int = MAX_HEALTH
var _dead: bool = false
var _no_cut: float = 0.0
var _hit_combo_step: int = 0
var _hit_reset_timer: float = 0.0
var _hit_anim_time: float = 0.0


func _ready() -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(RUN_ANIMATION):
		_sprite.play(RUN_ANIMATION)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timers(delta)

	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER_TIME

	var dir: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(dir):
		_facing = int(signf(dir))

	if _dash_time > 0.0:
		_apply_dash(delta)
	else:
		_apply_gravity(delta)
		_apply_horizontal(dir, on_floor, delta)
		_try_jump()
		_try_spin(dir, on_floor)

	_cut_jump()

	move_and_slide()

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
	_spin_cd = maxf(_spin_cd - delta, 0.0)
	_invuln = 0.0
	_no_cut = maxf(_no_cut - delta, 0.0)
	_hit_anim_time = maxf(_hit_anim_time - delta, 0.0)
	if _hit_reset_timer > 0.0:
		_hit_reset_timer = maxf(_hit_reset_timer - delta, 0.0)
		if _hit_reset_timer <= 0.0:
			_hit_combo_step = 0
	if _dash_time > 0.0:
		_dash_time = maxf(_dash_time - delta, 0.0)
	if _spin_time > 0.0:
		_spin_time = maxf(_spin_time - delta, 0.0)


func _do_spin(delta: float) -> void:
	velocity.x = float(_facing) * SPIN_SPEED
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, 0.0, 1400.0 * delta)


func _apply_dash(delta: float) -> void:
	velocity.x = float(_facing) * SPIN_SPEED * 2.0
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


func _try_spin(dir: float, on_floor: bool) -> void:
	if not Input.is_action_just_pressed("spin") or _spin_cd > 0.0:
		return
	if not is_zero_approx(dir):
		_facing = int(signf(dir))
	_dash_time = SPIN_DURATION
	_spin_cd = SPIN_COOLDOWN
	velocity.x = float(_facing) * SPIN_SPEED
	if not on_floor:
		velocity.y = maxf(velocity.y, 0.0)
	spin_started.emit()


func bounce(force: float) -> void:
	velocity.y = -force
	_coyote = 0.0
	_spin_time = 0.0
	_no_cut = 0.3


func get_half_height() -> float:
	return HALF_HEIGHT


func hurt(from_position: Vector2) -> void:
	if _dead or _spin_time > 0.0:
		return
	var away: float = signf(global_position.x - from_position.x)
	if is_zero_approx(away):
		away = -1.0
	velocity.x = away * 260.0
	velocity.y = -340.0
	_play_hit_animation()
	_health = maxi(_health - 1, 0)
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


func is_spinning() -> bool:
	return _spin_time > 0.0 or _dash_time > 0.0


func is_dead() -> bool:
	return _dead


func die() -> void:
	if _dead:
		return
	_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	died.emit()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_sprite, "rotation", 1.6, 0.35)
	tween.tween_property(_sprite, "modulate:a", 0.25, 0.7)


func _update_visuals(now_floor: bool, _delta: float) -> void:
	_sprite.flip_h = _facing < 0
	_sprite.modulate.a = 1.0

	if _dash_time > 0.0:
		if _sprite.animation != &"dash":
			_sprite.play(&"dash")
		return

	if _hit_anim_time > 0.0:
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
