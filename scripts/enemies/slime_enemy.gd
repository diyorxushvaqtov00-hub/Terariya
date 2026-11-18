extends CharacterBody2D
class_name SlimeEnemy

signal health_changed(current: int, maximum: int)
signal defeated

@export var player_path: NodePath = NodePath("../Player")
@export var max_health: int = 60
@export var move_speed: float = 82.0
@export var aggro_range: float = 320.0
@export var attack_range: float = 34.0
@export var attack_damage: int = 8
@export var attack_cooldown: float = 1.25
@export var jump_velocity: float = -300.0

var health: int
var _attack_ready: bool = true

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	var player := get_node_or_null(player_path) as PlayerController
	var direction := 0.0
	if player != null and health > 0:
		var distance := global_position.distance_to(player.global_position)
		if distance <= aggro_range:
			direction = signf(player.global_position.x - global_position.x)
			if distance <= attack_range:
				_try_attack(player)
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, 700.0 * delta)
		visual.scale.x = direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif is_on_wall() and direction != 0.0:
		velocity.y = jump_velocity
	move_and_slide()

func _try_attack(player: PlayerController) -> void:
	if not _attack_ready or player.health <= 0:
		return
	_attack_ready = false
	player.take_damage(attack_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	_attack_ready = true

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		defeated.emit()
		queue_free()
