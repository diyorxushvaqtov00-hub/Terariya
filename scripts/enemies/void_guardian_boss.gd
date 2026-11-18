extends "res://scripts/enemies/slime_enemy.gd"
class_name VoidGuardianBoss

signal phase_changed(phase: int)

var current_phase: int = 1
var _pulse_timer: float = 2.8
var _pulse_windup: float = 0.0
var _animation_time: float = 0.0
var _base_color := Color(0.22, 0.10, 0.38, 1.0)

func _ready() -> void:
	max_health = 1350
	move_speed = 88.0
	attack_damage = 30
	attack_range = 76.0
	aggro_range = 1100.0
	attack_cooldown = 0.95
	jump_velocity = -410.0
	super._ready()
	visual.color = _base_color
	visual.scale = Vector2(2.8, 3.0)

func _process(delta: float) -> void:
	_animation_time += delta
	if not is_instance_valid(visual):
		return
	var pulse := 1.0 + sin(_animation_time * (5.0 if current_phase == 2 else 2.6)) * 0.045
	visual.scale = Vector2(2.8 * pulse, 3.0 / pulse)
	visual.rotation = sin(_animation_time * 1.5) * 0.035
	if _pulse_windup > 0.0:
		visual.color = Color(0.95, 0.82, 1.0, 1.0) if int(_animation_time * 14.0) % 2 == 0 else Color(0.35, 0.08, 0.62, 1.0)
	elif current_phase == 2:
		visual.color = Color(0.68, 0.12, 0.88, 1.0)
	else:
		visual.color = _base_color

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0:
		return
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0:
		return
	if _pulse_windup > 0.0:
		_pulse_windup -= delta
		if _pulse_windup <= 0.0:
			_release_void_pulse(target)
		return
	_pulse_timer -= delta
	if _pulse_timer <= 0.0 and global_position.distance_to(target.global_position) <= 300.0:
		_pulse_windup = 0.72 if current_phase == 1 else 0.48

func _release_void_pulse(target: PlayerController) -> void:
	var radius := 190.0 if current_phase == 1 else 235.0
	if is_instance_valid(target) and target.health > 0 and global_position.distance_to(target.global_position) <= radius:
		target.take_damage(42 if current_phase == 1 else 62)
	_pulse_timer = 4.0 if current_phase == 1 else 2.7

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = 132.0
		attack_damage = 44
		attack_cooldown = 0.68
		jump_velocity = -490.0
		_pulse_timer = 0.7
		phase_changed.emit(current_phase)
