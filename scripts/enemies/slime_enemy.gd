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
var _night_mode: bool = false
var _base_move_speed: float
var _base_attack_damage: int
var _hit_tween: Tween

@onready var visual: Polygon2D = $Visual

func _ready() -> void:
	_base_move_speed = move_speed
	_base_attack_damage = attack_damage
	health = max_health
	health_changed.emit(health, max_health)

func set_night_mode(enabled: bool) -> void:
	_night_mode = enabled
	move_speed = _base_move_speed * (1.35 if enabled else 1.0)
	attack_damage = _base_attack_damage + (5 if enabled else 0)
	visual.color = Color(0.72, 0.30, 0.82, 1.0) if enabled else Color(0.35, 0.85, 0.42, 1.0)

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
	if health > 0:
		_play_hit_reaction()
	else:
		_play_defeat_reaction()

func _play_hit_reaction() -> void:
	var player := get_node_or_null(player_path) as Node2D
	var knockback_direction := -signf(velocity.x)
	if player != null:
		knockback_direction = signf(global_position.x - player.global_position.x)
	if is_zero_approx(knockback_direction):
		knockback_direction = -1.0 if visual.scale.x >= 0.0 else 1.0
	velocity.x = knockback_direction * 155.0
	if is_on_floor():
		velocity.y = -92.0
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	visual.modulate = Color(2.2, 2.2, 2.2, 1.0)
	_hit_tween = create_tween()
	_hit_tween.tween_property(visual, "modulate", Color.WHITE, 0.13)

func _play_defeat_reaction() -> void:
	defeated.emit()
	if is_instance_valid(_hit_tween):
		_hit_tween.kill()
	var defeat_tween := create_tween()
	defeat_tween.set_parallel(true)
	defeat_tween.tween_property(visual, "scale", visual.scale * Vector2(1.35, 0.35), 0.12)
	defeat_tween.tween_property(visual, "modulate", Color(1.0, 0.45, 0.35, 0.0), 0.12)
	defeat_tween.chain().tween_callback(queue_free)
