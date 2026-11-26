extends Node

## Controla el estado del color del mundo. El shader se aplica solo a los
## CanvasItem del grupo "monochrome" (mundo corrupto: fondo y tiles).
## Scarf no fue afectado por el virus; las arañas y el futuro mini jefe son
## creaciones del virus: ninguno lleva el grupo, por eso se ven a color.
## HUD, menús y diálogos tampoco se grisean.

signal color_restored
signal css_unlocked

const SAVE_PATH: String = "user://color_state.cfg"
const SAVE_SECTION: StringName = &"collar"
const KEY_HAS_COLOR: StringName = &"has_color"
const KEY_CSS_AVAILABLE: StringName = &"css_available"

var has_color: bool = false
var css_available: bool = false

var _material: ShaderMaterial
var _saturation: float = 0.0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/monochrome.gdshader")
	_load_state()
	_saturation = 1.0 if has_color else 0.0
	_material.set_shader_parameter("saturation", _saturation)

	get_tree().scene_changed.connect(_on_scene_changed)
	call_deferred("_apply_to_world")


func _on_scene_changed() -> void:
	call_deferred("_apply_to_world")


func _apply_to_world() -> void:
	if _material == null:
		return
	for root in get_tree().get_nodes_in_group("monochrome"):
		_apply_recursive(root)


func _apply_recursive(node: Node) -> void:
	if node is CanvasItem:
		node.material = _material
	for child in node.get_children():
		_apply_recursive(child)


## El mini jefe llama a esto al morir: deja el código disponible en el collar.
func unlock_css() -> void:
	if css_available:
		return
	css_available = true
	_save_state()
	css_unlocked.emit()


## El jugador inserta el código desde el menú del collar con la tecla E.
func insert_css() -> void:
	if not css_available or has_color:
		return
	has_color = true
	_save_state()

	var tween: Tween = create_tween()
	tween.tween_method(_set_saturation, _saturation, 1.0, 1.2)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	color_restored.emit()


func _set_saturation(value: float) -> void:
	_saturation = value
	if _material != null:
		_material.set_shader_parameter("saturation", value)


func _load_state() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	has_color = config.get_value(SAVE_SECTION, KEY_HAS_COLOR, false)
	css_available = config.get_value(SAVE_SECTION, KEY_CSS_AVAILABLE, false) or has_color


func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value(SAVE_SECTION, KEY_HAS_COLOR, has_color)
	config.set_value(SAVE_SECTION, KEY_CSS_AVAILABLE, css_available)
	config.save(SAVE_PATH)
