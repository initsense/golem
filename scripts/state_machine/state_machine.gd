extends Node
class_name FiniteStateMachine


var states: Dictionary = {}
var stairs: Stairs


@export var initial_state: State
var current_state: State

func _ready() -> void:
	stairs.check_step()
	
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_transition.connect(change_state)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state


func change_state(source_state: State, new_state_name: String) -> void:
	if source_state != current_state:
		return
	
	var new_state: State = states.get(new_state_name.to_lower())
	if !new_state:
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	
	current_state = new_state
