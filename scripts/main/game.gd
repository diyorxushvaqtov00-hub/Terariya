extends Node2D

const SAVE_PATH: String = "user://eternal_world_save.json"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 30.0
const DAY_LENGTH_SECONDS: float = 480.0
const NIGHT_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const ZOMBIE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/zombie_enemy.tscn")
const SKELETON_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/skeleton_archer.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/ancient_eye_boss.tscn")
const MAX_NIGHT_ENEMIES: int = 4
const NIGHT_SPAWN_INTERVAL: float = 18.0

var _autosave_elapsed: float = 0.0
var _world_time_seconds: float = DAY_LENGTH_SECONDS * 0.25
var _day_night_overlay: CanvasModulate
var _day_night_label: Label
var _night_spawn_elapsed: float = 0.0
var _is_night: bool = false
var _rng := RandomNumberGenerator.new()
var _inventory_panel: PanelContainer
var _oxygen_bar: ProgressBar
var _underwater_overlay: ColorRect
var _oxygen_label: Label
var _inventory_summary: Label
var _craft_buttons: Dictionary = {}
var _boss_health_bar: ProgressBar
var _boss_status_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _active_boss: AncientEyeBoss

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
	player.oxygen_changed.connect(_on_player_oxygen_changed)
	player.underwater_changed.connect(_on_underwater_changed)
	player.inventory.changed.connect(_on_inventory_changed)
	player.progression_changed.connect(_on_progression_changed)
	_connect_enemy_rewards(slime, 25)
	world.selected_block_changed.connect(_on_selected_block_changed)
	_load_game()
	_on_player_health_changed(player.health, player.max_health)
	_rng.randomize()
	_build_day_night_system()
	_build_underwater_overlay()
	_build_oxygen_ui()
	_on_underwater_changed(player.is_head_underwater)
	_on_player_oxygen_changed(player.oxygen_seconds, player.max_oxygen_seconds)
	_on_inventory_changed(player.inventory.items)
	_build_inventory_ui()
	_build_boss_ui()
	_build_progression_ui()
	_on_progression_changed(player.level, player.experience, player.experience_to_next_level)

func _process(delta: float) -> void:
	_update_day_night(delta)
	_update_night_spawns(delta)
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
			"oxygen_seconds": player.oxygen_seconds,
			"double_jump_unlocked": player.double_jump_unlocked,
			"level": player.level,
			"experience": player.experience
		},
		"time_of_day": _world_time_seconds,
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
	_world_time_seconds = fposmod(float(parsed.get("time_of_day", _world_time_seconds)), DAY_LENGTH_SECONDS)
	_update_day_night(0.0)
	var player_data: Variant = parsed.get("player", {})
	if player_data is Dictionary:
		player.global_position = Vector2(float(player_data.get("x", player.global_position.x)), float(player_data.get("y", player.global_position.y)))
		player.set_spawn_position(player.global_position)
		player.health = clampi(int(player_data.get("health", player.max_health)), 1, player.max_health)
		player.oxygen_seconds = clampf(float(player_data.get("oxygen_seconds", player.max_oxygen_seconds)), 0.0, player.max_oxygen_seconds)
		player.oxygen_changed.emit(player.oxygen_seconds, player.max_oxygen_seconds)
		player.double_jump_unlocked = bool(player_data.get("double_jump_unlocked", false))
		player.restore_progress(int(player_data.get("level", 1)), int(player_data.get("experience", 0)))
		player.health_changed.emit(player.health, player.max_health)
	return true


func _build_day_night_system() -> void:
	_day_night_overlay = CanvasModulate.new()
	_day_night_overlay.name = "DayNightLighting"
	add_child(_day_night_overlay)
	_day_night_label = Label.new()
	_day_night_label.name = "DayNightLabel"
	_day_night_label.position = Vector2(410, 20)
	_day_night_label.size = Vector2(190, 28)
	_day_night_label.add_theme_font_size_override("font_size", 18)
	($HUD as CanvasLayer).add_child(_day_night_label)
	_update_day_night(0.0)

func _update_day_night(delta: float) -> void:
	_world_time_seconds = fposmod(_world_time_seconds + delta, DAY_LENGTH_SECONDS)
	var phase := _world_time_seconds / DAY_LENGTH_SECONDS
	# Midnight=0.0, sunrise=0.25, noon=0.5, sunset=0.75.
	var daylight := maxf(0.0, sin((phase - 0.25) * TAU))
	_is_night = phase < 0.20 or phase > 0.80
	var night_color := Color(0.28, 0.34, 0.58)
	var day_color := Color(1.0, 1.0, 1.0)
	var lighting := night_color.lerp(day_color, daylight)
	var sunrise_strength := maxf(0.0, 1.0 - absf(phase - 0.25) / 0.12)
	var sunset_strength := maxf(0.0, 1.0 - absf(phase - 0.75) / 0.12)
	var warm_strength := maxf(sunrise_strength, sunset_strength)
	lighting = lighting.lerp(Color(1.0, 0.66, 0.42), warm_strength * 0.32)
	if is_instance_valid(_day_night_overlay):
		_day_night_overlay.color = lighting
	if is_instance_valid(_day_night_label):
		var total_minutes := int(floor(phase * 24.0 * 60.0))
		var hour := int(total_minutes / 60) % 24
		var minute := total_minutes % 60
		var period := "NIGHT" if daylight < 0.12 else ("DAWN" if sunrise_strength > 0.25 else ("DUSK" if sunset_strength > 0.25 else "DAY"))
		_day_night_label.text = "%s  %02d:%02d" % [period, hour, minute]


func _update_night_spawns(delta: float) -> void:
	slime.set_night_mode(_is_night)
	if not _is_night:
		_night_spawn_elapsed = 0.0
		for enemy in get_tree().get_nodes_in_group("night_spawned_enemy"):
			enemy.queue_free()
		return
	_night_spawn_elapsed += delta
	if _night_spawn_elapsed < NIGHT_SPAWN_INTERVAL:
		return
	_night_spawn_elapsed = 0.0
	if get_tree().get_nodes_in_group("night_spawned_enemy").size() >= MAX_NIGHT_ENEMIES:
		return
	var player_tile_x := int(floori(player.global_position.x / WorldGenerator.TILE_SIZE))
	var candidate_x := player_tile_x
	for attempt in range(8):
		candidate_x = _rng.randi_range(6, WorldGenerator.WORLD_WIDTH - 7)
		if absi(candidate_x - player_tile_x) >= 7:
			break
	if absi(candidate_x - player_tile_x) < 7:
		return
	var spawn_roll := _rng.randf()
	var enemy_scene: PackedScene = SKELETON_ENEMY_SCENE if spawn_roll < 0.20 else (ZOMBIE_ENEMY_SCENE if spawn_roll < 0.55 else NIGHT_ENEMY_SCENE)
	var enemy := enemy_scene.instantiate() as SlimeEnemy
	var enemy_kind := "Skeleton" if spawn_roll < 0.20 else ("Zombie" if spawn_roll < 0.55 else "Slime")
	if enemy == null:
		return
	enemy.name = "Night" + enemy_kind
	enemy.add_to_group("night_spawned_enemy")
	add_child(enemy)
	enemy.global_position = world.get_spawn_position(candidate_x)
	enemy.set_night_mode(true)
	var reward := 35 if enemy_kind == "Skeleton" else (40 if enemy_kind == "Zombie" else 25)
	_connect_enemy_rewards(enemy, reward)

func _build_progression_ui() -> void:
	var hud := $HUD as CanvasLayer
	_xp_label = Label.new()
	_xp_label.name = "ProgressionLabel"
	_xp_label.position = Vector2(430, 112)
	_xp_label.size = Vector2(420, 24)
	_xp_label.text = "LEVEL 1 — XP 0 / 100"
	hud.add_child(_xp_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "ExperienceBar"
	_xp_bar.position = Vector2(430, 138)
	_xp_bar.size = Vector2(420, 14)
	_xp_bar.show_percentage = false
	hud.add_child(_xp_bar)

func _on_progression_changed(current_level: int, current_xp: int, required_xp: int) -> void:
	if not is_instance_valid(_xp_label) or not is_instance_valid(_xp_bar):
		return
	_xp_label.text = "LEVEL %d — XP %d / %d" % [current_level, current_xp, required_xp]
	_xp_bar.max_value = maxi(required_xp, 1)
	_xp_bar.value = current_xp
	_xp_bar.visible = current_level < 50

func _connect_enemy_rewards(enemy: SlimeEnemy, reward: int) -> void:
	if enemy != null:
		enemy.defeated.connect(_grant_enemy_experience.bind(reward))

func _grant_enemy_experience(reward: int) -> void:
	player.add_experience(reward)

func _build_boss_ui() -> void:
	var hud := $HUD as CanvasLayer
	_boss_status_label = Label.new()
	_boss_status_label.name = "BossStatusLabel"
	_boss_status_label.position = Vector2(430, 54)
	_boss_status_label.size = Vector2(420, 28)
	_boss_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_status_label.text = ""
	hud.add_child(_boss_status_label)
	_boss_health_bar = ProgressBar.new()
	_boss_health_bar.name = "BossHealthBar"
	_boss_health_bar.position = Vector2(430, 84)
	_boss_health_bar.size = Vector2(420, 22)
	_boss_health_bar.show_percentage = false
	_boss_health_bar.visible = false
	hud.add_child(_boss_health_bar)

func _summon_ancient_eye() -> void:
	if is_instance_valid(_active_boss):
		return
	if not player.inventory.remove_item("eye_summon", 1):
		return
	_active_boss = BOSS_SCENE.instantiate() as AncientEyeBoss
	if _active_boss == null:
		player.inventory.add_item("eye_summon", 1)
		return
	_active_boss.name = "AncientEyeBoss"
	_active_boss.health_changed.connect(_on_boss_health_changed)
	_active_boss.defeated.connect(_on_boss_defeated)
	_active_boss.phase_changed.connect(_on_boss_phase_changed)
	add_child(_active_boss)
	_active_boss.global_position = player.global_position + Vector2(360.0 * player.get_facing(), 0.0)
	_boss_health_bar.max_value = _active_boss.max_health
	_boss_health_bar.value = _active_boss.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: ANCIENT EYE — PHASE 1"
	_boss_status_label.visible = true
	_on_inventory_changed(player.inventory.items)

func _on_boss_health_changed(current: int, maximum: int) -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.max_value = maximum
		_boss_health_bar.value = current

func _on_boss_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: ANCIENT EYE — PHASE %d" % phase

func _on_boss_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "ANCIENT EYE DEFEATED!"
	player.inventory.add_item("ore", 20)
	player.inventory.add_item("copper_sword", 1)
	player.add_experience(500)
	_active_boss = null

func _on_player_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP  %d / %d" % [current, maximum]

func _build_underwater_overlay() -> void:
	var hud := $HUD as CanvasLayer
	_underwater_overlay = ColorRect.new()
	_underwater_overlay.name = "UnderwaterOverlay"
	_underwater_overlay.color = Color(0.08, 0.30, 0.72, 0.20)
	_underwater_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_underwater_overlay.visible = false
	hud.add_child(_underwater_overlay)
	hud.move_child(_underwater_overlay, 0)

func _on_underwater_changed(is_underwater: bool) -> void:
	if is_instance_valid(_underwater_overlay):
		_underwater_overlay.visible = is_underwater

func _build_oxygen_ui() -> void:
	var hud := $HUD as CanvasLayer
	_oxygen_bar = ProgressBar.new()
	_oxygen_bar.name = "OxygenBar"
	_oxygen_bar.position = Vector2(24, 91)
	_oxygen_bar.size = Vector2(210, 18)
	_oxygen_bar.show_percentage = false
	hud.add_child(_oxygen_bar)
	_oxygen_label = Label.new()
	_oxygen_label.name = "OxygenLabel"
	_oxygen_label.position = Vector2(242, 87)
	_oxygen_label.size = Vector2(130, 26)
	hud.add_child(_oxygen_label)

func _on_player_oxygen_changed(current: float, maximum: float) -> void:
	if is_instance_valid(_oxygen_bar):
		_oxygen_bar.max_value = maximum
		_oxygen_bar.value = current
	if is_instance_valid(_oxygen_label):
		_oxygen_label.text = "AIR  %.1fs" % current

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
	toggle.position = Vector2(24, 120)
	toggle.size = Vector2(150, 44)
	toggle.pressed.connect(_toggle_inventory)
	hud.add_child(toggle)

	_inventory_panel = PanelContainer.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.position = Vector2(24, 174)
	_inventory_panel.custom_minimum_size = Vector2(360, 500)
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
	_add_recipe_button(layout, "wooden_pickaxe", "5 PLANKS + 3 STONE  →  PICKAXE")
	_add_recipe_button(layout, "wooden_axe", "4 PLANKS + 2 STONE  →  AXE")
	_add_recipe_button(layout, "wooden_bucket", "5 PLANKS  →  EMPTY BUCKET")
	_add_recipe_button(layout, "torch", "1 WOOD  →  4 TORCHES")
	_add_recipe_button(layout, "wooden_armor", "12 PLANKS  →  WOODEN ARMOR")
	_add_recipe_button(layout, "copper_sword", "10 ORE + 2 PLANKS  →  COPPER SWORD")
	_add_recipe_button(layout, "eye_summon", "8 ORE + 12 STONE + 5 WOOD  →  EYE SIGIL")
	var summon_button := Button.new()
	summon_button.text = "SUMMON ANCIENT EYE BOSS"
	summon_button.pressed.connect(_summon_ancient_eye)
	layout.add_child(summon_button)
	var equip_armor_button := Button.new()
	equip_armor_button.text = "EQUIP WOODEN ARMOR"
	equip_armor_button.pressed.connect(_equip_wooden_armor)
	layout.add_child(equip_armor_button)
	var remove_armor_button := Button.new()
	remove_armor_button.text = "UNEQUIP ARMOR"
	remove_armor_button.pressed.connect(_unequip_armor)
	layout.add_child(remove_armor_button)
	var torch_button := Button.new()
	torch_button.text = "PLACE TORCH (EMPTY TILE IN FRONT)"
	torch_button.pressed.connect(_place_torch)
	layout.add_child(torch_button)
	var fill_button := Button.new()
	fill_button.text = "FILL BUCKET (WATER IN FRONT)"
	fill_button.pressed.connect(_fill_water_bucket)
	layout.add_child(fill_button)
	var pour_button := Button.new()
	pour_button.text = "POUR BUCKET (EMPTY TILE IN FRONT)"
	pour_button.pressed.connect(_pour_water_bucket)
	layout.add_child(pour_button)
	var chest_button := Button.new()
	chest_button.text = "OPEN NEARBY DUNGEON CHEST"
	chest_button.pressed.connect(_open_nearby_chest)
	layout.add_child(chest_button)
	var potion_button := Button.new()
	potion_button.text = "USE HEALING POTION (+35 HP)"
	potion_button.pressed.connect(_use_healing_potion)
	layout.add_child(potion_button)
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
	return "DIRT: %d    STONE: %d\nORE: %d    WOOD: %d\nPLANKS: %d    WORKBENCH: %d\nTORCHES: %d    EYE SIGIL: %d\nHEALING POTIONS: %d\nWOOD ARMOR: %d (%s)\nCOPPER SWORD: %d\nEMPTY BUCKET: %d    WATER BUCKET: %d\nSTONE SWORD: %d\nPICKAXE: %d (%d durability)\nAXE: %d (%d durability)" % [
		int(items.get("dirt", 0)), int(items.get("stone", 0)),
		int(items.get("ore", 0)), int(items.get("wood", 0)),
		int(items.get("wooden_planks", 0)), int(items.get("workbench", 0)),
		int(items.get("torch", 0)), int(items.get("eye_summon", 0)), int(items.get("healing_potion", 0)), int(items.get("wooden_armor", 0)), "EQUIPPED" if player.inventory.equipped_armor == "wooden_armor" else "NOT EQUIPPED",
		int(items.get("copper_sword", 0)), int(items.get("empty_bucket", 0)), int(items.get("water_bucket", 0)),
		int(items.get("stone_sword", 0)),
		int(items.get("wooden_pickaxe", 0)), player.inventory.get_tool_durability("wooden_pickaxe"),
		int(items.get("wooden_axe", 0)), player.inventory.get_tool_durability("wooden_axe")
	]

func _refresh_craft_buttons() -> void:
	for recipe_id in _craft_buttons:
		var craft_button := _craft_buttons[recipe_id] as Button
		craft_button.disabled = not player.inventory.can_craft(str(recipe_id))

func _get_water_target_cell() -> Vector2i:
	var target := player.global_position + Vector2(player.get_facing() * WorldGenerator.TILE_SIZE * 1.35, WorldGenerator.TILE_SIZE * 0.5)
	var local_target := world.to_local(target)
	return Vector2i(floori(local_target.x / WorldGenerator.TILE_SIZE), floori(local_target.y / WorldGenerator.TILE_SIZE))

func _equip_wooden_armor() -> void:
	player.inventory.equip_armor("wooden_armor")
	_on_inventory_changed(player.inventory.items)

func _unequip_armor() -> void:
	player.inventory.equip_armor("")
	_on_inventory_changed(player.inventory.items)

func _place_torch() -> void:
	if world.place_torch(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _fill_water_bucket() -> void:
	if world.fill_bucket(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _pour_water_bucket() -> void:
	if world.pour_bucket(_get_water_target_cell(), player.inventory, player.global_position):
		_on_inventory_changed(player.inventory.items)

func _open_nearby_chest() -> void:
	if world.open_nearby_chest(player.global_position, player.inventory):
		_on_inventory_changed(player.inventory.items)

func _use_healing_potion() -> void:
	if player.inventory.remove_item("healing_potion", 1):
		player.heal(35)
		_on_inventory_changed(player.inventory.items)

func _craft_recipe(recipe_id: String) -> void:
	if player.inventory.craft(recipe_id):
		_on_inventory_changed(player.inventory.items)

func _toggle_inventory() -> void:
	if is_instance_valid(_inventory_panel):
		_inventory_panel.visible = not _inventory_panel.visible

func _on_selected_block_changed(_block_type: int) -> void:
	_on_inventory_changed(player.inventory.items)
