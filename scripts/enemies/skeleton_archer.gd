extends "res://scripts/enemies/slime_enemy.gd"
class_name SkeletonArcher

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")

@export var preferred_distance: float = 210.0
@export var ranged_attack_range: float = 420.0
@export var ranged_damage: int = 12
@export var ranged_cooldown: float = 1.8
var _shot_cooldown: float = 0.7

func _ready() -> void:
	max_health = 65
	move_speed = 72.0
	attack_damage = 5
	aggro_range = 440.0
	super._ready()
	visual.color = Color(0.82, 0.82, 0.72, 1.0)

func set_night_mode(enabled: bool) -> void:
	super.set_night_mode(enabled)
	visual.color = Color(0.72, 0.66, 0.82, 1.0) if enabled else Color(0.82, 0.82, 0.72, 1.0)

func _physics_process(delta: float) -> void:
	var target := get_node_or_null(player_path) as PlayerController
	var direction := 0.0
	if target != null and target.health > 0:
		var distance := global_position.distance_to(target.global_position)
		if distance <= aggro_range:
			var horizontal_distance := target.global_position.x - global_position.x
			if absf(horizontal_distance) > preferred_distance:
				direction = signf(horizontal_distance)
			elif absf(horizontal_distance) < preferred_distance * 0.65:
				direction = -signf(horizontal_distance)
			if distance <= ranged_attack_range:
				_shot_cooldown -= delta
				if _shot_cooldown <= 0.0:
					fire_at(target)
					_shot_cooldown = ranged_cooldown
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, 650.0 * delta)
		visual.scale.x = direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func fire_at(target: PlayerController) -> void:
	if target == null or target.health <= 0:
		return
	var projectile := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	if projectile == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		projectile.queue_free()
		return
	scene_root.add_child(projectile)
	projectile.global_position = global_position + Vector2(visual.scale.x * 12.0, -15.0)
	projectile.configure(target.global_position - projectile.global_position, ranged_damage)
