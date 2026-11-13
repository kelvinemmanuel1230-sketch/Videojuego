class_name Collectible
extends Area2D

## A floating "swirlie" pickup. Emits `collected` when the player touches it.

signal collected

@onready var _sprite: Sprite2D = $Sprite2D

var _taken: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group("collectibles")
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_sprite.position.y = sin(_t * 3.0) * 4.0
	_sprite.rotation = sin(_t * 2.0) * 0.15


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	collected.emit()
	set_deferred("monitoring", false)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.7, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)