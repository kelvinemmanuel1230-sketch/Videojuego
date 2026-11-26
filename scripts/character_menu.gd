extends CanvasLayer

## Menú del personaje. Se abre con E, no pausa el juego y se cierra al recibir daño.
## TODO: el collar tendrá un minimapa con teletransporte a zonas ya descubiertas.

const CSS_TEXT: String = "/* Collar v1.0 — restauración de color */\n" + \
	"body {\n" + \
	"  background-color: #2FBDFF;\n" + \
	"  color: #222034;\n" + \
	"}\n\n" + \
	".cielo  { background-color: #2FBDFF; }\n" + \
	".pasto  { background-color: #78CB2C; }\n" + \
	".tierra { background-color: #874920; }"

@onready var _hint_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HintLabel
@onready var _code_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Collar/CodeLabel
@onready var _insert_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Collar/InsertButton

var _last_health: int = 0


func _ready() -> void:
	visible = false

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		_last_health = player.get_health()
		player.health_changed.connect(_on_health_changed)

	ColorSystem.css_unlocked.connect(_refresh)
	ColorSystem.color_restored.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("collar"):
		visible = not visible


func _on_health_changed(current: int, _maximum: int) -> void:
	if current < _last_health:
		visible = false
	_last_health = current


func _on_insert_button_pressed() -> void:
	ColorSystem.insert_css()
	_refresh()


func _refresh() -> void:
	if ColorSystem.has_color:
		_hint_label.text = "Código insertado. El mundo vuelve a tener color."
		_code_label.text = CSS_TEXT + "\n\n[color=#78CB2C]ESTADO: COLLAR ACTIVO[/color]"
		_insert_button.disabled = true
		_insert_button.text = "CÓDIGO INSERTADO"
	elif ColorSystem.css_available:
		_hint_label.text = "El mini jefe te dio un código. Insértalo en el collar."
		_code_label.text = CSS_TEXT
		_insert_button.disabled = false
		_insert_button.text = "INSERTAR CÓDIGO"
	else:
		_hint_label.text = "El collar está en blanco. Derrota al virus para obtener el código."
		_code_label.text = "[color=#9aa6a8]Sin datos. El collar permanece invisible mientras no se usa.[/color]"
		_insert_button.disabled = true
		_insert_button.text = "SIN CÓDIGO"
