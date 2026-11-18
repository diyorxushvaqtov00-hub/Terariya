extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	assert(packed != null, "Player scene must load")
	var player := packed.instantiate() as PlayerController
	assert(player != null, "Player scene must instantiate")
	root.add_child(player)
	await process_frame

	assert(player.health == player.max_health, "Player starts at full health")
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

	print("PLAYER_COMBAT_RESPAWN_SMOKE_TEST: PASS")
	quit(0)
