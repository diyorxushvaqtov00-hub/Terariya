extends "res://scripts/enemies/slime_enemy.gd"
class_name SpiderQueenBoss

signal phase_changed(phase: int)

const WEB_PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemies/spider_web_projectile.tscn")
const MINION_SCENE: PackedScene = preload("res://scenes/enemies/cave_spider.tscn")
const MAX_MINIONS: int = 2

var current_phase: int = 1
var _web_attack_timer: float = 1.8
var _summon_timer: float = 7.0
var _animation_time: float = 0.0
var _summoned_minions: Array[Node2D] = []

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

func _process(delta: float) -> void:
	_animation_time += delta
	if is_instance_valid(visual):
		var pulse := 1.0 + sin(_animation_time * (5.0 if current_phase == 2 else 2.5)) * (0.035 if current_phase == 2 else 0.018)
		visual.scale = Vector2(3.0 * pulse, 2.6 / pulse)
		visual.rotation = sin(_animation_time * 1.7) * (0.045 if current_phase == 2 else 0.025)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health <= 0:
		return
	var living_minions: Array[Node2D] = []
	for minion in _summoned_minions:
		if is_instance_valid(minion):
			living_minions.append(minion)
	_summoned_minions = living_minions
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = 12.0 if current_phase == 1 else 8.0
		_summon_spiders()
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

func _summon_spiders() -> void:
	if _summoned_minions.size() >= MAX_MINIONS:
		return
	var parent := get_parent()
	if parent == null:
		return
	var target := get_node_or_null(player_path) as PlayerController
	if target == null or target.health <= 0:
		return
	var spawn_count := mini(2 if current_phase == 2 else 1, MAX_MINIONS - _summoned_minions.size())
	for index in range(spawn_count):
		var minion := MINION_SCENE.instantiate() as CaveSpider
		if minion == null:
			continue
		parent.add_child(minion)
		var side := -1.0 if index == 0 else 1.0
		minion.global_position = global_position + Vector2(side * (72.0 + index * 24.0), -8.0)
		minion.max_health = 105 if current_phase == 2 else 85
		minion.health = minion.max_health
		minion.move_speed = 138.0 if current_phase == 2 else 112.0
		minion.attack_damage = 15 if current_phase == 2 else 11
		minion.defeated.connect(_on_summoned_spider_defeated)
		_summoned_minions.append(minion)

func _on_summoned_spider_defeated() -> void:
	var target := get_node_or_null(player_path) as PlayerController
	if target != null and target.health > 0:
		target.add_experience(35)

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
		_summon_timer = 1.0
		phase_changed.emit(current_phase)
