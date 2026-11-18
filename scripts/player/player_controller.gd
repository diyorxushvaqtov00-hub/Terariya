extends CharacterBody2D
class_name PlayerController

signal health_changed(current: int, maximum: int)
signal oxygen_changed(current: float, maximum: float)
signal underwater_changed(is_underwater: bool)
signal attack_requested
signal died
signal respawned
signal progression_changed(level: int, experience: int, required: int)
signal level_up(new_level: int)

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
@export var max_oxygen_seconds: float = 12.0
@export var drowning_damage: int = 8
@export var drowning_damage_interval: float = 1.5

@export_category("Combat")
@export var attack_damage: int = 25
@export var attack_cooldown: float = 0.38
@export var attack_active_time: float = 0.12
@export var respawn_delay: float = 2.0

var health: int
var _fall_peak_speed: float = 0.0
var _was_on_floor: bool = false
var _facing: int = 1
var _air_jumps_used: int = 0
var _can_attack: bool = true
var _spawn_position := Vector2.ZERO
var _is_dead: bool = false
var is_swimming: bool = false
var is_head_underwater: bool = false
var oxygen_seconds: float
var _drowning_tick: float = 0.0
var level: int = 1
var experience: int = 0
var experience_to_next_level: int = 100
var bonus_attack_damage: int = 0
var _web_slow_remaining: float = 0.0
var _web_slow_multiplier: float = 1.0
var _lava_damage_elapsed: float = 0.0

@onready var body_visual: Polygon2D = $BodyVisual
@onready var attack_area: Area2D = $AttackArea
@onready var inventory: PlayerInventory = $Inventory

func _ready() -> void:
	_spawn_position = global_position
	health = max_health
	oxygen_seconds = max_oxygen_seconds
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	health_changed.emit(health, max_health)
	oxygen_changed.emit(oxygen_seconds, max_oxygen_seconds)

func _physics_process(delta: float) -> void:
	_web_slow_remaining = maxf(_web_slow_remaining - delta, 0.0)
	if _web_slow_remaining <= 0.0:
		_web_slow_multiplier = 1.0
	is_swimming = _is_in_water()
	var head_is_submerged := _is_head_underwater()
	if head_is_submerged != is_head_underwater:
		is_head_underwater = head_is_submerged
		underwater_changed.emit(is_head_underwater)
	_update_oxygen(delta)
	if _is_dead:
		return
	if _is_touching_lava():
		_lava_damage_elapsed += delta
		if _lava_damage_elapsed >= 0.8:
			_lava_damage_elapsed = 0.0
			take_damage(12)
	else:
		_lava_damage_elapsed = 0.0
	if _is_dead:
		return
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		_facing = 1 if direction > 0.0 else -1

	var target_speed := run_speed if Input.is_action_pressed("run") else walk_speed
	if is_swimming:
		target_speed *= 0.72
	target_speed *= _web_slow_multiplier
	var target_velocity := direction * target_speed
	var rate := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity, rate * delta)

	if not is_on_floor():
		velocity += get_gravity() * delta * (0.28 if is_swimming else 1.0)
		if is_swimming:
			velocity.y = minf(velocity.y, 115.0)
			velocity.y = move_toward(velocity.y, -24.0, 150.0 * delta)
			_fall_peak_speed = 0.0
		else:
			_fall_peak_speed = maxf(_fall_peak_speed, velocity.y)
	else:
		if not _was_on_floor and _fall_peak_speed > fall_damage_threshold:
			var impact := int((_fall_peak_speed - fall_damage_threshold) * fall_damage_scale)
			if impact > 0:
				take_damage(impact)
		_fall_peak_speed = 0.0
		_air_jumps_used = 0

	if Input.is_action_just_pressed("jump"):
		if is_swimming:
			velocity.y = -235.0
			_air_jumps_used = 0
		elif is_on_floor():
			velocity.y = jump_velocity
		elif double_jump_unlocked and _air_jumps_used < 1:
			velocity.y = jump_velocity * 0.92
			_air_jumps_used += 1

	if Input.is_action_just_pressed("attack"):
		_start_attack()

	_was_on_floor = is_on_floor()
	body_visual.scale.x = float(_facing)
	move_and_slide()

func _is_touching_lava() -> bool:
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null:
		return false
	return world.is_position_in_lava(global_position + Vector2(0.0, 10.0))

func _is_in_water() -> bool:
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null:
		return false
	return world.is_position_in_water(global_position + Vector2(0.0, 12.0))

func _is_head_underwater() -> bool:
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null:
		return false
	return world.is_position_in_water(global_position + Vector2(0.0, -30.0))

func _update_oxygen(delta: float) -> void:
	if is_head_underwater:
		oxygen_seconds = maxf(oxygen_seconds - delta, 0.0)
		if oxygen_seconds <= 0.0:
			_drowning_tick += delta
			if _drowning_tick >= drowning_damage_interval:
				_drowning_tick = 0.0
				take_damage(drowning_damage)
	else:
		oxygen_seconds = minf(oxygen_seconds + delta * 2.0, max_oxygen_seconds)
		_drowning_tick = 0.0
	oxygen_changed.emit(oxygen_seconds, max_oxygen_seconds)

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
		var total_damage := attack_damage + bonus_attack_damage
		var weapon_id := inventory.get_best_weapon_id()
		match weapon_id:
			"queens_fang":
				total_damage += 80
			"gold_sword":
				total_damage += 55
			"silver_sword":
				total_damage += 40
			"copper_sword":
				total_damage += 25
			"stone_sword":
				total_damage += 15
		if not weapon_id.is_empty():
			total_damage += inventory.get_weapon_upgrade_level(weapon_id) * 3
		body.take_damage(total_damage)

func set_spawn_position(position: Vector2) -> void:
	_spawn_position = position

func get_facing() -> int:
	return _facing

func add_experience(amount: int) -> void:
	if amount <= 0 or level >= 50:
		return
	experience += amount
	while level < 50 and experience >= experience_to_next_level:
		experience -= experience_to_next_level
		level += 1
		experience_to_next_level = level * 100
		if level % 5 == 0:
			max_health += 10
			health = mini(health + 10, max_health)
			health_changed.emit(health, max_health)
		if level % 2 == 0:
			bonus_attack_damage += 2
		level_up.emit(level)
	if level >= 50:
		experience = 0
		experience_to_next_level = 0
	progression_changed.emit(level, experience, experience_to_next_level)

func restore_progress(saved_level: int, saved_experience: int) -> void:
	level = clampi(saved_level, 1, 50)
	experience_to_next_level = 0 if level >= 50 else level * 100
	experience = clampi(saved_experience, 0, maxi(experience_to_next_level - 1, 0))
	bonus_attack_damage = int(floori(float(level - 1) / 2.0)) * 2
	max_health = 100 + int(floori(float(level) / 5.0)) * 10
	health = mini(health, max_health)
	progression_changed.emit(level, experience, experience_to_next_level)

func unlock_double_jump() -> void:
	double_jump_unlocked = true

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0 or _is_dead:
		return
	var defense := inventory.get_armor_defense() if is_instance_valid(inventory) else 0
	var reduced_damage := maxi(amount - defense, 1)
	health = maxi(health - reduced_damage, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

func apply_web_slow(duration: float, speed_multiplier: float) -> void:
	_web_slow_remaining = maxf(_web_slow_remaining, duration)
	_web_slow_multiplier = minf(_web_slow_multiplier, clampf(speed_multiplier, 0.2, 1.0))

func apply_poison(damage_per_tick: int, tick_count: int, interval: float = 1.0) -> void:
	for tick in range(maxi(tick_count, 0)):
		await get_tree().create_timer(maxf(interval, 0.1)).timeout
		if not is_inside_tree() or health <= 0:
			return
		take_damage(damage_per_tick)

func heal(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	died.emit()
	await get_tree().create_timer(respawn_delay).timeout
	global_position = _spawn_position
	velocity = Vector2.ZERO
	health = max_health
	_is_dead = false
	health_changed.emit(health, max_health)
	set_physics_process(true)
	respawned.emit()
