extends "res://scripts/enemies/slime_enemy.gd"
class_name MushroomGuardianBoss

signal phase_changed(phase: int)

const SPORE_SCENE: PackedScene = preload("res://scenes/enemies/spore_projectile.tscn")
var current_phase: int = 1
var _volley_timer: float = 2.0
var _animation_time: float = 0.0

func _ready() -> void:
	max_health = 1750
	move_speed = 76.0
	attack_damage = 22
	attack_range = 70.0
	aggro_range = 1150.0
	attack_cooldown = 1.0
	jump_velocity = -370.0
	super._ready()
	visual.color = Color(0.18, 0.48, 0.24, 1.0)
	visual.scale = Vector2(2.7, 3.0)

func _process(delta: float) -> void:
	_animation_time += delta
	if is_instance_valid(visual):
		var pulse := 1.0 + sin(_animation_time * (4.8 if current_phase == 2 else 2.2)) * 0.035
		visual.scale = Vector2(2.7 * pulse, 3.0 / pulse)
		visual.rotation = sin(_animation_time * 1.4) * 0.035
		if current_phase == 2:
			visual.color = Color(0.52, 0.20, 0.72, 1.0)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0:
		return
	_volley_timer -= delta
	if _volley_timer > 0.0:
		return
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0:
		_volley_timer = 1.0
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= aggro_range:
		_fire_spore_volley(target)
	_volley_timer = 3.0 if current_phase == 1 else 1.8

func _fire_spore_volley(target: PlayerController) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var count := 3 if current_phase == 1 else 5
	for index in range(count):
		var projectile := SPORE_SCENE.instantiate() as SporeProjectile
		if projectile == null:
			continue
		parent.add_child(projectile)
		projectile.global_position = global_position + Vector2(0.0, -38.0)
		var spread := (float(index) - float(count - 1) * 0.5) * (0.16 if current_phase == 1 else 0.22)
		var aim := (target.global_position - projectile.global_position).normalized()
		projectile.direction = aim.rotated(spread)
		projectile.impact_damage = 9 if current_phase == 1 else 13
		projectile.poison_damage = 3 if current_phase == 1 else 5

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = 132.0
		attack_damage = 34
		attack_cooldown = 0.72
		jump_velocity = -470.0
		_volley_timer = 0.8
		phase_changed.emit(current_phase)
