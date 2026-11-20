extends Node2D

const SAVE_PATH: String = "user://eternal_world_save.json"
const SAVE_TEMP_PATH: String = "user://eternal_world_save.tmp"
const SAVE_BACKUP_PATH: String = "user://eternal_world_save.bak"
const SAVE_VERSION: int = 1
const AUTOSAVE_INTERVAL: float = 30.0
@export_range(120.0, 1800.0, 30.0) var day_length_seconds: float = 480.0
const NIGHT_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const ZOMBIE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/zombie_enemy.tscn")
const SKELETON_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/skeleton_archer.tscn")
const NIGHT_BAT_SCENE: PackedScene = preload("res://scenes/enemies/night_bat.tscn")
const DUNGEON_SKELETON_SCENE: PackedScene = preload("res://scenes/enemies/dungeon_skeleton.tscn")
const CAVE_SPIDER_SCENE: PackedScene = preload("res://scenes/enemies/cave_spider.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/ancient_eye_boss.tscn")
const SPIDER_QUEEN_SCENE: PackedScene = preload("res://scenes/enemies/spider_queen_boss.tscn")
const MAGMA_GOLEM_SCENE: PackedScene = preload("res://scenes/enemies/magma_golem_boss.tscn")
const MUSHROOM_GUARDIAN_SCENE: PackedScene = preload("res://scenes/enemies/mushroom_guardian_boss.tscn")
const DUNGEON_WARDEN_SCENE: PackedScene = preload("res://scenes/enemies/dungeon_warden_boss.tscn")
const VOID_GUARDIAN_SCENE: PackedScene = preload("res://scenes/enemies/void_guardian_boss.tscn")
const MERCHANT_SCENE: PackedScene = preload("res://scenes/npcs/merchant.tscn")
const GUIDE_SCENE: PackedScene = preload("res://scenes/npcs/guide.tscn")
const SPIKE_TRAP_SCENE: PackedScene = preload("res://scenes/world/spike_trap.tscn")
const SWINGING_BLADE_SCENE: PackedScene = preload("res://scenes/world/swinging_blade.tscn")
@export_range(1, 12, 1) var max_night_enemies: int = 4
@export_range(5.0, 60.0, 1.0) var night_spawn_interval: float = 18.0

var _autosave_elapsed: float = 0.0
var _world_time_seconds: float = day_length_seconds * 0.25
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
var _station_summary: Label
var _quest_summary: Label
var _quest_tracker: QuestTracker
var _merchant_shop_panel: PanelContainer
var _merchant_status: Label
var _merchant: Node2D
var _guide: GuideNPC
var _guide_dialogue_label: Label
var _guide_dialogue_index: int = 0
var _dungeon_status_label: Label
var _craft_buttons: Dictionary = {}
var _boss_health_bar: ProgressBar
var _boss_status_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _mana_bar: ProgressBar
var _mana_label: Label
var _active_boss: AncientEyeBoss
var _active_spider_queen: SpiderQueenBoss
var _active_magma_golem: MagmaGolemBoss
var _active_mushroom_guardian: MushroomGuardianBoss
var _active_dungeon_warden: DungeonWardenBoss
var _active_void_guardian: VoidGuardianBoss

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
	player.mana_changed.connect(_on_player_mana_changed)
	player.underwater_changed.connect(_on_underwater_changed)
	player.progression_changed.connect(_on_progression_changed)
	_connect_enemy_rewards(slime, 25)
	world.selected_block_changed.connect(_on_selected_block_changed)
	_quest_tracker = QuestTracker.new()
	add_child(_quest_tracker)
	_quest_tracker.quest_completed.connect(_on_quest_completed)
	_quest_tracker.updated.connect(_on_quests_updated)
	_load_game()
	player.inventory.changed.connect(_on_inventory_changed)
	_quest_tracker.sync_inventory(player.inventory.items)
	_spawn_merchant()
	_spawn_dungeon_hazards()
	_spawn_dungeon_guards()
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
	_build_mana_ui()
	_on_player_mana_changed(player.mana, player.max_mana)
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
			"mana": player.mana,
			"double_jump_unlocked": player.double_jump_unlocked,
			"level": player.level,
			"experience": player.experience
		},
		"time_of_day": _world_time_seconds,
		"inventory": player.inventory.serialize(),
		"world": world.get_save_data(),
		"quests": _quest_tracker.serialize() if is_instance_valid(_quest_tracker) else {}
	}
	var temp_file := FileAccess.open(SAVE_TEMP_PATH, FileAccess.WRITE)
	if temp_file == null:
		push_warning("Save failed: could not create the temporary save file.")
		return false
	temp_file.store_string(JSON.stringify(data))
	temp_file.flush()
	temp_file.close()
	var temp_check := _read_save_dictionary(SAVE_TEMP_PATH)
	if temp_check.is_empty() or int(temp_check.get("version", -1)) != SAVE_VERSION:
		push_warning("Save failed: temporary save verification did not pass.")
		return false
	var save_absolute := ProjectSettings.globalize_path(SAVE_PATH)
	var temp_absolute := ProjectSettings.globalize_path(SAVE_TEMP_PATH)
	var backup_absolute := ProjectSettings.globalize_path(SAVE_BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			push_warning("Save failed: could not preserve the previous save.")
			return false
	var replace_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(SAVE_BACKUP_PATH):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		push_warning("Save failed: could not replace the previous save.")
		return false
	return true

func _read_save_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", -1)) != SAVE_VERSION:
		return {}
	return parsed

func _load_game() -> bool:
	var parsed := _read_save_dictionary(SAVE_PATH)
	if parsed.is_empty():
		parsed = _read_save_dictionary(SAVE_BACKUP_PATH)
	if parsed.is_empty():
		if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_BACKUP_PATH):
			push_warning("Main and backup saves are invalid or use an unsupported version.")
		return false
	var quest_data: Variant = parsed.get("quests", {})
	if quest_data is Dictionary and is_instance_valid(_quest_tracker):
		if not quest_data.is_empty() and not _quest_tracker.restore(quest_data):
			push_warning("Saved quest data is invalid; using new quest progress.")
	var world_data: Variant = parsed.get("world", {})
	if not world_data is Dictionary or not world.load_save_data(world_data):
		push_warning("Saved world data is invalid; starting with generated world.")
		return false
	var inventory_data: Variant = parsed.get("inventory", {})
	if not inventory_data is Dictionary or not player.inventory.restore(inventory_data):
		push_warning("Saved inventory is invalid; keeping starter inventory.")
		return false
	_world_time_seconds = fposmod(float(parsed.get("time_of_day", _world_time_seconds)), day_length_seconds)
	_update_day_night(0.0)
	var player_data: Variant = parsed.get("player", {})
	if player_data is Dictionary:
		player.global_position = Vector2(float(player_data.get("x", player.global_position.x)), float(player_data.get("y", player.global_position.y)))
		player.set_spawn_position(player.global_position)
		player.health = clampi(int(player_data.get("health", player.max_health)), 1, player.max_health)
		player.oxygen_seconds = clampf(float(player_data.get("oxygen_seconds", player.max_oxygen_seconds)), 0.0, player.max_oxygen_seconds)
		player.mana = clampf(float(player_data.get("mana", player.max_mana)), 0.0, player.max_mana)
		player.mana_changed.emit(player.mana, player.max_mana)
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
	_world_time_seconds = fposmod(_world_time_seconds + delta, day_length_seconds)
	var phase := _world_time_seconds / day_length_seconds
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
	if _night_spawn_elapsed < night_spawn_interval:
		return
	_night_spawn_elapsed = 0.0
	if get_tree().get_nodes_in_group("night_spawned_enemy").size() >= max_night_enemies:
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
	var enemy_scene: PackedScene = NIGHT_BAT_SCENE if spawn_roll < 0.18 else (SKELETON_ENEMY_SCENE if spawn_roll < 0.36 else (ZOMBIE_ENEMY_SCENE if spawn_roll < 0.62 else NIGHT_ENEMY_SCENE))
	var enemy := enemy_scene.instantiate() as SlimeEnemy
	var enemy_kind := "Bat" if spawn_roll < 0.18 else ("Skeleton" if spawn_roll < 0.36 else ("Zombie" if spawn_roll < 0.62 else "Slime"))
	if enemy == null:
		return
	enemy.name = "Night" + enemy_kind
	enemy.add_to_group("night_spawned_enemy")
	add_child(enemy)
	enemy.global_position = world.get_spawn_position(candidate_x)
	enemy.set_night_mode(true)
	var reward := 30 if enemy_kind == "Bat" else (35 if enemy_kind == "Skeleton" else (40 if enemy_kind == "Zombie" else 25))
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

func _spawn_dungeon_hazards() -> void:
	for position in world.get_dungeon_spike_positions():
		var trap := SPIKE_TRAP_SCENE.instantiate() as SpikeTrap
		if trap == null:
			continue
		add_child(trap)
		trap.global_position = position
	for position in world.get_dungeon_blade_positions():
		var blade := SWINGING_BLADE_SCENE.instantiate() as SwingingBlade
		if blade == null:
			continue
		add_child(blade)
		blade.global_position = position

func _spawn_dungeon_guards() -> void:
	var spawn_positions := world.get_dungeon_guard_positions()
	for index in range(spawn_positions.size()):
		var is_skeleton := index % 2 == 0
		var enemy_scene: PackedScene = DUNGEON_SKELETON_SCENE if is_skeleton else CAVE_SPIDER_SCENE
		var enemy := enemy_scene.instantiate() as SlimeEnemy
		if enemy == null:
			continue
		enemy.name = "DungeonSkeleton" if is_skeleton else "CaveSpider"
		enemy.add_to_group("dungeon_enemy")
		add_child(enemy)
		enemy.global_position = spawn_positions[index]
		if is_skeleton:
			_connect_dungeon_reward(enemy, 55, "silver_ore", 3)
		else:
			_connect_dungeon_reward(enemy, 35, "spider_fang", 2)

func _connect_dungeon_reward(enemy: SlimeEnemy, xp_reward: int, item_id: String, item_amount: int) -> void:
	if enemy != null:
		enemy.defeated.connect(_grant_dungeon_reward.bind(xp_reward, item_id, item_amount))

func _grant_dungeon_reward(xp_reward: int, item_id: String, item_amount: int) -> void:
	player.add_experience(xp_reward)
	_quest_tracker.record_enemy_defeat()
	player.inventory.add_item(item_id, item_amount)
	player.inventory.add_item("coins", maxi(1, int(floori(float(xp_reward) / 12.0))))

func _connect_enemy_rewards(enemy: SlimeEnemy, reward: int) -> void:
	if enemy != null:
		enemy.defeated.connect(_grant_enemy_experience.bind(reward))

func _grant_enemy_experience(reward: int) -> void:
	player.add_experience(reward)
	_quest_tracker.record_enemy_defeat()
	player.inventory.add_item("coins", maxi(1, int(floori(float(reward) / 10.0))))

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

func _summon_spider_queen() -> void:
	if is_instance_valid(_active_spider_queen) or is_instance_valid(_active_boss) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_mushroom_guardian) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
		return
	if not player.inventory.remove_item("spider_summon", 1):
		return
	_active_spider_queen = SPIDER_QUEEN_SCENE.instantiate() as SpiderQueenBoss
	if _active_spider_queen == null:
		player.inventory.add_item("spider_summon", 1)
		return
	_active_spider_queen.name = "SpiderQueenBoss"
	_active_spider_queen.health_changed.connect(_on_boss_health_changed)
	_active_spider_queen.defeated.connect(_on_spider_queen_defeated)
	_active_spider_queen.phase_changed.connect(_on_spider_queen_phase_changed)
	add_child(_active_spider_queen)
	_active_spider_queen.global_position = player.global_position + Vector2(420.0 * player.get_facing(), 0.0)
	_boss_health_bar.max_value = _active_spider_queen.max_health
	_boss_health_bar.value = _active_spider_queen.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: SPIDER QUEEN — PHASE 1"
	_boss_status_label.visible = true
	_on_inventory_changed(player.inventory.items)

func _on_spider_queen_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: SPIDER QUEEN — PHASE %d" % phase

func _on_spider_queen_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "SPIDER QUEEN DEFEATED!"
	player.inventory.add_item("gold_ore", 30)
	player.inventory.add_item("spider_fang", 12)
	player.inventory.add_item("queens_fang", 1)
	player.inventory.add_item("healing_potion", 5)
	player.add_experience(900)
	_active_spider_queen = null

func _summon_ancient_eye() -> void:
	if is_instance_valid(_active_boss) or is_instance_valid(_active_spider_queen) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
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

func _summon_magma_golem() -> void:
	if is_instance_valid(_active_boss) or is_instance_valid(_active_spider_queen) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
		return
	if not player.inventory.remove_item("magma_heart", 1):
		return
	_active_magma_golem = MAGMA_GOLEM_SCENE.instantiate() as MagmaGolemBoss
	if _active_magma_golem == null:
		player.inventory.add_item("magma_heart", 1)
		return
	_active_magma_golem.name = "MagmaGolemBoss"
	_active_magma_golem.health_changed.connect(_on_boss_health_changed)
	_active_magma_golem.defeated.connect(_on_magma_golem_defeated)
	_active_magma_golem.phase_changed.connect(_on_magma_golem_phase_changed)
	add_child(_active_magma_golem)
	_active_magma_golem.global_position = player.global_position + Vector2(460.0 * player.get_facing(), 0.0)
	_boss_health_bar.max_value = _active_magma_golem.max_health
	_boss_health_bar.value = _active_magma_golem.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: MAGMA GOLEM — PHASE 1"
	_boss_status_label.visible = true
	_on_inventory_changed(player.inventory.items)

func _on_magma_golem_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: MAGMA GOLEM — PHASE %d" % phase

func _on_magma_golem_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "MAGMA GOLEM DEFEATED!"
	player.inventory.add_item("magma_core", 16)
	player.inventory.add_item("gold_ore", 35)
	player.inventory.add_item("healing_potion", 6)
	player.add_experience(1400)
	_active_magma_golem = null

func _summon_dungeon_warden() -> void:
	if is_instance_valid(_active_boss) or is_instance_valid(_active_spider_queen) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_mushroom_guardian) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
		return
	if not player.inventory.remove_item("dungeon_warden_sigil", 1):
		return
	_active_dungeon_warden = DUNGEON_WARDEN_SCENE.instantiate() as DungeonWardenBoss
	if _active_dungeon_warden == null:
		player.inventory.add_item("dungeon_warden_sigil", 1)
		return
	_active_dungeon_warden.name = "DungeonWardenBoss"
	_active_dungeon_warden.health_changed.connect(_on_boss_health_changed)
	_active_dungeon_warden.defeated.connect(_on_dungeon_warden_defeated)
	_active_dungeon_warden.phase_changed.connect(_on_dungeon_warden_phase_changed)
	add_child(_active_dungeon_warden)
	_active_dungeon_warden.global_position = world.get_nearest_dungeon_arena_position(player.global_position)
	_boss_health_bar.max_value = _active_dungeon_warden.max_health
	_boss_health_bar.value = _active_dungeon_warden.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: DUNGEON WARDEN — PHASE 1"
	_boss_status_label.visible = true
	_on_inventory_changed(player.inventory.items)

func _on_dungeon_warden_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: DUNGEON WARDEN — PHASE %d" % phase

func _on_dungeon_warden_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "DUNGEON WARDEN DEFEATED!"
	player.inventory.add_item("dungeon_relic", 3)
	player.inventory.add_item("gold_ore", 28)
	player.inventory.add_item("healing_potion", 8)
	player.add_experience(1800)
	_active_dungeon_warden = null

func _summon_void_guardian() -> void:
	if is_instance_valid(_active_boss) or is_instance_valid(_active_spider_queen) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_mushroom_guardian) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
		return
	var arena_position := world.get_nearest_secret_cache_position(player.global_position)
	if not world.is_secret_vault_open_nearby(player.global_position):
		if is_instance_valid(_dungeon_status_label):
			_dungeon_status_label.text = "THE VOID GUARDIAN CAN ONLY BE SUMMONED INSIDE A SECRET VAULT."
		return
	if not player.inventory.remove_item("void_guardian_sigil", 1):
		if is_instance_valid(_dungeon_status_label):
			_dungeon_status_label.text = "CRAFT A VOID GUARDIAN SIGIL FIRST."
		return
	_active_void_guardian = VOID_GUARDIAN_SCENE.instantiate() as VoidGuardianBoss
	if _active_void_guardian == null:
		player.inventory.add_item("void_guardian_sigil", 1)
		return
	_active_void_guardian.name = "VoidGuardianBoss"
	_active_void_guardian.health_changed.connect(_on_boss_health_changed)
	_active_void_guardian.defeated.connect(_on_void_guardian_defeated)
	_active_void_guardian.phase_changed.connect(_on_void_guardian_phase_changed)
	add_child(_active_void_guardian)
	_active_void_guardian.global_position = arena_position + Vector2(0.0, -WorldGenerator.TILE_SIZE)
	_boss_health_bar.max_value = _active_void_guardian.max_health
	_boss_health_bar.value = _active_void_guardian.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: VOID GUARDIAN — PHASE 1"
	_boss_status_label.visible = true
	if is_instance_valid(_dungeon_status_label):
		_dungeon_status_label.text = "THE VOID GUARDIAN HAS AWAKENED!"
	_on_inventory_changed(player.inventory.items)

func _on_void_guardian_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: VOID GUARDIAN — PHASE %d" % phase

func _on_void_guardian_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "VOID GUARDIAN DEFEATED!"
	player.inventory.add_item("void_shard", 3)
	player.inventory.add_item("dungeon_relic", 2)
	player.inventory.add_item("healing_potion", 5)
	player.add_experience(1600)
	_active_void_guardian = null
	_on_inventory_changed(player.inventory.items)

func _summon_mushroom_guardian() -> void:
	if is_instance_valid(_active_boss) or is_instance_valid(_active_spider_queen) or is_instance_valid(_active_magma_golem) or is_instance_valid(_active_mushroom_guardian) or is_instance_valid(_active_dungeon_warden) or is_instance_valid(_active_void_guardian):
		return
	if not player.inventory.remove_item("guardian_totem", 1):
		return
	_active_mushroom_guardian = MUSHROOM_GUARDIAN_SCENE.instantiate() as MushroomGuardianBoss
	if _active_mushroom_guardian == null:
		player.inventory.add_item("guardian_totem", 1)
		return
	_active_mushroom_guardian.name = "MushroomGuardianBoss"
	_active_mushroom_guardian.health_changed.connect(_on_boss_health_changed)
	_active_mushroom_guardian.defeated.connect(_on_mushroom_guardian_defeated)
	_active_mushroom_guardian.phase_changed.connect(_on_mushroom_guardian_phase_changed)
	add_child(_active_mushroom_guardian)
	_active_mushroom_guardian.global_position = player.global_position + Vector2(390.0 * player.get_facing(), 0.0)
	_boss_health_bar.max_value = _active_mushroom_guardian.max_health
	_boss_health_bar.value = _active_mushroom_guardian.health
	_boss_health_bar.visible = true
	_boss_status_label.text = "BOSS: MUSHROOM GUARDIAN — PHASE 1"
	_boss_status_label.visible = true
	_on_inventory_changed(player.inventory.items)

func _on_mushroom_guardian_phase_changed(phase: int) -> void:
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "BOSS: MUSHROOM GUARDIAN — PHASE %d" % phase

func _on_mushroom_guardian_defeated() -> void:
	if is_instance_valid(_boss_health_bar):
		_boss_health_bar.visible = false
	if is_instance_valid(_boss_status_label):
		_boss_status_label.text = "MUSHROOM GUARDIAN DEFEATED!"
	player.inventory.add_item("glow_mushroom", 30)
	player.inventory.add_item("mushroom_soil", 20)
	player.inventory.add_item("healing_potion", 5)
	player.add_experience(1100)
	_active_mushroom_guardian = null

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

func _on_quests_updated(summary: String) -> void:
	if is_instance_valid(_quest_summary):
		_quest_summary.text = summary

func _on_quest_completed(quest_id: String) -> void:
	match quest_id:
		"gather_wood":
			player.inventory.add_item("coins", 15)
			player.inventory.add_item("healing_potion", 1)
		"hunter":
			player.inventory.add_item("coins", 25)
			player.inventory.add_item("silver_ore", 3)
		"dungeon_delver":
			player.inventory.add_item("coins", 40)
			player.inventory.add_item("gold_ore", 2)
	_on_inventory_changed(player.inventory.items)

func _build_mana_ui() -> void:
	var hud := $HUD as CanvasLayer
	_mana_label = Label.new()
	_mana_label.name = "ManaLabel"
	_mana_label.position = Vector2(24, 112)
	_mana_label.size = Vector2(110, 22)
	_mana_label.text = "MANA 100"
	hud.add_child(_mana_label)
	_mana_bar = ProgressBar.new()
	_mana_bar.name = "ManaBar"
	_mana_bar.position = Vector2(135, 116)
	_mana_bar.size = Vector2(180, 14)
	_mana_bar.show_percentage = false
	hud.add_child(_mana_bar)

func _on_player_mana_changed(current: float, maximum: float) -> void:
	if is_instance_valid(_mana_bar):
		_mana_bar.max_value = maximum
		_mana_bar.value = current
	if is_instance_valid(_mana_label):
		_mana_label.text = "MANA %.0f" % current

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
	if is_instance_valid(_quest_tracker):
		_quest_tracker.sync_inventory(items)
	inventory_label.text = "DIRT %d | STONE %d | ORE %d | WOOD %d | SELECTED: %s" % [
		int(items.get("dirt", 0)),
		int(items.get("stone", 0)),
		int(items.get("ore", 0)),
		int(items.get("wood", 0)),
		world.get_selected_block_name()
	]
	if is_instance_valid(_inventory_summary):
		_inventory_summary.text = _format_inventory(items)
	if is_instance_valid(_station_summary):
		_station_summary.text = "CRAFTING STATIONS  |  WORKBENCH %d  ANVIL %d  ALCHEMY %d  TINKERING %d" % [int(items.get("workbench", 0)), int(items.get("anvil", 0)), int(items.get("alchemy_table", 0)), int(items.get("tinkering_bench", 0))]
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

	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.name = "InventoryScroll"
	recipe_scroll.custom_minimum_size = Vector2(340, 460)
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	recipe_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_inventory_panel.add_child(recipe_scroll)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	recipe_scroll.add_child(layout)
	var heading := Label.new()
	heading.text = "INVENTORY & CRAFTING"
	heading.add_theme_font_size_override("font_size", 20)
	layout.add_child(heading)
	_inventory_summary = Label.new()
	_inventory_summary.text = _format_inventory(player.inventory.items)
	_inventory_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_inventory_summary)
	_station_summary = Label.new()
	_station_summary.name = "CraftingStationSummary"
	_station_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_station_summary.text = "CRAFTING STATIONS  |  WORKBENCH 0  ANVIL 0  ALCHEMY 0  TINKERING 0"
	layout.add_child(_station_summary)

	_quest_summary = Label.new()
	_quest_summary.name = "QuestSummary"
	_quest_summary.text = _quest_tracker.get_summary() if is_instance_valid(_quest_tracker) else "QUEST LOG"
	_quest_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_quest_summary)
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
	_add_recipe_button(layout, "lantern", "6 PLANKS + 3 ORE  →  LANTERN")
	_add_recipe_button(layout, "water_pump", "12 PLANKS + 8 ORE  →  WATER PUMP")
	_add_recipe_button(layout, "drain_charge", "6 STONE + 3 ORE  →  3 DRAIN CHARGES")
	_add_recipe_button(layout, "wooden_armor", "12 PLANKS  →  WOODEN ARMOR")
	_add_recipe_button(layout, "wooden_helmet", "8 PLANKS  →  WOODEN HELMET")
	_add_recipe_button(layout, "wooden_boots", "6 PLANKS  →  WOODEN BOOTS")
	_add_recipe_button(layout, "silver_helmet", "12 SILVER + 4 PLANKS  →  SILVER HELMET")
	_add_recipe_button(layout, "silver_boots", "10 SILVER + 3 PLANKS  →  SILVER BOOTS")
	_add_recipe_button(layout, "gold_helmet", "10 GOLD + 4 PLANKS  →  GOLD HELMET")
	_add_recipe_button(layout, "gold_boots", "8 GOLD + 3 PLANKS  →  GOLD BOOTS")
	_add_recipe_button(layout, "copper_sword", "10 ORE + 2 PLANKS  →  COPPER SWORD")
	_add_recipe_button(layout, "eye_summon", "8 ORE + 12 STONE + 5 WOOD  →  EYE SIGIL")
	_add_recipe_button(layout, "silver_sword", "12 SILVER + 4 PLANKS  →  SILVER SWORD")
	_add_recipe_button(layout, "gold_sword", "10 GOLD + 5 PLANKS  →  GOLD SWORD")
	_add_recipe_button(layout, "silver_armor", "28 SILVER + 8 PLANKS  →  SILVER ARMOR")
	_add_recipe_button(layout, "gold_armor", "24 GOLD + 10 PLANKS  →  GOLD ARMOR")
	_add_recipe_button(layout, "anvil", "20 STONE + 10 ORE + 8 PLANKS  →  ANVIL")
	_add_recipe_button(layout, "alchemy_table", "12 PLANKS + 8 SOIL + 6 SILVER  →  ALCHEMY TABLE")
	_add_recipe_button(layout, "healing_potion", "3 GLOW MUSHROOM + 2 SOIL  →  HEALING POTION")
	_add_recipe_button(layout, "tinkering_bench", "10 PLANKS + 8 SILVER + 4 FANGS  →  TINKERING BENCH")
	_add_recipe_button(layout, "double_jump_charm", "10 SILVER + 6 MUSHROOM + 4 FANGS  →  DOUBLE JUMP CHARM")
	_add_recipe_button(layout, "repair_kit", "4 PLANKS + 3 ORE + 2 MUSHROOM  →  REPAIR KIT")
	_add_recipe_button(layout, "spider_summon", "6 FANGS + 20 SILVER + 8 GOLD  →  QUEEN SIGIL")
	_add_recipe_button(layout, "magma_heart", "8 CORES + 30 GOLD + 20 MAGMA ROCK  →  MAGMA HEART")
	_add_recipe_button(layout, "obsidian_sword", "12 CORES + 18 GOLD + 8 PLANKS  →  OBSIDIAN SWORD")
	_add_recipe_button(layout, "obsidian_armor", "24 CORES + 24 GOLD + 12 PLANKS  →  OBSIDIAN ARMOR")
	_add_recipe_button(layout, "guardian_totem", "12 GLOW MUSHROOM + 18 SOIL + 15 SILVER  →  GUARDIAN TOTEM")
	_add_recipe_button(layout, "mushroom_blade", "18 GLOW MUSHROOM + 4 CORES + 10 PLANKS  →  MUSHROOM BLADE")
	_add_recipe_button(layout, "fungal_armor", "24 GLOW MUSHROOM + 20 SOIL + 18 SILVER  →  FUNGAL ARMOR")
	_add_recipe_button(layout, "dungeon_key", "6 SILVER + 3 GOLD + 2 FANGS  →  3 DUNGEON KEYS")
	_add_recipe_button(layout, "ancient_key", "1 RELIC + 8 GOLD + 4 FANGS  →  2 ANCIENT KEYS")
	_add_recipe_button(layout, "dungeon_warden_sigil", "1 RELIC + 20 GOLD + 10 SILVER + 6 FANGS  →  WARDEN SIGIL")
	_add_recipe_button(layout, "void_guardian_sigil", "1 RELIC + 12 GOLD + 6 CORES + 6 FANGS  →  VOID SIGIL")
	_add_recipe_button(layout, "void_armor", "8 VOID SHARDS + 3 RELICS + 20 GOLD  →  VOID ARMOR")
	_add_recipe_button(layout, "voidbreaker", "2 RELICS + 16 GOLD + 8 CORES + 12 FANGS  →  VOIDBREAKER")
	_add_recipe_button(layout, "void_staff", "6 VOID SHARDS + 2 RELICS + 12 MUSHROOMS  →  VOID STAFF")

	var guide_title := Label.new()
	guide_title.text = "THE ELDER'S ADVICE"
	guide_title.add_theme_font_size_override("font_size", 18)
	layout.add_child(guide_title)
	_guide_dialogue_label = Label.new()
	_guide_dialogue_label.name = "GuideDialogue"
	_guide_dialogue_label.text = "Find the Elder near your starting camp."
	_guide_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_guide_dialogue_label)
	var guide_button := Button.new()
	guide_button.text = "TALK TO THE ELDER"
	guide_button.pressed.connect(_talk_to_guide)
	layout.add_child(guide_button)
	var merchant_button := Button.new()
	merchant_button.text = "OPEN MERCHANT SHOP"
	merchant_button.pressed.connect(_open_merchant_shop)
	layout.add_child(merchant_button)
	_merchant_shop_panel = PanelContainer.new()
	_merchant_shop_panel.name = "MerchantShopPanel"
	_merchant_shop_panel.visible = false
	layout.add_child(_merchant_shop_panel)
	var shop_layout := VBoxContainer.new()
	_merchant_shop_panel.add_child(shop_layout)
	var shop_heading := Label.new()
	shop_heading.text = "TRAVELLING MERCHANT"
	shop_heading.add_theme_font_size_override("font_size", 18)
	shop_layout.add_child(shop_heading)
	_merchant_status = Label.new()
	_merchant_status.text = "Come close to the merchant to trade."
	_merchant_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	shop_layout.add_child(_merchant_status)
	_add_shop_button(shop_layout, "BUY HEALING POTION — 8 COINS", _buy_from_merchant.bind("healing_potion", 1, 8))
	_add_shop_button(shop_layout, "BUY 4 TORCHES — 6 COINS", _buy_from_merchant.bind("torch", 4, 6))
	_add_shop_button(shop_layout, "BUY SILVER ORE — 12 COINS", _buy_from_merchant.bind("silver_ore", 1, 12))
	_add_shop_button(shop_layout, "BUY SPIDER FANG — 25 COINS", _buy_from_merchant.bind("spider_fang", 1, 25))
	_add_shop_button(shop_layout, "SELL 10 WOOD — 5 COINS", _sell_to_merchant.bind("wood", 10, 5))
	_add_shop_button(shop_layout, "SELL 5 COPPER ORE — 8 COINS", _sell_to_merchant.bind("ore", 5, 8))
	var summon_button := Button.new()
	summon_button.text = "SUMMON ANCIENT EYE BOSS"
	summon_button.pressed.connect(_summon_ancient_eye)
	layout.add_child(summon_button)
	var spider_summon_button := Button.new()
	spider_summon_button.text = "SUMMON SPIDER QUEEN BOSS"
	spider_summon_button.pressed.connect(_summon_spider_queen)
	layout.add_child(spider_summon_button)
	var magma_summon_button := Button.new()
	magma_summon_button.text = "SUMMON MAGMA GOLEM BOSS"
	magma_summon_button.pressed.connect(_summon_magma_golem)
	layout.add_child(magma_summon_button)
	var guardian_button := Button.new()
	guardian_button.text = "SUMMON MUSHROOM GUARDIAN"
	guardian_button.pressed.connect(_summon_mushroom_guardian)
	layout.add_child(guardian_button)
	var warden_button := Button.new()
	warden_button.text = "SUMMON DUNGEON WARDEN"
	warden_button.pressed.connect(_summon_dungeon_warden)
	layout.add_child(warden_button)
	var void_guardian_button := Button.new()
	void_guardian_button.text = "SUMMON VOID GUARDIAN (SECRET VAULT ONLY)"
	void_guardian_button.pressed.connect(_summon_void_guardian)
	layout.add_child(void_guardian_button)
	var equip_helmet_button := Button.new()
	equip_helmet_button.text = "EQUIP BEST HELMET"
	equip_helmet_button.pressed.connect(_equip_best_helmet)
	layout.add_child(equip_helmet_button)
	var equip_boots_button := Button.new()
	equip_boots_button.text = "EQUIP BEST BOOTS"
	equip_boots_button.pressed.connect(_equip_best_boots)
	layout.add_child(equip_boots_button)
	var repair_pickaxe_button := Button.new()
	repair_pickaxe_button.text = "REPAIR PICKAXE (1 REPAIR KIT)"
	repair_pickaxe_button.pressed.connect(_repair_pickaxe)
	layout.add_child(repair_pickaxe_button)
	var repair_axe_button := Button.new()
	repair_axe_button.text = "REPAIR AXE (1 REPAIR KIT)"
	repair_axe_button.pressed.connect(_repair_axe)
	layout.add_child(repair_axe_button)
	var upgrade_pickaxe_button := Button.new()
	upgrade_pickaxe_button.text = "UPGRADE PICKAXE AT ANVIL (+15% MINING SPEED)"
	upgrade_pickaxe_button.pressed.connect(_upgrade_pickaxe)
	layout.add_child(upgrade_pickaxe_button)
	var equip_armor_button := Button.new()
	equip_armor_button.tooltip_text = "Equip the strongest armor tier currently in your inventory."
	equip_armor_button.text = "EQUIP BEST AVAILABLE ARMOR"
	equip_armor_button.pressed.connect(_equip_best_armor)
	layout.add_child(equip_armor_button)
	var upgrade_weapon_button := Button.new()
	upgrade_weapon_button.text = "UPGRADE BEST WEAPON AT ANVIL"
	upgrade_weapon_button.pressed.connect(_upgrade_best_weapon)
	layout.add_child(upgrade_weapon_button)
	var upgrade_staff_button := Button.new()
	upgrade_staff_button.text = "UPGRADE VOID STAFF (+8 DAMAGE / -1 MANA)"
	upgrade_staff_button.pressed.connect(_upgrade_void_staff)
	layout.add_child(upgrade_staff_button)
	var upgrade_armor_button := Button.new()
	upgrade_armor_button.text = "UPGRADE EQUIPPED ARMOR AT ANVIL"
	upgrade_armor_button.pressed.connect(_upgrade_equipped_armor)
	layout.add_child(upgrade_armor_button)
	var remove_armor_button := Button.new()
	remove_armor_button.text = "UNEQUIP ARMOR"
	remove_armor_button.pressed.connect(_unequip_armor)
	layout.add_child(remove_armor_button)
	var torch_button := Button.new()
	torch_button.tooltip_text = "Place a warm light source in the empty tile in front of you."
	torch_button.text = "PLACE TORCH (EMPTY TILE IN FRONT)"
	torch_button.pressed.connect(_place_torch)
	layout.add_child(torch_button)
	var lantern_button := Button.new()
	lantern_button.tooltip_text = "A brighter light source than a torch. Placement persists in world saves."
	lantern_button.text = "PLACE LANTERN (BRIGHTER LIGHT)"
	lantern_button.pressed.connect(_place_lantern)
	layout.add_child(lantern_button)
	var pump_button := Button.new()
	pump_button.text = "INSTALL WATER PUMP (ON WATER)"
	pump_button.tooltip_text = "Turn a water tile into a renewable source that feeds nearby water flow."
	pump_button.pressed.connect(_install_water_pump)
	layout.add_child(pump_button)
	var drain_button := Button.new()
	drain_button.text = "DRAIN WATER (REMOVE WATER TILE)"
	drain_button.tooltip_text = "Consume one drain charge to remove a water tile and stop its source."
	drain_button.pressed.connect(_drain_water)
	layout.add_child(drain_button)
	var fill_button := Button.new()
	fill_button.text = "FILL BUCKET (WATER IN FRONT)"
	fill_button.pressed.connect(_fill_water_bucket)
	layout.add_child(fill_button)
	var pour_button := Button.new()
	pour_button.text = "POUR BUCKET (EMPTY TILE IN FRONT)"
	pour_button.pressed.connect(_pour_water_bucket)
	layout.add_child(pour_button)
	var chest_button := Button.new()
	chest_button.text = "UNLOCK NEARBY DUNGEON CHEST (1 KEY)"
	chest_button.pressed.connect(_open_nearby_chest)
	layout.add_child(chest_button)
	var secret_gate_button := Button.new()
	secret_gate_button.text = "OPEN NEARBY SECRET VAULT (1 ANCIENT KEY)"
	secret_gate_button.pressed.connect(_unlock_nearby_secret_room)
	layout.add_child(secret_gate_button)
	var secret_cache_button := Button.new()
	secret_cache_button.text = "LOOT SECRET VAULT CACHE"
	secret_cache_button.pressed.connect(_loot_nearby_secret_cache)
	layout.add_child(secret_cache_button)
	_dungeon_status_label = Label.new()
	_dungeon_status_label.text = "Craft dungeon keys to unlock the three vault chests."
	_dungeon_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_dungeon_status_label)
	var potion_button := Button.new()
	potion_button.text = "USE HEALING POTION (+35 HP)"
	potion_button.pressed.connect(_use_healing_potion)
	layout.add_child(potion_button)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.pressed.connect(_toggle_inventory)
	layout.add_child(close_button)
	_refresh_craft_buttons()

func _spawn_merchant() -> void:
	_guide = GUIDE_SCENE.instantiate() as GuideNPC
	if is_instance_valid(_guide):
		_guide.name = "ElderGuide"
		add_child(_guide)
		_guide.global_position = world.get_spawn_position(8)
	_merchant = MERCHANT_SCENE.instantiate() as Node2D
	if _merchant == null:
		return
	_merchant.name = "TravellingMerchant"
	add_child(_merchant)
	_merchant.global_position = world.get_spawn_position(16)

func _add_shop_button(parent: VBoxContainer, caption: String, callback: Callable) -> void:
	var shop_button := Button.new()
	shop_button.text = caption
	shop_button.custom_minimum_size = Vector2(290, 42)
	shop_button.pressed.connect(callback)
	parent.add_child(shop_button)

func _talk_to_guide() -> void:
	if not is_instance_valid(_guide) or player.global_position.distance_to(_guide.global_position) > _guide.interaction_radius:
		_guide_dialogue_label.text = "The Elder is near the starting camp. Move closer to speak."
		return
	var lines := PackedStringArray()
	lines.append("Welcome, traveller. This world rewards patience, preparation and courage.")
	if not bool(_quest_tracker.completed.get("gather_wood", false)):
		lines.append("Your first task: gather 10 wood. Chop trees with your axe, then return to your inventory to track progress.")
	elif not bool(_quest_tracker.completed.get("hunter", false)):
		lines.append("Good work gathering wood. Now defeat 3 enemies. Craft a sword first and watch your health.")
	elif not bool(_quest_tracker.completed.get("dungeon_delver", false)):
		lines.append("You are ready for the next trial. Explore underground and open a dungeon chest. Beware the guards and traps.")
	else:
		lines.append("You have proven yourself. Explore the desert, snowfields, glowing caverns and magma depths. Prepare before challenging their guardians.")
	lines.append("Tip: open INVENTORY to craft, trade with the merchant, and review your quest log.")
	_guide_dialogue_label.text = lines[mini(_guide_dialogue_index, lines.size() - 1)]
	_guide_dialogue_index = (_guide_dialogue_index + 1) % lines.size()

func _open_merchant_shop() -> void:
	if not is_instance_valid(_merchant) or player.global_position.distance_to(_merchant.global_position) > 260.0:
		if is_instance_valid(_merchant_status):
			_merchant_status.text = "MERCHANT TOO FAR — find the trader near the forest spawn."
		_merchant_shop_panel.visible = true
		return
	_merchant_status.text = "Coins: %d | Trade nearby with the merchant." % player.inventory.count("coins")
	_merchant_shop_panel.visible = not _merchant_shop_panel.visible

func _buy_from_merchant(item_id: String, amount: int, price: int) -> void:
	if not is_instance_valid(_merchant) or player.global_position.distance_to(_merchant.global_position) > 260.0:
		_merchant_status.text = "Move closer to the merchant."
		return
	if player.inventory.buy_item(item_id, amount, price):
		_merchant_status.text = "Purchased %d %s. Coins left: %d" % [amount, item_id.replace("_", " "), player.inventory.count("coins")]
	else:
		_merchant_status.text = "Not enough coins."
	_on_inventory_changed(player.inventory.items)

func _sell_to_merchant(item_id: String, amount: int, price: int) -> void:
	if not is_instance_valid(_merchant) or player.global_position.distance_to(_merchant.global_position) > 260.0:
		_merchant_status.text = "Move closer to the merchant."
		return
	if player.inventory.sell_item(item_id, amount, price):
		_merchant_status.text = "Sold %d %s. Coins: %d" % [amount, item_id.replace("_", " "), player.inventory.count("coins")]
	else:
		_merchant_status.text = "You do not have enough goods."
	_on_inventory_changed(player.inventory.items)

func _add_recipe_button(parent: VBoxContainer, recipe_id: String, caption: String) -> void:
	var craft_button := Button.new()
	craft_button.text = caption
	craft_button.tooltip_text = "Craft: %s. Ingredients are consumed only when all requirements and inventory space are available." % recipe_id.replace("_", " ").capitalize()
	craft_button.custom_minimum_size = Vector2(290, 44)
	craft_button.pressed.connect(_craft_recipe.bind(recipe_id))
	parent.add_child(craft_button)
	_craft_buttons[recipe_id] = craft_button

func _format_inventory(items: Dictionary) -> String:
	return "COINS %d | ANVIL %d | WPN +%d | ARMOR +%d\nDIRT %d | STONE %d\nCOPPER %d | SILVER %d | GOLD %d\nWOOD %d | PLANKS %d\nARMOR W%d / S%d / G%d / O%d (%s)\nHELMET %s | BOOTS %s | PICKAXE SPEED x%.2f\nSWORDS C%d / S%d / G%d / O%d\nTORCH %d | LANTERN %d | PUMP %d | DRAIN %d | DUNGEON KEYS %d | EYE SIGIL %d | POTIONS %d\nBUCKETS %d EMPTY / %d WATER\nPICKAXE %d (%d durability)\nAXE %d (%d durability)\nMAGMA CORE %d | MAGMA ROCK %d\nOBSIDIAN SWORD %d | ARMOR %d | HEART %d\nMUSHROOM BLADE %d | FUNGAL ARMOR %d | TOTEM %d\nDUNGEON RELIC %d | WARDEN SIGIL %d | VOID SIGIL %d\nVOID SHARD %d | VOID ARMOR %d | VOIDBREAKER %d | VOID STAFF %d (+%d)" % [
		int(items.get("coins", 0)), int(items.get("anvil", 0)), player.inventory.get_weapon_upgrade_level(player.inventory.get_best_weapon_id()), player.inventory.get_armor_upgrade_level(player.inventory.equipped_armor),
		int(items.get("dirt", 0)), int(items.get("stone", 0)),
		int(items.get("ore", 0)), int(items.get("silver_ore", 0)), int(items.get("gold_ore", 0)),
		int(items.get("wood", 0)), int(items.get("wooden_planks", 0)),
		int(items.get("wooden_armor", 0)), int(items.get("silver_armor", 0)), int(items.get("gold_armor", 0)), int(items.get("obsidian_armor", 0)), player.inventory.equipped_armor.to_upper() if not player.inventory.equipped_armor.is_empty() else "NONE", player.inventory.equipped_helmet.to_upper() if not player.inventory.equipped_helmet.is_empty() else "NONE", player.inventory.equipped_boots.to_upper() if not player.inventory.equipped_boots.is_empty() else "NONE", player.inventory.get_mining_speed_multiplier(),
		int(items.get("copper_sword", 0)), int(items.get("silver_sword", 0)), int(items.get("gold_sword", 0)), int(items.get("obsidian_sword", 0)),
		int(items.get("torch", 0)), int(items.get("lantern", 0)), int(items.get("water_pump", 0)), int(items.get("drain_charge", 0)), int(items.get("dungeon_key", 0)), int(items.get("eye_summon", 0)), int(items.get("healing_potion", 0)),
		int(items.get("empty_bucket", 0)), int(items.get("water_bucket", 0)),
		int(items.get("wooden_pickaxe", 0)), player.inventory.get_tool_durability("wooden_pickaxe"),
		int(items.get("wooden_axe", 0)), player.inventory.get_tool_durability("wooden_axe"),
		int(items.get("magma_core", 0)), int(items.get("magma_rock", 0)),
		int(items.get("obsidian_sword", 0)), int(items.get("obsidian_armor", 0)), int(items.get("magma_heart", 0)),
		int(items.get("mushroom_blade", 0)), int(items.get("fungal_armor", 0)), int(items.get("guardian_totem", 0)),
		int(items.get("dungeon_relic", 0)), int(items.get("dungeon_warden_sigil", 0)), int(items.get("void_guardian_sigil", 0)), int(items.get("void_shard", 0)), int(items.get("void_armor", 0)), int(items.get("voidbreaker", 0)), int(items.get("void_staff", 0)), player.inventory.get_weapon_upgrade_level("void_staff")
	]

func _refresh_craft_buttons() -> void:
	for recipe_id in _craft_buttons:
		var craft_button := _craft_buttons[recipe_id] as Button
		var recipe_key := str(recipe_id)
		var block_reason := player.inventory.get_crafting_block_reason(recipe_key)
		craft_button.disabled = not block_reason.is_empty() or not player.inventory.can_craft(recipe_key)
		if not block_reason.is_empty():
			craft_button.tooltip_text = "Locked: %s" % block_reason
		elif not player.inventory.can_craft(recipe_key):
			craft_button.tooltip_text = "Missing ingredients or inventory space for %s." % recipe_key.replace("_", " ").capitalize()
		else:
			craft_button.tooltip_text = "Ready to craft: %s." % recipe_key.replace("_", " ").capitalize()

func _get_water_target_cell() -> Vector2i:
	var target := player.global_position + Vector2(player.get_facing() * WorldGenerator.TILE_SIZE * 1.35, WorldGenerator.TILE_SIZE * 0.5)
	var local_target := world.to_local(target)
	return Vector2i(floori(local_target.x / WorldGenerator.TILE_SIZE), floori(local_target.y / WorldGenerator.TILE_SIZE))

func _equip_best_helmet() -> void:
	for item_id in ["gold_helmet", "silver_helmet", "wooden_helmet"]:
		if player.inventory.count(item_id) > 0:
			player.inventory.equip_helmet(item_id)
			return
	player.inventory.equip_helmet("")

func _equip_best_boots() -> void:
	for item_id in ["gold_boots", "silver_boots", "wooden_boots"]:
		if player.inventory.count(item_id) > 0:
			player.inventory.equip_boots(item_id)
			return
	player.inventory.equip_boots("")

func _repair_pickaxe() -> void:
	player.inventory.repair_tool("wooden_pickaxe")

func _repair_axe() -> void:
	player.inventory.repair_tool("wooden_axe")

func _upgrade_pickaxe() -> void:
	if player.inventory.upgrade_pickaxe():
		_on_inventory_changed(player.inventory.items)

func _equip_best_armor() -> void:
	var inventory := player.inventory
	if inventory.count("void_armor") > 0:
		inventory.equip_armor("void_armor")
	elif inventory.count("obsidian_armor") > 0:
		inventory.equip_armor("obsidian_armor")
	elif inventory.count("fungal_armor") > 0:
		inventory.equip_armor("fungal_armor")
	elif inventory.count("gold_armor") > 0:
		inventory.equip_armor("gold_armor")
	elif inventory.count("silver_armor") > 0:
		inventory.equip_armor("silver_armor")
	else:
		inventory.equip_armor("wooden_armor")
	_on_inventory_changed(inventory.items)

func _upgrade_best_weapon() -> void:
	if player.inventory.upgrade_best_weapon():
		_on_inventory_changed(player.inventory.items)

func _upgrade_void_staff() -> void:
	if player.inventory.upgrade_void_staff():
		_on_inventory_changed(player.inventory.items)

func _upgrade_equipped_armor() -> void:
	if player.inventory.upgrade_equipped_armor():
		_on_inventory_changed(player.inventory.items)

func _unequip_armor() -> void:
	player.inventory.equip_armor("")
	_on_inventory_changed(player.inventory.items)

func _place_torch() -> void:
	if world.place_torch(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _place_lantern() -> void:
	if world.place_lantern(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _install_water_pump() -> void:
	if world.install_water_pump(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _drain_water() -> void:
	if world.drain_water(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _fill_water_bucket() -> void:
	if world.fill_bucket(_get_water_target_cell(), player.inventory):
		_on_inventory_changed(player.inventory.items)

func _pour_water_bucket() -> void:
	if world.pour_bucket(_get_water_target_cell(), player.inventory, player.global_position):
		_on_inventory_changed(player.inventory.items)

func _open_nearby_chest() -> void:
	if world.open_nearby_chest(player.global_position, player.inventory):
		_dungeon_status_label.text = "VAULT UNLOCKED! Loot added to your inventory."
		_quest_tracker.record_chest_opened()
		_on_inventory_changed(player.inventory.items)
	else:
		_dungeon_status_label.text = "No unopened chest nearby, or you need a DUNGEON KEY. Craft 3 keys from silver, gold and spider fangs."

func _unlock_nearby_secret_room() -> void:
	if world.unlock_nearby_secret_room(player.global_position, player.inventory):
		_dungeon_status_label.text = "ANCIENT SEAL BROKEN! The hidden chamber is open."
		_on_inventory_changed(player.inventory.items)
	else:
		_dungeon_status_label.text = "No sealed secret vault nearby, or you need an ANCIENT KEY."

func _loot_nearby_secret_cache() -> void:
	if world.open_nearby_secret_cache(player.global_position, player.inventory):
		_dungeon_status_label.text = "SECRET CACHE CLAIMED! Relic, gold, silver and potions added."
		_on_inventory_changed(player.inventory.items)
	else:
		_dungeon_status_label.text = "Open a nearby secret vault first, then stand beside its cache."

func _use_healing_potion() -> void:
	if player.inventory.remove_item("healing_potion", 1):
		player.heal(35)
		_on_inventory_changed(player.inventory.items)

func _craft_recipe(recipe_id: String) -> void:
	if player.inventory.craft(recipe_id):
		if recipe_id == "double_jump_charm":
			player.double_jump_unlocked = true
		_on_inventory_changed(player.inventory.items)

func _toggle_inventory() -> void:
	if is_instance_valid(_inventory_panel):
		_inventory_panel.visible = not _inventory_panel.visible

func _on_selected_block_changed(_block_type: int) -> void:
	_on_inventory_changed(player.inventory.items)
