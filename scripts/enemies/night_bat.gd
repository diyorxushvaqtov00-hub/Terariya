extends "res://scripts/enemies/slime_enemy.gd"
class_name NightBat

@export var hover_height: float = 110.0
@export var hover_speed: float = 2.8
@export var vertical_speed: float = 95.0

var _hover_clock: float = 0.0

func _ready() -> void:
	max_health = 48
	move_speed = 108.0
	attack_damage = 11
	attack_range = 42.0
	aggro_range = 420.0
	attack_cooldown = 1.45
	super._ready()
	visual.color = Color(0.40, 0.28, 0.68, 1.0)

func set_night_mode(enabled: bool) -> void:
	super.set_night_mode(enabled)
	visual.color = Color(0.48, 0.30, 0.82, 1.0) if enabled else Color(0.32, 0.38, 0.48, 1.0)

func _physics_process(delta: float) -> void:
	_hover_clock += delta
	var target := get_node_or_null(player_path) as PlayerController
	var direction := 0.0
	if target != null and health > 0:
		var offset := target.global_position - global_position
		if offset.length() <= aggro_range:
			direction = signf(offset.x)
			if offset.length() <= attack_range:
				_try_attack(target)
			var desired_y := target.global_position.y - hover_height + sin(_hover_clock * hover_speed) * 22.0
			velocity.y = move_toward(velocity.y, clampf((desired_y - global_position.y) * 1.8, -vertical_speed, vertical_speed), 420.0 * delta)
		else:
			velocity.y = sin(_hover_clock * hover_speed) * 28.0
	else:
		velocity.y = sin(_hover_clock * hover_speed) * 28.0
	velocity.x = move_toward(velocity.x, direction * move_speed, 620.0 * delta)
	if direction != 0.0:
		visual.scale.x = direction
	move_and_slide()
