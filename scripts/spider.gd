class_name Spider
extends CharacterBody2D

## Basic patrolling enemy. Walks left and right, turning at walls, at ledges and
## at its patrol limit. It is defeated with two stomps from above.

signal defeated

const SPEED: float = 95.0
const GRAVITY: float = 1800.0
const MAX_FALL_SPEED: float = 900.0
const MAX_HP: int = 2
const STOMP_BOUNCE: float = 470.0
const HURT_TIME: float = 0.35
const HURT_KNOCKBACK: float = 130.0
const TURN_COOLDOWN: float = 0.15

@export var patrol_range: float = 96.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hitbox: Area2D = $Hitbox
@onready var _ledge_ray: RayCast2D = $LedgeRay

var _dir: int = -1
var _hp: int = MAX_HP
var _dead: bool = false
var _hurt_time: float = 0.0
var _turn_cd: float = 0.0
var _spawn_x: float = 0.0


func _ready() -> void:
	_spawn_x = global_position.x
	_hitbox.body_entered.connect(_on_body_entered)
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(&"walk"):
		_sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	if _dead:
		return

	_ledge_ray.position.x = float(_dir) * 20.0
	_hurt_time = maxf(_hurt_time - delta, 0.0)
	_turn_cd = maxf(_turn_cd - delta, 0.0)

	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	else:
		velocity.y = 0.0

	if _hurt_time <= 0.0:
		velocity.x = float(_dir) * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)

	move_and_slide()

	if _hurt_time <= 0.0 and _turn_cd <= 0.0 and _should_turn():
		_dir = -_dir
		_turn_cd = TURN_COOLDOWN

	_sprite.flip_h = _dir > 0
	_sprite.modulate = Color(1.0, 0.4, 0.4, 1.0) if _hurt_time > 0.0 else Color.WHITE


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
	if _is_stomp(player):
		player.bounce(STOMP_BOUNCE)
		_take_hit(player.global_position)
	else:
		player.hurt(global_position)


func _is_stomp(player: Player) -> bool:
	if player.velocity.y <= 0.0:
		return false
	return player.global_position.y < global_position.y - 12.0


func _take_hit(from_position: Vector2) -> void:
	_hp -= 1
	if _hp > 0:
		_hurt_time = HURT_TIME
		velocity.x = -signf(from_position.x - global_position.x) * HURT_KNOCKBACK
		return
	_die()


func _die() -> void:
	_dead = true
	defeated.emit()
	_hitbox.set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.35, 0.2), 0.22)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(queue_free)