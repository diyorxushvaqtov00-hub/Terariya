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

	print("PLAYER_SMOKE_TEST: PASS")
	quit(0)
