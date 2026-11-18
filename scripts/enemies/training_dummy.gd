extends StaticBody2D
class_name TrainingDummy

signal health_changed(current: int, maximum: int)
signal defeated

@export var max_health: int = 100
var health: int

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		defeated.emit()
		queue_free()
