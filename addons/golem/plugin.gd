@tool
extends EditorPlugin

const Defaults := preload("res://addons/golem/input_defaults.gd")


func _enter_tree() -> void:
	var existing := PackedStringArray()
	for action: String in Defaults.ACTIONS:
		if ProjectSettings.has_setting("input/%s" % action):
			existing.append(action)
	var missing := Defaults.missing_actions(existing)
	if missing.is_empty():
		return
	for action: String in missing:
		var event := InputEventKey.new()
		event.physical_keycode = Defaults.ACTIONS[action]
		ProjectSettings.set_setting("input/%s" % action, {
			"deadzone": 0.2,
			"events": [event],
		})
	ProjectSettings.save()
