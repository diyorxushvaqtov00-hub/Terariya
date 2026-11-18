extends CharacterBody2D
class_name PlayerController

signal health_changed(current: int, maximum: int)

@export_category("Movement")
@export var walk_speed: float = 220.0
@export var run_speed: float = 320.0
@export var jump_velocity: float = -390.0
@export var acceleration: float = 1800.0
@export var air_acceleration: float = 1000.0

@export_category("Vitals")
@export var max_health: int = 100
@export var fall_damage_threshold: float = 850.0
@export var fall_damage_scale: float = 0.035

var health: int
var _fall_peak_speed: float = 0.0
var _was_on_floor: bool = false
var _facing: int = 1

@onready var body_visual: Polygon2D = $BodyVisual

func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		_facing = signi(direction)

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

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	_was_on_floor = is_on_floor()
	body_visual.scale.x = float(_facing)
	move_and_slide()

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
	# Respawn flow will be added with the world/save milestones.
