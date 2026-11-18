extends "res://scripts/enemies/slime_enemy.gd"
class_name SpiderQueenBoss

signal phase_changed(phase: int)

const WEB_PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/spider_web_projectile.tscn")

var current_phase: int = 1
var _web_attack_timer: float = 1.8

func _ready() -> void:
	max_health = 1400
	move_speed = 92.0
	attack_damage = 24
	attack_range = 66.0
	aggro_range = 1100.0
	attack_cooldown = 1.0
	jump_velocity = -420.0
	super._ready()
	visual.color = Color(0.20, 0.08, 0.30, 1.0)
	visual.scale = Vector2(3.0, 2.6)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0:
		return
	_web_attack_timer -= delta
	if _web_attack_timer > 0.0:
		return
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0:
		_web_attack_timer = 1.0
		return
	var distance := global_position.distance_to(target.global_position)
	if distance >= 190.0 and distance <= aggro_range:
		_shoot_web(target)
	_web_attack_timer = 2.8 if current_phase == 1 else 1.75

func _shoot_web(target: PlayerController) -> void:
	var projectile := WEB_PROJECTILE_SCENE.instantiate() as SpiderWebProjectile
	if projectile == null:
		return
	var parent := get_parent()
	if parent == null:
		projectile.queue_free()
		return
	parent.add_child(projectile)
	projectile.global_position = global_position + Vector2(0.0, -34.0)
	projectile.direction = (target.global_position - projectile.global_position).normalized()

func take_damage(amount: int) -> void:
	var previous_health := health
	super.take_damage(amount)
	if health <= 0 or health == previous_health:
		return
	if current_phase == 1 and health <= int(max_health * 0.5):
		current_phase = 2
		move_speed = 158.0
		attack_damage = 34
		attack_cooldown = 0.72
		jump_velocity = -520.0
		visual.color = Color(0.55, 0.05, 0.12, 1.0)
		phase_changed.emit(current_phase)
