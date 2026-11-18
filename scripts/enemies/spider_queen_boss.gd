extends "res://scripts/enemies/slime_enemy.gd"
class_name SpiderQueenBoss

signal phase_changed(phase: int)

var current_phase: int = 1

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
