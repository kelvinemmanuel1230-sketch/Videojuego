class_name Spring
extends StaticBody2D

## Bounce pad. When the player lands on top of it they are launched upward,
## regardless of how fast they were falling.

signal launched

const LAUNCH_VELOCITY: float = 1300.0
const HALF_HEIGHT: float = 17.0
const TOP_TOLERANCE: float = 10.0
const SQUASH: float = 0.45

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trigger: Area2D = $Trigger

var _base_scale_y: float = 1.0
var _half_height: float = 0.0
var _tween: Tween


func _ready() -> void:
	_base_scale_y = _sprite.scale.y
	if _sprite.texture:
		_half_height = _sprite.texture.get_height() * 0.5 * _base_scale_y
	_trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	var player: Player = body
	if player.is_dead():
		return
	var feet: float = player.global_position.y + player.get_half_height()
	if feet > global_position.y - HALF_HEIGHT + TOP_TOLERANCE:
		return
	player.bounce(LAUNCH_VELOCITY)
	_play_squash()
	launched.emit()


func _play_squash() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_squash, SQUASH, 1.12, 0.1)
	_tween.tween_method(_set_squash, 1.12, 1.0, 0.16)


func _set_squash(amount: float) -> void:
	_sprite.scale.y = _base_scale_y * amount
	_sprite.position.y = _half_height * (1.0 - amount)