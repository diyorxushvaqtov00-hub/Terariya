extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_packed := load("res://scenes/world/world.tscn") as PackedScene
	assert(world_packed != null, "World scene must load")
	var world := world_packed.instantiate() as WorldGenerator
	assert(world != null, "World generator must instantiate")
	root.add_child(world)
	await process_frame
	assert(world.tiles.size() == WorldGenerator.WORLD_WIDTH, "World has expected width")
	assert(world.get_tile(Vector2i(10, world.get_surface_y(10))) == WorldGenerator.GRASS, "Forest surface is grass")
	assert(world.get_biome_at(10) == "forest", "Western region is forest biome")
	assert(world.get_biome_at(90) == "desert", "Middle region is desert biome")
	assert(world.get_biome_at(150) == "snow", "Eastern region is snow biome")
	assert(world.get_tile(Vector2i(90, world.get_surface_y(90))) == WorldGenerator.SAND, "Desert surface uses sand")
	assert(world.get_tile(Vector2i(150, world.get_surface_y(150))) == WorldGenerator.SNOW, "Snow biome surface uses snow")
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
	player.unlock_double_jump()
	assert(player.double_jump_unlocked, "Double jump unlock flag is persistent on player instance")

	var slime_packed := load("res://scenes/enemies/slime_enemy.tscn") as PackedScene
	assert(slime_packed != null, "Slime enemy scene must load")
	var slime := slime_packed.instantiate() as SlimeEnemy
	assert(slime != null, "Slime enemy must instantiate")
	root.add_child(slime)
	await process_frame
	assert(slime.health == slime.max_health, "Slime starts at full health")
	slime.take_damage(20)
	assert(slime.health == 40, "Slime receives damage")
	slime.global_position = player.global_position
	await physics_frame
	assert(player.health == player.max_health - slime.attack_damage, "Slime attacks the player inside contact range")
	player.heal(slime.attack_damage)

	var dummy_packed := load("res://scenes/enemies/training_dummy.tscn") as PackedScene
	assert(dummy_packed != null, "Training dummy scene must load")
	var dummy := dummy_packed.instantiate() as TrainingDummy
	assert(dummy != null, "Training dummy must instantiate")
	root.add_child(dummy)
	await process_frame
	player._on_attack_area_body_entered(dummy)
	assert(dummy.health == 60, "Crafted stone sword increases melee damage to forty")
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

	print("WORLD_PLAYER_COMBAT_RESPAWN_TEST: PASS")
	quit(0)
