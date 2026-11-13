class_name Game
extends Node2D

## Level coordinator: counts the swirlies, respawns the player after a fall
## and shows a small HUD.

@onready var _player: Player = $Player
@onready var _death_zone: Area2D = $DeathZone
@onready var _status_label: Label = $HUD/StatusLabel

var _spawn_point: Vector2
var _total: int = 0
var _collected: int = 0
var _won: bool = false


func _ready() -> void:
	_spawn_point = _player.global_position
	_death_zone.body_entered.connect(_on_death_zone_body_entered)

	for node in get_tree().get_nodes_in_group("collectibles"):
		if node is Collectible:
			node.collected.connect(_on_collected)
			_total += 1

	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _on_collected() -> void:
	_collected += 1
	_update_status()
	if _collected >= _total and not _won:
		_won = true
		_status_label.text = "¡Los recogiste todos!  %d / %d  ✨" % [_collected, _total]


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body is Player:
		_player.velocity = Vector2.ZERO
		_player.global_position = _spawn_point


func _update_status() -> void:
	if _won:
		return
	_status_label.text = "Swirlies: %d / %d" % [_collected, _total]