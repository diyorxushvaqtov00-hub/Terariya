extends Node2D

@onready var health_label: Label = $HUD/HealthLabel
@onready var player: PlayerController = $Player
@onready var world: WorldGenerator = $World
@onready var training_dummy: TrainingDummy = $TrainingDummy

func _ready() -> void:
	player.global_position = world.get_spawn_position(10)
	training_dummy.global_position = world.get_spawn_position(15)
	player.health_changed.connect(_on_player_health_changed)
	_on_player_health_changed(player.health, player.max_health)

func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]
