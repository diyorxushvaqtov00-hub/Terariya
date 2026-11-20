extends "res://scripts/enemies/slime_enemy.gd"
class_name MagmaGolemBoss

signal phase_changed(phase: int)

var current_phase: int = 1
var _slam_timer: float = 3.8
var _slam_windup: float = 0.0
var _slam_ready: bool = false
var _animation_time: float = 0.0
var _base_color := Color(0.48, 0.16, 0.08, 1.0)

func _ready() -> void:
	max_health = 2200
	move_speed = 66.0
	attack_damage = 30
	attack_range = 72.0
	aggro_range = 1200.0
	attack_cooldown = 1.05
	jump_velocity = -330.0
	super._ready()
	visual.color = _base_color
	visual.scale = Vector2(2.9, 3.1)

func _process(delta: float) -> void:
	_animation_time += delta
	if is_instance_valid(visual):
		var pulse := 1.0 + sin(_animation_time * 3.2) * 0.025
		visual.scale = Vector2(2.9 * pulse, 3.1 / pulse)
		if _slam_windup > 0.0:
			visual.color = Color(1.0, 0.48, 0.08, 1.0) if int(_animation_time * 10.0) % 2 == 0 else Color(0.72, 0.12, 0.03, 1.0)
		elif current_phase == 2:
			visual.color = Color(0.95, 0.20, 0.035, 1.0)
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
			_release_magma_slam(target)
		return
	_slam_timer -= delta
	if _slam_timer <= 0.0 and global_position.distance_to(target.global_position) <= 250.0:
		_slam_windup = 0.72 if current_phase == 1 else 0.48
		_slam_ready = true

func _release_magma_slam(target: PlayerController) -> void:
	if not _slam_ready:
		return
	_slam_ready = false
	var blast_range := 168.0 if current_phase == 1 else 205.0
	if is_instance_valid(target) and target.health > 0 and global_position.distance_to(target.global_position) <= blast_range:
		target.take_damage(42 if current_phase == 1 else 58)
	_slam_timer = 4.2 if current_phase == 1 else 3.0

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = 112.0
		attack_damage = 42
		attack_cooldown = 0.78
		jump_velocity = -430.0
		_slam_timer = 1.0
		_play_phase_transition(Color(1.0, 0.38, 0.08, 1.0))
	phase_changed.emit(current_phase)
