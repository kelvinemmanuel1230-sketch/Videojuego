class_name MetalScarf
extends CharacterBody2D

## IA de Metal Scarf (boss1). Se mueve con CharacterBody2D y usa Areas
## solo para detectar el contacto y el ataque especial.

signal health_changed(current: int, maximum: int)
signal defeated

const MAX_HEALTH: int = 8
const CHASE_SPEED: float = 90.0
const ATTACK_SPEED: float = 260.0
const DETECT_RANGE: float = 280.0
const ATTACK_RANGE: float = 110.0
const VERTICAL_TOLERANCE: float = 60.0
const CONTACT_COOLDOWN: float = 0.8
const ATTACK_COOLDOWN: float = 5.0
const RECOVER_TIME: float = 0.5
const APPROACH_TIME: float = 0.8
const CONTACT_DAMAGE: int = 1
const ATTACK_DAMAGE: int = 3
const ATTACK_HIT_START_RATIO: float = 0.30
const ATTACK_HIT_END_RATIO: float = 0.80
const ATTACK_HITBOX_X: float = 70.0
const HURT_FLASH_TIME: float = 0.12

const IDLE_ANIMATION: StringName = &"idle"
const RUN_ANIMATION: StringName = &"run"
const ATTACK_ANIMATION: StringName = &"attack"

enum State { IDLE, CHASE, SPECIAL_CHASE, ATTACK, RECOVER }

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _contact_hitbox: Area2D = $ContactHitbox
@onready var _attack_hitbox: Area2D = $AttackHitbox
@onready var _attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var _health: int = MAX_HEALTH
var _dead: bool = false
var _combat_enabled: bool = false
var _state: State = State.IDLE
var _player: Player

var _facing: int = -1
var _contact_cd: float = 0.0
var _attack_cd: float = 0.0
var _recover_time: float = 0.0
var _approach_time: float = 0.0
var _flash_time: float = 0.0

var _attack_time: float = 0.0
var _attack_duration: float = 0.0
var _attack_damage_done: bool = false
var _attack_hit_active: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_contact_hitbox.monitoring = true
	_attack_hitbox.monitoring = false
	_attack_shape.disabled = true
	_set_animation(IDLE_ANIMATION)


func _physics_process(delta: float) -> void:
	if _dead or _player == null:
		return
	_tick_timers(delta)

	if not _combat_enabled:
		if _approach_time > 0.0:
			_approach_time -= delta
			_move_toward_player(CHASE_SPEED, delta)
			_set_animation(RUN_ANIMATION)
			if _approach_time <= 0.0:
				_combat_enabled = true
				_state = State.IDLE
		else:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_set_animation(IDLE_ANIMATION)
		move_and_slide()
		return

	_update_combat(delta)
	move_and_slide()
	_check_hitboxes()


func _tick_timers(delta: float) -> void:
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	# El cooldown del ataque especial corre mientras el jefe persigue o descansa.
	# Se congela durante la carga y el propio ataque para que no se reinicie
	# antes de haberlo ejecutado.
	if _state == State.IDLE or _state == State.CHASE or _state == State.RECOVER:
		_attack_cd = maxf(_attack_cd - delta, 0.0)
	if _flash_time > 0.0:
		_flash_time = maxf(_flash_time - delta, 0.0)
		if _flash_time <= 0.0:
			_sprite.modulate = Color.WHITE


func _update_combat(delta: float) -> void:
	var distance: float = _horizontal_distance()
	var in_range: bool = _player_in_vertical_range()

	match _state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			_set_animation(IDLE_ANIMATION)
			# El especial no depende de la distancia: al vencer el cooldown el
			# jefe corre hacia el jugador hasta poder ejecutarlo.
			if _attack_cd <= 0.0 and in_range:
				_state = State.SPECIAL_CHASE
			elif in_range and distance <= DETECT_RANGE:
				_state = State.CHASE
		State.CHASE:
			_move_toward_player(CHASE_SPEED, delta)
			_set_animation(RUN_ANIMATION)
			if _attack_cd <= 0.0 and in_range:
				_state = State.SPECIAL_CHASE
		State.SPECIAL_CHASE:
			_move_toward_player(ATTACK_SPEED, delta)
			_set_animation(RUN_ANIMATION)
			if in_range and distance <= ATTACK_RANGE:
				_start_attack()
		State.ATTACK:
			_attack_time = maxf(_attack_time - delta, 0.0)
			var elapsed: float = _attack_duration - _attack_time
			var ratio: float = clampf(elapsed / maxf(_attack_duration, 0.001), 0.0, 1.0)
			if ratio >= ATTACK_HIT_START_RATIO and ratio <= ATTACK_HIT_END_RATIO:
				_move_toward_player(ATTACK_SPEED, delta)
				_set_attack_hitbox(true)
				_attack_hitbox.position = Vector2(ATTACK_HITBOX_X * float(_facing), 6.0)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
				_set_attack_hitbox(false)
			if _attack_time <= 0.0:
				_set_attack_hitbox(false)
				_state = State.RECOVER
				_recover_time = RECOVER_TIME
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1600.0 * delta)
			_set_animation(IDLE_ANIMATION)
			_recover_time = maxf(_recover_time - delta, 0.0)
			if _recover_time <= 0.0:
				_state = State.IDLE


func _move_toward_player(speed: float, delta: float) -> void:
	var diff: float = _player.global_position.x - global_position.x
	if is_zero_approx(diff):
		return
	_facing = 1 if diff > 0.0 else -1
	_sprite.flip_h = _facing < 0
	velocity.x = move_toward(velocity.x, float(_facing) * speed, 1600.0 * delta)


func _horizontal_distance() -> float:
	if _player == null:
		return INF
	return absf(global_position.x - _player.global_position.x)


func _player_in_vertical_range() -> bool:
	if _player == null:
		return false
	return absf(global_position.y - _player.global_position.y) <= VERTICAL_TOLERANCE


func _start_attack() -> void:
	var diff: float = _player.global_position.x - global_position.x
	if not is_zero_approx(diff):
		_facing = 1 if diff > 0.0 else -1
	_sprite.flip_h = _facing < 0
	_attack_duration = _get_animation_duration(ATTACK_ANIMATION)
	_attack_time = _attack_duration
	_attack_damage_done = false
	_attack_cd = ATTACK_COOLDOWN
	_state = State.ATTACK
	_set_animation(ATTACK_ANIMATION)


func _set_attack_hitbox(active: bool) -> void:
	if active == _attack_hit_active:
		return
	_attack_hit_active = active
	_attack_hitbox.monitoring = active
	_attack_shape.disabled = not active
	if active:
		_attack_hitbox.position = Vector2(ATTACK_HITBOX_X * float(_facing), 6.0)


func _check_hitboxes() -> void:
	if _contact_cd <= 0.0 and _state != State.ATTACK:
		for body in _contact_hitbox.get_overlapping_bodies():
			if body is Player:
				body.hurt(global_position, CONTACT_DAMAGE)
				_contact_cd = CONTACT_COOLDOWN
				break

	if _attack_hit_active and not _attack_damage_done:
		for body in _attack_hitbox.get_overlapping_bodies():
			if body is Player:
				body.hurt(global_position, ATTACK_DAMAGE)
				_attack_damage_done = true
				break


func _get_animation_duration(animation: StringName) -> float:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation):
		return 1.0
	var frame_count: int = _sprite.sprite_frames.get_frame_count(animation)
	var fps: float = maxf(_sprite.sprite_frames.get_animation_speed(animation), 0.001)
	var duration: float = 0.0
	for i in frame_count:
		duration += _sprite.sprite_frames.get_frame_duration(animation, i) / fps
	return maxf(duration, 0.05)


func _set_animation(animation: StringName) -> void:
	if not _sprite.sprite_frames or not _sprite.sprite_frames.has_animation(animation):
		return
	if _sprite.animation == animation and _sprite.is_playing():
		return
	_sprite.play(animation)


# --- Control del encuentro --------------------------------------------------

func hold_idle() -> void:
	_combat_enabled = false
	_approach_time = 0.0
	_attack_cd = ATTACK_COOLDOWN
	_state = State.IDLE
	_set_attack_hitbox(false)
	_set_animation(IDLE_ANIMATION)


func begin_approach() -> void:
	_combat_enabled = false
	_approach_time = APPROACH_TIME
	_attack_cd = ATTACK_COOLDOWN
	_state = State.IDLE


# --- Daño y muerte ----------------------------------------------------------

func take_damage(amount: int) -> void:
	if _dead:
		return
	_health = maxi(_health - maxi(amount, 0), 0)
	health_changed.emit(_health, MAX_HEALTH)
	_flash_time = HURT_FLASH_TIME
	_sprite.modulate = Color(1.0, 0.45, 0.45, 1.0)
	global_position.x += float(-_facing) * 6.0
	if _health <= 0:
		_die()


func get_health() -> int:
	return _health


func get_max_health() -> int:
	return MAX_HEALTH


func is_dead() -> bool:
	return _dead


func _die() -> void:
	if _dead:
		return
	_dead = true
	_set_attack_hitbox(false)
	_contact_hitbox.monitoring = false
	_body_shape.disabled = true
	set_physics_process(false)
	defeated.emit()

	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.6)
	tween.finished.connect(queue_free)
