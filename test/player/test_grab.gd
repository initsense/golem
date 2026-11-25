extends GdUnitTestSuite
## Pickup, carry, wheel distance, mouse rotation, drop, throw, and the crosshair.


const PLAYER_SCENE := preload("res://addons/golem/scenes/player.tscn")
const CRATE_SCENE := preload("res://addons/golem/scenes/grabbable_crate.tscn")
const PLAIN_CRATE_SCENE := preload("res://addons/golem/scenes/plain_crate.tscn")

var _root: Node3D


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action_name: String in ["interact", "throw", "rotate_held", "hold_nearer", "hold_farther"]:
		if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
			Input.action_release(action_name)
	if _root != null and is_instance_valid(_root):
		_root.free()
	_root = null


func test_interact_and_left_click_pick_up_the_grabbable() -> void:
	var rig := await _make_rig(1.2)
	var grab: PlayerGrab = rig["grab"]
	assert_bool(grab.is_holding()).is_false()

	await _press_action("interact")
	assert_bool(grab.is_holding()).is_true()
	assert_object(grab.held_body()).is_same(rig["body"])
	await _release_held(grab)

	await _press_action("throw")
	assert_bool(grab.is_holding()).is_true()
	await _release_action("throw")


func test_player_body_does_not_collide_with_the_grab_area() -> void:
	var rig := await _make_rig(2.0)
	var player: CharacterBody3D = rig["player"]
	var area: Grabbable = rig["area"]
	var grab_area := area.get_grab_area()
	var body: RigidBody3D = rig["body"]
	assert_object(grab_area).is_not_null()
	assert_int(player.collision_mask & grab_area.collision_layer).is_equal(0)
	assert_int(grab_area.collision_layer).is_equal(8)
	assert_int(grab_area.collision_mask).is_equal(0)

	body.collision_layer = 0
	var walker := CharacterBody3D.new()
	walker.collision_layer = 1
	walker.collision_mask = player.collision_mask
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	shape.shape = capsule
	walker.add_child(shape)
	_root.add_child(walker)
	walker.global_position = body.global_position
	var before := walker.global_position
	var forward := -(rig["view"] as Camera3D).global_basis.z
	walker.velocity = forward * 4.0
	walker.move_and_slide()
	assert_float(walker.global_position.distance_to(before)).is_greater(0.01)


func test_hold_moves_the_body_toward_the_camera() -> void:
	var rig := await _make_rig(1.2)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var forward := -(rig["view"] as Camera3D).global_basis.z
	var start_along := body.global_position.dot(forward)
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_true()
	assert_float(body.gravity_scale).is_equal(0.0)
	assert_bool(body.freeze).is_false()
	var moved := false
	for _step: int in 20:
		await get_tree().physics_frame
		if body.global_position.dot(forward) > start_along + 0.2:
			moved = true
			break
	assert_bool(moved).is_true()
	await _release_action("interact")


func test_wheel_clamps_the_hold_distance() -> void:
	var rig := await _make_rig(1.2)
	var grab: PlayerGrab = rig["grab"]
	await _press_action("interact")
	grab.hold_distance = 2.0
	await _press_action("hold_nearer")
	assert_float(grab.hold_distance).is_equal(1.75)
	await _release_action("hold_nearer")

	grab.hold_distance = grab.min_hold_distance
	await _press_action("hold_nearer")
	assert_float(grab.hold_distance).is_equal(grab.min_hold_distance)
	await _release_action("hold_nearer")

	grab.hold_distance = grab.max_hold_distance
	await _press_action("hold_farther")
	assert_float(grab.hold_distance).is_equal(grab.max_hold_distance)
	await _release_action("hold_farther")


func test_rotate_held_turns_the_object_and_not_the_camera() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var camera: SpringArm3D = rig["camera"]
	await _press_action("interact")
	await get_tree().physics_frame
	assert_bool(grab.is_holding()).is_true()
	var carried_basis := body.global_basis
	Input.action_press("rotate_held")
	await get_tree().physics_frame
	var yaw_before := camera.rotation
	camera.apply_look_motion(Vector2(90, 0))
	assert_float(absf(wrapf(camera.rotation.y - yaw_before.y, -PI, PI))).is_less(0.001)
	assert_float(absf(camera.rotation.x - yaw_before.x)).is_less(0.001)
	grab.apply_mouse_look(Vector2(90, 0))
	await get_tree().physics_frame
	assert_float(_basis_angle(carried_basis, body.global_basis)).is_greater(0.05)

	var pitched_basis := body.global_basis
	grab.apply_mouse_look(Vector2(0, -70))
	await get_tree().physics_frame
	assert_float(_basis_angle(pitched_basis, body.global_basis)).is_greater(0.05)
	assert_float(absf(wrapf(camera.rotation.y - yaw_before.y, -PI, PI))).is_less(0.001)
	Input.action_release("rotate_held")
	await get_tree().physics_frame

	var steady := body.global_basis
	for _step: int in 5:
		await get_tree().physics_frame
	assert_float(_basis_angle(steady, body.global_basis)).is_less(0.02)

	var look_before := camera.rotation.y
	camera.apply_look_motion(Vector2(90, 0))
	assert_float(absf(wrapf(camera.rotation.y - look_before, -PI, PI))).is_greater(0.01)


func test_interact_again_drops_onto_the_floor() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	await _press_action("interact")
	var held_y := body.global_position.y
	await _release_action("interact")
	await get_tree().physics_frame
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_false()
	assert_float(body.gravity_scale).is_equal(1.0)
	assert_bool(body.freeze).is_false()
	await _release_action("interact")
	var fell := false
	var rested := false
	for _step: int in 180:
		await get_tree().physics_frame
		if body.global_position.y < held_y - 0.2:
			fell = true
		if fell and absf(body.linear_velocity.y) < 0.15 and body.global_position.y < 0.8:
			rested = true
			break
	assert_bool(fell).is_true()
	assert_bool(rested).is_true()
	assert_bool(body.freeze).is_false()


func test_left_click_throws_and_does_not_grab_again() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var camera: Camera3D = rig["view"]
	await _press_action("interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var forward := -camera.global_basis.z
	await _release_action("interact")
	var before := body.linear_velocity.dot(forward)
	await _press_action("throw")
	assert_bool(grab.is_holding()).is_false()
	assert_float(body.linear_velocity.dot(forward)).is_greater(before + grab.throw_speed - 1.0)
	await get_tree().physics_frame
	assert_bool(grab.is_holding()).is_false()
	await _release_action("throw")
	await _press_action("throw")
	assert_bool(grab.is_holding()).is_true()
	await _release_action("throw")


func test_disabling_the_area_drops_the_body() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var area: Grabbable = rig["area"]
	await _press_action("interact")
	var held_y := body.global_position.y
	area.set_grab_enabled(false)
	await get_tree().physics_frame
	assert_bool(grab.is_holding()).is_false()
	assert_bool(area.can_be_grabbed()).is_false()
	assert_float(body.gravity_scale).is_equal(1.0)
	assert_bool(body.freeze).is_false()
	var fell := false
	for _step: int in 60:
		await get_tree().physics_frame
		if body.global_position.y < held_y - 0.15:
			fell = true
			break
	assert_bool(fell).is_true()


func test_crosshair_fills_and_gains_a_ring() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var mark: GrabCrosshair = rig["mark"]
	var body: RigidBody3D = rig["body"]
	var view: Camera3D = rig["view"]
	var forward := -view.global_basis.z
	await get_tree().physics_frame
	assert_int(mark.mark).is_equal(GrabCrosshair.Mark.FILLED)

	var area: Grabbable = rig["area"]
	area.set_grab_enabled(false)
	await get_tree().physics_frame
	assert_int(mark.mark).is_equal(GrabCrosshair.Mark.HOLLOW)

	area.set_grab_enabled(true)
	await get_tree().physics_frame
	assert_int(mark.mark).is_equal(GrabCrosshair.Mark.FILLED)

	var plain: RigidBody3D = PLAIN_CRATE_SCENE.instantiate()
	_root.add_child(plain)
	plain.global_position = view.global_position + forward * 1.2
	area.set_grab_enabled(false)
	await get_tree().physics_frame
	assert_int(mark.mark).is_equal(GrabCrosshair.Mark.HOLLOW)

	area.set_grab_enabled(true)
	plain.global_position = view.global_position + view.global_basis.x * 6.0
	await _press_action("interact")
	assert_int(mark.mark).is_equal(GrabCrosshair.Mark.HELD)
	assert_float(mark.inner_radius).is_equal(6.0)
	await _release_action("interact")


func test_grabbable_under_static_body_discovers_and_carries_it() -> void:
	var rig := await _make_player_rig()
	var grab: PlayerGrab = rig["grab"]
	var view: Camera3D = rig["view"]
	var forward := -view.global_basis.z

	var block := StaticBody3D.new()
	block.collision_layer = 2
	block.collision_mask = 2
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	block.add_child(shape)
	var grabbable := Grabbable.new()
	block.add_child(grabbable)
	_root.add_child(block)
	block.global_position = view.global_position + forward * 2.5
	for _step: int in 3:
		await get_tree().physics_frame

	assert_int(grabbable.get_grab_area().collision_layer).is_equal(8)
	assert_int(grabbable._get_configuration_warnings().size()).is_equal(0)
	assert_object(grabbable.get_body()).is_not_null()
	assert_int(block.collision_layer).is_equal(0)
	assert_object(grab.target_under_crosshair()).is_same(grabbable)

	var start_distance := block.global_position.distance_to(view.global_position)
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_true()
	var moved := false
	for _step: int in 10:
		await get_tree().physics_frame
		if block.global_position.distance_to(view.global_position) < start_distance - 0.15:
			moved = true
			break
	assert_bool(moved).is_true()
	await _release_action("interact")
	await get_tree().physics_frame
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_false()
	await _release_action("interact")

	block.remove_child(grabbable)
	grabbable.free()
	await get_tree().physics_frame
	assert_int(block.collision_layer).is_equal(2)


func test_grabbable_under_mesh_with_child_static_body_converts_it() -> void:
	var rig := await _make_player_rig()
	var grab: PlayerGrab = rig["grab"]
	var view: Camera3D = rig["view"]
	var forward := -view.global_basis.z

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var static_body := StaticBody3D.new()
	static_body.name = "Collider"
	static_body.collision_layer = 2
	static_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	static_body.add_child(shape)
	mesh.add_child(static_body)
	var grabbable := Grabbable.new()
	mesh.add_child(grabbable)
	_root.add_child(mesh)
	mesh.global_position = view.global_position + forward * 2.5
	for _step: int in 3:
		await get_tree().physics_frame

	assert_object(mesh.get_node_or_null("Collider") as RigidBody3D).is_not_null()
	assert_object(grab.target_under_crosshair()).is_same(grabbable)
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_true()
	var start_distance := mesh.global_position.distance_to(view.global_position)
	var moved := false
	for _step: int in 10:
		await get_tree().physics_frame
		if mesh.global_position.distance_to(view.global_position) < start_distance - 0.1:
			moved = true
			break
	assert_bool(moved).is_true()
	await _release_action("interact")
	await get_tree().physics_frame
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_false()
	await _release_action("interact")


func test_grabbable_under_mesh_without_collider_builds_one() -> void:
	var rig := await _make_player_rig()
	var grab: PlayerGrab = rig["grab"]
	var view: Camera3D = rig["view"]
	var forward := -view.global_basis.z

	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var grabbable := Grabbable.new()
	mesh.add_child(grabbable)
	_root.add_child(mesh)
	mesh.global_position = view.global_position + forward * 2.5
	for _step: int in 3:
		await get_tree().physics_frame

	var body := grabbable.get_body()
	assert_object(body).is_not_null()
	assert_bool(body.freeze).is_true()
	assert_object(grab.target_under_crosshair()).is_same(grabbable)
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_true()
	await _release_action("interact")
	await get_tree().physics_frame
	await _press_action("interact")
	assert_bool(grab.is_holding()).is_false()
	await _release_action("interact")
	var fell := false
	var drop_y := mesh.global_position.y
	for _step: int in 60:
		await get_tree().physics_frame
		if mesh.global_position.y < drop_y - 0.15:
			fell = true
			break
	assert_bool(fell).is_true()


func test_grabbable_rotation_toggles_and_snapping() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var area: Grabbable = rig["area"]
	var camera: SpringArm3D = rig["camera"]

	# Horizontal-only: vertical mouse input does nothing, horizontal spins around world up.
	area.can_rotate_horizontally = true
	area.can_rotate_vertically = false
	await _press_action("interact")
	await get_tree().physics_frame
	var start_basis := body.global_basis
	grab.apply_mouse_look(Vector2(0, 90))
	await get_tree().physics_frame
	assert_float(_basis_angle(start_basis, body.global_basis)).is_less(0.01)

	grab.apply_mouse_look(Vector2(90, 0))
	await get_tree().physics_frame
	assert_float(_basis_angle(start_basis, body.global_basis)).is_greater(0.05)
	assert_float(body.global_basis.y.dot(Vector3.UP)).is_greater(0.99)

	# Diagonal disabled: diagonal move applies only the stronger axis.
	area.can_rotate_vertically = true
	area.can_rotate_diagonally = false
	var before_diag := body.global_basis
	grab.apply_mouse_look(Vector2(80, 30))
	await get_tree().physics_frame
	assert_float(_basis_angle(before_diag, body.global_basis)).is_greater(0.05)
	assert_float(body.global_basis.y.dot(Vector3.UP)).is_greater(0.99)

	# Angle snapping: 90-degree increments snap cleanly once past half a step.
	area.can_rotate_diagonally = true
	area.can_rotate_vertically = false
	area.rotation_snap_degrees = 90.0
	grab.apply_mouse_look(Vector2(100, 0))
	await get_tree().physics_frame
	var snapped_y := absf(rad_to_deg(body.global_basis.get_euler().y))
	var remainder := fmod(snapped_y, 90.0)
	assert_bool(remainder < 2.0 or absf(remainder - 90.0) < 2.0).is_true()

	# All rotation off: holding rotate_held no longer blocks camera turning.
	area.can_rotate_horizontally = false
	area.can_rotate_vertically = false
	assert_bool(grab.can_rotate_held()).is_false()
	Input.action_press("rotate_held")
	var yaw_before := camera.rotation.y
	camera.apply_look_motion(Vector2(90, 0))
	assert_float(absf(wrapf(camera.rotation.y - yaw_before, -PI, PI))).is_greater(0.01)
	Input.action_release("rotate_held")
	await _release_held(grab)


func test_grabbable_carry_and_release_toggles() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var area: Grabbable = rig["area"]

	area.can_move_vertically = false
	area.can_adjust_distance = false
	area.can_throw = false
	area.release_mode = Grabbable.ReleaseMode.FREEZE
	area.lock_rotation_on_release = true

	var start_y := body.global_position.y
	await _press_action("interact")
	await _release_action("interact")
	grab.hold_distance = 2.0
	await _press_action("hold_nearer")
	await _release_action("hold_nearer")
	assert_float(grab.hold_distance).is_equal(2.0)

	# Throw button does not release when can_throw is false.
	await _press_action("throw")
	await _release_action("throw")
	assert_bool(grab.is_holding()).is_true()
	assert_float(absf(body.global_position.y - start_y)).is_less(0.15)

	# Releasing freezes the body in place when release_mode is FREEZE.
	await _press_action("interact")
	await _release_action("interact")
	assert_bool(grab.is_holding()).is_false()
	assert_bool(body.freeze).is_true()
	assert_bool(body.lock_rotation).is_true()


func test_release_mode_float_and_freeze_blocks_throw() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var area: Grabbable = rig["area"]

	# FREEZE blocks throw even when can_throw is true.
	area.can_throw = true
	area.release_mode = Grabbable.ReleaseMode.FREEZE
	assert_bool(area.can_be_thrown()).is_false()
	await _press_action("interact")
	await _release_action("interact")
	await _press_action("throw")
	await _release_action("throw")
	assert_bool(grab.is_holding()).is_true()

	# FLOAT lets go unfrozen with zero gravity.
	area.release_mode = Grabbable.ReleaseMode.FLOAT
	assert_bool(area.can_be_thrown()).is_true()
	await _press_action("interact")
	await _release_action("interact")
	assert_bool(grab.is_holding()).is_false()
	assert_bool(body.freeze).is_false()
	assert_float(body.gravity_scale).is_equal(0.0)


func test_hold_distance_override_wheel_and_snap_edge_cases() -> void:
	var rig := await _make_rig(1.5)
	var grab: PlayerGrab = rig["grab"]
	var body: RigidBody3D = rig["body"]
	var area: Grabbable = rig["area"]

	# Preserve existing RigidBody3D mass when body_mass is 0.
	body.mass = 12.5
	area.body_mass = 0.0
	area.hold_distance_override = 4.5
	area.can_move_horizontally = false
	area.can_rotate_horizontally = false
	area.can_rotate_vertically = false
	area.follow_player_yaw = false
	area.rotation_snap_degrees = 90.0
	body.global_basis = Basis(Vector3.UP, deg_to_rad(25.0))
	var start_basis := body.global_basis

	await _press_action("interact")
	await _release_action("interact")
	await get_tree().physics_frame

	assert_float(body.mass).is_equal_approx(12.5, 0.01)
	assert_float(grab.hold_distance).is_equal_approx(4.5, 0.01)
	# Starting angle is not snapped when all rotation and follow_player_yaw are off.
	assert_float(_basis_angle(start_basis, body.global_basis)).is_less(0.02)

	# Wheel is ignored while can_move_horizontally is false.
	await _press_action("hold_nearer")
	await _release_action("hold_nearer")
	await get_tree().process_frame
	assert_float(grab.hold_distance).is_equal_approx(4.5, 0.01)

	# Enabling horizontal movement allows wheel adjustment within auto-expanded bounds.
	area.can_move_horizontally = true
	await _press_action("hold_nearer")
	await _release_action("hold_nearer")
	await get_tree().process_frame
	assert_float(grab.hold_distance).is_equal_approx(4.5 - grab.distance_step, 0.01)
	await _press_action("hold_farther")
	await _release_action("hold_farther")
	assert_float(grab.hold_distance).is_equal_approx(4.5, 0.01)
	await _release_held(grab)


func test_validate_property_marks_inactive_dependents_read_only() -> void:
	var node := Grabbable.new()
	add_child(node)
	var is_read_only := func(prop_name: String) -> bool:
		for prop: Dictionary in node.get_property_list():
			if prop.get("name", "") == prop_name:
				return (int(prop.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY) != 0
		return false

	# Defaults: everything active and editable.
	assert_bool(is_read_only.call("can_adjust_distance")).is_false()
	assert_bool(is_read_only.call("can_rotate_diagonally")).is_false()
	assert_bool(is_read_only.call("keep_upright")).is_false()
	assert_bool(is_read_only.call("throw_speed_multiplier")).is_false()

	# Horizontal move off grays out can_adjust_distance, keeps carry speed editable while vertical is on.
	node.can_move_horizontally = false
	assert_bool(is_read_only.call("can_adjust_distance")).is_true()
	assert_bool(is_read_only.call("max_carry_speed")).is_false()
	assert_bool(is_read_only.call("hold_distance_override")).is_false()

	# Both move axes off grays out carry speed and hold distance override too.
	node.can_move_vertically = false
	assert_bool(is_read_only.call("max_carry_speed")).is_true()
	assert_bool(is_read_only.call("hold_distance_override")).is_true()

	# Single-axis rotation grays out diagonal and upright locks, keeps speed and snap editable.
	node.can_rotate_vertically = false
	assert_bool(is_read_only.call("can_rotate_diagonally")).is_true()
	assert_bool(is_read_only.call("keep_upright")).is_true()
	assert_bool(is_read_only.call("rotate_speed_multiplier")).is_false()
	assert_bool(is_read_only.call("rotation_snap_degrees")).is_false()

	# All manual rotation off grays out speed and snap unless follow_player_yaw is enabled.
	node.can_rotate_horizontally = false
	assert_bool(is_read_only.call("rotate_speed_multiplier")).is_true()
	assert_bool(is_read_only.call("rotation_snap_degrees")).is_true()
	node.follow_player_yaw = true
	assert_bool(is_read_only.call("rotation_snap_degrees")).is_false()

	# ReleaseMode.FREEZE grays out throwing and lock_rotation_on_release.
	node.release_mode = Grabbable.ReleaseMode.FREEZE
	assert_bool(is_read_only.call("can_throw")).is_true()
	assert_bool(is_read_only.call("throw_speed_multiplier")).is_true()
	assert_bool(is_read_only.call("lock_rotation_on_release")).is_true()

	# FALL with can_throw = false grays out throw_speed_multiplier only.
	node.release_mode = Grabbable.ReleaseMode.FALL
	node.can_throw = false
	assert_bool(is_read_only.call("can_throw")).is_false()
	assert_bool(is_read_only.call("throw_speed_multiplier")).is_true()
	assert_bool(is_read_only.call("lock_rotation_on_release")).is_false()

	node.queue_free()


func _make_player_rig() -> Dictionary:
	_root = Node3D.new()
	add_child(_root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 0.2, 40)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_shape)
	_root.add_child(floor_body)

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	_root.add_child(player)
	player.global_position = Vector3.ZERO
	for _step: int in 3:
		await get_tree().physics_frame
	return {
		"player": player,
		"grab": player.get_node("Grab") as PlayerGrab,
		"mark": player.get_node("Crosshair/Mark") as GrabCrosshair,
		"camera": player.get_node("CamHolder") as SpringArm3D,
		"view": player.get_node("CamHolder/Camera3D") as Camera3D,
	}


func _make_rig(forward_distance: float) -> Dictionary:
	_root = Node3D.new()
	add_child(_root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 0.2, 40)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.1, 0)
	floor_body.add_child(floor_shape)
	_root.add_child(floor_body)

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	_root.add_child(player)
	player.global_position = Vector3.ZERO
	var crate: RigidBody3D = CRATE_SCENE.instantiate()
	_root.add_child(crate)
	for _step: int in 3:
		await get_tree().physics_frame
	var aim := player.get_node("CamHolder/Camera3D") as Camera3D
	var forward := -aim.global_basis.z
	crate.global_position = aim.global_position + forward * forward_distance
	await get_tree().physics_frame
	return {
		"player": player,
		"grab": player.get_node("Grab") as PlayerGrab,
		"mark": player.get_node("Crosshair/Mark") as GrabCrosshair,
		"camera": player.get_node("CamHolder") as SpringArm3D,
		"view": player.get_node("CamHolder/Camera3D") as Camera3D,
		"body": crate,
		"area": crate.get_node("Grabbable") as Grabbable,
	}


func _press_action(action_name: String) -> void:
	_queue_action(action_name, true)
	await get_tree().physics_frame


func _release_action(action_name: String) -> void:
	_queue_action(action_name, false)
	await get_tree().physics_frame


func _queue_action(action_name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)


func _release_held(grab: PlayerGrab) -> void:
	await _release_action("interact")
	await _release_action("throw")
	if grab.is_holding():
		await _press_action("interact")
		await _release_action("interact")


func _place_body(body: RigidBody3D, where: Vector3) -> void:
	var frozen := body.freeze
	body.freeze = false
	body.global_position = where
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(
		body.get_rid(),
		PhysicsServer3D.BODY_STATE_TRANSFORM,
		Transform3D(body.global_basis, where)
	)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	body.freeze = frozen
	body.force_update_transform()


func _send_mouse(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	Input.parse_input_event(motion)


func _basis_angle(before: Basis, after: Basis) -> float:
	var delta := Quaternion(before).inverse().normalized() * Quaternion(after).normalized()
	return delta.get_angle()
