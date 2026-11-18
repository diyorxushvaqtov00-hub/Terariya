extends "res://scripts/enemies/slime_enemy.gd"
class_name CaveSpider

func _ready() -> void:
	max_health = 85
	move_speed = 112.0
	attack_damage = 11
	attack_range = 38.0
	aggro_range = 460.0
	attack_cooldown = 0.9
	jump_velocity = -390.0
	super._ready()
	visual.color = Color(0.22, 0.18, 0.28, 1.0)

func set_night_mode(enabled: bool) -> void:
	super.set_night_mode(enabled)
	visual.color = Color(0.12, 0.10, 0.18, 1.0) if enabled else Color(0.22, 0.18, 0.28, 1.0)
