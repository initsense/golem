extends GdUnitTestSuite

const FIXTURE := "res://test/player/player_fixture.tscn"


func test_headbob_rests_until_walking() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)
	var index_at_rest: float = cam_holder.headbob_index
	await runner.simulate_frames(1, 400)
	assert_float(cam_holder.headbob_index).is_equal_approx(index_at_rest, 0.0001)
	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)


func test_headbob_target_rests_and_sways_both_ways() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	var rest: Vector2 = cam_holder.headbob_target(0.0, player.headbob_walk_side, player.headbob_walk_up)
	assert_float(rest.length()).is_equal_approx(0.0, 0.0001)

	var min_x := 0.0
	var max_x := 0.0
	var index_span: float = TAU / player.headbob_side_rate_ratio
	for step in 33:
		var index: float = index_span * float(step) / 32.0
		var target: Vector2 = cam_holder.headbob_target(index, player.headbob_walk_side, player.headbob_walk_up)
		min_x = minf(min_x, target.x)
		max_x = maxf(max_x, target.x)
	assert_float(min_x).is_less(-player.headbob_walk_side * 0.9)
	assert_float(max_x).is_greater(player.headbob_walk_side * 0.9)


func test_headbob_strength_quiets_the_step() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	player.headbob_strength = 0.0
	var silent := await _peak_while_moving(runner, player, cam_holder, 400)
	assert_float(silent).is_equal_approx(0.0, 0.0001)
	assert_float(cam_holder.headbob_index).is_greater(1.0)
	runner.simulate_action_release("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)

	player.headbob_strength = 0.3
	var quiet := await _peak_while_moving(runner, player, cam_holder, 800)
	runner.simulate_action_release("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	await _settle_headbob(runner, cam_holder)

	player.headbob_strength = 1.0
	var full := await _peak_while_moving(runner, player, cam_holder, 800)
	runner.simulate_action_release("move_forward")
	assert_float(quiet).is_greater(0.01)
	assert_float(full).is_greater(quiet)


func test_headbob_eases_home_and_keeps_the_index() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	await _peak_while_moving(runner, player, cam_holder, 400)
	assert_float(cam_holder.headbob_offset.length()).is_greater(0.01)
	runner.simulate_action_release("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	var index_at_stop: float = cam_holder.headbob_index
	await _settle_headbob(runner, cam_holder)
	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)
	assert_float(cam_holder.headbob_index).is_equal_approx(index_at_stop, 0.0001)


func test_headbob_run_advances_faster_than_walk() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	var walk_gain := await _index_gain(runner, player, cam_holder, false, 400)
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	var run_gain := await _index_gain(runner, player, cam_holder, true, 400)
	runner.simulate_action_release("move_forward")
	assert_float(run_gain).is_greater(walk_gain * 1.2)


func test_headbob_crouch_stays_smaller_than_run() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	runner.simulate_action_press("run")
	var running := await _peak_while_moving(runner, player, cam_holder, 800)
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Idle", 1000)
	await _settle_headbob(runner, cam_holder)

	await _tap(runner, "crouch")
	var crouched := await _peak_while_moving(runner, player, cam_holder, 800)
	runner.simulate_action_release("move_forward")
	assert_float(running).is_greater(crouched)
	assert_float(crouched).is_greater(0.005)


func test_headbob_freezes_in_the_air() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)

	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return cam_holder.headbob_index > 1.0, 1000)
	runner.simulate_action_press("jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1500)
	var index_at_takeoff: float = cam_holder.headbob_index
	await runner.simulate_frames(1, 300)
	assert_float(cam_holder.headbob_index).is_equal_approx(index_at_takeoff, 0.05)
	runner.simulate_action_release("move_forward")
	runner.simulate_action_release("jump")


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
	player.can_landing_shake = true

	var peak := await _jump_and_sample_shake(runner, cam_holder)
	assert_float(peak).is_greater(0.001)
	await runner.simulate_frames(1, int(player.shake_duration * 1000.0) + 80)
	assert_float(cam_holder.cam_shake_offset.length()).is_equal_approx(0.0, 0.0001)
	runner.simulate_action_release("jump")


func test_landing_shake_can_be_disabled() -> void:
	var runner := scene_runner(FIXTURE)
	var player: CharacterBody3D = runner.scene().find_child("Player", true, false)
	player.can_landing_shake = false
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
	assert_bool(player.can_ragdoll_on_floor_only).is_true()

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


func test_speed_widens_field_of_view_and_eases_home() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	var rest: float = player.cam_fov

	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Run", 1000)
	await runner.simulate_frames(1, 150)
	assert_float(cam_holder.cam.fov).is_less(rest + 3.0)
	await _wait_until(runner, func() -> bool: return Vector2(player.velocity.x, player.velocity.z).length() > 8.0, 2000)
	await runner.simulate_frames(1, 800)
	assert_float(cam_holder.cam.fov).is_greater(rest + 5.0)
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")
	await runner.simulate_frames(1, 2500)
	assert_float(cam_holder.cam.fov).is_less(rest + 1.5)

	player.can_speed_fov = false
	player.run_accel = 0.0
	player.velocity = Vector3.ZERO
	cam_holder.curr_fov = rest
	cam_holder.cam.fov = rest
	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Run", 1000)
	await runner.simulate_frames(1, 1000)
	var slow := Vector2(player.velocity.x, player.velocity.z).length()
	assert_float(slow).is_less(0.5)
	assert_float(cam_holder.cam.fov).is_greater(rest + player.run_fov_increase * 0.65)
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")


func test_turn_lean_follows_the_mouse_then_levels() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	player.can_view_noise = false
	player.turn_lean_return = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return Vector2(player.velocity.x, player.velocity.z).length() > 1.0, 1000)
	cam_holder.add_turn_lean(200.0)
	await runner.simulate_frames(1, 50)
	assert_float(absf(cam_holder.cam.rotation.z)).is_greater(0.02)
	player.turn_lean_return = 6.0
	runner.simulate_action_release("move_forward")
	await runner.simulate_frames(1, 1200)
	assert_float(absf(cam_holder.cam.rotation.z)).is_less(0.015)

	player.can_turn_lean = false
	cam_holder._turn_lean = 0.0
	cam_holder.cam.rotation.z = 0.0
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return Vector2(player.velocity.x, player.velocity.z).length() > 1.0, 1000)
	cam_holder.add_turn_lean(200.0)
	await runner.simulate_frames(1, 50)
	assert_float(absf(cam_holder.cam.rotation.z)).is_less(0.015)
	runner.simulate_action_release("move_forward")


func test_view_noise_stays_zero_when_disabled() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)
	var cam_holder = player.find_child("CamHolder", true, false)
	player.can_view_noise = false

	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return Vector2(player.velocity.x, player.velocity.z).length() > 5.0, 2000)
	await runner.simulate_frames(1, 300)
	assert_float(cam_holder.view_noise_pitch).is_equal_approx(0.0, 0.0001)
	assert_float(cam_holder.view_noise_roll).is_equal_approx(0.0, 0.0001)
	runner.simulate_action_release("run")
	runner.simulate_action_release("move_forward")


func test_crouch_blocks_run() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)

	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Walk", 1000)
	await _tap(runner, "crouch")
	runner.simulate_action_press("run")
	await runner.simulate_frames(8, 50)
	runner.simulate_action_release("run")
	var walk_crouch := Vector2(player.velocity.x, player.velocity.z).length()
	assert_str(player.state_machine.curr_state_name).is_equal("Walk")
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	assert_float(walk_crouch).is_less_equal(player.crouch_speed + 0.05)
	runner.simulate_action_release("move_forward")

	await _tap(runner, "crouch")
	await _wait_until(runner, func() -> bool: return player.pose == player.Pose.STANDING, 1000)
	runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == "Run", 1000)
	var early := Vector2(player.velocity.x, player.velocity.z).length()
	assert_float(early).is_less(player.slide_min_speed)
	await _tap(runner, "crouch")
	runner.simulate_action_release("run")
	await runner.simulate_frames(16, 50)
	var crouched_speed := Vector2(player.velocity.x, player.velocity.z).length()
	assert_str(player.state_machine.curr_state_name).is_equal("Walk")
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	assert_float(crouched_speed).is_greater(0.2)
	assert_float(crouched_speed).is_less_equal(player.crouch_speed + 0.05)
	runner.simulate_action_release("move_forward")


func test_crouch_clears_an_armed_run() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)

	await _tap(runner, "run")
	await _tap(runner, "crouch")
	assert_str(player.walk_or_run).is_equal("WalkState")
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	runner.simulate_action_press("move_forward")
	await runner.simulate_frames(4, 50)
	assert_str(player.state_machine.curr_state_name).is_equal("Walk")
	assert_int(player.pose).is_equal(player.Pose.CROUCHED)
	runner.simulate_action_release("move_forward")


func test_crouched_jump_lands_standing() -> void:
	var runner := scene_runner(FIXTURE)
	var player := await _ready_player(runner)

	await _tap(runner, "crouch")
	await _tap(runner, "jump")
	await _wait_until(runner, func() -> bool: return not player.is_on_floor(), 1000)
	assert_int(player.pose).is_equal(player.Pose.STANDING)
	await runner.simulate_frames(1, int(player.standing_speed * 1000.0) + 80)
	var cam_holder = player.find_child("CamHolder", true, false)
	assert_float(cam_holder.position.y).is_equal_approx(player.first_cam_height, 0.05)
	await _wait_until(runner, func() -> bool: return player.is_on_floor(), 3000)
	await runner.simulate_frames(1, 50)
	assert_int(player.pose).is_equal(player.Pose.STANDING)
	assert_float(cam_holder.position.y).is_equal_approx(player.first_cam_height, 0.05)


func _peak_while_moving(runner: GdUnitSceneRunner, player: CharacterBody3D, cam_holder, ms: int) -> float:
	runner.simulate_action_press("move_forward")
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name in ["Walk", "Run"], 1000)
	var peak := 0.0
	var waited := 0
	while waited < ms:
		await runner.simulate_frames(1, 50)
		peak = maxf(peak, cam_holder.headbob_offset.length())
		waited += 50
	return peak


func _index_gain(runner: GdUnitSceneRunner, player: CharacterBody3D, cam_holder, run: bool, ms: int) -> float:
	if run:
		runner.simulate_action_press("run")
	runner.simulate_action_press("move_forward")
	var state_name: String = "Run" if run else "Walk"
	await _wait_until(runner, func() -> bool: return player.state_machine.curr_state_name == state_name, 1000)
	var start: float = cam_holder.headbob_index
	await runner.simulate_frames(1, ms)
	runner.simulate_action_release("move_forward")
	if run:
		runner.simulate_action_release("run")
	return cam_holder.headbob_index - start


func _settle_headbob(runner: GdUnitSceneRunner, cam_holder) -> void:
	await runner.simulate_frames(1, 1500)
	assert_float(cam_holder.headbob_offset.length()).is_equal_approx(0.0, 0.0001)


func _tap(runner: GdUnitSceneRunner, action: String) -> void:
	runner.simulate_action_press(action)
	await runner.simulate_frames(2, 50)
	runner.simulate_action_release(action)
	await runner.simulate_frames(1, 50)


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

