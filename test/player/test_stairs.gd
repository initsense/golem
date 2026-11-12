extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_low_step_is_climbed_tall_wall_stops_and_jump_leaves_the_floor() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0)))
	root.add_child(_static_box(Vector3(4, 0.4, 2), Vector3(0, 0.2, 2.2)))
	var wall := _static_box(Vector3(4, 1, 0.4), Vector3(8, 0.5, 2))
	root.add_child(wall)

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	var runner := scene_runner(root)

	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)

	var start_y: float = player.global_position.y
	runner.simulate_action_press("move_forward")
	var climbed := false
	var stayed_walk := false
	for _step in 40:
		await runner.simulate_frames(1, 50)
		if player.global_position.y > start_y + 0.25:
			climbed = true
			stayed_walk = player.state_machine.curr_state_name == "Walk"
			break
		if player.ledge_pulling:
			break
	runner.simulate_action_release("move_forward")
	assert_bool(climbed).is_true()
	assert_bool(stayed_walk).is_true()
	assert_bool(player.ledge_pulling).is_false()

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(8, 0.05, 0)
	await _wait_until(runner, func() -> bool: return player.is_on_floor(), 1000)
	var before_wall := player.global_position
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(25, 50)
	runner.simulate_action_release("move_forward")
	assert_float(player.global_position.y).is_less(before_wall.y + 0.2)
	assert_float(player.global_position.z).is_less(1.7)

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(-8, 0.05, 0)
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 1000)
	var before_jump: float = player.global_position.y
	runner.simulate_action_press("jump")
	await runner.simulate_frames(8, 50)
	runner.simulate_action_release("jump")
	assert_bool(player.is_on_floor()).is_false()
	assert_float(player.global_position.y).is_greater(before_jump)


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
