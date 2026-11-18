extends Node2D

const SAVE_PATH: String = "user://eternal_world_save.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 30.0

var _autosave_elapsed: float = 0.0
var _inventory_panel: PanelContainer
var _inventory_summary: Label
var _craft_buttons: Dictionary = {}

@onready var health_label: Label = $HUD/HealthLabel
@onready var inventory_label: Label = $HUD/InventoryLabel
@onready var player: PlayerController = $Player
@onready var world: WorldGenerator = $World
@onready var training_dummy: TrainingDummy = $TrainingDummy
@onready var slime: SlimeEnemy = $SlimeEnemy

func _ready() -> void:
	player.global_position = world.get_spawn_position(10)
	player.set_spawn_position(player.global_position)
	training_dummy.global_position = world.get_spawn_position(15)
	slime.global_position = world.get_spawn_position(20)
	player.health_changed.connect(_on_player_health_changed)
	player.inventory.changed.connect(_on_inventory_changed)
	world.selected_block_changed.connect(_on_selected_block_changed)
	_load_game()
	_on_player_health_changed(player.health, player.max_health)
	_on_inventory_changed(player.inventory.items)
	_build_inventory_ui()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory_toggle") and is_instance_valid(_inventory_panel):
		_toggle_inventory()
	_autosave_elapsed += delta
	if _autosave_elapsed >= AUTOSAVE_INTERVAL:
		_autosave_elapsed = 0.0
		save_game()

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
	inventory_label.text = "DIRT %d | STONE %d | ORE %d | WOOD %d | SELECTED: %s" % [
		int(items.get("dirt", 0)),
		int(items.get("stone", 0)),
		int(items.get("ore", 0)),
		int(items.get("wood", 0)),
		world.get_selected_block_name()
	]
	if is_instance_valid(_inventory_summary):
		_inventory_summary.text = _format_inventory(items)
		_refresh_craft_buttons()

func _build_inventory_ui() -> void:
	var hud := $HUD as CanvasLayer
	var toggle := Button.new()
	toggle.name = "InventoryToggle"
	toggle.text = "INVENTORY"
	toggle.position = Vector2(24, 96)
	toggle.size = Vector2(150, 44)
	toggle.pressed.connect(_toggle_inventory)
	hud.add_child(toggle)

	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.position = Vector2(24, 150)
	_inventory_panel.custom_minimum_size = Vector2(330, 390)
	_inventory_panel.visible = false
	hud.add_child(_inventory_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_inventory_panel.add_child(layout)
	var heading := Label.new()
	heading.text = "INVENTORY & CRAFTING"
	heading.add_theme_font_size_override("font_size", 20)
	layout.add_child(heading)
	_inventory_summary = Label.new()
	_inventory_summary.text = _format_inventory(player.inventory.items)
	_inventory_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_inventory_summary)

	var recipe_title := Label.new()
	recipe_title.text = "RECIPES"
	recipe_title.add_theme_font_size_override("font_size", 18)
	layout.add_child(recipe_title)
	_add_recipe_button(layout, "wooden_planks", "2 WOOD  →  4 PLANKS")
	_add_recipe_button(layout, "workbench", "10 WOOD  →  WORKBENCH")
	_add_recipe_button(layout, "stone_sword", "3 WOOD + 8 STONE  →  STONE SWORD")
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(_toggle_inventory)
	layout.add_child(close_button)
	_refresh_craft_buttons()

func _add_recipe_button(parent: VBoxContainer, recipe_id: String, caption: String) -> void:
	var craft_button := Button.new()
	craft_button.text = caption
	craft_button.custom_minimum_size = Vector2(290, 44)
	craft_button.pressed.connect(_craft_recipe.bind(recipe_id))
	parent.add_child(craft_button)
	_craft_buttons[recipe_id] = craft_button

func _format_inventory(items: Dictionary) -> String:
	return "DIRT: %d    STONE: %d\nORE: %d    WOOD: %d\nPLANKS: %d    WORKBENCH: %d\nSTONE SWORD: %d" % [
		int(items.get("dirt", 0)), int(items.get("stone", 0)),
		int(items.get("ore", 0)), int(items.get("wood", 0)),
		int(items.get("wooden_planks", 0)), int(items.get("workbench", 0)),
		int(items.get("stone_sword", 0))
	]

func _refresh_craft_buttons() -> void:
	for recipe_id in _craft_buttons:
		var craft_button := _craft_buttons[recipe_id] as Button
		craft_button.disabled = not player.inventory.can_craft(str(recipe_id))

func _craft_recipe(recipe_id: String) -> void:
	if player.inventory.craft(recipe_id):
		_on_inventory_changed(player.inventory.items)

func _toggle_inventory() -> void:
	if is_instance_valid(_inventory_panel):
		_inventory_panel.visible = not _inventory_panel.visible

func _on_selected_block_changed(_block_type: int) -> void:
	_on_inventory_changed(player.inventory.items)
