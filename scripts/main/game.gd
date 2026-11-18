extends Node2D

const SAVE_PATH: String = "user://eternal_world_save.json"
const SAVE_VERSION: int = 1

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
	world.selected_block_changed.connect(_on_selected_block_changed)
	_load_game()
	_on_player_health_changed(player.health, player.max_health)
	_on_inventory_changed(player.inventory.items)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"player": {
			"x": player.global_position.x,
			"y": player.global_position.y,
			"health": player.health,
			"double_jump_unlocked": player.double_jump_unlocked
		},
		"inventory": player.inventory.serialize(),
		"world": world.get_save_data()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Save failed: could not open save file for writing.")
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func _load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Save file exists but could not be opened.")
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("Save file is invalid or uses an unsupported version.")
		return false
	var world_data: Variant = parsed.get("world", {})
	if not world_data is Dictionary or not world.load_save_data(world_data):
		push_warning("Saved world data is invalid; starting with generated world.")
		return false
	var inventory_data: Variant = parsed.get("inventory", {})
	if not inventory_data is Dictionary or not player.inventory.restore(inventory_data):
		push_warning("Saved inventory is invalid; keeping starter inventory.")
		return false
	var player_data: Variant = parsed.get("player", {})
	if player_data is Dictionary:
		player.global_position = Vector2(float(player_data.get("x", player.global_position.x)), float(player_data.get("y", player.global_position.y)))
		player.set_spawn_position(player.global_position)
		player.health = clampi(int(player_data.get("health", player.max_health)), 1, player.max_health)
		player.double_jump_unlocked = bool(player_data.get("double_jump_unlocked", false))
		player.health_changed.emit(player.health, player.max_health)
	return true

func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]

func _on_inventory_changed(items: Dictionary) -> void:
	inventory_label.text = "DIRT %d | STONE %d | ORE %d | SELECTED: %s" % [
		int(items.get("dirt", 0)),
		int(items.get("stone", 0)),
		int(items.get("ore", 0)),
		world.get_selected_block_name()
	]

func _on_selected_block_changed(_block_type: int) -> void:
	_on_inventory_changed(player.inventory.items)
