extends Area2D
class_name EnemyProjectile

@export var speed: float = 300.0
@export var lifetime: float = 3.0
var direction: Vector2 = Vector2.RIGHT
var damage: int = 10
var _remaining_lifetime: float

func _ready() -> void:
	_remaining_lifetime = lifetime
	body_entered.connect(_on_body_entered)

func configure(new_direction: Vector2, new_damage: int) -> void:
	direction = new_direction.normalized()
	damage = maxi(new_damage, 1)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		(body as PlayerController).take_damage(damage)
		queue_free()
