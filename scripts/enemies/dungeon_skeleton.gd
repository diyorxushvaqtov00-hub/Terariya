extends "res://scripts/enemies/slime_enemy.gd"
class_name DungeonSkeleton

func _ready() -> void:
	max_health = 150
	move_speed = 78.0
	attack_damage = 20
	attack_range = 42.0
	aggro_range = 520.0
	attack_cooldown = 1.2
	jump_velocity = -330.0
	super._ready()
	visual.color = Color(0.78, 0.78, 0.70, 1.0)

func set_night_mode(enabled: bool) -> void:
	super.set_night_mode(enabled)
	visual.color = Color(0.56, 0.55, 0.66, 1.0) if enabled else Color(0.78, 0.78, 0.70, 1.0)
