extends "res://scripts/enemies/slime_enemy.gd"
class_name DungeonWardenBoss

signal phase_changed(phase: int)

var current_phase: int = 1
var _slam_timer: float = 3.2
var _slam_windup: float = 0.0
var _animation_time: float = 0.0
var _base_color := Color(0.25, 0.30, 0.42, 1.0)

func _ready() -> void:
	max_health = 2800
	move_speed = 78.0
	attack_damage = 38
	attack_range = 78.0
	aggro_range = 1350.0
	attack_cooldown = 1.0
	jump_velocity = -390.0
	super._ready()
	visual.color = _base_color
	visual.scale = Vector2(3.0, 3.25)

func _process(delta: float) -> void:
	_animation_time += delta
	if not is_instance_valid(visual):
		return
	var pulse := 1.0 + sin(_animation_time * (4.2 if current_phase == 2 else 2.0)) * 0.035
	visual.scale = Vector2(3.0 * pulse, 3.25 / pulse)
	visual.rotation = sin(_animation_time * 1.1) * 0.025
	if _slam_windup > 0.0:
		visual.color = Color(0.85, 0.88, 1.0, 1.0) if int(_animation_time * 12.0) % 2 == 0 else Color(0.30, 0.48, 0.95, 1.0)
	elif current_phase == 2:
		visual.color = Color(0.55, 0.20, 0.72, 1.0)
	else:
		visual.color = _base_color

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0:
		return
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0:
		return
	if _slam_windup > 0.0:
		_slam_windup -= delta
		if _slam_windup <= 0.0:
			_release_vault_slam(target)
		return
	_slam_timer -= delta
	if _slam_timer <= 0.0 and global_position.distance_to(target.global_position) <= 310.0:
		_slam_windup = 0.82 if current_phase == 1 else 0.55

func _release_vault_slam(target: PlayerController) -> void:
	var blast_range := 205.0 if current_phase == 1 else 255.0
	if is_instance_valid(target) and target.health > 0 and global_position.distance_to(target.global_position) <= blast_range:
		target.take_damage(56 if current_phase == 1 else 78)
	_slam_timer = 4.0 if current_phase == 1 else 2.8

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = 126.0
		attack_damage = 52
		attack_cooldown = 0.72
		jump_velocity = -470.0
		_slam_timer = 0.8
		phase_changed.emit(current_phase)
