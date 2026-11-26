extends Control

@onready var _controls_panel: PanelContainer = $MenuPanel/VBoxContainer/controls_panel
@onready var _play_button: Button = $MenuPanel/VBoxContainer/play_button
@onready var _ajustes = $Ajustes
@onready var _embers: Node2D = $Embers
@onready var _music: AudioStreamPlayer = $MenuMusic
@onready var _prologo: DialogueResource = load("res://dialogue/prologo.dialogue")

var _starting: bool = false


func _ready() -> void:
	get_tree().paused = false

	var viewport_rect := get_viewport_rect()
	_embers.position = viewport_rect.size / 2.0
	for emitter in _embers.get_children():
		if emitter is CPUParticles2D:
			emitter.emission_rect_extents = viewport_rect.size / 2.0

	var stream := _music.stream as AudioStreamMP3
	if stream != null:
		stream.loop = true
	# En headless no hay dispositivo de audio; evitar crear un playback que fugue al salir.
	if DisplayServer.get_name() != "headless":
		_music.play()

	_play_button.grab_focus()


func _on_play_button_pressed() -> void:
	if _starting:
		return
	_starting = true
	_music.stop()
	_play_button.disabled = true
	get_tree().paused = false
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon(_prologo, "prologo")


func _on_dialogue_ended(_resource: DialogueResource) -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_controls_button_pressed() -> void:
	_controls_panel.visible = not _controls_panel.visible


func _on_ajustes_button_pressed() -> void:
	_ajustes.open()


func _exit_tree() -> void:
	if _music != null:
		_music.stop()
		_music.stream = null


func _on_exit_button_pressed() -> void:
	get_tree().quit()
