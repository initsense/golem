extends GdUnitTestSuite

const FIXTURE := "res://test/player/player_fixture.tscn"


func test_headbob_rests_walks_and_settles() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)

	runner.simulate_action_press("move_forward")
	var max_offset := 0.0
	var walk_seconds: float = player.headbob_fade_in_time + (0.5 / player.headbob_frequency)
	var steps := int(ceil(walk_seconds / 0.05))
	for step in steps:
		await runner.simulate_frames(1, 50)
		max_offset = maxf(max_offset, cam_holder.headbob_offset.length())
	assert_float(max_offset).is_greater(0.001)

	runner.simulate_action_release("move_forward")
	await runner.simulate_frames(1)
	assert_float(cam_holder.headbob_offset.length()).is_greater(0.0001)

	await runner.simulate_frames(1, int(player.headbob_fade_out_time * 1000.0) + 80)
	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)


func test_headbob_stays_zero_in_third_person() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	cam_holder.set_camera_mode(cam_holder.Camera.THIRD, true)

	runner.simulate_action_press("move_forward")
	var max_offset := 0.0
	for step in 10:
		await runner.simulate_frames(1, 50)
		max_offset = maxf(max_offset, cam_holder.headbob_offset.length())
	runner.simulate_action_release("move_forward")
	assert_float(max_offset).is_equal_approx(0.0, 0.0001)


func test_camera_mode_blend_height_spring_pitch_and_visibility() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	player.third_cam_height = 2.2
	player.camera_mode_blend_time = 0.4
	cam_holder.rotation.x = 1.2
	cam_holder.set_camera_mode(cam_holder.Camera.THIRD)

	assert_bool(player.visual_root.visible).is_true()
	await runner.simulate_frames(1, 200)
	assert_float(cam_holder.rotation.x).is_greater(player.third_limit_down + 0.05)
	assert_float(cam_holder.rotation.x).is_less(1.15)

	await runner.simulate_frames(1, 300)
	assert_float(cam_holder.position.y).is_equal_approx(player.third_cam_height, 0.05)
	assert_float(cam_holder.spring_length).is_equal_approx(player.zoom_val, 0.05)
	assert_bool(player.visual_root.visible).is_true()

	cam_holder.set_camera_mode(cam_holder.Camera.FIRST)
	assert_bool(player.visual_root.visible).is_false()
	await runner.simulate_frames(1, 500)
	assert_float(cam_holder.position.y).is_equal_approx(player.first_cam_height, 0.05)
	assert_float(cam_holder.spring_length).is_equal_approx(0.0, 0.05)


func test_crouch_lowers_first_person_holder() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	cam_holder.set_camera_mode(cam_holder.Camera.FIRST, true)

	runner.simulate_action_press("crouch")
	await runner.simulate_frames(1)
	runner.simulate_action_release("crouch")
	await runner.simulate_frames(1, int(player.crouching_speed * 1000.0) + 80)
	assert_float(cam_holder.position.y).is_equal_approx(player.first_cam_crouch_height, 0.05)


func test_landing_shake_plays_and_clears() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	player.landing_shake = true

	var peak := await _jump_and_sample_shake(runner, cam_holder)
	assert_float(peak).is_greater(0.001)
	await runner.simulate_frames(1, int(player.shake_duration * 1000.0) + 80)
	assert_float(cam_holder.cam_shake_offset.length()).is_equal_approx(0.0, 0.0001)
	runner.simulate_action_release("jump")


func test_landing_shake_can_be_disabled() -> void:
	var runner := scene_runner(FIXTURE)
	var player: CharacterBody3D = runner.scene().find_child("Player", true, false)
	player.landing_shake = false
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	await _wait_until(runner, func() -> bool: return player.is_on_floor(), 1000)
	var cam_holder = player.find_child("CamHolder", true, false)

	var peak := await _jump_and_sample_shake(runner, cam_holder)
	assert_float(peak).is_equal_approx(0.0, 0.0001)
	runner.simulate_action_release("jump")


func test_ragdoll_follows_hips_without_launching() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	cam_holder.set_camera_mode(cam_holder.Camera.FIRST, true)

	runner.simulate_action_press("ragdoll")
	await runner.simulate_frames(1)
	runner.simulate_action_release("ragdoll")

	var max_speed := 0.0
	var max_distance := 0.0
	for step in 8:
		await runner.simulate_frames(1, 50)
		max_speed = maxf(max_speed, player.velocity.length())
		var hips: Vector3 = player.godot_plush_skin.hips_bone.global_position
		max_distance = maxf(max_distance, cam_holder.cam.global_position.distance_to(hips))
	assert_str(player.state_machine.curr_state_name).is_equal("Ragdoll")
	assert_float(max_speed).is_less(1.0)
	assert_float(max_distance).is_less(6.0)

	runner.simulate_action_press("ragdoll")
	await runner.simulate_frames(1, 100)
	runner.simulate_action_release("ragdoll")
	await runner.simulate_frames(1, int(player.camera_mode_blend_time * 1000.0) + 150)
	assert_str(player.state_machine.curr_state_name).is_equal("Idle")
	assert_float(cam_holder.spring_length).is_equal_approx(0.0, 0.05)
	assert_bool(player.visual_root.visible).is_false()


func test_ragdoll_on_floor_only_ignores_air_press() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	assert_bool(player.ragdoll_on_floor_only).is_true()

	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1500)
	runner.simulate_action_press("ragdoll")
	await runner.simulate_frames(1, 100)
	runner.simulate_action_release("ragdoll")
	runner.simulate_action_release("jump")
	assert_str(player.state_machine.curr_state_name).is_not_equal("Ragdoll")


func test_directed_jump_reaches_walk_speed_and_a_still_jump_does_not() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)

	runner.simulate_action_press("move_forward")
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1500)
	await runner.simulate_frames(8, 50)
	var directed := Vector2(player.velocity.x, player.velocity.z).length()
	runner.simulate_action_release("move_forward")
	runner.simulate_action_release("jump")
	assert_float(directed).is_greater(player.walk_speed * 0.5)

	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 3000)
	var before := Vector2(player.velocity.x, player.velocity.z).length()
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1500)
	await runner.simulate_frames(8, 50)
	var still := Vector2(player.velocity.x, player.velocity.z).length()
	runner.simulate_action_release("jump")
	assert_float(still).is_less(maxf(before, 0.2) + 0.3)

	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 3000)
	var released := await _rising_speed_after(runner, player, true)
	await _wait_until(runner, func() -> bool:
		return player.is_on_floor() and player.state_machine.curr_state_name == "Idle"
	, 3000)
	var held := await _rising_speed_after(runner, player, false)
	assert_float(released.x).is_greater(0.0)
	assert_float(released.x).is_equal_approx(released.y, 0.5)
	assert_float(held.x).is_equal_approx(held.y, 0.5)


func _rising_speed_after(runner: GdUnitSceneRunner, player: CharacterBody3D, release: bool) -> Vector2:
	var frames := 4
	var delta_ms := 16
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1500)
	var start_vy: float = player.velocity.y
	if release:
		runner.simulate_action_release("jump")
	await runner.simulate_frames(frames, delta_ms)
	var expected: float = start_vy - player.jump_gravity * frames * (float(delta_ms) / 1000.0)
	if not release:
		runner.simulate_action_release("jump")
	return Vector2(player.velocity.y, expected)


func _ready_player(runner: GdUnitSceneRunner) -> CharacterBody3D:
	var player: CharacterBody3D = runner.scene().find_child("Player", true, false)
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	await _wait_until(runner, func() -> bool: return player.is_on_floor(), 1000)
	return player


func _wait_until(runner: GdUnitSceneRunner, condition: Callable, timeout_ms: int) -> void:
	var waited := 0
	while waited < timeout_ms:
		if condition.call():
			return
		await runner.simulate_frames(1, 20)
		waited += 20
	assert_bool(condition.call()).is_true()


func _jump_and_sample_shake(runner: GdUnitSceneRunner, cam_holder) -> float:
	runner.simulate_action_press("jump")
	var peak := 0.0
	for step in 80:
		await runner.simulate_frames(1, 30)
		peak = maxf(peak, cam_holder.cam_shake_offset.length())
		if peak > 0.001:
			return peak
	return peak

