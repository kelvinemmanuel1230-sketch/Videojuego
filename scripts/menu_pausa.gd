extends Control

@onready var _ajustes = $Ajustes


func pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if _ajustes.is_open():
		_ajustes.close()
		get_viewport().set_input_as_handled()
		return
	pause()


func _on_continue_button_pressed() -> void:
	pause()


func _on_ajustes_button_pressed() -> void:
	_ajustes.open()


func _on_reset_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu_inicio.tscn")


func _on_exit_button_pressed() -> void:
	get_tree().quit()
