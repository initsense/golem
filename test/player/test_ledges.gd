extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_jump_climbs_a_close_ledge_and_can_leave_it() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0)))
	# Near face at z = 0.9, top at y = 1.2. Deep enough to stand on.
	root.add_child(_static_box(Vector3(4, 1.2, 2), Vector3(0, 0.6, 1.9)))

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	var runner := scene_runner(root)

	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)

	await _approach(runner, player)
	assert_float(player.global_position.y).is_less(0.3)
	assert_float(player.global_position.z).is_less(0.6)
	runner.simulate_action_release("move_forward")

	_reset(player)
	player.can_climb_ledges = false
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 1000)
	await _approach(runner, player)
	runner.simulate_action_press("jump")
	var rose := false
	var crossed_while_low := false
	for _step in 12:
		await runner.simulate_frames(1, 50)
		if player.global_position.y < 1.0 and player.global_position.z > 0.6:
			crossed_while_low = true
		if player.global_position.y > 2.5:
			rose = true
	assert_bool(crossed_while_low).is_false()
	assert_bool(rose).is_true()
	assert_bool(player.is_on_floor()).is_false()
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")
	await _wait_until(runner, func() -> bool: return player.is_on_floor(), 3000)
	assert_float(player.global_position.y).is_less(0.3)

	_reset(player)
	player.can_climb_ledges = true
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 1000)
	await _approach(runner, player)
	runner.simulate_action_press("jump")
	var topped := false
	for _step in 30:
		await runner.simulate_frames(1, 50)
		if player.global_position.y > 1.0 and player.global_position.z > 0.9:
			topped = true
			break
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")
	assert_bool(topped).is_true()

	_reset(player)
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 1000)
	await _approach(runner, player)
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return player.ledge_pulling, 1000)
	runner.simulate_action_release("jump")
	await runner.simulate_frames(1, 50)
	runner.simulate_action_press("jump")
	await runner.simulate_frames(2, 50)
	assert_float(player.velocity.y).is_greater(2.0)
	assert_float(player.global_position.z).is_less(0.9)
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")


func _approach(runner: GdUnitSceneRunner, player: CharacterBody3D) -> void:
	runner.simulate_action_press("move_forward")
	var still := 0
	var last_z := player.global_position.z
	for _step in 40:
		await runner.simulate_frames(1, 50)
		var here: float = player.global_position.z
		if absf(here - last_z) < 0.01 and here > 0.15:
			still += 1
			if still >= 3:
				return
		else:
			still = 0
		last_z = here


func _reset(player: CharacterBody3D) -> void:
	player.velocity = Vector3.ZERO
	player.ledge_pulling = false
	player.global_position = Vector3(0, 0.05, 0)


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
