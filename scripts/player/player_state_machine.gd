extends Node
class_name FiniteStateMachine


var state: Dictionary = {}

@export var initial_state: State

func _ready() -> void:
	for child in get_children():
		if child is State:
			state[child.name.to_lower()] = child
			child.state_transition.connect(change_state)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state
