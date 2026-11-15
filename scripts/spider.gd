class_name Spider
extends CharacterBody2D

## Basic patrolling enemy. Walks left and right, turning at walls, at ledges and
## at its patrol limit. The first hit stuns it and leaves it motionless; if it is
## not finished off before the timer expires it gets back up with full health.

signal defeated

const SPEED: float = 95.0
const GRAVITY: float = 1800.0
const MAX_FALL_SPEED: float = 900.0
const STOMP_BOUNCE: float = 470.0
const STUN_TIME: float = 4.0
const STUN_KNOCKBACK: float = 130.0
const TURN_COOLDOWN: float = 0.15
const BLINK_TIME: float = 1.2

const WALK_ANIMATION: StringName = &"walk"
const STUNNED_ANIMATION: StringName = &"stunned"

@export var patrol_range: float = 96.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _ledge_ray: RayCast2D = $LedgeRay

var _dir: int = -1
var _dead: bool = false
var _stunned: bool = false
var _stun_time: float = 0.0
var _turn_cd: float = 0.0
var _spawn_x: float = 0.0


func _ready() -> void:
	_spawn_x = global_position.x
	_hitbox.body_entered.connect(_on_body_entered)
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(WALK_ANIMATION):
		_sprite.play(WALK_ANIMATION)


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_turn_cd = maxf(_turn_cd - delta, 0.0)
	_apply_gravity(delta)

	if _stunned:
		_do_stun(delta)
		return

	_ledge_ray.position.x = float(_dir) * 20.0
	velocity.x = float(_dir) * SPEED
	move_and_slide()

	if _turn_cd <= 0.0 and _should_turn():
		_dir = -_dir
		_turn_cd = TURN_COOLDOWN

	_sprite.flip_h = _dir > 0


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)


func _do_stun(delta: float) -> void:
	_stun_time = maxf(_stun_time - delta, 0.0)
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	move_and_slide()
	if _stun_time <= BLINK_TIME:
		_sprite.modulate.a = 1.0 if int(_stun_time * 8.0) % 2 == 0 else 0.3
	if _stun_time <= 0.0:
		_recover()


func _should_turn() -> bool:
	if is_on_wall():
		return true
	if is_on_floor() and not _ledge_ray.is_colliding():
		return true
	return absf(global_position.x - _spawn_x) > patrol_range


func _on_body_entered(body: Node2D) -> void:
	if _dead or not body is Player:
		return
	var player: Player = body
	if player.is_dead():
		return

	if _stunned:
		# A stunned spider is harmless and has to be finished off deliberately.
		if player.is_spinning() or _is_stomp(player):
			_die()
		return

	if player.is_spinning():
		_stun(player.global_position)
	elif _is_stomp(player):
		player.bounce(STOMP_BOUNCE)
		_stun(player.global_position)
	else:
		player.hurt(global_position)


func _is_stomp(player: Player) -> bool:
	if player.velocity.y <= 0.0:
		return false
	return player.global_position.y < global_position.y - 12.0


func _stun(from_position: Vector2) -> void:
	_stunned = true
	_stun_time = STUN_TIME
	velocity.x = -signf(from_position.x - global_position.x) * STUN_KNOCKBACK
	_sprite.modulate.a = 1.0
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(STUNNED_ANIMATION):
		_sprite.play(STUNNED_ANIMATION)


func _recover() -> void:
	_stunned = false
	_sprite.modulate.a = 1.0
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(WALK_ANIMATION):
		_sprite.play(WALK_ANIMATION)


func _die() -> void:
	_dead = true
	_sprite.modulate.a = 1.0
	defeated.emit()
	_hitbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 0.2), 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)