extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mobile_script := load("res://scripts/ui/mobile_controls.gd") as Script
	assert(mobile_script != null, "Mobile controls script loads")
	var mobile_controls := Control.new()
	mobile_controls.set_script(mobile_script)
	mobile_controls.size = Vector2(1280, 720)
	root.add_child(mobile_controls)
	await process_frame
	var mobile_centers: Dictionary = mobile_controls.call("_button_centers")
	assert(mobile_centers.has("inventory"), "Mobile controls expose a dedicated inventory button")
	assert(mobile_centers.has("magic"), "Mobile controls expose a dedicated Void magic button")
	assert(mobile_centers.magic.distance_to(mobile_centers.attack) > 90.0, "Void button stays clear of the melee attack button")
	mobile_controls.call("_handle_touch", 78, mobile_centers.magic, true)
	assert(Input.is_action_pressed("magic"), "Touching Void button presses magic action")
	mobile_controls.call("_handle_touch", 78, mobile_centers.magic, false)
	assert(not Input.is_action_pressed("magic"), "Releasing Void button releases magic action")
	assert(mobile_centers.inventory.distance_to(mobile_centers.jump) > 100.0, "Inventory button does not overlap jump control")
	mobile_controls.call("_handle_touch", 77, mobile_centers.inventory, true)
	assert(Input.is_action_pressed("inventory_toggle"), "Touching inventory button presses inventory action")
	mobile_controls.call("_handle_touch", 77, mobile_centers.inventory, false)
	assert(not Input.is_action_pressed("inventory_toggle"), "Releasing inventory button releases inventory action")
	mobile_controls.queue_free()

	var player_visual_scene := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_visual_scene != null, "Pixel-art player scene loads")
	var player_visual_instance := player_visual_scene.instantiate() as PlayerController
	assert(player_visual_instance != null and player_visual_instance.get_node("BodyVisual") is AnimatedSprite2D, "Player uses an animated pixel-art sprite")
	assert((player_visual_instance.get_node("BodyVisual") as AnimatedSprite2D).sprite_frames.has_animation("walk"), "Player sprite has a walk animation")
	player_visual_instance.queue_free()

	var world_packed := load("res://scenes/world/world.tscn") as PackedScene
	assert(world_packed != null, "World scene must load")
	var world := world_packed.instantiate() as WorldGenerator
	assert(world != null, "World generator must instantiate")
	root.add_child(world)
	await process_frame
	assert(world.tiles.size() == WorldGenerator.WORLD_WIDTH, "World has expected width")
	var visible_bounds: Rect2i = world._get_visible_tile_bounds()
	assert(visible_bounds.size.x <= WorldGenerator.WORLD_WIDTH and visible_bounds.size.y <= WorldGenerator.WORLD_HEIGHT, "Terrain draw bounds are clamped to generated world dimensions")
	assert(world.get_tile(Vector2i(10, world.get_surface_y(10))) == WorldGenerator.GRASS, "Forest surface is grass")
	assert(world.get_biome_at(10) == "forest", "Western region is forest biome")
	assert(world.get_biome_at(90) == "desert", "Middle region is desert biome")
	assert(world.get_biome_at(150) == "snow", "Eastern region is snow biome")
	assert(is_equal_approx(world._smoothstep01(inverse_lerp(56.0, 64.0, 60.0)), 0.5), "Forest-to-desert transition blends terrain at its midpoint")
	assert(is_equal_approx(world._smoothstep01(inverse_lerp(116.0, 124.0, 120.0)), 0.5), "Desert-to-snow transition blends terrain at its midpoint")
	var mushroom_y := mini(world.get_surface_y(25) + 29, WorldGenerator.WORLD_HEIGHT - 7)
	assert(world.get_tile(Vector2i(20, mushroom_y + 2)) == WorldGenerator.GLOW_MUSHROOM, "World generates a glowing mushroom cavern")
	assert(world.get_tile(Vector2i(25, mushroom_y + 3)) == WorldGenerator.MUSHROOM_SOIL, "Mushroom cavern has fungal ground")
	var magma_y := mini(world.get_surface_y(82) + 30, WorldGenerator.WORLD_HEIGHT - 8)
	assert(world.get_tile(Vector2i(82, magma_y + 1)) == WorldGenerator.LAVA, "World generates a deep lava pool")
	assert(world.get_tile(Vector2i(82, magma_y + 3)) == WorldGenerator.MAGMA_ROCK, "Lava pool has a magma-rock floor")
	assert(not world._is_solid_tile(WorldGenerator.LAVA), "Lava remains traversable as a hazard volume")
	assert(not world._is_solid_tile(WorldGenerator.GLOW_MUSHROOM), "Glow mushrooms do not block movement")
	var lava_world_position := world.to_global(Vector2((82.5) * WorldGenerator.TILE_SIZE, (magma_y + 1.5) * WorldGenerator.TILE_SIZE))
	assert(world.is_position_in_lava(lava_world_position), "World detects the lava hazard volume")
	var pillar_room_y := mini(world.get_surface_y(42) + 19, WorldGenerator.WORLD_HEIGHT - 9)
	var gallery_room_y := mini(world.get_surface_y(102) + 19, WorldGenerator.WORLD_HEIGHT - 9)
	var flooded_room_y := mini(world.get_surface_y(160) + 19, WorldGenerator.WORLD_HEIGHT - 9)
	assert(world.get_tile(Vector2i(37, pillar_room_y - 1)) == WorldGenerator.STONE, "Pillar Hall has its own column layout")
	assert(world.get_tile(Vector2i(96, gallery_room_y - 1)) == WorldGenerator.STONE, "High Gallery has raised side platforms")
	assert(world.get_tile(Vector2i(158, flooded_room_y + 3)) == WorldGenerator.WATER, "Flooded Vault has a shallow water trench")
	var dungeon_positions := world.get_dungeon_guard_positions()
	assert(dungeon_positions.size() == 6, "Three dungeons provide six guard spawn positions")
	var skeleton_scene := load("res://scenes/enemies/dungeon_skeleton.tscn") as PackedScene
	var spider_scene := load("res://scenes/enemies/cave_spider.tscn") as PackedScene
	assert(skeleton_scene != null and spider_scene != null, "Dungeon enemy scenes load")
	var dungeon_skeleton := skeleton_scene.instantiate() as SlimeEnemy
	var cave_spider := spider_scene.instantiate() as SlimeEnemy
	assert(dungeon_skeleton != null and cave_spider != null, "Dungeon enemies instantiate")
	root.add_child(dungeon_skeleton)
	root.add_child(cave_spider)
	await process_frame
	assert(dungeon_skeleton.max_health == 150 and dungeon_skeleton.attack_damage == 20, "Dungeon skeleton has elite guard stats")
	assert(cave_spider.max_health == 85 and cave_spider.move_speed == 112.0, "Cave spider has fast ambush stats")
	dungeon_skeleton.queue_free()
	cave_spider.queue_free()

	var spike_scene := load("res://scenes/world/spike_trap.tscn") as PackedScene
	var blade_scene := load("res://scenes/world/swinging_blade.tscn") as PackedScene
	var queen_scene := load("res://scenes/enemies/spider_queen_boss.tscn") as PackedScene
	var spider_minion_scene := load("res://scenes/enemies/cave_spider.tscn") as PackedScene
	assert(spike_scene != null and blade_scene != null and queen_scene != null and spider_minion_scene != null, "Dungeon hazard, Spider Queen and spider minion scenes load")
	assert(world.get_dungeon_spike_positions().size() == 6, "Each dungeon has two spike traps")
	assert(world.get_dungeon_blade_positions().size() == 3, "Each dungeon has one swinging blade")
	var queen := queen_scene.instantiate() as SpiderQueenBoss
	assert(queen != null, "Spider Queen boss instantiates")
	root.add_child(queen)
	await process_frame
	assert(queen.max_health == 1400 and queen.attack_damage == 24, "Spider Queen starts with boss stats")
	queen.take_damage(700)
	assert(queen.current_phase == 2 and queen.attack_damage == 34, "Spider Queen enters enraged second phase at half health")
	queen.queue_free()

	var golem_scene := load("res://scenes/enemies/magma_golem_boss.tscn") as PackedScene
	assert(golem_scene != null, "Magma Golem boss scene loads")
	var golem := golem_scene.instantiate() as MagmaGolemBoss
	assert(golem != null, "Magma Golem boss instantiates")
	root.add_child(golem)
	await process_frame
	assert(golem.max_health == 2200 and golem.attack_damage == 30, "Magma Golem starts with its heavy boss stats")
	golem.take_damage(1100)
	assert(golem.current_phase == 2 and golem.attack_damage == 42, "Magma Golem enters its enraged second phase")
	golem.queue_free()

	var guardian_scene := load("res://scenes/enemies/mushroom_guardian_boss.tscn") as PackedScene
	var spore_scene := load("res://scenes/enemies/spore_projectile.tscn") as PackedScene
	assert(guardian_scene != null and spore_scene != null, "Mushroom Guardian and spore projectile scenes load")
	var guardian := guardian_scene.instantiate() as MushroomGuardianBoss
	assert(guardian != null, "Mushroom Guardian boss instantiates")
	root.add_child(guardian)
	await process_frame
	assert(guardian.max_health == 1750 and guardian.attack_damage == 22, "Mushroom Guardian starts with boss stats")
	guardian.take_damage(875)
	assert(guardian.current_phase == 2 and guardian.attack_damage == 34, "Mushroom Guardian enters phase two at half health")
	guardian.queue_free()
	var spore := spore_scene.instantiate() as SporeProjectile
	assert(spore != null and spore.impact_damage == 9, "Spore projectile has poison impact")
	spore.queue_free()

	var web_scene := load("res://scenes/enemies/spider_web_projectile.tscn") as PackedScene
	assert(web_scene != null, "Spider Queen web projectile scene loads")
	var web_projectile := web_scene.instantiate() as SpiderWebProjectile
	assert(web_projectile != null and web_projectile.impact_damage == 12, "Web projectile has impact damage")
	web_projectile.queue_free()
	var legendary_inventory := PlayerInventory.new()
	root.add_child(legendary_inventory)
	await process_frame
	legendary_inventory.add_item("gold_sword", 1)
	legendary_inventory.add_item("queens_fang", 1)
	assert(legendary_inventory.get_best_weapon_id() == "queens_fang", "Queen Fang outranks gold sword")
	legendary_inventory.add_item("anvil", 1)
	legendary_inventory.add_item("spider_fang", 5)
	assert(legendary_inventory.upgrade_best_weapon(), "Queen Fang can be upgraded at anvil")
	assert(legendary_inventory.get_weapon_upgrade_level("queens_fang") == 1, "Queen Fang upgrade level is stored")
	var queen_fang_snapshot := legendary_inventory.serialize()
	var restored_queen_fang := PlayerInventory.new()
	root.add_child(restored_queen_fang)
	await process_frame
	assert(restored_queen_fang.restore(queen_fang_snapshot), "Queen Fang inventory restores")
	assert(restored_queen_fang.get_weapon_upgrade_level("queens_fang") == 1, "Queen Fang upgrade level persists")
	restored_queen_fang.queue_free()
	legendary_inventory.queue_free()

	var fungal_inventory := PlayerInventory.new()
	root.add_child(fungal_inventory)
	await process_frame
	fungal_inventory.add_item("glow_mushroom", 80)
	fungal_inventory.add_item("mushroom_soil", 60)
	fungal_inventory.add_item("silver_ore", 80)
	fungal_inventory.add_item("magma_core", 20)
	fungal_inventory.add_item("wooden_planks", 20)
	fungal_inventory.add_item("stone", 40)
	fungal_inventory.add_item("ore", 20)
	assert(fungal_inventory.craft("anvil"), "Fungal equipment progression can craft an anvil")
	assert(fungal_inventory.craft("guardian_totem"), "Guardian summon totem crafts")
	assert(fungal_inventory.craft("mushroom_blade"), "Mushroom blade crafts")
	assert(fungal_inventory.craft("fungal_armor"), "Fungal armor crafts")
	assert(fungal_inventory.get_best_weapon_id() == "mushroom_blade", "Mushroom blade has highest weapon priority")
	assert(fungal_inventory.equip_armor("fungal_armor") and fungal_inventory.get_armor_defense() == 22, "Fungal armor equips with twenty-two defense")
	assert(fungal_inventory.upgrade_best_weapon() and fungal_inventory.upgrade_equipped_armor(), "Fungal gear upgrades at anvil")
	var fungal_save := fungal_inventory.serialize()
	var fungal_restored := PlayerInventory.new()
	root.add_child(fungal_restored)
	await process_frame
	assert(fungal_restored.restore(fungal_save), "Fungal equipment saves and restores")
	assert(fungal_restored.get_weapon_upgrade_level("mushroom_blade") == 1 and fungal_restored.get_armor_upgrade_level("fungal_armor") == 1, "Fungal gear upgrade levels persist")
	fungal_inventory.queue_free()
	fungal_restored.queue_free()

	var silver_nodes := 0
	var gold_nodes := 0
	for x in range(WorldGenerator.WORLD_WIDTH):
		for y in range(world.get_surface_y(x) + 1, WorldGenerator.WORLD_HEIGHT):
			if world.get_tile(Vector2i(x, y)) == WorldGenerator.SILVER_ORE:
				silver_nodes += 1
			elif world.get_tile(Vector2i(x, y)) == WorldGenerator.GOLD_ORE:
				gold_nodes += 1
	assert(silver_nodes > 0 and gold_nodes > 0, "World generation includes silver and gold deposits")
	assert(world.get_tile(Vector2i(90, world.get_surface_y(90))) == WorldGenerator.SAND, "Desert surface uses sand")
	assert(world.get_tile(Vector2i(150, world.get_surface_y(150))) == WorldGenerator.SNOW, "Snow biome surface uses snow")
	assert(world.get_dungeon_chest_count() == 3, "World generates one dungeon chest in each biome")
	var first_arena := world.get_nearest_dungeon_arena_position(world.get_spawn_position(10))
	assert(is_equal_approx(first_arena.x, 42.5 * WorldGenerator.TILE_SIZE), "Dungeon arena locator targets the center of the nearest forest vault")
	assert(first_arena.y > world.get_spawn_position(10).y, "Dungeon arena is positioned underground at the chamber floor")
	var first_chest: Dictionary = world._dungeon_chests[0]
	var first_chest_cell: Vector2i = first_chest["cell"]
	var chest_position := world.to_global(Vector2((first_chest_cell.x + 0.5) * WorldGenerator.TILE_SIZE, (first_chest_cell.y + 0.5) * WorldGenerator.TILE_SIZE))
	var chest_inventory := PlayerInventory.new()
	root.add_child(chest_inventory)
	await process_frame
	assert(not world.open_nearby_chest(chest_position, chest_inventory), "Dungeon chest stays locked without a key")
	assert(chest_inventory.count("dungeon_key") == 0, "Locked chest does not create a key")
	chest_inventory.add_item("silver_ore", 6)
	chest_inventory.add_item("gold_ore", 3)
	chest_inventory.add_item("spider_fang", 2)
	assert(chest_inventory.craft("dungeon_key"), "Dungeon keys craft from silver, gold and spider fangs")
	assert(chest_inventory.count("dungeon_key") == 3, "One key recipe creates three dungeon keys")
	assert(world.open_nearby_chest(chest_position, chest_inventory), "Nearby dungeon chest opens with a key")
	assert(chest_inventory.count("dungeon_key") == 2, "Opening a vault consumes exactly one key")
	assert(chest_inventory.count("silver_ore") == 4, "First vault grants silver ore in addition to base loot")
	assert(chest_inventory.count("ore") == WorldGenerator.CHEST_REWARD_ORE, "Dungeon chest grants ore")
	assert(chest_inventory.count("torch") == 3 and chest_inventory.count("healing_potion") == 2, "Dungeon chest grants torches and healing potions")
	assert(not world.open_nearby_chest(chest_position, chest_inventory), "Opened chest cannot be looted twice")
	var chest_save := world.get_save_data()
	var chest_world_copy := world_packed.instantiate() as WorldGenerator
	root.add_child(chest_world_copy)
	await process_frame
	assert(chest_world_copy.load_save_data(chest_save), "World save restores dungeon chest states")
	assert(chest_world_copy._dungeon_chests.size() == 3 and bool(chest_world_copy._dungeon_chests[0].get("opened", false)), "Opened chest state persists")
	chest_world_copy.queue_free()
	assert(world.get_dungeon_secret_room_count() == 3, "Every dungeon has one concealed side vault")
	var secret_gate_position := world.get_secret_gate_position(0)
	var secret_cache_position := world.get_secret_cache_position(0)
	assert(not world.is_secret_vault_open_nearby(secret_cache_position), "Void Guardian cannot be summoned while the secret vault is sealed")
	assert(not world.unlock_nearby_secret_room(secret_gate_position, chest_inventory), "Secret vault stays sealed without an ancient key")
	chest_inventory.add_item("dungeon_relic", 1)
	chest_inventory.add_item("gold_ore", 8)
	chest_inventory.add_item("spider_fang", 4)
	assert(chest_inventory.craft("ancient_key"), "Ancient keys craft from a relic, gold and spider fangs")
	assert(chest_inventory.count("ancient_key") == 2, "Ancient key recipe creates two keys")
	assert(world.unlock_nearby_secret_room(secret_gate_position, chest_inventory), "Ancient key opens the nearby hidden vault gate")
	assert(world.is_secret_vault_open_nearby(secret_cache_position), "Opened secret vault enables its boss encounter")
	assert(chest_inventory.count("ancient_key") == 1, "Opening a secret gate consumes one ancient key")
	assert(world.open_nearby_secret_cache(secret_cache_position, chest_inventory), "Player can loot the cache inside the opened secret room")
	assert(chest_inventory.count("dungeon_relic") == 1 and chest_inventory.count("gold_ore") >= 12, "Secret cache grants rare relic and gold rewards")
	assert(not world.open_nearby_secret_cache(secret_cache_position, chest_inventory), "Secret cache cannot be looted twice")
	var secret_save := world.get_save_data()
	var secret_world_copy := world_packed.instantiate() as WorldGenerator
	root.add_child(secret_world_copy)
	await process_frame
	assert(secret_world_copy.load_save_data(secret_save), "Secret vault state restores from world save")
	assert(secret_world_copy.get_tile(Vector2i(int(secret_gate_position.x / WorldGenerator.TILE_SIZE), int(secret_gate_position.y / WorldGenerator.TILE_SIZE))) == WorldGenerator.AIR, "Opened secret gate remains open after loading")
	assert(not secret_world_copy.open_nearby_secret_cache(secret_world_copy.get_secret_cache_position(0), chest_inventory), "Claimed secret cache stays empty after loading")
	secret_world_copy.queue_free()
	chest_inventory.queue_free()
	var water_cell := Vector2i(-1, -1)
	var water_count := 0
	for water_x in range(WorldGenerator.WORLD_WIDTH):
		for water_y in range(WorldGenerator.WORLD_HEIGHT):
			if world.get_tile(Vector2i(water_x, water_y)) == WorldGenerator.WATER:
				water_count += 1
				if water_cell.x < 0:
					water_cell = Vector2i(water_x, water_y)
	assert(water_count >= 15, "Seeded world generates three guaranteed shallow lakes")
	assert(water_cell.x >= 0, "A water tile is available for swimming tests")
	assert(not world._is_solid_tile(WorldGenerator.WATER), "Water does not block movement")
	assert(not world.mine_cell(water_cell), "Water cannot be mined as a solid block")
	assert(world._water_sources.size() > 0, "Lakes have renewable water sources")
	var pump_inventory := PlayerInventory.new()
	root.add_child(pump_inventory)
	await process_frame
	pump_inventory.add_item("water_pump", 1)
	var pump_cell: Vector2i = world._water_sources.keys()[0]
	assert(world.install_water_pump(pump_cell, pump_inventory), "Water pump can reinforce a generated renewable source")
	assert(world.is_water_source(pump_cell), "Installed pump keeps the water tile renewable")
	var drain_cell := Vector2i(pump_cell.x + 1, pump_cell.y)
	if world.get_tile(drain_cell) != WorldGenerator.WATER:
		drain_cell = Vector2i(pump_cell.x - 1, pump_cell.y)
	assert(world.get_tile(drain_cell) == WorldGenerator.WATER, "A nearby lake tile is available for drainage")
	pump_inventory.add_item("drain_charge", 1)
	assert(world.drain_water(drain_cell, pump_inventory), "Drain charge removes a water tile")
	assert(world.get_tile(drain_cell) == WorldGenerator.AIR and not world.is_water_source(drain_cell), "Drained water tile becomes empty and non-renewable")
	pump_inventory.queue_free()
	var water_sample_world := world.to_global(Vector2(water_cell.x * WorldGenerator.TILE_SIZE + 16.0, water_cell.y * WorldGenerator.TILE_SIZE + 16.0))
	assert(world.is_position_in_water(water_sample_world), "Water detection samples the actual tile position")
	var flow_test_source := Vector2i(WorldGenerator.WORLD_WIDTH - 2, 1)
	var flow_test_destination := flow_test_source + Vector2i(0, 1)
	world.tiles[flow_test_source.x][flow_test_source.y] = WorldGenerator.WATER
	assert(world._simulate_water_step() > 0, "Water simulation processes active water")
	assert(world.get_tile(flow_test_source) == WorldGenerator.AIR, "Falling water leaves its previous tile")
	assert(world.get_tile(flow_test_destination) == WorldGenerator.WATER, "Water flows down into an empty tile")
	world.tiles[flow_test_destination.x][flow_test_destination.y] = WorldGenerator.AIR
	var source_test_cell := Vector2i(170, 2)
	world.tiles[source_test_cell.x][source_test_cell.y] = WorldGenerator.WATER
	assert(world.set_water_source(source_test_cell), "A water tile can be marked as a renewable source")
	var source_below := source_test_cell + Vector2i(0, 1)
	assert(world._simulate_water_step() > 0, "Renewable water source produces flowing water")
	assert(world.get_tile(source_test_cell) == WorldGenerator.WATER, "Renewable source remains in place after flowing")
	assert(world.get_tile(source_below) == WorldGenerator.WATER, "Renewable source fills the tile below")
	world.tiles[source_test_cell.x][source_test_cell.y] = WorldGenerator.AIR
	world.tiles[source_below.x][source_below.y] = WorldGenerator.AIR
	world._water_sources.erase(source_test_cell)
	var sand_build_cell := Vector2i(90, world.get_surface_y(90) - 1)
	assert(world.place_block(sand_build_cell, WorldGenerator.SAND), "Sand blocks can be placed")
	assert(world.get_tile(sand_build_cell) == WorldGenerator.SAND, "Placed sand keeps its material")
	var snow_build_cell := Vector2i(150, world.get_surface_y(150) - 1)
	assert(world.place_block(snow_build_cell, WorldGenerator.SNOW), "Snow blocks can be placed")
	assert(world.get_tile(snow_build_cell) == WorldGenerator.SNOW, "Placed snow keeps its material")
	var cave_air_count := 0
	var ore_count := 0
	for scan_x in range(WorldGenerator.WORLD_WIDTH):
		for scan_y in range(world.get_surface_y(scan_x) + 8, WorldGenerator.WORLD_HEIGHT - 4):
			var scanned_tile := world.get_tile(Vector2i(scan_x, scan_y))
			if scanned_tile == WorldGenerator.AIR:
				cave_air_count += 1
			elif scanned_tile == WorldGenerator.ORE:
				ore_count += 1
	assert(cave_air_count > 0, "Seeded world generates underground cave spaces")
	assert(ore_count > 0, "Underground world contains ore deposits")
	var test_cell := Vector2i(10, world.get_surface_y(10))
	assert(world.mine_cell(test_cell), "Mining a solid block succeeds")
	assert(world.get_tile(test_cell) == WorldGenerator.AIR, "Mined cell becomes air")
	assert(world.place_block(test_cell), "Placing a block into an empty cell succeeds")
	assert(world.get_tile(test_cell) == WorldGenerator.DIRT, "Placed block becomes dirt")
	assert(not world.place_block(test_cell), "Cannot place a block into an occupied cell")
	var world_snapshot := world.get_save_data()
	assert(world.mine_cell(test_cell), "A saved test block can be mined")
	assert(world.load_save_data(world_snapshot), "World snapshot restores successfully")
	assert(world.get_tile(test_cell) == WorldGenerator.DIRT, "World restore reinstates the saved block")
	assert(world.get_tile(sand_build_cell) == WorldGenerator.SAND, "World save preserves placed sand")
	assert(world.get_tile(snow_build_cell) == WorldGenerator.SNOW, "World save preserves placed snow")
	assert(world.get_tile(water_cell) == WorldGenerator.WATER, "World save preserves lake water")
	assert(world._water_sources.size() > 0, "World save preserves renewable lake source positions")
	assert(world.selected_block_type == WorldGenerator.DIRT, "World restore preserves selected block")
	world.cycle_block_selection()
	assert(world.selected_block_type == WorldGenerator.STONE, "Block selection cycles to stone")
	world.cycle_block_selection()
	assert(world.selected_block_type == WorldGenerator.SAND, "Block selection cycles to sand")
	world.cycle_block_selection()
	assert(world.selected_block_type == WorldGenerator.SNOW, "Block selection cycles to snow")
	world.cycle_block_selection()
	assert(world.selected_block_type == WorldGenerator.DIRT, "Block selection cycles back to dirt")
	var invalid_snapshot := world_snapshot.duplicate(true)
	invalid_snapshot["width"] = 1
	assert(not world.load_save_data(invalid_snapshot), "World restore rejects incompatible dimensions")

	var player_packed := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_packed != null, "Player scene must load")
	var player := player_packed.instantiate() as PlayerController
	assert(player != null, "Player scene must instantiate")
	root.add_child(player)
	await process_frame
	assert(player.health == player.max_health, "Player starts at full health")
	assert(player.inventory.count("dirt") == 20, "Player starts with twenty dirt blocks")

	var merchant_scene := load("res://scenes/npcs/merchant.tscn") as PackedScene
	assert(merchant_scene != null, "Travelling merchant scene loads")
	var merchant_node := merchant_scene.instantiate() as MerchantNPC
	assert(merchant_node != null and merchant_node.interaction_radius == 260.0, "Merchant NPC instantiates with its trade radius")
	root.add_child(merchant_node)
	await process_frame
	assert(merchant_node.get_node_or_null("NameTag") != null, "Merchant displays an identifying name tag")
	merchant_node.queue_free()

	var trader_inventory := PlayerInventory.new()
	root.add_child(trader_inventory)
	await process_frame
	trader_inventory.add_item("coins", 30)
	assert(trader_inventory.buy_item("healing_potion", 2, 8), "Merchant purchase spends coins and grants items")
	assert(trader_inventory.count("coins") == 14 and trader_inventory.count("healing_potion") == 2, "Merchant purchase updates both balances")
	assert(not trader_inventory.buy_item("silver_ore", 2, 12), "Merchant blocks purchases the player cannot afford")
	trader_inventory.add_item("wood", 10)
	assert(trader_inventory.sell_item("wood", 10, 5), "Merchant accepts sellable resources")
	assert(trader_inventory.count("coins") == 64 and trader_inventory.count("wood") == 0, "Merchant sale grants the correct coin payment")
	assert(not trader_inventory.sell_item("wood", 1, 5), "Merchant refuses sales without stock")
	var trader_snapshot := trader_inventory.serialize()
	var trader_restored := PlayerInventory.new()
	root.add_child(trader_restored)
	await process_frame
	assert(trader_restored.restore(trader_snapshot) and trader_restored.count("coins") == 64, "Merchant coin balance persists through save data")
	trader_inventory.queue_free()
	trader_restored.queue_free()
	player.inventory.add_item("wooden_planks", 12)
	assert(player.inventory.craft("wooden_armor"), "Wooden armor can be crafted")
	assert(player.inventory.equip_armor("wooden_armor"), "Crafted wooden armor can be equipped")
	assert(player.inventory.get_armor_defense() == 6, "Wooden armor provides six defense")
	var armored_health := player.health
	player.take_damage(10)
	assert(player.health == armored_health - 4, "Armor reduces incoming damage by its defense value")
	assert(player.inventory.equip_armor(""), "Armor can be unequipped")
	player.heal(10)
	player.inventory.add_item("ore", 10)
	player.inventory.add_item("wooden_planks", 2)
	assert(player.inventory.craft("copper_sword"), "Copper sword can be crafted")
	assert(player.inventory.count("copper_sword") == 1, "Crafting adds copper sword")
	player.inventory.add_item("wood", 1)
	assert(player.inventory.craft("torch"), "Torches can be crafted from wood")
	assert(player.inventory.count("torch") == 4, "Torch recipe produces four torches")
	var torch_cell := Vector2i(WorldGenerator.WORLD_WIDTH - 5, 1)
	assert(world.place_torch(torch_cell, player.inventory), "A torch can be placed in an empty world cell")
	assert(player.inventory.count("torch") == 3, "Placing a torch consumes one torch")
	var torch_snapshot := world.get_save_data()
	assert(world.load_save_data(torch_snapshot), "World restores placed torches")
	assert(world._torch_cells.has(torch_cell), "Placed torch position persists after world restore")
	player.inventory.add_item("wooden_planks", 5)
	assert(player.inventory.craft("wooden_bucket"), "Wooden bucket can be crafted")
	assert(player.inventory.count("empty_bucket") == 1, "Crafting creates an empty bucket")
	var bucket_water_cell := Vector2i(-1, -1)
	for bucket_x in range(WorldGenerator.WORLD_WIDTH):
		for bucket_y in range(WorldGenerator.WORLD_HEIGHT):
			var candidate := Vector2i(bucket_x, bucket_y)
			if world.get_tile(candidate) == WorldGenerator.WATER and candidate != water_cell:
				bucket_water_cell = candidate
				break
		if bucket_water_cell.x >= 0:
			break
	assert(bucket_water_cell.x >= 0, "A second water tile is available for bucket collection")
	assert(world.fill_bucket(bucket_water_cell, player.inventory), "Empty bucket collects one water tile")
	assert(player.inventory.count("water_bucket") == 1, "Filled bucket enters inventory")
	var poured_water_cell := Vector2i(WorldGenerator.WORLD_WIDTH - 4, 1)
	assert(world.pour_bucket(poured_water_cell, player.inventory), "Filled bucket pours water into an empty tile")
	assert(world.get_tile(poured_water_cell) == WorldGenerator.WATER, "Poured water occupies the target tile")
	assert(player.inventory.count("empty_bucket") == 1 and player.inventory.count("water_bucket") == 0, "Pouring returns an empty bucket")
	world.tiles[poured_water_cell.x][poured_water_cell.y] = WorldGenerator.AIR
	player.global_position = world.to_global(Vector2(water_cell.x * WorldGenerator.TILE_SIZE + 16.0, water_cell.y * WorldGenerator.TILE_SIZE + 16.0))
	assert(player._is_in_water(), "Player detects water around the body")
	player.is_swimming = player._is_in_water()
	assert(player.is_swimming, "Player enters swimming state in water")
	player.global_position = world.to_global(Vector2(water_cell.x * WorldGenerator.TILE_SIZE + 16.0, water_cell.y * WorldGenerator.TILE_SIZE + 46.0))
	assert(player._is_head_underwater(), "Player detects when the head is submerged")
	player.oxygen_seconds = player.max_oxygen_seconds
	player._update_oxygen(3.0)
	assert(is_equal_approx(player.oxygen_seconds, 9.0), "Oxygen drains while the head is underwater")
	player.oxygen_seconds = 0.5
	var health_before_drowning := player.health
	player._update_oxygen(2.0)
	assert(player.health == health_before_drowning - player.drowning_damage, "Drowning damages the player after oxygen runs out")
	player.global_position = world.get_spawn_position(10)
	player._update_oxygen(1.0)
	assert(player.oxygen_seconds > 0.0, "Oxygen recovers outside water")
	var tree_cell := Vector2i(-1, -1)
	for tree_x in range(WorldGenerator.WORLD_WIDTH):
		for tree_y in range(WorldGenerator.WORLD_HEIGHT):
			if world.get_tile(Vector2i(tree_x, tree_y)) == WorldGenerator.WOOD:
				tree_cell = Vector2i(tree_x, tree_y)
				break
		if tree_cell.x >= 0:
			break
	assert(tree_cell.x >= 0, "Seeded world generates at least one tree")
	assert(not world._is_solid_tile(WorldGenerator.LEAVES), "Tree leaves do not block player movement")
	assert(world.mine_cell(tree_cell), "Tree trunk can be harvested")
	assert(player.inventory.count("wood") == 1, "Harvesting a trunk adds one wood")
	assert(not player.inventory.can_craft("stone_sword"), "Crafting is blocked when ingredients are missing")
	assert(not player.inventory.craft("stone_sword"), "Failed crafting does not consume ingredients")
	player.inventory.add_item("wood", 4)
	player.inventory.add_item("stone", 8)
	assert(player.inventory.can_craft("stone_sword"), "Stone sword recipe becomes available with enough materials")
	assert(player.inventory.craft("stone_sword"), "Stone sword can be crafted")
	assert(player.inventory.count("stone_sword") == 1, "Crafting adds the output item")
	assert(player.inventory.count("wood") == 2 and player.inventory.count("stone") == 0, "Crafting consumes exactly the required ingredients")
	assert(player.inventory.craft("wooden_planks"), "Wooden planks can be crafted from two wood")
	assert(player.inventory.count("wooden_planks") == 4, "Plank recipe produces four planks")
	player.inventory.add_item("wood", 10)
	assert(player.inventory.craft("workbench"), "A workbench can be crafted from ten wood")
	assert(player.inventory.count("workbench") == 1, "Crafting adds one workbench")
	player.inventory.add_item("wooden_planks", 9)
	player.inventory.add_item("stone", 5)
	assert(player.inventory.craft("wooden_pickaxe"), "Wooden pickaxe can be crafted")
	assert(player.inventory.get_tool_durability("wooden_pickaxe") == 40, "Pickaxe starts with forty durability")
	assert(player.inventory.craft("wooden_axe"), "Wooden axe can be crafted")
	assert(player.inventory.get_tool_durability("wooden_axe") == 35, "Axe starts with thirty-five durability")
	var stone_cell := Vector2i(30, world.get_surface_y(30) + 9)
	assert(world.get_tile(stone_cell) == WorldGenerator.STONE or world.get_tile(stone_cell) == WorldGenerator.ORE, "Underground test cell contains mineable stone or ore")
	var stone_before := player.inventory.count("stone")
	assert(world.mine_cell(stone_cell), "Pickaxe can mine underground stone")
	assert(player.inventory.get_tool_durability("wooden_pickaxe") == 39, "Mining stone consumes one pickaxe durability")
	assert(player.inventory.count("stone") == stone_before + 2, "Pickaxe increases stone yield")
	var second_tree_cell := Vector2i(-1, -1)
	for tree_x2 in range(WorldGenerator.WORLD_WIDTH):
		for tree_y2 in range(WorldGenerator.WORLD_HEIGHT):
			if world.get_tile(Vector2i(tree_x2, tree_y2)) == WorldGenerator.WOOD:
				second_tree_cell = Vector2i(tree_x2, tree_y2)
				break
		if second_tree_cell.x >= 0:
			break
	assert(second_tree_cell.x >= 0, "Another tree trunk remains for axe test")
	var wood_before := player.inventory.count("wood")
	assert(world.mine_cell(second_tree_cell), "Axe can harvest a tree trunk")
	assert(player.inventory.get_tool_durability("wooden_axe") == 34, "Harvesting wood consumes one axe durability")
	assert(player.inventory.count("wood") == wood_before + 2, "Axe doubles wood yield")
	assert(player.inventory.equip_armor("wooden_armor"), "Wooden armor can be equipped again before saving")
	var equipment_snapshot := player.inventory.serialize()
	player.inventory.equip_armor("")
	assert(player.inventory.restore(equipment_snapshot), "Equipped armor restores from save data")
	assert(player.inventory.equipped_armor == "wooden_armor", "Saved armor remains equipped after restore")
	player.inventory.equip_armor("")
	var tool_snapshot := player.inventory.serialize()
	player.inventory.use_tool("wooden_pickaxe")
	assert(player.inventory.restore(tool_snapshot), "Tool durability restores from save data")
	assert(player.inventory.get_tool_durability("wooden_pickaxe") == 39, "Restored pickaxe keeps its remaining durability")
	assert(not player.inventory.can_craft("wooden_pickaxe"), "A second pickaxe cannot stack over durability state")
	player.inventory.tool_durability["wooden_axe"] = 1
	assert(player.inventory.use_tool("wooden_axe"), "A tool can consume its final durability point")
	assert(player.inventory.count("wooden_axe") == 0, "Broken axe is removed from inventory")
	assert(player.inventory.get_tool_durability("wooden_axe") == 0, "Broken axe has no remaining durability")
	var inventory_test_cell := Vector2i(12, world.get_surface_y(12))
	assert(world.mine_cell(inventory_test_cell), "Mining a block with a player succeeds")
	assert(player.inventory.count("dirt") == 21, "Mining a grass or dirt block adds a dirt drop")
	assert(world.place_block(inventory_test_cell), "Player can place a block using inventory")
	assert(player.inventory.count("dirt") == 20, "Placing a block consumes one dirt item")
	var inventory_snapshot := player.inventory.serialize()
	player.inventory.add_item("stone", 3)
	assert(player.inventory.restore(inventory_snapshot), "Inventory snapshot restores successfully")
	assert(player.inventory.count("stone") == 0, "Inventory restore removes unsaved items")
	assert(player.inventory.count("dirt") == 20, "Inventory restore preserves saved counts")
	player.take_damage(25)
	assert(player.health == 75, "Damage subtracts health")
	player.heal(10)
	assert(player.health == 85, "Healing restores health")
	player.heal(1000)
	assert(player.health == player.max_health, "Healing is capped at max health")
	player.take_damage(50)
	player.inventory.add_item("healing_potion", 1)
	assert(player.inventory.remove_item("healing_potion", 1), "Healing potion can be consumed")
	player.heal(35)
	assert(player.health == 85, "Healing potion restores thirty-five health points")
	player.restore_progress(1, 0)
	player.add_experience(100)
	assert(player.level == 2 and player.experience == 0, "One hundred XP advances the player to level two")
	assert(player.bonus_attack_damage == 2, "Every second level grants two bonus melee damage")
	player.add_experience(900)
	assert(player.level == 5 and player.max_health == 110, "Level five increases maximum health by ten")
	assert(player.experience == 0, "Exact level thresholds leave no extra XP")
	player.add_experience(100000)
	assert(player.level == 50 and player.experience_to_next_level == 0, "Progression is capped at level fifty")
	player.restore_progress(7, 125)
	assert(player.level == 7 and player.experience == 125 and player.experience_to_next_level == 700, "Player progression restores from save values")
	assert(player.bonus_attack_damage == 6 and player.max_health == 110, "Restored level reapplies permanent stat bonuses")
	player.unlock_double_jump()
	assert(player.double_jump_unlocked, "Double jump unlock flag is persistent on player instance")

	var slime_packed := load("res://scenes/enemies/slime_enemy.tscn") as PackedScene
	assert(slime_packed != null, "Slime enemy scene must load")
	var slime := slime_packed.instantiate() as SlimeEnemy
	assert(slime != null, "Slime enemy must instantiate")
	root.add_child(slime)
	await process_frame
	assert(slime.health == slime.max_health, "Slime starts at full health")
	var daytime_speed := slime.move_speed
	var daytime_damage := slime.attack_damage
	slime.set_night_mode(true)
	assert(slime.move_speed > daytime_speed and slime.attack_damage > daytime_damage, "Slime becomes stronger at night")
	slime.set_night_mode(false)
	assert(is_equal_approx(slime.move_speed, daytime_speed) and slime.attack_damage == daytime_damage, "Slime returns to daytime stats")
	slime.take_damage(20)
	assert(slime.health == 40, "Slime receives damage")
	slime.global_position = player.global_position
	await physics_frame
	assert(player.health == player.max_health - slime.attack_damage, "Slime attacks the player inside contact range")
	player.heal(slime.attack_damage)

	var bat_packed := load("res://scenes/enemies/night_bat.tscn") as PackedScene
	assert(bat_packed != null, "Night bat scene must load")
	var bat := bat_packed.instantiate() as NightBat
	assert(bat != null, "Night bat must instantiate")
	root.add_child(bat)
	await process_frame
	assert(bat.max_health == 48 and bat.attack_damage == 11, "Night bat uses its distinct night-enemy stats")
	bat.set_night_mode(true)
	assert(bat.move_speed > 108.0, "Night bat receives night-mode speed boost")
	bat.queue_free()

	var lantern_inventory := PlayerInventory.new()
	root.add_child(lantern_inventory)
	await process_frame
	lantern_inventory.add_item("wooden_planks", 6)
	lantern_inventory.add_item("ore", 3)
	assert(lantern_inventory.craft("lantern"), "Lantern recipe crafts from planks and ore")
	var lantern_cell := Vector2i(12, world.get_surface_y(12) - 2)
	assert(world.place_lantern(lantern_cell, lantern_inventory), "Lantern can be placed in an empty tile")
	assert(world._lantern_cells.has(lantern_cell), "Placed lantern is tracked by the world")
	assert(world.get_save_data().get("lanterns", []).size() == 1, "Lantern placement is included in world saves")
	lantern_inventory.queue_free()

	var zombie_packed := load("res://scenes/enemies/zombie_enemy.tscn") as PackedScene
	assert(zombie_packed != null, "Zombie enemy scene must load")
	var zombie := zombie_packed.instantiate() as ZombieEnemy
	assert(zombie != null, "Zombie enemy must instantiate")
	root.add_child(zombie)
	await process_frame
	assert(zombie.health == 100, "Zombie starts with one hundred health")
	assert(zombie.move_speed < slime.move_speed, "Zombie is slower than a slime")
	assert(zombie.attack_damage > slime.attack_damage, "Zombie deals more contact damage than a slime")
	zombie.set_night_mode(true)
	assert(zombie.move_speed > 58.0 and zombie.attack_damage > 14, "Zombie becomes stronger at night")
	zombie.queue_free()

	var skeleton_packed := load("res://scenes/enemies/skeleton_archer.tscn") as PackedScene
	assert(skeleton_packed != null, "Skeleton archer scene must load")
	var skeleton := skeleton_packed.instantiate() as SkeletonArcher
	assert(skeleton != null, "Skeleton archer must instantiate")
	root.add_child(skeleton)
	await process_frame
	assert(skeleton.health == 65, "Skeleton archer starts with sixty-five health")
	assert(skeleton.ranged_attack_range > skeleton.attack_range, "Skeleton archer has a dedicated ranged attack range")
	var projectile_count_before := root.get_child_count()
	skeleton.fire_at(player)
	assert(root.get_child_count() > projectile_count_before, "Skeleton archer creates a ranged projectile")
	assert(root.get_child(root.get_child_count() - 1) is EnemyProjectile, "Skeleton archer projectile uses the enemy projectile scene")
	skeleton.queue_free()

	player.inventory.add_item("ore", 8)
	player.inventory.add_item("stone", 12)
	player.inventory.add_item("wood", 5)
	assert(player.inventory.craft("eye_summon"), "Eye Sigil can be crafted from ore, stone and wood")
	assert(player.inventory.count("eye_summon") == 1, "Crafting creates one Eye Sigil")

	var boss_packed := load("res://scenes/enemies/ancient_eye_boss.tscn") as PackedScene
	assert(boss_packed != null, "Ancient Eye boss scene must load")
	var boss := boss_packed.instantiate() as AncientEyeBoss
	assert(boss != null, "Ancient Eye boss must instantiate")
	root.add_child(boss)
	await process_frame
	assert(boss.health == 900, "Ancient Eye starts with nine hundred health")
	assert(boss.current_phase == 1, "Ancient Eye starts in phase one")
	boss.take_damage(460)
	assert(boss.current_phase == 2, "Ancient Eye enters phase two below half health")
	assert(boss.attack_damage == 26 and boss.move_speed > 92.0, "Phase two increases boss damage and movement speed")
	boss.queue_free()

	var capacity_inventory := PlayerInventory.new()
	root.add_child(capacity_inventory)
	await process_frame
	for slot_index in range(PlayerInventory.MAX_INVENTORY_SLOTS - 1):
		capacity_inventory.add_item("test_item_%d" % slot_index, 1)
	assert(capacity_inventory.get_used_slots() == PlayerInventory.MAX_INVENTORY_SLOTS, "Inventory stops at its forty unique-item slot capacity")
	assert(not capacity_inventory.has_inventory_space("new_test_item"), "New item types are rejected when inventory is full")
	assert(capacity_inventory.has_inventory_space("test_item_0"), "Existing stacks remain usable at full capacity")
	var full_inventory_snapshot := capacity_inventory.serialize()
	var invalid_full_inventory := full_inventory_snapshot.duplicate(true)
	var invalid_items: Dictionary = invalid_full_inventory["items"]
	invalid_items["overflow_item"] = 1
	invalid_full_inventory["items"] = invalid_items
	assert(not capacity_inventory.restore(invalid_full_inventory), "Inventory restore rejects saves beyond slot capacity")
	capacity_inventory.queue_free()

	var metal_inventory := PlayerInventory.new()
	root.add_child(metal_inventory)
	await process_frame
	metal_inventory.add_item("silver_ore", 40)
	metal_inventory.add_item("gold_ore", 40)
	metal_inventory.add_item("wooden_planks", 30)
	assert(metal_inventory.craft("silver_sword"), "Silver sword recipe crafts")
	assert(metal_inventory.craft("gold_sword"), "Gold sword recipe crafts")
	assert(metal_inventory.craft("silver_armor"), "Silver armor recipe crafts")
	assert(metal_inventory.craft("gold_armor"), "Gold armor recipe crafts")
	assert(metal_inventory.equip_armor("silver_armor"), "Silver armor can be equipped")
	assert(metal_inventory.get_armor_defense() == 12, "Silver armor grants twelve defense")
	assert(metal_inventory.equip_armor("gold_armor"), "Gold armor can be equipped")
	assert(metal_inventory.get_armor_defense() == 20, "Gold armor grants twenty defense")
	var metal_snapshot := metal_inventory.serialize()
	var restored_metal_inventory := PlayerInventory.new()
	root.add_child(restored_metal_inventory)
	await process_frame
	assert(restored_metal_inventory.restore(metal_snapshot), "Silver and gold equipment restore from inventory save")
	assert(restored_metal_inventory.equipped_armor == "gold_armor", "Gold armor equipment state persists")
	assert(restored_metal_inventory.get_armor_defense() == 20, "Restored gold armor keeps its defense")
	metal_inventory.queue_free()
	restored_metal_inventory.queue_free()

	var equipment_inventory := PlayerInventory.new()
	root.add_child(equipment_inventory)
	await process_frame
	equipment_inventory.add_item("wooden_planks", 60)
	equipment_inventory.add_item("silver_ore", 30)
	equipment_inventory.add_item("gold_ore", 25)
	equipment_inventory.add_item("stone", 50)
	equipment_inventory.add_item("ore", 30)
	assert(equipment_inventory.craft("wooden_helmet") and equipment_inventory.craft("wooden_boots"), "Wooden helmet and boots can be crafted")
	assert(equipment_inventory.craft("anvil"), "Equipment progression can craft an anvil")
	assert(equipment_inventory.craft("silver_helmet") and equipment_inventory.craft("gold_boots"), "Metal helmet and boots recipes craft")
	assert(equipment_inventory.craft("wooden_armor"), "Wooden body armor can be crafted")
	assert(equipment_inventory.equip_armor("wooden_armor"), "Body armor can be equipped")
	assert(equipment_inventory.equip_helmet("silver_helmet") and equipment_inventory.equip_boots("gold_boots"), "Helmet and boots occupy separate equipment slots")
	assert(equipment_inventory.get_armor_defense() == 14, "Body armor, helmet and boots defenses are combined")
	equipment_inventory.add_item("wooden_pickaxe", 1)
	equipment_inventory.add_item("stone", 30)
	assert(equipment_inventory.upgrade_pickaxe(), "Pickaxe upgrades at an anvil")
	assert(equipment_inventory.get_mining_speed_multiplier() > 1.0, "Pickaxe upgrade increases mining speed")
	var equipment_save := equipment_inventory.serialize()
	var equipment_restored := PlayerInventory.new()
	root.add_child(equipment_restored)
	await process_frame
	assert(equipment_restored.restore(equipment_save), "Helmet, boots and pickaxe progression restore from save")
	assert(equipment_restored.equipped_helmet == "silver_helmet" and equipment_restored.equipped_boots == "gold_boots", "Equipment slots persist")
	assert(equipment_restored.get_mining_speed_multiplier() > 1.0, "Pickaxe mining speed progression persists")
	equipment_inventory.queue_free()
	equipment_restored.queue_free()

	var forge_inventory := PlayerInventory.new()
	root.add_child(forge_inventory)
	await process_frame
	forge_inventory.add_item("stone", 40)
	forge_inventory.add_item("ore", 20)
	forge_inventory.add_item("wooden_planks", 20)
	assert(forge_inventory.craft("anvil"), "Anvil recipe crafts")
	forge_inventory.add_item("gold_ore", 50)
	assert(forge_inventory.craft("gold_sword"), "Gold sword can be crafted after anvil")
	assert(forge_inventory.craft("gold_armor"), "Gold armor can be crafted after anvil")
	assert(forge_inventory.equip_armor("gold_armor"), "Gold armor equips for forge test")
	assert(forge_inventory.upgrade_best_weapon(), "Anvil upgrades best owned weapon")
	assert(forge_inventory.get_weapon_upgrade_level("gold_sword") == 1, "Weapon upgrade level increments")
	assert(forge_inventory.upgrade_equipped_armor(), "Anvil upgrades equipped armor")
	assert(forge_inventory.get_armor_upgrade_level("gold_armor") == 1, "Armor upgrade level increments")
	assert(forge_inventory.get_armor_defense() == 21, "Armor upgrade adds one defense")
	var forge_snapshot := forge_inventory.serialize()
	var restored_forge := PlayerInventory.new()
	root.add_child(restored_forge)
	await process_frame
	assert(restored_forge.restore(forge_snapshot), "Forge upgrades restore from save")
	assert(restored_forge.get_weapon_upgrade_level("gold_sword") == 1, "Weapon upgrade persists")
	assert(restored_forge.get_armor_upgrade_level("gold_armor") == 1, "Armor upgrade persists")
	forge_inventory.queue_free()
	restored_forge.queue_free()

	var alchemy_inventory := PlayerInventory.new()
	root.add_child(alchemy_inventory)
	await process_frame
	alchemy_inventory.add_item("wooden_planks", 20)
	alchemy_inventory.add_item("mushroom_soil", 20)
	alchemy_inventory.add_item("silver_ore", 10)
	alchemy_inventory.add_item("glow_mushroom", 6)
	assert(not alchemy_inventory.can_craft("healing_potion"), "Healing potions require an alchemy table")
	assert(alchemy_inventory.craft("alchemy_table"), "Alchemy table crafts from underground materials")
	assert(alchemy_inventory.craft("healing_potion"), "Alchemy table unlocks healing potion crafting")
	assert(alchemy_inventory.count("healing_potion") == 1, "Alchemy recipe creates a healing potion")
	alchemy_inventory.queue_free()

	var obsidian_inventory := PlayerInventory.new()
	root.add_child(obsidian_inventory)
	await process_frame
	obsidian_inventory.add_item("stone", 40)
	obsidian_inventory.add_item("ore", 20)
	obsidian_inventory.add_item("wooden_planks", 50)
	obsidian_inventory.add_item("gold_ore", 80)
	obsidian_inventory.add_item("magma_core", 60)
	obsidian_inventory.add_item("magma_rock", 20)
	assert(obsidian_inventory.craft("anvil"), "Obsidian progression can craft its anvil")
	assert(obsidian_inventory.craft("magma_heart"), "Magma Heart summon item crafts")
	assert(obsidian_inventory.craft("obsidian_sword"), "Obsidian sword crafts from magma cores")
	assert(obsidian_inventory.craft("obsidian_armor"), "Obsidian armor crafts from magma cores")
	assert(obsidian_inventory.get_best_weapon_id() == "obsidian_sword", "Obsidian sword is the highest weapon tier")
	assert(obsidian_inventory.equip_armor("obsidian_armor"), "Obsidian armor can be equipped")
	assert(obsidian_inventory.get_armor_defense() == 28, "Obsidian armor grants twenty-eight defense")
	assert(obsidian_inventory.upgrade_best_weapon(), "Obsidian sword upgrades with magma cores")
	assert(obsidian_inventory.upgrade_equipped_armor(), "Obsidian armor upgrades with magma cores")
	var obsidian_snapshot := obsidian_inventory.serialize()
	var restored_obsidian := PlayerInventory.new()
	root.add_child(restored_obsidian)
	await process_frame
	assert(restored_obsidian.restore(obsidian_snapshot), "Obsidian gear and upgrades restore from save")
	assert(restored_obsidian.get_weapon_upgrade_level("obsidian_sword") == 1, "Obsidian weapon upgrade persists")
	assert(restored_obsidian.get_armor_upgrade_level("obsidian_armor") == 1, "Obsidian armor upgrade persists")
	assert(restored_obsidian.get_armor_defense() == 29, "Restored obsidian armor retains upgraded defense")
	obsidian_inventory.queue_free()
	restored_obsidian.queue_free()

	var voidbreaker_inventory := PlayerInventory.new()
	root.add_child(voidbreaker_inventory)
	await process_frame
	voidbreaker_inventory.add_item("stone", 40)
	voidbreaker_inventory.add_item("ore", 20)
	voidbreaker_inventory.add_item("wooden_planks", 20)
	voidbreaker_inventory.add_item("dungeon_relic", 3)
	voidbreaker_inventory.add_item("gold_ore", 16)
	voidbreaker_inventory.add_item("magma_core", 8)
	voidbreaker_inventory.add_item("spider_fang", 12)
	assert(voidbreaker_inventory.craft("anvil"), "Voidbreaker progression can craft an anvil")
	assert(voidbreaker_inventory.craft("voidbreaker"), "Voidbreaker crafts from dungeon relics and endgame materials")
	assert(voidbreaker_inventory.get_best_weapon_id() == "voidbreaker", "Voidbreaker outranks every existing weapon")
	assert(voidbreaker_inventory.upgrade_best_weapon(), "Voidbreaker upgrades with an additional dungeon relic")
	assert(voidbreaker_inventory.get_weapon_upgrade_level("voidbreaker") == 1, "Voidbreaker upgrade level increments")
	var voidbreaker_save := voidbreaker_inventory.serialize()
	var voidbreaker_restored := PlayerInventory.new()
	root.add_child(voidbreaker_restored)
	await process_frame
	assert(voidbreaker_restored.restore(voidbreaker_save), "Voidbreaker inventory restores from save")
	assert(voidbreaker_restored.count("voidbreaker") == 1 and voidbreaker_restored.get_weapon_upgrade_level("voidbreaker") == 1, "Voidbreaker and its upgrade persist")
	voidbreaker_inventory.queue_free()
	voidbreaker_restored.queue_free()

	var dummy_packed := load("res://scenes/enemies/training_dummy.tscn") as PackedScene
	assert(dummy_packed != null, "Training dummy scene must load")
	var dummy := dummy_packed.instantiate() as TrainingDummy
	assert(dummy != null, "Training dummy must instantiate")
	root.add_child(dummy)
	await process_frame
	player._on_attack_area_body_entered(dummy)
	assert(dummy.health == 50, "Crafted copper sword increases melee damage to fifty")
	player._on_attack_area_body_entered(dummy)
	player._on_attack_area_body_entered(dummy)
	player._on_attack_area_body_entered(dummy)
	assert(dummy.health == 0, "Training dummy is defeated at zero health")

	player.respawn_delay = 0.02
	player.take_damage(player.max_health)
	assert(player.health == 0, "Lethal damage reduces player health to zero")
	await create_timer(0.06).timeout
	assert(player.health == player.max_health, "Player respawns with full health")
	assert(player.is_physics_processing(), "Player physics resumes after respawn")

	var quest_script: Script = load("res://scripts/systems/quest_tracker.gd") as Script
	assert(quest_script != null, "Quest tracker script must load")
	var quests := quest_script.new() as QuestTracker
	assert(quests != null, "Quest tracker must instantiate")
	root.add_child(quests)
	var completed_quests: Array[String] = []
	quests.quest_completed.connect(func(quest_id: String) -> void: completed_quests.append(quest_id))
	quests.sync_inventory({"wood": 6})
	assert(int(quests.progress["gather_wood"]) == 6, "Wood collection objective tracks inventory")
	quests.sync_inventory({"wood": 10})
	assert(bool(quests.completed["gather_wood"]), "Woodcutter quest completes at ten wood")
	assert(completed_quests.has("gather_wood"), "Quest completion signal fires once")
	quests.record_enemy_defeat()
	quests.record_enemy_defeat()
	quests.record_enemy_defeat()
	assert(bool(quests.completed["hunter"]), "Hunter quest completes after three enemy defeats")
	quests.record_chest_opened()
	assert(bool(quests.completed["dungeon_delver"]), "Dungeon quest completes after opening a chest")
	var quest_snapshot := quests.serialize()
	var restored_quests := quest_script.new() as QuestTracker
	root.add_child(restored_quests)
	assert(restored_quests.restore(quest_snapshot), "Quest progress restores from save data")
	assert(bool(restored_quests.completed["gather_wood"]) and bool(restored_quests.completed["hunter"]) and bool(restored_quests.completed["dungeon_delver"]), "All completed quest flags persist")
	quests.queue_free()
	restored_quests.queue_free()

	var warden_scene: PackedScene = load("res://scenes/enemies/dungeon_warden_boss.tscn") as PackedScene
	assert(warden_scene != null, "Dungeon Warden boss scene must load")
	var warden := warden_scene.instantiate() as DungeonWardenBoss
	assert(warden != null, "Dungeon Warden must instantiate")
	root.add_child(warden)
	await process_frame
	assert(warden.max_health == 2800 and warden.current_phase == 1, "Dungeon Warden starts with two thousand eight hundred health")
	warden.take_damage(1450)
	assert(warden.current_phase == 2, "Dungeon Warden enters phase two below half health")
	assert(warden.attack_damage == 52 and warden.move_speed == 126.0, "Dungeon Warden phase two increases aggression")
	var volley_count_before := root.get_child_count()
	warden.fire_vault_volley(player)
	assert(root.get_child_count() >= volley_count_before + 3, "Dungeon Warden phase-two volley fires three projectiles")
	warden.queue_free()

	var warden_inventory := PlayerInventory.new()
	root.add_child(warden_inventory)
	await process_frame
	warden_inventory.add_item("dungeon_relic", 1)
	warden_inventory.add_item("gold_ore", 20)
	warden_inventory.add_item("silver_ore", 10)
	warden_inventory.add_item("spider_fang", 6)
	assert(warden_inventory.craft("dungeon_warden_sigil"), "Dungeon Warden sigil crafts from the final vault relic")
	assert(warden_inventory.count("dungeon_warden_sigil") == 1, "Warden sigil crafting produces one summon item")
	warden_inventory.queue_free()

	var void_bolt_scene: PackedScene = load("res://scenes/projectiles/void_bolt.tscn") as PackedScene
	assert(void_bolt_scene != null, "Void Bolt projectile scene loads")
	var void_bolt := void_bolt_scene.instantiate() as VoidBoltProjectile
	assert(void_bolt != null, "Void Bolt projectile instantiates")
	void_bolt.setup(Vector2.LEFT, 120)
	assert(void_bolt.direction == Vector2.LEFT and void_bolt.impact_damage == 120, "Void Bolt accepts facing and configured damage")
	void_bolt.queue_free()

	var void_guardian_scene: PackedScene = load("res://scenes/enemies/void_guardian_boss.tscn") as PackedScene
	assert(void_guardian_scene != null, "Void Guardian boss scene must load")
	var void_guardian := void_guardian_scene.instantiate() as VoidGuardianBoss
	assert(void_guardian != null, "Void Guardian must instantiate")
	root.add_child(void_guardian)
	await process_frame
	assert(void_guardian.max_health == 1350 and void_guardian.current_phase == 1, "Void Guardian starts with thirteen hundred fifty health")
	void_guardian.take_damage(700)
	assert(void_guardian.current_phase == 2, "Void Guardian enters phase two below half health")
	assert(void_guardian.attack_damage == 44 and void_guardian.move_speed == 132.0, "Void Guardian phase two increases aggression")
	void_guardian.queue_free()

	var void_sigil_inventory := PlayerInventory.new()
	root.add_child(void_sigil_inventory)
	await process_frame
	void_sigil_inventory.add_item("dungeon_relic", 1)
	void_sigil_inventory.add_item("gold_ore", 12)
	void_sigil_inventory.add_item("magma_core", 6)
	void_sigil_inventory.add_item("spider_fang", 6)
	assert(void_sigil_inventory.craft("void_guardian_sigil"), "Void Guardian sigil crafts from vault relic and endgame materials")
	assert(void_sigil_inventory.count("void_guardian_sigil") == 1, "Void Guardian sigil recipe creates one summon item")
	assert(world.get_nearest_secret_cache_position(world.get_secret_gate_position(0)).distance_to(world.get_secret_cache_position(0)) < WorldGenerator.TILE_SIZE * 3.0, "Secret vault locator selects its own cache as boss arena")
	void_sigil_inventory.add_item("stone", 40)
	void_sigil_inventory.add_item("ore", 20)
	void_sigil_inventory.add_item("wooden_planks", 20)
	void_sigil_inventory.add_item("void_shard", 10)
	void_sigil_inventory.add_item("dungeon_relic", 3)
	void_sigil_inventory.add_item("gold_ore", 20)
	assert(void_sigil_inventory.craft("anvil"), "Void Armor progression can craft an anvil")
	assert(void_sigil_inventory.craft("void_armor"), "Void Armor crafts from Void Shards and dungeon relics")
	assert(void_sigil_inventory.equip_armor("void_armor") and void_sigil_inventory.get_armor_defense() == 38, "Void Armor equips with thirty-eight defense")
	assert(is_equal_approx(void_sigil_inventory.get_armor_damage_multiplier(), 0.85), "Void Armor reduces incoming damage by fifteen percent")
	void_sigil_inventory.add_item("void_shard", 6)
	void_sigil_inventory.add_item("dungeon_relic", 2)
	void_sigil_inventory.add_item("glow_mushroom", 12)
	assert(void_sigil_inventory.craft("void_staff"), "Void Staff crafts from endgame Void materials")
	assert(void_sigil_inventory.count("void_staff") == 1, "Void Staff is added to inventory")
	void_sigil_inventory.add_item("void_shard", 2)
	assert(void_sigil_inventory.upgrade_void_staff(), "Void Staff upgrades with Void Shards at an anvil")
	assert(void_sigil_inventory.get_weapon_upgrade_level("void_staff") == 1, "Void Staff upgrade level increments")
	assert(void_sigil_inventory.upgrade_equipped_armor(), "Void Armor upgrades using Void Shards")
	assert(void_sigil_inventory.get_armor_defense() == 39, "Void Armor upgrade adds one defense")
	var void_armor_save := void_sigil_inventory.serialize()
	var void_armor_restored := PlayerInventory.new()
	root.add_child(void_armor_restored)
	await process_frame
	assert(void_armor_restored.restore(void_armor_save), "Void Armor equipment restores from save")
	assert(void_armor_restored.equipped_armor == "void_armor" and void_armor_restored.get_armor_defense() == 39, "Void Armor and its upgraded defense persist")
	assert(void_armor_restored.get_weapon_upgrade_level("void_staff") == 1, "Void Staff upgrade level persists")
	void_armor_restored.queue_free()
	void_sigil_inventory.queue_free()

	var guide_scene: PackedScene = load("res://scenes/npcs/guide.tscn") as PackedScene
	assert(guide_scene != null, "Elder guide scene must load")
	var guide_instance := guide_scene.instantiate() as GuideNPC
	assert(guide_instance != null, "Elder guide must instantiate")
	assert(guide_instance.interaction_radius >= 200.0, "Guide interaction radius must be usable on mobile")
	guide_instance.queue_free()

	print("WORLD_PLAYER_COMBAT_RESPAWN_TEST: PASS")
	quit(0)
