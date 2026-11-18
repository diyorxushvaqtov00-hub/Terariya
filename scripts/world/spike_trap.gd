extends Area2D
class_name SpikeTrap

@export var damage: int = 18

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_damage(damage)
