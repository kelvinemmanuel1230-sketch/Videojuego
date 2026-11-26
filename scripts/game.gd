class_name Game
extends Node2D

## Level coordinator: respawns the player after a fall, shows the health bar and
## controls the Metal Scarf encounter.

const BOSS_DIALOGUE = preload("res://dialogue/boss1.dialogue")
const BOSS_INTRO_CUE: String = "boss1_encuentro"
const BOSS_DEFEAT_CUE: String = "boss1_derrota"
const COMBO_DAMAGE: Array[int] = [1, 1, 1, 2]

@onready var _player: Player = $Player
@onready var _death_zone: Area2D = $DeathZone
@onready var _health_bar: ProgressBar = $HUD/HealthBar
@onready var _boss: MetalScarf = $Enemies/metal_scarf
@onready var _boss_panel: Control = $HUD/BossPanel
@onready var _boss_bar: ProgressBar = $HUD/BossPanel/BossBar

var _spawn_point: Vector2
var _game_over: bool = false
var _boss_intro_started: bool = false
var _boss_defeat_started: bool = false
var _attack_damage: int = 1


func _ready() -> void:
	_spawn_point = _player.global_position
	_death_zone.body_entered.connect(_on_death_zone_body_entered)
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_player.attack_started.connect(_on_player_attack_started)
	_player.attack_hit.connect(_on_player_attack_hit)

	_boss.hold_idle()
	_boss.health_changed.connect(_on_boss_health_changed)
	_boss.defeated.connect(_on_boss_defeated)
	_boss_panel.visible = false
	_update_boss_bar(_boss.get_health(), _boss.get_max_health())

	_update_health_bar(_player.get_health(), _player.get_max_health())


func _physics_process(_delta: float) -> void:
	if _boss_intro_started or _boss_defeat_started or _game_over:
		return
	if not is_instance_valid(_boss) or _boss.is_dead() or _player.is_dead():
		return

	var distance_x: float = absf(_player.global_position.x - _boss.global_position.x)
	var distance_y: float = absf(_player.global_position.y - _boss.global_position.y)
	if distance_x <= MetalScarf.DETECT_RANGE and distance_y <= 140.0:
		_start_boss_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()


func _on_health_changed(current: int, maximum: int) -> void:
	_update_health_bar(current, maximum)


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	_player.set_dialogue_locked(false)
	await get_tree().create_timer(1.4).timeout
	get_tree().reload_current_scene()


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body is Player and not _player.is_dead():
		_player.velocity = Vector2.ZERO
		_player.global_position = _spawn_point


func _update_health_bar(current: int, maximum: int) -> void:
	_health_bar.max_value = float(maximum)
	_health_bar.value = float(current)


# --- Encuentro con Metal Scarf ----------------------------------------------


func _start_boss_intro() -> void:
	_boss_intro_started = true
	_boss.hold_idle()
	_player.set_dialogue_locked(true)
	_boss_panel.visible = true
	DialogueManager.dialogue_ended.connect(_on_boss_intro_ended, CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon(BOSS_DIALOGUE, BOSS_INTRO_CUE)


func _on_boss_intro_ended(_resource: DialogueResource) -> void:
	if _game_over:
		return
	_player.set_dialogue_locked(false)
	_boss.begin_approach()


func _on_player_attack_started(step: int) -> void:
	_attack_damage = COMBO_DAMAGE[clampi(step, 1, COMBO_DAMAGE.size()) - 1]


func _on_player_attack_hit(body: Node2D) -> void:
	if body is MetalScarf and is_instance_valid(body):
		body.take_damage(_attack_damage)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_update_boss_bar(current, maximum)


func _update_boss_bar(current: int, maximum: int) -> void:
	_boss_bar.max_value = float(maximum)
	_boss_bar.value = float(current)


func _on_boss_defeated() -> void:
	if _boss_defeat_started or _game_over:
		return
	_boss_defeat_started = true
	_player.set_dialogue_locked(true)
	ColorSystem.unlock_css()
	DialogueManager.dialogue_ended.connect(_on_boss_defeat_ended, CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon(BOSS_DIALOGUE, BOSS_DEFEAT_CUE)


func _on_boss_defeat_ended(_resource: DialogueResource) -> void:
	_boss_panel.visible = false
	if not _game_over:
		_player.set_dialogue_locked(false)
