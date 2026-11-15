class_name Player
extends CharacterBody2D

## Momentum-based platformer controller inspired by Fancy Pants Adventures:
## run with inertia, variable-height jumps, wall slide / wall jump and a spin roll.

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

# --- Wall interaction -------------------------------------------------------
const WALL_SLIDE_SPEED: float = 130.0
const WALL_JUMP_PUSH: float = 430.0
const WALL_JUMP_UP: float = -820.0
const WALL_STICK_TIME: float = 0.14

# --- Spin (roll / dive) -----------------------------------------------------
const SPIN_SPEED: float = 650.0
const SPIN_DURATION: float = 0.32
const SPIN_COOLDOWN: float = 0.45
const SPIN_ROTATION_SPEED: float = 18.0

const RUN_ANIMATION: StringName = &"run"
const JUMP_ANIMATION: StringName = &"jump"
const FALL_ANIMATION: StringName = &"fall"

# --- Health -----------------------------------------------------------------
const MAX_HEALTH: int = 5
const INVULN_TIME: float = 1.2

## Half of the collision box height; springs and enemies compare it with the feet.
const HALF_HEIGHT: float = 43.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote: float = 0.0
var _buffer: float = 0.0
var _wall_stick: float = 0.0
var _spin_time: float = 0.0
var _spin_cd: float = 0.0
var _facing: int = 1
var _was_on_floor: bool = true
var _idle_time: float = 0.0
var _invuln: float = 0.0
var _health: int = MAX_HEALTH
var _dead: bool = false
var _no_cut: float = 0.0


func _ready() -> void:
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(RUN_ANIMATION):
		_sprite.play(RUN_ANIMATION)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timers(delta)

	var on_floor: bool = is_on_floor()
	var on_wall: bool = is_on_wall_only()
	var wall_normal: Vector2 = get_wall_normal()

	if on_floor:
		_coyote = COYOTE_TIME
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER_TIME

	var dir: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(dir):
		_facing = int(signf(dir))

	if _spin_time > 0.0:
		_do_spin(delta)
	else:
		_apply_gravity(delta, dir, on_wall, on_floor, wall_normal)
		_apply_horizontal(dir, on_floor, delta)
		_try_wall_jump(on_wall, on_floor, wall_normal)
		_try_jump()
		_try_spin(dir, on_floor)

	_cut_jump()

	move_and_slide()

	var now_floor: bool = is_on_floor()
	if now_floor and not _was_on_floor:
		landed.emit()
	_was_on_floor = now_floor

	_update_visuals(now_floor, delta)


# --- Per-frame helpers ------------------------------------------------------

func _tick_timers(delta: float) -> void:
	_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	_wall_stick = maxf(_wall_stick - delta, 0.0)
	_spin_cd = maxf(_spin_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_no_cut = maxf(_no_cut - delta, 0.0)
	if _spin_time > 0.0:
		_spin_time = maxf(_spin_time - delta, 0.0)


func _do_spin(delta: float) -> void:
	velocity.x = float(_facing) * SPIN_SPEED
	if not is_on_floor():
		velocity.y = move_toward(velocity.y, 0.0, 1400.0 * delta)


func _apply_gravity(delta: float, dir: float, on_wall: bool, on_floor: bool, wall_normal: Vector2) -> void:
	var pushing_into_wall: bool = not is_zero_approx(dir) and dir * wall_normal.x < 0.0
	var wall_sliding: bool = on_wall and not on_floor and velocity.y > 0.0 and _wall_stick <= 0.0 and pushing_into_wall
	if wall_sliding:
		velocity.y = minf(velocity.y + GRAVITY * delta, WALL_SLIDE_SPEED)
		return
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


func _try_wall_jump(on_wall: bool, on_floor: bool, wall_normal: Vector2) -> void:
	if not (on_wall and not on_floor and _buffer > 0.0):
		return
	if is_zero_approx(wall_normal.x):
		return
	velocity.x = wall_normal.x * WALL_JUMP_PUSH
	velocity.y = WALL_JUMP_UP
	_wall_stick = WALL_STICK_TIME
	_buffer = 0.0
	_coyote = 0.0
	_facing = int(signf(wall_normal.x))


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
	_spin_time = SPIN_DURATION
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
	if _dead or _invuln > 0.0 or _spin_time > 0.0:
		return
	_invuln = INVULN_TIME
	_wall_stick = 0.0
	var away: float = signf(global_position.x - from_position.x)
	if is_zero_approx(away):
		away = -1.0
	velocity.x = away * 260.0
	velocity.y = -340.0
	_health = maxi(_health - 1, 0)
	health_changed.emit(_health, MAX_HEALTH)
	if _health <= 0:
		die()


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
	return _spin_time > 0.0


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


func _update_visuals(now_floor: bool, delta: float) -> void:
	_sprite.flip_h = _facing < 0
	_sprite.modulate.a = 0.35 if _invuln > 0.0 and int(_invuln * 14.0) % 2 == 0 else 1.0

	if _spin_time > 0.0:
		_sprite.rotation -= SPIN_ROTATION_SPEED * delta * float(_facing)
		return

	_sprite.rotation = 0.0
	_sprite.position.y = 0.0

	if not now_floor:
		_set_animation(JUMP_ANIMATION if velocity.y < 0.0 else FALL_ANIMATION)
		return

	var speed: float = absf(velocity.x)
	if speed > 25.0:
		_idle_time = 0.0
		_sprite.speed_scale = clampf(speed / MAX_SPEED, 0.55, 1.7)
		_set_animation(RUN_ANIMATION)
	else:
		_idle_time += delta
		_sprite.position.y = sin(_idle_time * 4.0) * 2.0
		if _sprite.animation != RUN_ANIMATION:
			_sprite.animation = RUN_ANIMATION
		_sprite.stop()
		_sprite.frame = 0


func _set_animation(animation: StringName) -> void:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation):
		return
	if _sprite.animation == animation and _sprite.is_playing():
		return
	_sprite.play(animation)