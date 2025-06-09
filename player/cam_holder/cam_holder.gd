extends SpringArm3D

var active : bool = true : set = set_active

@export_group("Camera mode")
enum Camera {
	FIRST,
	THIRD,
	THIRD_L,
	THIRD_R
}
@export var camera_mode: Camera = Camera.THIRD
var cam_aimed : bool = false #if true, cam goes into "aim/shooter mode", above the play char shoulder
@export var first_cam_height : float = 1.5
@export var third_cam_height : float = 1.5
@export var aim_cam_pos : Vector2 = Vector2(1.6, 0.8)

@export_group("Head bob")
@export var headbob_amplitude : float = 0.03
@export var headbob_frequency : float = 2.3
var headbob_time : float = 0.0
var cached_speed_factor : float = 0.0

@export_group("Camera movement")
@export_range(0.0, 0.005, 0.0005) var mouse_sens : float = 0.002
var cam_limit_up : float
var cam_limit_down : float
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_up : float = -1.4
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var first_limit_down : float = 1.4
@export_range(0.0, 20.0, 0.01) var pan_rotation_val : float = 2.0
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_up : float = -1.4
@export_range(-90.0, 90.0, 0.1, "radians_as_degrees") var third_limit_down : float = 0.8

@export_group("FOV")
@export var cam_fov : float = 90
@export var min_fov : float = 30.0
@export var max_fov : float = 150.0
@export var fov_speed : float = 32.0

@export_group("Zoom")
@export var zoom_val : float = 3.0
@export var max_zoom_val : float = 8.0
@export var min_zoom_val : float = 1.0
@export var zoom_speed : float = 4.0
@onready var last_zoom_val : float = zoom_val

@export_group("Keybinding")
@export var mouse_mode_action : String = "toggle_mouse_mode"
@export var cam_zoom_in_action : String = "zoom_in"
@export var cam_zoom_out_action : String = "zoom_out"
@export var cam_fov_decrease : String = "fov_decrease"
@export var cam_fov_increase : String = "fov_increase"

#references variables
@onready var cam : Camera3D = %Camera3D
@onready var godot_plush_skin : Node3D = %GodotPlushSkin
@onready var visual_root : Node3D = %VisualRoot
@onready var player: CharacterBody3D = $".."
@onready var state_machine: Node = $"../StateMachine"


func _ready():
	#capture mouse cursor, and enable camera
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.set_use_accumulated_input(false)
	set_active(active)
	cam.fov = cam_fov
	set_zoom(camera_mode)


func set_active(state : bool):
	#enable/disable play char camera
	active = state
	set_process_input(active)
	set_process(active)


func _input(event) -> void:
	#free/capture mouse cursor
	if event.is_action_pressed(mouse_mode_action):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	#if mouse cursor is free, can't rotate cam
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	# switches between camera modes
	if event.is_action_pressed("first_person") and camera_mode != Camera.FIRST:
		set_zoom(Camera.FIRST)
		set_camera_mode(Camera.FIRST)
		visual_root.visible = false

	if event.is_action_pressed("third_person") and camera_mode != Camera.THIRD:
		set_zoom(Camera.THIRD)
		set_camera_mode(Camera.THIRD)
		visual_root.visible = true

	if event.is_action_pressed("third_aim_left") and camera_mode != Camera.THIRD_L:
		set_zoom(Camera.THIRD_L)
		set_camera_mode(Camera.THIRD_L)
		visual_root.visible = true

	if event.is_action_pressed("third_aim_right") and camera_mode != Camera.THIRD_R:
		set_zoom(Camera.THIRD_R)
		set_camera_mode(Camera.THIRD_R)
		visual_root.visible = true

	#rotate cam according to the mouse
	if event is InputEventMouseMotion:
		# simple method
		rotation.y -= event.relative.x * mouse_sens
		rotation.y = wrapf(rotation.y, 0.0, TAU)
		rotation.x -= event.relative.y * mouse_sens
		rotation.x = clamp(rotation.x, cam_limit_up, cam_limit_down)
		
		# complex method: use only if you manually stretch or scale viewports
		#var viewport_transform: Transform2D = get_tree().root.get_final_transform()
		#var mouse_motion = event.xformed_by(viewport_transform).relative
		#rotate_from_vector(mouse_motion * mouse_sens)


func _process(delta):
	#get pan direction
	var joy_dir: Vector2 = Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	
	set_camera_position()
	
	# handle zoom in third person
	if camera_mode != Camera.FIRST:
		zoom_handling(delta)
	
	fov_handling(delta)
	
	if not player.was_on_floor and state_machine.curr_state_name != "Idle":
		handle_headbob(delta)
	
	#rotate cam with keyboard
	#rotate_from_vector(joy_dir * Vector2(1.0, 0.5) * pan_rotation_val * delta)


#func rotate_from_vector(vector : Vector2) -> void:
	##rotate cam by the vector's amount, and clamp the rotation between max up and max down values
	##(to avoid doing 360 degree turn with the cam for example)
	#if vector.length() == 0:
		#return
	#rotation.y -= vector.x
	#rotation.x -= vector.y
	#if camera_mode == Camera.FIRST:
		#rotation.x = clamp(rotation.x, first_limit_up, first_limit_down)
	#else:
		#rotation.x = clamp(rotation.x, third_limit_up, third_limit_down)


func set_camera_position():
	"""Set camera position based on current camera mode"""
	match camera_mode:
		Camera.FIRST:
			position = Vector3(0, first_cam_height, 0)
			spring_length = 0
			cam_limit_down = first_limit_down
			cam_limit_up = first_limit_up
		Camera.THIRD:
			position = Vector3(0, third_cam_height, 0)
			spring_length = zoom_val
			cam_limit_down = third_limit_down
			cam_limit_up = third_limit_up
		Camera.THIRD_L:
			position = Vector3(-aim_cam_pos.x, aim_cam_pos.y, 0)
			spring_length = zoom_val
			cam_limit_down = third_limit_down
			cam_limit_up = third_limit_up
		Camera.THIRD_R:
			position = Vector3(aim_cam_pos.x, aim_cam_pos.y, 0)
			spring_length = zoom_val
			cam_limit_down = third_limit_down
			cam_limit_up = third_limit_up


func set_zoom(new_camera_mode: Camera) -> void:
	var switching_to_first = new_camera_mode == Camera.FIRST
	var switching_from_first = camera_mode == Camera.FIRST and new_camera_mode != Camera.FIRST

	if switching_to_first:
		if camera_mode != Camera.FIRST:
			last_zoom_val = zoom_val
		zoom_val = 0.0
	elif switching_from_first:
		zoom_val = last_zoom_val


func set_camera_mode(new_mode: Camera) -> void:
	if new_mode in Camera.values():
		camera_mode = new_mode
		print("Camera mode set to: ", get_camera_mode_name())
	else:
		print("Invalid camera mode: ", new_mode)


func get_camera_mode_name() -> String:
	"""Get the string name of the current camera mode"""
	match camera_mode:
		Camera.FIRST:
			return "FIRST"
		Camera.THIRD:
			return "THIRD"
		Camera.THIRD_L:
			return "THIRD_L"
		Camera.THIRD_R:
			return "THIRD_R"
		_:
			return "UNKNOWN"


func fov_handling(delta : float):
	var fov_input: float = Input.get_axis(cam_fov_decrease, cam_fov_increase)
	cam_fov += fov_input * fov_speed * delta
	cam_fov = clamp(cam_fov, min_fov, max_fov)
	cam.fov = cam_fov


func zoom_handling(delta : float):
	#zoom in/out cam, and clamp zoom value between min and max zoom values
	var zoom_input: float = Input.get_axis(cam_zoom_in_action, cam_zoom_out_action)
	zoom_val += zoom_input * zoom_speed * delta
	zoom_val = clamp(zoom_val, min_zoom_val, max_zoom_val)


func handle_headbob(delta: float):
	"""Handle camera head bobbing effect based on player movement"""
	var player_speed: float = player.velocity.length()
	cached_speed_factor = pow(player_speed, 0.5)
	
	headbob_time += delta * pow(player_speed, 0.8)
	
	var headbob_offset: Vector3 = Vector3(
		cos(headbob_time * headbob_frequency * 0.5) * headbob_amplitude * cached_speed_factor,
		sin(headbob_time * headbob_frequency) * headbob_amplitude * cached_speed_factor,
		0.0
	)
	
	cam.transform.origin += headbob_offset
