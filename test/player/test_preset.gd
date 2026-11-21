extends GdUnitTestSuite

const PLAYER := "res://addons/golem/scenes/player.tscn"
const Preset := preload("res://addons/golem/scripts/golem_preset.gd")
const DEFAULT_PRESET := "res://addons/golem/presets/default.tres"
const GROUNDED_PRESET := "res://addons/golem/presets/grounded.tres"


func test_capture_mirrors_the_player_configuration() -> void:
	var player: Node = auto_free(load(PLAYER).instantiate())
	var preset: Resource = Preset.capture(player)
	var exports: PackedStringArray = Preset.export_names()
	for key: String in exports:
		assert_bool(preset.values.has(key)).override_failure_message(key).is_true()
	for key: String in ["camera_mode", "body_layer", "body_mask", "camera_mask", "ragdoll_layer", "ragdoll_mask"]:
		assert_bool(preset.values.has(key)).override_failure_message(key).is_true()
	assert_bool(preset.values.has("probe_mask")).is_true()
	assert_bool(preset.values.has("jump_velocity")).is_true()
	assert_float(preset.values["jump_velocity"]).is_equal(4.5)
	assert_bool(preset.values.has("jump_gravity")).is_false()
	assert_bool(preset.values.has("fall_gravity")).is_false()
	assert_bool(preset.values.has("jump_height")).is_false()
	assert_bool(preset.values.has("jump_time_to_peak")).is_false()
	assert_bool(preset.values.has("jump_time_to_descent")).is_false()
	assert_int(preset.values.size()).is_equal(exports.size() + 6)
	assert_int(preset.values["probe_mask"]).is_equal(2)
	assert_int(preset.values["body_layer"]).is_equal(1)
	assert_int(preset.values["body_mask"]).is_equal(2)


func test_default_preset_matches_a_fresh_capture() -> void:
	var player: Node = auto_free(load(PLAYER).instantiate())
	var fresh: Resource = Preset.capture(player)
	var saved: Resource = load(DEFAULT_PRESET)
	assert_int(saved.values.size()).is_equal(fresh.values.size())
	for key: String in fresh.values:
		assert_bool(saved.values.has(key)).override_failure_message(key).is_true()
		_assert_same(saved.values[key], fresh.values[key], key)
	assert_bool(saved.values["can_continuous_run"]).is_false()
	assert_int(saved.values["nb_jumps_in_air_allowed"]).is_equal(0)
	assert_float(saved.values["headbob_side_bias"]).is_equal(0.0)


func test_grounded_preset_keeps_every_key_and_turns_parkour_off() -> void:
	var grounded: Resource = load(GROUNDED_PRESET)
	var defaults: Resource = load(DEFAULT_PRESET)
	for key: String in defaults.values:
		assert_bool(grounded.values.has(key)).override_failure_message(key).is_true()
	assert_bool(grounded.values["can_slide"]).is_false()
	assert_bool(grounded.values["can_climb_walls"]).is_false()
	assert_bool(grounded.values["can_wall_run"]).is_false()
	assert_bool(grounded.values["can_vault"]).is_false()
	assert_bool(grounded.values["can_climb_ledges"]).is_false()
	assert_bool(grounded.values["can_climb_stairs"]).is_true()
	assert_float(grounded.values["walk_speed"]).is_equal(defaults.values["walk_speed"])


func test_apply_writes_the_whole_configuration_before_the_player_enters_the_tree() -> void:
	var player: Node = auto_free(load(PLAYER).instantiate())
	assert_bool(player.is_inside_tree()).is_false()
	var preset: Resource = load(DEFAULT_PRESET)
	player.walk_speed = 1.25
	player.can_vault = false
	player.crouch_speed = 9.0
	player.collision_mask = 1
	player.probe_mask = 1
	var cam: Node = player.get_node("CamHolder")
	cam.collision_mask = 1
	cam.camera_mode = cam.Camera.THIRD
	var floor_ray: RayCast3D = player.get_node("Raycasts/FloorRaycast")
	floor_ray.collision_mask = 1
	var bones := player.find_children("*", "PhysicalBone3D", true, false)
	assert_int(bones.size()).is_greater(0)
	for bone: Node in bones:
		bone.collision_layer = 4
		bone.collision_mask = 1
	preset.apply_to(player)
	for key: String in preset.values:
		match key:
			"body_layer":
				assert_int(player.collision_layer).is_equal(int(preset.values[key]))
			"body_mask":
				assert_int(player.collision_mask).is_equal(int(preset.values[key]))
			"camera_mask":
				assert_int(cam.collision_mask).is_equal(int(preset.values[key]))
			"camera_mode":
				assert_int(cam.camera_mode).is_equal(int(preset.values[key]))
			"ragdoll_layer":
				for bone: Node in bones:
					assert_int(bone.collision_layer).is_equal(int(preset.values[key]))
			"ragdoll_mask":
				for bone: Node in bones:
					assert_int(bone.collision_mask).is_equal(int(preset.values[key]))
			"probe_mask":
				assert_int(player.probe_mask).is_equal(int(preset.values[key]))
				assert_int(floor_ray.collision_mask).is_equal(int(preset.values[key]))
			_:
				_assert_same(player.get(key), preset.values[key], key)


func _assert_same(actual: Variant, expected: Variant, key: String) -> void:
	match typeof(expected):
		TYPE_BOOL:
			assert_bool(bool(actual)).override_failure_message(key).is_equal(bool(expected))
		TYPE_INT:
			assert_int(int(actual)).override_failure_message(key).is_equal(int(expected))
		TYPE_FLOAT:
			assert_float(float(actual)).override_failure_message(key).is_equal(float(expected))
		TYPE_STRING:
			assert_str(String(actual)).override_failure_message(key).is_equal(String(expected))
		TYPE_VECTOR2:
			assert_vector(actual).override_failure_message(key).is_equal(expected)
		_:
			assert_str(str(actual)).override_failure_message(key).is_equal(str(expected))
