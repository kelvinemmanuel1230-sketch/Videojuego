extends CanvasLayer

## Panel de ajustes compartido por el menú principal y el menú de pausa.
## El deslizador controla el volumen del bus maestro y se guarda en user://settings.cfg.

const SAVE_PATH: String = "user://settings.cfg"
const SAVE_SECTION: StringName = &"ajustes"
const KEY_VOLUME: StringName = &"volume"
const KEY_WINDOW_MODE: StringName = &"window_mode"

const DEFAULT_VOLUME: float = 1.0
const DEFAULT_MODE: int = DisplayServer.WINDOW_MODE_FULLSCREEN

@onready var _volume_slider: HSlider = $PanelContainer/VBoxContainer/VolumeSlider
@onready var _mode_option: OptionButton = $PanelContainer/VBoxContainer/ModeOption

var _applying: bool = false


func _ready() -> void:
	visible = false

	_mode_option.add_item("Pantalla completa", DisplayServer.WINDOW_MODE_FULLSCREEN)
	_mode_option.add_item("Ventana", DisplayServer.WINDOW_MODE_WINDOWED)
	_mode_option.add_item("Maximizada", DisplayServer.WINDOW_MODE_MAXIMIZED)

	var volume: float = DEFAULT_VOLUME
	var mode: int = DEFAULT_MODE
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		volume = float(config.get_value(SAVE_SECTION, KEY_VOLUME, DEFAULT_VOLUME))
		mode = int(config.get_value(SAVE_SECTION, KEY_WINDOW_MODE, DEFAULT_MODE))

	_apply_window_mode(mode)
	_applying = true
	_volume_slider.value = volume
	_mode_option.selected = _mode_option.get_item_index(mode)
	_applying = false
	_apply_volume(volume)


func open() -> void:
	visible = true
	_volume_slider.grab_focus()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _apply_window_mode(mode: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(mode)


func _apply_volume(value: float) -> void:
	# 0.0001 evita linear_to_db(0) = -inf; suena como silencio.
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value, 0.0001)))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, KEY_VOLUME, _volume_slider.value)
	config.set_value(SAVE_SECTION, KEY_WINDOW_MODE, _mode_option.get_item_id(_mode_option.selected))
	config.save(SAVE_PATH)


func _on_volume_slider_value_changed(_value: float) -> void:
	if _applying:
		return
	_apply_volume(_value)
	_save()


func _on_mode_option_item_selected(_index: int) -> void:
	if _applying:
		return
	_apply_window_mode(_mode_option.get_item_id(_mode_option.selected))
	_save()


func _on_close_button_pressed() -> void:
	close()
