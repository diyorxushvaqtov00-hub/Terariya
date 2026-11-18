extends "res://scripts/enemies/slime_enemy.gd"
class_name AncientEyeBoss

signal phase_changed(phase: int)

var current_phase: int = 1
var _charge_timer: float = 0.0
var _charging: bool = false
var _charge_direction: float = 1.0
var _charge_remaining: float = 0.0
var _phase_one_speed: float = 92.0
var _phase_two_speed: float = 142.0

func _ready() -> void:
	max_health = 900
	move_speed = _phase_one_speed
	attack_damage = 18
	attack_range = 58.0
	aggro_range = 900.0
	attack_cooldown = 1.1
	jump_velocity = -360.0
	super._ready()
	visual.color = Color(0.82, 0.16, 0.22, 1.0)
	visual.scale = Vector2(2.5, 2.5)
	_charge_timer = 3.0

func _physics_process(delta: float) -> void:
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0 or health <= 0:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return
	var distance := global_position.distance_to(target.global_position)
	var horizontal_direction := signf(target.global_position.x - global_position.x)
	if distance <= attack_range:
		_try_attack(target)
	if current_phase == 2:
		_charge_timer -= delta
		if _charge_timer <= 0.0 and not _charging:
			_charging = true
			_charge_remaining = 0.9
			_charge_direction = horizontal_direction if horizontal_direction != 0.0 else 1.0
	if _charging:
		velocity.x = _charge_direction * 390.0
		_charge_remaining -= delta
		if _charge_remaining <= 0.0:
			_charging = false
			_charge_timer = 3.0
	else:
		velocity.x = move_toward(velocity.x, horizontal_direction * move_speed, 500.0 * delta)
	if horizontal_direction != 0.0:
		visual.scale.x = signf(horizontal_direction) * 2.5
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif is_on_wall() and horizontal_direction != 0.0:
		velocity.y = jump_velocity
	move_and_slide()

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = _phase_two_speed
		attack_damage = 26
		attack_cooldown = 0.85
		visual.color = Color(1.0, 0.08, 0.12, 1.0)
		phase_changed.emit(current_phase)
