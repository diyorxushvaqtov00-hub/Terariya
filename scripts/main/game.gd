extends Node2D

@onready var health_label: Label = $HUD/HealthLabel
@onready var inventory_label: Label = $HUD/InventoryLabel
@onready var player: PlayerController = $Player
@onready var world: WorldGenerator = $World
@onready var training_dummy: TrainingDummy = $TrainingDummy

func _ready() -> void:
	player.global_position = world.get_spawn_position(10)
	player.set_spawn_position(player.global_position)
	training_dummy.global_position = world.get_spawn_position(15)
	player.health_changed.connect(_on_player_health_changed)
	player.inventory.changed.connect(_on_inventory_changed)
	_on_player_health_changed(player.health, player.max_health)
	_on_inventory_changed(player.inventory.items)

func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]

func _on_inventory_changed(items: Dictionary) -> void:
	inventory_label.text = "DIRT %d | STONE %d | ORE %d" % [
		int(items.get("dirt", 0)),
		int(items.get("stone", 0)),
		int(items.get("ore", 0))
	]
