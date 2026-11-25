extends GdUnitTestSuite

const Defaults := preload("res://addons/golem/input_defaults.gd")


func test_missing_actions_skips_names_that_already_exist() -> void:
	var existing := PackedStringArray(["jump", "run"])
	var missing := Defaults.missing_actions(existing)
	assert_bool(missing.has("jump")).is_false()
	assert_bool(missing.has("run")).is_false()
	assert_bool(missing.has("crouch")).is_true()
	assert_bool(missing.has("mouse_mode")).is_false()
	assert_bool(missing.has("pan_up")).is_false()
	assert_int(missing.size()).is_equal(Defaults.ACTIONS.size() - 2)
	assert_int(Defaults.ACTIONS["interact"]).is_equal(KEY_E)
	assert_int(Defaults.ACTIONS["rotate_held"]).is_equal(KEY_T)
	assert_int(Defaults.ACTIONS["ragdoll"]).is_equal(KEY_R)
	assert_int(Defaults.POINTER_ACTIONS["throw"]).is_equal(MOUSE_BUTTON_LEFT)
	assert_int(Defaults.POINTER_ACTIONS["hold_nearer"]).is_equal(MOUSE_BUTTON_WHEEL_UP)
	assert_int(Defaults.POINTER_ACTIONS["hold_farther"]).is_equal(MOUSE_BUTTON_WHEEL_DOWN)
	var pointer_missing := Defaults.missing_pointer_actions(PackedStringArray(["throw"]))
	assert_bool(pointer_missing.has("throw")).is_false()
	assert_bool(pointer_missing.has("hold_nearer")).is_true()
