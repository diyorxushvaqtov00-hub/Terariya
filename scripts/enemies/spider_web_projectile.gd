extends Area2D
class_name SpiderWebProjectile

@export var speed: float = 245.0
@export var max_lifetime: float = 4.0
@export var impact_damage: int = 12
@export var poison_damage: int = 4
@export var poison_ticks: int = 3

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
	var player := body as PlayerController
	player.take_damage(impact_damage)
	player.apply_poison(poison_damage, poison_ticks, 0.8)
	player.apply_web_slow(2.2, 0.55)
	queue_free()
