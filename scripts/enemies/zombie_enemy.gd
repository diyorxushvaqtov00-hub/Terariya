extends "res://scripts/enemies/slime_enemy.gd"
class_name ZombieEnemy

func _ready() -> void:
	max_health = 100
	move_speed = 58.0
	attack_damage = 14
	attack_range = 38.0
	aggro_range = 360.0
	attack_cooldown = 1.55
	super._ready()
	visual.color = Color(0.30, 0.58, 0.28, 1.0)

func set_night_mode(enabled: bool) -> void:
	super.set_night_mode(enabled)
	if not enabled:
		visual.color = Color(0.30, 0.58, 0.28, 1.0)
	else:
		visual.color = Color(0.42, 0.30, 0.56, 1.0)
