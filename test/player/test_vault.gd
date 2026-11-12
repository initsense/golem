extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_run_vaults_a_mid_block_and_a_walk_stops() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0)))
	# Top at y = 1. Near face at z = 5.4. Taller than a step, within the vault height.
	root.add_child(_static_box(Vector3(4, 1.0, 1.2), Vector3(0, 0.5, 6)))

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	player.can_climb_ledges = false
	root.add_child(player)
	var runner := scene_runner(root)
	await _settle(runner, player)

	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	var saw_vault := false
	var landed := false
	for _step in 90:
		await runner.simulate_frames(1, 50)
		if player.vaulting:
			saw_vault = true
		elif saw_vault:
			assert_float(player.global_position.y).is_greater(0.7)
			assert_float(player.global_position.z).is_greater(5.8)
			assert_float(player.global_position.z).is_less(6.8)
			landed = true
			break
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	assert_bool(saw_vault).is_true()
	assert_bool(landed).is_true()

	_reset(player)
	await _settle(runner, player)
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(40, 50)
	runner.simulate_action_release("move_forward")
	assert_bool(player.vaulting).is_false()
	assert_float(player.global_position.y).is_less(0.4)
	assert_float(player.global_position.z).is_less(5.2)

	_reset(player)
	player.can_vault = false
	await _settle(runner, player)
	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(50, 50)
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	assert_bool(player.vaulting).is_false()
	assert_float(player.global_position.y).is_less(0.4)
	assert_float(player.global_position.z).is_less(5.2)


func _reset(player: CharacterBody3D) -> void:
	player.velocity = Vector3.ZERO
	player.vaulting = false
	player.wall_climbing = false
	player.global_position = Vector3(0, 0.05, 0)


func _settle(runner: GdUnitSceneRunner, player: CharacterBody3D) -> void:
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)


func _static_box(size: Vector3, center: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	body.add_child(shape)
	return body


func _wait_until(runner: GdUnitSceneRunner, condition: Callable, timeout_ms: int) -> void:
	var waited := 0
	while waited < timeout_ms:
		if condition.call():
			return
		await runner.simulate_frames(1, 20)
		waited += 20
	assert_bool(condition.call()).is_true()
