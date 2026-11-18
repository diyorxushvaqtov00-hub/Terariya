extends Area2D
class_name SwingingBlade

@export var damage: int = 24
@export var swing_speed: float = 1.8
@export var swing_angle_degrees: float = 48.0

var _elapsed: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_elapsed += delta
	rotation = deg_to_rad(swing_angle_degrees) * sin(_elapsed * swing_speed)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_damage(damage)
