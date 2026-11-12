extends GdUnitTestSuite

const PLAYER := "res://addons/golem/player/player.tscn"


func test_wall_climb_reaches_a_high_lip_then_fades() -> void:
	var root := Node3D.new()
	auto_free(root)
	root.add_child(_static_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0)))
	# Lip at y = 6.9, near face at z = 3.35. The jump meets the face near the top of the arc.
	root.add_child(_static_box(Vector3(4, 6.9, 2.5), Vector3(0, 3.45, 4.6)))
	root.add_child(_static_box(Vector3(6, 8, 1.2), Vector3(0, 10.9, 6.55)))
	root.add_child(_static_box(Vector3(4, 12, 1), Vector3(18, 6, 1.4)))

	var player: CharacterBody3D = load(PLAYER).instantiate()
	player.position = Vector3(0, 0.05, 0)
	root.add_child(player)
	var runner := scene_runner(root)

	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)

	player.can_climb_walls = false
	player.can_climb_ledges = true
	await _jump_at_wall(runner, player)
	var missed_height: float = player.global_position.y
	for _step in 40:
		await runner.simulate_frames(1, 50)
		missed_height = maxf(missed_height, player.global_position.y)
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")
	assert_float(missed_height).is_less(6.4)

	player.velocity = Vector3.ZERO
	player.wall_climbing = false
	player.wall_climb_spent = false
	player.global_position = Vector3(0, 0.05, 0)
	player.can_climb_walls = true
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)
	await _jump_at_wall(runner, player)
	var topped := false
	for _step in 40:
		await runner.simulate_frames(1, 50)
		if player.global_position.y > 6.5 and player.global_position.z > 3.5:
			topped = true
			break
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")
	assert_bool(topped).is_true()

	player.velocity = Vector3.ZERO
	player.wall_climbing = false
	player.wall_climb_spent = false
	player.global_position = Vector3(18, 0.05, 0)
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 2000)
	await _jump_at_wall(runner, player)
	await _wait_until(runner, func() -> bool: return player.wall_climbing, 2000)
	await _wait_until(runner, func() -> bool: return not player.wall_climbing, 2000)
	await _wait_until(runner, func() -> bool: return player.velocity.y < 0.0, 2000)
	assert_bool(player.wall_climbing).is_false()
	runner.simulate_action_release("jump")
	runner.simulate_action_release("move_forward")


func _jump_at_wall(runner: GdUnitSceneRunner, player: CharacterBody3D) -> void:
	runner.simulate_action_press("move_forward")
	runner.simulate_action_press("jump")


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
