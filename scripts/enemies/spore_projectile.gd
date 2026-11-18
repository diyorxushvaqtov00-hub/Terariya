extends Area2D
class_name SporeProjectile

@export var speed: float = 220.0
@export var max_lifetime: float = 4.5
@export var impact_damage: int = 9
@export var poison_damage: int = 3

var direction: Vector2 = Vector2.LEFT
var _elapsed: float = 0.0
var _has_hit: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta
	_elapsed += delta
	if _elapsed >= max_lifetime:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _has_hit or not body is PlayerController:
		return
	_has_hit = true
	var target := body as PlayerController
	target.take_damage(impact_damage)
	target.apply_poison(poison_damage, 4, 0.85)
	queue_free()
