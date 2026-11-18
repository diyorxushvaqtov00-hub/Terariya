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
	assert(world.get_tile(Vector2i(10, world.get_surface_y(10))) == WorldGenerator.GRASS, "Surface is grass")
	var test_cell := Vector2i(10, world.get_surface_y(10))
	assert(world.mine_cell(test_cell), "Mining a solid block succeeds")
	assert(world.get_tile(test_cell) == WorldGenerator.AIR, "Mined cell becomes air")
	assert(world.place_block(test_cell), "Placing a block into an empty cell succeeds")
	assert(world.get_tile(test_cell) == WorldGenerator.DIRT, "Placed block becomes dirt")
	assert(not world.place_block(test_cell), "Cannot place a block into an occupied cell")

	var player_packed := load("res://scenes/player/player.tscn") as PackedScene
	assert(player_packed != null, "Player scene must load")
	var player := player_packed.instantiate() as PlayerController
	assert(player != null, "Player scene must instantiate")
	root.add_child(player)
	await process_frame
	assert(player.health == player.max_health, "Player starts at full health")
	assert(player.inventory.count("dirt") == 20, "Player starts with twenty dirt blocks")
	var inventory_test_cell := Vector2i(12, world.get_surface_y(12))
	assert(world.mine_cell(inventory_test_cell), "Mining a block with a player succeeds")
	assert(player.inventory.count("dirt") == 21, "Mining a grass or dirt block adds a dirt drop")
	assert(world.place_block(inventory_test_cell), "Player can place a block using inventory")
	assert(player.inventory.count("dirt") == 20, "Placing a block consumes one dirt item")
	player.take_damage(25)
	assert(player.health == 75, "Damage subtracts health")
	player.heal(10)
	assert(player.health == 85, "Healing restores health")
	player.heal(1000)
	assert(player.health == player.max_health, "Healing is capped at max health")
	player.unlock_double_jump()
	assert(player.double_jump_unlocked, "Double jump unlock flag is persistent on player instance")

	var dummy_packed := load("res://scenes/enemies/training_dummy.tscn") as PackedScene
	assert(dummy_packed != null, "Training dummy scene must load")
	var dummy := dummy_packed.instantiate() as TrainingDummy
	assert(dummy != null, "Training dummy must instantiate")
	root.add_child(dummy)
	await process_frame
	player._on_attack_area_body_entered(dummy)
	assert(dummy.health == 75, "Player melee hit applies configured damage")
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
