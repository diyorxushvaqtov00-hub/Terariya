extends Area2D
class_name VoidBoltProjectile

@export var speed: float = 540.0
@export var lifetime: float = 2.8
@export var impact_damage: int = 92

var direction: Vector2 = Vector2.RIGHT
var _remaining_lifetime: float
var _has_hit: bool = false

func _ready() -> void:
	_remaining_lifetime = lifetime
	body_entered.connect(_on_body_entered)

func setup(facing: Vector2, damage: int) -> void:
	direction = facing.normalized() if facing.length_squared() > 0.0 else Vector2.RIGHT
	impact_damage = maxi(damage, 1)

func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	global_position += direction * speed * delta
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _has_hit or not body.has_method("take_damage"):
		return
	_has_hit = true
	body.take_damage(impact_damage)
	queue_free()
