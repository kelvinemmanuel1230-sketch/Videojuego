class_name Game
extends Node2D

## Level coordinator: counts the swirlies, respawns the player after a fall
## and shows a small HUD.

@onready var _player: Player = $Player
@onready var _death_zone: Area2D = $DeathZone
@onready var _status_label: Label = $HUD/StatusLabel
@onready var _health_bar: ProgressBar = $HUD/HealthBar

var _spawn_point: Vector2
var _total: int = 0
var _collected: int = 0
var _won: bool = false
var _game_over: bool = false


func _ready() -> void:
	_spawn_point = _player.global_position
	_death_zone.body_entered.connect(_on_death_zone_body_entered)
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_update_health_bar(_player.get_health(), _player.get_max_health())

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
	_player.heal(1)
	_update_status()
	if _collected >= _total and not _won:
		_won = true
		_status_label.text = "¡Los recogiste todos!  %d / %d  ✨" % [_collected, _total]


func _on_health_changed(current: int, maximum: int) -> void:
	_update_health_bar(current, maximum)


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	_status_label.text = "¡Te quedaste sin vida!  Reiniciando…"
	await get_tree().create_timer(1.4).timeout
	get_tree().reload_current_scene()


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body is Player and not _player.is_dead():
		_player.velocity = Vector2.ZERO
		_player.global_position = _spawn_point


func _update_health_bar(current: int, maximum: int) -> void:
	_health_bar.max_value = float(maximum)
	_health_bar.value = float(current)


func _update_status() -> void:
	if _won:
		return
	_status_label.text = "Swirlies: %d / %d" % [_collected, _total]