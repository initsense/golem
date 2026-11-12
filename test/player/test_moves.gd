extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_fast_crouch_slides_and_stays_off_when_disabled() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0)))

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	var runner := scene_runner(root)
	await _settle(runner, player)

	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool:
		return player.state_machine.curr_state_name == "Run" and _speed(player) >= player.slide_min_speed
	, 3000)
	runner.simulate_action_press("crouch")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Slide", 1000)
	runner.simulate_action_release("crouch")
	await runner.simulate_frames(2, 50)
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	assert_float(_speed(player)).is_greater(player.crouch_speed + 0.5)
	runner.simulate_action_release("run")
	await runner.simulate_frames(4, 50)
	assert_str(player.state_machine.curr_state_name).is_equal("Slide")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Walk", 2500)
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	runner.simulate_action_release("move_forward")

	_reset(player)
	player.can_slide = false
	await _settle(runner, player)
	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool:
		return player.state_machine.curr_state_name == "Run" and _speed(player) >= player.slide_min_speed
	, 3000)
	await _tap(runner, "crouch")
	runner.simulate_action_release("run")
	await runner.simulate_frames(16, 50)
	assert_str(player.state_machine.curr_state_name).is_equal("Walk")
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	assert_float(_speed(player)).is_less_equal(player.crouch_speed + 0.05)
	runner.simulate_action_release("move_forward")


func test_side_wall_run_jumps_off_and_head_on_still_climbs() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0)))
	# Face at x = 0.7, running along +Z.
	root.add_child(_static_box(Vector3(0.5, 8, 24), Vector3(0.95, 4, 4)))
	# Face at z = 1.2 so the jump meets the wall while still rising.
	root.add_child(_static_box(Vector3(4, 8, 1), Vector3(-20, 4, 1.7)))

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	player.can_climb_ledges = false
	root.add_child(player)
	var runner := scene_runner(root)
	await _settle(runner, player)

	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return _speed(player) >= 6.0, 3000)
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "WallRun", 2000)
	assert_float(_speed(player)).is_greater(4.0)
	assert_bool(player.wall_climbing).is_false()
	var away: Vector3 = player.wall_run_normal
	runner.simulate_action_release("jump")
	await runner.simulate_frames(1, 50)
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name != "WallRun", 1000)
	assert_float(player.velocity.dot(away)).is_greater(1.0)
	assert_float(player.velocity.y).is_greater(1.0)
	runner.simulate_action_release("jump")
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")

	_reset(player)
	player.can_wall_run = false
	player.wall_climbing = false
	await _settle(runner, player)
	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return _speed(player) >= 6.0, 3000)
	runner.simulate_action_press("jump")
	var ran_wall := false
	for _step in 25:
		await runner.simulate_frames(1, 50)
		if player.state_machine.curr_state_name == "WallRun":
			ran_wall = true
	runner.simulate_action_release("jump")
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	assert_bool(ran_wall).is_false()
	assert_bool(player.wall_climbing).is_false()

	_reset(player)
	player.can_wall_run = true
	player.can_climb_walls = true
	player.global_position = Vector3(-20, 0.05, 0)
	await _settle(runner, player)
	runner.simulate_action_press("move_forward")
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return player.wall_climbing, 2000)
	assert_bool(player.wall_climbing).is_true()
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")


func _speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _reset(player: CharacterBody3D) -> void:
	player.velocity = Vector3.ZERO
	player.vaulting = false
	player.wall_climbing = false
	player.wall_climb_armed = false
	player.wall_climb_spent = false
	player.wall_run_lockout = 0.0
	player.slide_momentum = 0.0
	player.walk_or_run = "WalkState"
	if player.pose != player.Pose.STANDING:
		player.pose = player.Pose.STANDING
		player.pose_changed.emit()
	player.global_position = Vector3(0, 0.05, 0)


func _settle(runner: GdUnitSceneRunner, player: CharacterBody3D) -> void:
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)


func _tap(runner: GdUnitSceneRunner, action: String) -> void:
	runner.simulate_action_press(action)
	await runner.simulate_frames(2, 50)
	runner.simulate_action_release(action)
	await runner.simulate_frames(1, 50)


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
