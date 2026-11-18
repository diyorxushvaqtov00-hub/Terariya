extends CharacterBody2D
class_name PlayerController

signal health_changed(current: int, maximum: int)
signal attack_requested

@export_category("Movement")
@export var walk_speed: float = 220.0
@export var run_speed: float = 320.0
@export var jump_velocity: float = -390.0
@export var acceleration: float = 1800.0
@export var air_acceleration: float = 1000.0
@export var double_jump_unlocked: bool = false

@export_category("Vitals")
@export var max_health: int = 100
@export var fall_damage_threshold: float = 850.0
@export var fall_damage_scale: float = 0.035

@export_category("Combat")
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.38
@export var attack_active_time: float = 0.12

var health: int
var _fall_peak_speed: float = 0.0
var _was_on_floor: bool = false
var _facing: int = 1
var _air_jumps_used: int = 0
var _can_attack: bool = true

@onready var body_visual: Polygon2D = $BodyVisual
@onready var attack_area: Area2D = $AttackArea

func _ready() -> void:
	health = max_health
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		_facing = 1 if direction > 0.0 else -1

	var target_speed := run_speed if Input.is_action_pressed("run") else walk_speed
	var target_velocity := direction * target_speed
	var rate := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity, rate * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta
		_fall_peak_speed = maxf(_fall_peak_speed, velocity.y)
	else:
		if not _was_on_floor and _fall_peak_speed > fall_damage_threshold:
			var impact := int((_fall_peak_speed - fall_damage_threshold) * fall_damage_scale)
			if impact > 0:
				take_damage(impact)
		_fall_peak_speed = 0.0
		_air_jumps_used = 0

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
		elif double_jump_unlocked and _air_jumps_used < 1:
			velocity.y = jump_velocity * 0.92
			_air_jumps_used += 1

	if Input.is_action_just_pressed("attack"):
		_start_attack()

	_was_on_floor = is_on_floor()
	body_visual.scale.x = float(_facing)
	move_and_slide()

func _start_attack() -> void:
	if not _can_attack or health <= 0:
		return
	_can_attack = false
	attack_area.position.x = 24.0 * _facing
	attack_requested.emit()
	attack_area.set_deferred("monitoring", true)
	await get_tree().create_timer(attack_active_time).timeout
	attack_area.set_deferred("monitoring", false)
	await get_tree().create_timer(maxf(attack_cooldown - attack_active_time, 0.0)).timeout
	_can_attack = true

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func unlock_double_jump() -> void:
	double_jump_unlocked = true

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

func heal(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
