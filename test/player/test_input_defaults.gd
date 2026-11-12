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
